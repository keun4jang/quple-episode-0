class_name IdleActor
extends Node2D
## 싸우는 그림 하나 (쿼카·몬스터). 걷기 시트(4칸 x 3줄)의 한 줄을 돌리고, 맞으면 하얗게 번쩍인다.
## 원점이 발끝이다.

const SHADER := """shader_type canvas_item;
uniform float flash = 0.0;
uniform vec4 flash_col : source_color = vec4(1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mix(c.rgb, flash_col.rgb, flash);
	COLOR = c;
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
