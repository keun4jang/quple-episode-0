extends CanvasLayer
## 지금 어디로 가야 하는지 화면에 표시한다.
##
## 목표는 왼쪽 위에 글자로만 떠 있었다. "사무실에서 애인 찾기" 를 읽어도
## 어느 쪽으로 걸어야 하는지는 알 수 없다. 특히 카메라를 360° 로 돌릴 수 있게
## 되면서 방향 감각이 더 쉽게 흐트러진다.
##
## 화면 안에 있으면 대상 위에 표식을, 화면 밖이면 가장자리에 화살표를 띄운다.
## 거리도 같이 적는다. 힐링 게임이라 몰아붙이지는 않되, 헤매게 두지도 않는다.

const EDGE_MARGIN := 92.0
const NEAR_DIST := 2.2          # 이만큼 가까우면 표식을 지운다. 다 왔는데 계속 띄우면 잔소리다.
const D := preload("res://scripts/ui/design.gd")
const COL := D.ACCENT

var _cam: Camera3D
var _player: Node3D
var _draw: Control
var _target: Node3D
var _t := 0.0


func _ready() -> void:
	add_to_group("quest_marker")
	layer = 6                    # 3D 위, 터치 UI(8) 아래
	_draw = Control.new()
	_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_on_draw)
	add_child(_draw)
	await get_tree().process_frame
	await get_tree().process_frame


func _process(delta: float) -> void:
	_t += delta
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_3d()
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_target = null if _blocked() else _pick_target()
	_draw.queue_redraw()


## 길 안내를 접어야 할 때.
##
## 마커는 3D 위에 그려지므로 그 위에 뜨는 것들과 자리를 다툰다. 실제로 설정
## 창의 슬라이더 한가운데에 "3m" 화살표가 찍혀 손잡이처럼 보였고, 복도에서는
## 대사 위에 겹쳐 "문 너머에서3m목소리가 새" 로 읽혔다.
##
## 레이어를 조절해 봐야 소용없다 — 겹치는 것 자체가 문제다. 설정 창이 떠 있거나
## 대사를 읽는 중이면 어차피 걷지 않는다. 그때는 길 안내가 필요 없다.
func _blocked() -> bool:
	var sv := get_tree().get_first_node_in_group("settings_ui")
	if sv != null and ("visible" in sv) and sv.visible:
		return true
	for g in ["dialogue_box", "album_ui", "wind_note"]:
		var n := get_tree().get_first_node_in_group(g)
		if n != null and ("visible" in n) and n.visible:
			return true
	return false


## 아직 안 쓴 상호작용 지점 중 가장 가까운 것.
##
## 스토리 목표를 노드에 일일이 표시해 두는 방법도 있지만, 이 게임의 씬에는
## 상호작용 지점이 몇 개 없고 진행하면 하나씩 꺼진다. 그래서 "안 쓴 것 중
## 제일 가까운 것" 이 대체로 지금 할 일과 같다. 틀려도 헤매는 것보다 낫다.
func _pick_target() -> Node3D:
	if _player == null:
		return null
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (n is Node3D) or not is_instance_valid(n):
			continue
		if ("_used" in n) and ("one_shot" in n) and n._used and n.one_shot:
			continue
		var d: float = _player.global_position.distance_to(n.global_position)
		# 한 번만 쓰는 지점이 대체로 이야기를 잇는 쪽이다. 조금 더 쳐준다.
		if ("one_shot" in n) and n.one_shot:
			d *= 0.6
		if d < best_d:
			best_d = d
			best = n
	return best


func _on_draw() -> void:
	if _target == null or _cam == null or _player == null:
		return
	var world: Vector3 = _target.global_position + Vector3(0, 1.9, 0)
	var dist: float = _player.global_position.distance_to(_target.global_position)
	if dist < NEAR_DIST:
		return

	var size := _draw.size
	var pulse := 0.82 + sin(_t * 3.0) * 0.18
	var behind := _cam.is_position_behind(world)
	var p := _cam.unproject_position(world)

	if not behind and Rect2(Vector2.ZERO, size).grow(-8.0).has_point(p):
		_draw_on_screen(p, pulse, dist)
	else:
		# 화면 밖(또는 등 뒤) — 가장자리로 밀어 화살표로 방향을 알린다
		if behind:
			p = size * 0.5 + (size * 0.5 - p)
		var c := size * 0.5
		var v := p - c
		if v.length() < 0.001:
			v = Vector2(0, -1)
		var lim := (size * 0.5) - Vector2(EDGE_MARGIN, EDGE_MARGIN)
		var k: float = minf(lim.x / maxf(absf(v.x), 0.001), lim.y / maxf(absf(v.y), 0.001))
		_draw_edge(c + v * k, v.angle(), pulse, dist)


func _draw_on_screen(p: Vector2, pulse: float, dist: float) -> void:
	# 아래를 가리키는 작은 삼각형 + 고리
	var bob := sin(_t * 3.0) * 6.0
	var q := p + Vector2(0, bob)
	var s := 15.0 * pulse
	_draw.draw_colored_polygon(
		PackedVector2Array([q + Vector2(-s, -s), q + Vector2(s, -s), q + Vector2(0, s * 0.9)]),
		Color(COL.r, COL.g, COL.b, 0.92))
	_draw.draw_arc(q + Vector2(0, -s * 2.2), 9.0 * pulse, 0, TAU, 20,
		Color(COL.r, COL.g, COL.b, 0.5), 2.5, true)
	_label(q + Vector2(0, s * 2.4), "%.0fm" % dist)


func _draw_edge(p: Vector2, ang: float, pulse: float, dist: float) -> void:
	var s := 22.0 * pulse
	var dir := Vector2(cos(ang), sin(ang))
	var side := Vector2(-dir.y, dir.x)
	_draw.draw_colored_polygon(
		PackedVector2Array([p + dir * s, p - dir * s * 0.5 + side * s * 0.7,
			p - dir * s * 0.5 - side * s * 0.7]),
		Color(COL.r, COL.g, COL.b, 0.9))
	_label(p - dir * s * 1.9, "%.0fm" % dist)


func _label(at: Vector2, text: String) -> void:
	# 전역 테마의 굵은 한글 폰트를 쓴다. fallback 을 쓰면 여기만 다른 글꼴이 된다.
	var font := _draw.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var sz := D.TEXT_S
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	_draw.draw_string_outline(font, at - Vector2(w * 0.5, -sz * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 6, D.OUTLINE)
	_draw.draw_string(font, at - Vector2(w * 0.5, -sz * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, sz, D.TEXT)
