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

## 손에 든 무기 (직업마다): "" · stick · sword · staff · bow · dagger. 휘두르는 동작이 있어 그림에 넣지 않고 따로 그린다.
var weapon := ""
## 무기를 기본 자세에서 얼마나 돌렸나 (라디안, + 는 등 쪽). 화면 쪽이 트윈으로 휘두른다.
var swing := 0.0
## 무기를 앞으로 내민 거리 (그림 픽셀 단위) - 찌르기·지팡이 내밀기.
var reach := 0.0
## 활시위를 당긴 정도 (0~1).
var pull := 0.0
## 무기가 빛나는 정도 (0~1) - 스킬 쓸 때.
var glow := 0.0
var glow_col := Color.WHITE
## 그림 속 손 자리 (칸 픽셀, 발끝 원점, 옆모습 기준). 칸 크기에서 저절로 잡는다.
var hand := Vector2(-5.5, -11.0)

## 무기 그림 - 위가 끝, `grip` 이 손에 쥐는 자리. 글자 하나가 픽셀 하나다.
const WEAPONS := {
	"stick": {"grip": Vector2(1, 7), "base": -0.45, "rows": [
		".k.", ".h.", "hh.", ".h.", ".h.", ".h.", ".h.", ".h.", ".h."]},
	"sword": {"grip": Vector2(2, 10), "base": -0.35, "rows": [
		"..w..", ".wlw.", ".wlw.", ".wlw.", ".wlw.", ".wlw.", ".wlw.", ".wlw.", "ggygg", "..h..", "..h..",
		"..y.."]},
	"staff": {"grip": Vector2(2, 10), "base": -0.15, "rows": [
		"..b..", ".bBb.", "bBBBb", ".bBb.", "..b..", ".k.k.", "..h..", "..h..", "..h..", "..h..", "..h..",
		"..h..", "..h..", "..h..", "..h.."]},
	"bow": {"grip": Vector2(0, 6), "base": 0.0, "rows": [
		"...h", "..h.", ".h..", ".h..", "h...", "h...", "h...", "h...", "h...", ".h..", ".h..", "..h.",
		"...h"]},
	"dagger": {"grip": Vector2(1, 5), "base": -0.9, "rows": [
		".w.", "wlw", "wlw", "wlw", "ggg", ".h.", ".y."]},
}
const WEAPON_COL := {"w": Color("#F2F6FA"), "l": Color("#A9B4C2"), "g": Color("#E0B23C"),
	"y": Color("#FFDB6E"), "h": Color("#D49A4E"), "k": Color("#F0C070"), "b": Color("#7FA8FF"),
	"B": Color("#E8F1FF")}
const WEAPON_OUTLINE := Color(0.16, 0.10, 0.16, 0.95)
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
		# 손은 몸통 가운데쯤 (옛 칸 17x25 의 14번째 줄 · 3번째 칸) - 위 여백이 늘어도 발끝에서 잰다
		hand = Vector2(1.0 - cell.x * 0.5, -11.0)
	if _shadow != null:
		_shadow.queue_redraw()


## 몸 높이 (px).
func height() -> float:
	return cell.y * px


func _process(dt: float) -> void:
	_t += dt
	flash = maxf(0.0, flash - dt * 5.0)
	glow = maxf(0.0, glow - dt * 2.5)
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
	if weapon != "" and WEAPONS.has(weapon):
		_draw_weapon(squash * Vector2(1.0, breath))


## 무기를 손에 쥐고 그린다. 옆모습은 왼쪽을 보는 그림이라 앞은 -x, `flip` 이면 거울로 뒤집힌다.
func _draw_weapon(k: Vector2) -> void:
	var w: Dictionary = WEAPONS[weapon]
	var at := Vector2(hand.x - reach, hand.y) * px * k
	var m := Transform2D(float(w["base"]) + swing, Vector2(px, px), 0.0, at)
	if flip:
		m = Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2.ZERO) * m
	draw_set_transform_matrix(m)
	var grip: Vector2 = w["grip"]
	var rows: Array = w["rows"]
	if glow > 0.0:
		var gc := glow_col
		gc.a = 0.45 * glow
		draw_rect(Rect2(-grip.x - 1.5, -grip.y - 1.5, String(rows[0]).length() + 3.0, rows.size() + 3.0), gc)
	# 테두리 먼저 - 털 빛깔과 겹쳐도 무기가 또렷하게
	for y in rows.size():
		var r0 := String(rows[y])
		for x in r0.length():
			if r0[x] != ".":
				draw_rect(Rect2(x - grip.x - 0.35, y - grip.y - 0.35, 1.7, 1.7), WEAPON_OUTLINE)
	for y in rows.size():
		var r := String(rows[y])
		for x in r.length():
			var ch := r[x]
			if ch == ".":
				continue
			var c: Color = WEAPON_COL.get(ch, Color.WHITE)
			if glow > 0.0:
				c = c.lerp(glow_col.lightened(0.4), glow * 0.6)
			draw_rect(Rect2(x - grip.x, y - grip.y, 1.0, 1.0), c)
	if weapon == "bow":
		# 활시위 - 당기면 등 쪽으로 휜다. 당긴 동안은 화살이 걸려 있다.
		var top := Vector2(3 - grip.x, -grip.y + 0.5)
		var bot := Vector2(3 - grip.x, rows.size() - 1 - grip.y + 0.5)
		var mid := Vector2(3.5 - grip.x + pull * 3.5, 0.5)
		var sc := Color("#F1EADB")
		draw_line(top, mid, sc, 0.35)
		draw_line(mid, bot, sc, 0.35)
		if pull > 0.05:
			draw_line(mid, Vector2(mid.x - 9.0, 0.5), Color("#C9A23A"), 0.5)
			draw_rect(Rect2(mid.x - 10.0, 0.0, 1.0, 1.0), Color("#F2F6FA"))
