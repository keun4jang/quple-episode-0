class_name IdleActor
extends Node2D
## 싸우는 그림 하나 (쿼카·몬스터). 걷기 시트(4칸 x 3줄)의 한 줄을 돌리고, 맞으면 하얗게 번쩍인다.
## 원점이 발끝이다.

## 테두리(`godot-shaders-basics` 의 outline) + 맞을 때 번쩍임 + 사라질 때 빛나는 가장자리로 녹아내림(dissolve).
## 테두리가 있으면 복잡한 풍경 위에서도 작은 도트 그림이 또렷하다.
const SHADER := """shader_type canvas_item;
uniform float flash = 0.0;
uniform vec4 flash_col : source_color = vec4(1.0);
uniform vec4 outline_col : source_color = vec4(0.16, 0.10, 0.16, 0.85);
uniform float dissolve = 0.0;
uniform vec4 edge_col : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform sampler2D noise_tex : repeat_enable;
varying vec4 vcol;
void vertex() {
	vcol = COLOR;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float n = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float ol = step(0.5, n) * (1.0 - step(0.5, c.a));
	vec4 col = mix(c, outline_col, ol);
	col.rgb = mix(col.rgb, flash_col.rgb, clamp(flash, 0.0, 1.0));
	float nz = texture(noise_tex, UV * 5.0).r;
	float on = step(0.001, dissolve);
	float keep = step(dissolve, nz);
	float edge = step(dissolve, nz + 0.1) * (1.0 - keep) * on;
	col.rgb = mix(col.rgb, edge_col.rgb, edge);
	col.a *= max(keep, edge);
	COLOR = col * vcol;
}
"""

var tex: Texture2D
var cell := Vector2(16, 16)
var row := 1
var flip := false
var px := 4.0
var walking := false
var flash := 0.0
var flash_col := Color.WHITE
## 0 이면 멀쩡, 1 이면 다 녹아 사라짐.
var dissolve := 0.0
var edge_col := Color(1.0, 0.9, 0.6)
static var _noise: Texture2D
var squash := Vector2.ONE
var _t := 0.0
var _mat: ShaderMaterial
var _shadow: Node2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	material = _mat
	if _noise == null:
		var nt := NoiseTexture2D.new()
		nt.width = 64
		nt.height = 64
		nt.seamless = true
		var fn := FastNoiseLite.new()
		fn.frequency = 0.08
		nt.noise = fn
		_noise = nt
	_mat.set_shader_parameter("noise_tex", _noise)
	_shadow = Node2D.new()
	_shadow.show_behind_parent = true
	_shadow.draw.connect(func() -> void:
		_shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.28))
		_shadow.draw_circle(Vector2.ZERO, cell.x * px * 0.45, Color(0.1, 0.08, 0.15, 0.25)))
	add_child(_shadow)


func set_sheet(path: String) -> void:
	tex = load(path) if ResourceLoader.exists(path) else null
	if tex != null:
		cell = Vector2(tex.get_width() / 4.0, tex.get_height() / 3.0)
	if _shadow != null:
		_shadow.queue_redraw()


## 몸 높이 (px).
func height() -> float:
	return cell.y * px


func _process(dt: float) -> void:
	_t += dt
	flash = maxf(0.0, flash - dt * 5.0)
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-14.0 * dt))
	if _mat != null:
		_mat.set_shader_parameter("flash", flash)
		_mat.set_shader_parameter("flash_col", flash_col)
		_mat.set_shader_parameter("dissolve", dissolve)
		_mat.set_shader_parameter("edge_col", edge_col)
	queue_redraw()


func _draw() -> void:
	if tex == null:
		return
	var f := int(_t * 9.0) % 4 if walking else 0
	var breath := 1.0 + sin(_t * 3.2) * 0.03 if not walking else 1.0 + absf(sin(_t * 9.0)) * 0.04
	var sz := cell * px * squash * Vector2(1.0, breath)
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture_rect_region(tex, Rect2(-sz.x * 0.5, -sz.y, sz.x, sz.y),
		Rect2(Vector2(f * cell.x, row * cell.y), cell))
