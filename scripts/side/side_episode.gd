extends Node2D
class_name SideEpisode
## 0편 맵의 옆에서 보는 판. 네 맵이 이걸 물려받는다.
##
## 3D 맵을 갈아엎으면서도 **이야기는 한 글자도 바꾸지 않는다.** 대사, 순서,
## 상태 전이는 그대로다 — 바뀌는 것은 그 이야기가 벌어지는 화면뿐이다.
## 그래서 0편 진행 테스트가 그대로 통과해야 하고, 통과하지 않으면 옮기다
## 흘린 것이 있다는 뜻이다.
##
## 물려받는 쪽이 할 일은 `build()` 하나다. 지형을 깔고, 자리(spot)를 놓고,
## 문을 단다. 카메라·조작·대사창·파트너는 여기서 다 해 준다.

const Parts := preload("res://scripts/side/side_parts.gd")
const Indoor := preload("res://scripts/side/indoor_parts.gd")

## 바닥 높이. 네 맵이 같은 높이를 쓰면 맵을 넘나들 때 눈이 안 흔들린다.
const FLOOR_Y := 860.0
## 캐릭터가 올라앉는 물리 레이어.
const WALKER_LAYER := 4

var walker: SideWalker
var partner: Sprite2D
var dialogue_box: Node
var choice_box: Node

var _cam: Camera2D
var _spots: Array = []          # [{area, label, cb, once, done}]
var _here: Dictionary = {}      # 지금 겹쳐 있는 자리
var _prompt: Label
var _title: Label
var _objective: Label
var _items_row: Label
## 화면 밖의 갈 곳을 가리키는 가장자리 화살표.
var _edge_arrow: Label
var _map_w := 4200.0
var _start_x := 300.0
## 파트너가 따라오는가. 합류한 뒤로는 늘 붙어 다닌다.
var _partner_follows := false


# ─────────────────────────── 물려받는 쪽이 채운다 ───────────────────────────

## 지형·자리·문을 놓는다.
func build() -> void:
	pass

## 맵에 들어선 직후 벌어지는 일 (독백, 상태 전이).
func on_enter() -> void:
	pass

## 화면 왼쪽 위에 뜨는 곳 이름.
func map_title() -> String:
	return ""


# ─────────────────────────────── 뼈대 ───────────────────────────────

func _ready() -> void:
	add_to_group("side_episode")
	_build_ui()
	build()
	_build_walker()
	_build_walls()
	_build_camera()
	_sync_backdrop()
	_touch = SideTouch.new()
	add_child(_touch)
	if _title != null:
		_title.text = map_title()
	AudioManager.play_bgm("episode0")
	await get_tree().process_frame
	on_enter()


## 그려 받은 배경이 있으면 걸고, 없으면 false. 있으면 코드로 그리는
## 하늘·벽·천장은 건너뛴다 — 겹쳐 그리면 그림이 가려진다.
##
## 이 화면이 실제로 보는 세로 범위에 맞춰 그림이 만들어져 있으므로,
## 여기서는 가로로만 카메라를 따라 되밀어 주면 된다.
const BACKDROP_TOP := -240.0

var _backdrop: TextureRect
var _backdrop_factor := Indoor.BACKDROP_FACTOR
var _touch: SideTouch

func use_backdrop(map_name: String) -> bool:
	_backdrop = Indoor.backdrop(self, map_name)
	_backdrop_factor = Indoor.backdrop_factor(map_name)
	return _backdrop != null


func _sync_backdrop() -> void:
	if _backdrop == null:
		return
	# 줌이 1이 아니면 화면이 실제로 보는 폭은 vp/zoom 이다.
	var half_w := get_viewport_rect().size.x * 0.5 / CAM_ZOOM
	_backdrop.position = Vector2(
		_cam.global_position.x * (1.0 - _backdrop_factor) - half_w,
		BACKDROP_TOP)


## 맵 양 끝의 보이지 않는 벽.
##
## 카메라는 끝에서 멈추는데 캐릭터는 계속 걸어 나가서, 화면 밖 그림도
## 없는 곳까지 가 버릴 수 있었다. 걷다 만나는 것이 낭떠러지가 아니라
## 벽이어야 안심하고 끝까지 걸어 본다.
func _build_walls() -> void:
	for x in [-40.0, _map_w + 40.0]:
		var wall := StaticBody2D.new()
		wall.name = "EdgeWall"
		wall.position = Vector2(x, FLOOR_Y - 400)
		wall.collision_layer = Parts.L_SOLID
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(80, 1400)
		cs.shape = rs
		wall.add_child(cs)
		add_child(wall)


## 맵 크기와 들어서는 자리. build() 안에서 부른다.
func set_bounds(w: float, start_x: float) -> void:
	_map_w = w
	_start_x = start_x


# ─────────────────────────────── 자리 ───────────────────────────────

## 무언가 할 수 있는 자리를 놓는다.
##
## 3D 쪽 Interactable 과 같은 일을 한다 — 가까이 가면 무엇을 할 수 있는지
## 뜨고, 조사 버튼을 누르면 벌어진다. 다른 점은 판정이 앞뒤가 아니라
## **가로 한 줄뿐**이라는 것이고, 그래서 훨씬 덜 헷갈린다.
##
## once 면 한 번만 된다 (물건 줍기). 아니면 몇 번이든 된다 (말 걸기).
func spot(x: float, label: String, cb: Callable, once := false, w := 190.0) -> Area2D:
	var a := Area2D.new()
	a.name = "Spot"
	a.position = Vector2(x, FLOOR_Y)
	a.collision_mask = WALKER_LAYER
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	# 세로를 캐릭터 키(175)보다 넉넉히 잡는다. 260 이었을 때 책상 위
	# 물건의 판정이 바닥에 선 캐릭터의 머리와 8px 차이로 안 겹쳐서,
	# 앞에 서 있는데도 "선택" 이 안 떴다.
	rs.size = Vector2(w, 320)
	cs.shape = rs
	cs.position = Vector2(0, -150)
	a.add_child(cs)
	add_child(a)
	var rec := {"area": a, "label": label, "cb": cb, "once": once, "done": false, "locked": false}
	_spots.append(rec)
	a.body_entered.connect(func(b): if b is SideWalker: _here[a] = rec; _refresh_prompt())
	a.body_exited.connect(func(b): if b is SideWalker: _here.erase(a); _refresh_prompt())
	return a


## 자리를 잠그거나 푼다. 아직 할 때가 아닌 것은 뜨지 않아야 한다 —
## 보이지도 않는 일에 버튼만 떠 있으면 눌러 보고 실망한다.
func lock_spot(a: Area2D, locked: bool) -> void:
	for r in _spots:
		if r["area"] == a:
			r["locked"] = locked
	_refresh_prompt()


func set_spot_label(a: Area2D, label: String) -> void:
	for r in _spots:
		if r["area"] == a:
			r["label"] = label
	_refresh_prompt()


## 다른 맵으로 나가는 문. 포탈처럼 빛나야 문인 줄 안다 —
## 문틀만 그려 두니 배경 그림에 묻혀서 지나가는 사람이 못 알아봤다.
func door(x: float, label: String, path: String, style := "normal") -> Area2D:
	Indoor.door_frame(self, x, FLOOR_Y, Indoor.GLASS, _backdrop != null)

	# 숨쉬는 빛무리
	var glow := ColorRect.new()
	glow.color = Color(1.0, 0.9, 0.55, 0.16)
	glow.size = Vector2(300, 340)
	glow.position = Vector2(x - 150, FLOOR_Y - 320)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.z_index = -1
	add_child(glow)
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "color:a", 0.30, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "color:a", 0.12, 1.1).set_trans(Tween.TRANS_SINE)

	# 위아래로 까딱이는 화살표. 메이플 포탈 위의 그 화살표다.
	var arrow := Label.new()
	arrow.text = "▼"
	arrow.add_theme_font_size_override("font_size", 44)
	arrow.add_theme_color_override("font_color", Color("#FFE7A8"))
	arrow.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	arrow.add_theme_constant_override("outline_size", 8)
	arrow.position = Vector2(x - 22, FLOOR_Y - 360)
	add_child(arrow)
	var tw2 := create_tween().set_loops()
	tw2.tween_property(arrow, "position:y", FLOOR_Y - 336.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(arrow, "position:y", FLOOR_Y - 360.0, 0.55).set_trans(Tween.TRANS_SINE)

	return spot(x, label, func(): SceneTransition.go_to(path, style))


func _refresh_prompt() -> void:
	if _prompt == null:
		return
	var r := _live_spot()
	# 기호를 "선택" 으로 바꾼다. ▲ 는 십자 방향키 시절의 흔적이라,
	# 밝아지는 버튼과 화면의 기호가 서로 다른 곳을 가리키고 있었다.
	_prompt.text = ("선택 ·  " + str(r["label"])) if not r.is_empty() else ""
	if _touch != null:
		_touch.highlight_interact(not r.is_empty())


## 지금 할 수 있는 일. 없으면 빈 사전.
##
## 잠긴 자리와 이미 한 번 쓴 자리는 건너뛴다. null 이 아니라 빈 사전을
## 돌려주는 것은 GDScript 가 함수의 반환 타입을 알 수 있게 하려는 것이다.
func _live_spot() -> Dictionary:
	for a in _here:
		var r: Dictionary = _here[a]
		if r["locked"] or (r["once"] and r["done"]):
			continue
		return r
	return {}


func _unhandled_input(e: InputEvent) -> void:
	if not (e.is_action_pressed("move_up") or e.is_action_pressed("interact")):
		return
	# 사다리를 타는 중에 위를 누른 것은 오르라는 뜻이지 조사가 아니다.
	if walker != null and walker.state == SideWalker.State.LADDER:
		return
	var r := _live_spot()
	if r.is_empty():
		return
	r["done"] = true
	_refresh_prompt()
	get_viewport().set_input_as_handled()
	(r["cb"] as Callable).call()


# ─────────────────────────────── 캐릭터 ───────────────────────────────

func _build_walker() -> void:
	walker = SideWalker.new()
	walker.name = "Leader"
	walker.position = Vector2(_start_x, FLOOR_Y - 10)
	walker.collision_layer = WALKER_LAYER
	walker.collision_mask = Parts.L_SOLID | Parts.L_ONEWAY
	walker.body_height = 175.0

	var art := Sprite2D.new()
	art.name = "Art"
	walker.add_child(art)
	var cs := CollisionShape2D.new()
	cs.name = "Shape"
	cs.shape = CapsuleShape2D.new()
	walker.add_child(cs)

	var probe := Area2D.new()
	probe.name = "LadderProbe"
	probe.collision_mask = Parts.L_SOLID
	var pcs := CollisionShape2D.new()
	var prs := RectangleShape2D.new()
	prs.size = Vector2(40, 160)
	pcs.shape = prs
	pcs.position = Vector2(0, -80)
	probe.add_child(pcs)
	walker.add_child(probe)
	probe.area_entered.connect(func(a: Area2D): if a.name == "Ladder": walker.ladder_entered(a))
	probe.area_exited.connect(func(a: Area2D): if a.name == "Ladder": walker.ladder_exited(a))

	add_child(walker)
	walker.add_to_group("player")

	if Episode0State.partner_joined:
		spawn_partner()


## 합류한 애인. 캐릭터가 아니라 따라다니는 그림이다 —
## 둘 다 물리로 굴리면 서로 밀치다가 문에 낀다.
func spawn_partner() -> void:
	if partner != null:
		return
	var tex := load("res://assets/mascots/sheet/partner-side.png") as Texture2D
	if tex == null:
		return
	partner = Sprite2D.new()
	partner.name = "Partner"
	partner.texture = tex
	var s := 168.0 / float(tex.get_height())
	partner.scale = Vector2(s, s)
	partner.offset = Vector2(0, -tex.get_height() * 0.5)
	partner.position = Vector2(_start_x - 150.0, FLOOR_Y)
	add_child(partner)
	_partner_follows = true


## 몇 걸음 뒤에서 따라온다. 딱 붙어 오면 겹쳐서 한 마리로 보인다.
const FOLLOW_GAP := 150.0

func _follow_partner(delta: float) -> void:
	if partner == null or walker == null:
		return
	var want := walker.global_position.x - walker.facing * FOLLOW_GAP
	var dx := want - partner.position.x
	var walking := absf(dx) > 12.0
	if walking:
		partner.position.x += clampf(dx, -420.0, 420.0) * clampf(delta * 3.2, 0.0, 1.0)
		partner.flip_h = dx < 0.0

	# 세로도 따라와야 한다.
	#
	# 예전에는 y 를 늘 1층 바닥(FLOOR_Y)으로 두었다. 그래서 엘리베이터로
	# 2층에 올라가면 파트너만 541px 아래 남아, 통로 밑 허공을 나란히
	# 걸어가는 그림이 됐다 — 합류가 로비에서 일어나고 바로 다음 목적지가
	# 2층 문이라, 하필 합류 직후에 제일 먼저 보이는 장면이었다.
	#
	# 물리로 굴리지 않는 그림이므로 층을 "따라 붙는다". 리더가 사다리나
	# 엘리베이터로 올라가면 파트너도 부드럽게 그 높이로 올라온다.
	var bob := sin(Time.get_ticks_msec() * (0.010 if walking else 0.0022)) * (5.0 if walking else 2.0)
	var want_y := walker.global_position.y + bob
	partner.position.y += (want_y - partner.position.y) * clampf(delta * 3.0, 0.0, 1.0)


# ─────────────────────────────── 카메라 ───────────────────────────────

## 실내는 천장부터 바닥까지가 한 화면에 들어와야 방으로 보인다.
##
## 처음엔 캐릭터를 계속 따라 올려다봤더니, 화면에 창밖 도시만 가득하고
## 천장도 바닥도 안 보여서 어디에 서 있는지 알 수 없었다. 세로로는
## 캐릭터를 좇되 방을 벗어나지 않게 묶어 둔다.
const CAM_Y_MIN := 380.0
const CAM_Y_MAX := 480.0
## 카메라를 이만큼 뒤로 뺀다. 1.0 이면 캐릭터가 화면의 1/5 을 차지해서
## 방보다 캐릭터를 보는 화면이 됐다. 뒤로 빼면 방이 넓어 보이고 앞이
## 더 멀리 보인다.
##
## 주의: 값을 더 낮추려면 배경 그림의 세로(1340px)와 가로 여유
## (import-indoor-bg.py 의 SCREEN_W)도 같이 늘려야 한다. 보이는 범위가
## 그림보다 커지면 가장자리에 검은 띠가 생긴다.
const CAM_ZOOM := 0.88

func _build_camera() -> void:
	_cam = Camera2D.new()
	_cam.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 6.0
	_cam.limit_left = 0
	_cam.limit_right = int(_map_w)
	add_child(_cam)
	_cam.global_position = Vector2(walker.global_position.x, _cam_y())


func _process(delta: float) -> void:
	if walker == null or _cam == null:
		return
	var want := Vector2(walker.global_position.x + walker.facing * 150.0, _cam_y())
	_cam.global_position = _cam.global_position.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
	_sync_backdrop()
	_follow_partner(delta)
	_update_edge_arrow()


func _cam_y() -> float:
	return clampf(walker.global_position.y - 300.0, CAM_Y_MIN, CAM_Y_MAX)


# ─────────────────────────────── 화면 ───────────────────────────────

func _build_ui() -> void:
	var cl := CanvasLayer.new()
	cl.name = "SideUI"
	cl.layer = 9
	add_child(cl)

	_title = _mk_label(30, Color("#CFC9E8"))
	_title.position = Vector2(-600, 20)
	_title.size = Vector2(1200, 40)
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	cl.add_child(_title)

	# 설정. 옆맵 안에서는 소리 조절도, 메인으로 나가는 길도 이것뿐이다.
	# 목표 표시 — 메이플의 퀘스트 트래커 자리(왼쪽 위).
	#
	# 다른 게임들과 나란히 놓고 보면 우리 옆맵에 없던 것이 이것이다.
	# 지금 뭘 해야 하는지가 화면에 없으면, 대사를 한 번 놓친 사람은
	# 맵을 헤매는 수밖에 없다. 3D 쪽의 바람 노트가 하던 일을 여기서 한다.
	_objective = Label.new()
	_objective.add_theme_font_size_override("font_size", 30)
	_objective.add_theme_color_override("font_color", Color("#FDFBD4"))
	_objective.add_theme_color_override("font_outline_color", Color(0.07, 0.06, 0.11))
	_objective.add_theme_constant_override("outline_size", 8)
	_objective.position = Vector2(48, 44)
	cl.add_child(_objective)

	# 수집 진행 — 메이플이 "몬스터 11/26" 을 띄우는 그 자리다.
	# 여행 물품을 챙기는 동안에만 나타난다.
	_items_row = Label.new()
	_items_row.add_theme_font_size_override("font_size", 30)
	_items_row.add_theme_color_override("font_color", Color("#FFE7A8"))
	_items_row.add_theme_color_override("font_outline_color", Color(0.07, 0.06, 0.11))
	_items_row.add_theme_constant_override("outline_size", 8)
	_items_row.position = Vector2(48, 92)
	cl.add_child(_items_row)

	# 화면 끝 안내 화살표 — 메이플의 퀘스트 화살표 자리.
	#
	# 회사 앞에서 시작하면 들어갈 문이 화면 밖 1300px 너머다. 포탈이
	# 아무리 빛나도 화면에 없으면 소용이 없다 — 어느 쪽으로 가야 하는지를
	# 화면 가장자리가 말해 줘야 한다.
	_edge_arrow = Label.new()
	_edge_arrow.add_theme_font_size_override("font_size", 40)
	_edge_arrow.add_theme_color_override("font_color", Color("#FFE7A8"))
	_edge_arrow.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	_edge_arrow.add_theme_constant_override("outline_size", 8)
	_edge_arrow.visible = false
	cl.add_child(_edge_arrow)

	Episode0State.state_changed.connect(func(_s): _refresh_hud())
	_refresh_hud()

	# 메이플처럼 오른쪽 위 구석. 왼쪽 위는 곳 이름이 쓴다.
	var gear := Button.new()
	gear.name = "SettingsBtn"
	gear.text = "⚙ 설정"
	gear.add_theme_font_size_override("font_size", 30)
	# 높이 84 는 이 화면이 스스로 쓰는 하한(점프 160, 선택 236)의 절반이라
	# 손가락에 안 맞았다. 여백도 조작 버튼과 같은 48 로 맞춘다 — 20/36 은
	# 노치와 둥근 모서리에 물린다.
	gear.custom_minimum_size = Vector2(168, 116)
	gear.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gear.position = Vector2(-216, 48)
	gear.pressed.connect(_open_settings)
	cl.add_child(gear)

	_prompt = _mk_label(36, Color("#FDFBD4"))
	_prompt.position = Vector2(-600, 66)
	_prompt.size = Vector2(1200, 48)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	cl.add_child(_prompt)

	# 대사창과 선택지는 3D 때 쓰던 것을 그대로 쓴다. 이야기를 옮기는 것이지
	# 다시 만드는 것이 아니다.
	dialogue_box = load("res://scenes/ui/DialogueBox.tscn").instantiate()
	add_child(dialogue_box)
	_move_dialogue_to_top()
	choice_box = load("res://scenes/ui/ChoiceBox.tscn").instantiate()
	add_child(choice_box)
	# 선택지가 떠 있는 동안에는 조작을 감춘다.
	#
	# 선택지 패널은 화면을 가로지르는데 그 위에 조이스틱·점프·선택이
	# 그대로 떠 있었다. 버튼이 터치를 먼저 가로채기 때문에, 두 번째
	# 선택지를 눌러도 버튼이 먹고 **첫 번째가 골라졌다** — 이야기 분기가
	# 손가락이 아니라 우연으로 정해지고 있었다.
	choice_box.visibility_changed.connect(_on_choice_visibility)


## 대사창을 위로 올린다.
##
## 3D 때는 화면 아래가 비어 있어서 거기가 대사 자리였다. 옆에서 보는
## 화면은 다르다 — 아래 왼쪽에 방향 십자, 아래 오른쪽에 점프가 있고
## 캐릭터도 아래쪽에 선다. 그 자리에 대사를 놓으면 셋이 겹친다.
func _move_dialogue_to_top() -> void:
	var p := dialogue_box.get_node_or_null("PanelRect") as Control
	if p == null:
		return
	p.anchor_top = 0.0
	p.anchor_bottom = 0.0
	p.anchor_left = 0.0
	p.anchor_right = 1.0
	p.offset_left = 420.0
	p.offset_right = -420.0
	p.offset_top = 120.0
	p.offset_bottom = 262.0


## 갈 수 있는 자리 중 화면 밖에 있는 가장 가까운 곳을 가장자리에서 가리킨다.
##
## 이미 화면 안에 보이거나 캐릭터가 그 위에 서 있으면 숨긴다 —
## 화살표는 "안 보이는 것" 을 가리킬 때만 값어치가 있다.
func _update_edge_arrow() -> void:
	if _edge_arrow == null or walker == null or _cam == null:
		return
	var half_w := get_viewport_rect().size.x * 0.5 / CAM_ZOOM
	var view_l := _cam.global_position.x - half_w
	var view_r := _cam.global_position.x + half_w
	var best_x := 0.0
	var best_d := 1e12
	for rec in _spots:
		if rec["locked"] or (rec["once"] and rec["done"]):
			continue
		var sx: float = (rec["area"] as Area2D).global_position.x
		if sx > view_l and sx < view_r:
			continue                      # 화면 안이면 화살표가 필요 없다
		var d := absf(sx - walker.global_position.x)
		if d < best_d:
			best_d = d
			best_x = sx
	if best_d > 1e11:
		_edge_arrow.visible = false
		return
	_edge_arrow.visible = true
	var vp := get_viewport().get_visible_rect().size
	var bob := sin(Time.get_ticks_msec() * 0.006) * 10.0
	if best_x > walker.global_position.x:
		_edge_arrow.text = "▶"
		_edge_arrow.position = Vector2(vp.x - 96 + bob, vp.y * 0.42)
	else:
		_edge_arrow.text = "◀"
		_edge_arrow.position = Vector2(56 + bob, vp.y * 0.42)


## 목표와 수집 현황을 새로 쓴다. 상태가 바뀔 때와 물건을 주울 때 부른다.
func _refresh_hud() -> void:
	if _objective != null:
		var obj := Episode0State.get_objective()
		_objective.text = ("🎯 " + obj) if obj != "" else ""
	if _items_row != null:
		var st := Episode0State.current_state
		if st == Episode0State.State.COLLECT_TRAVEL_ITEMS \
				or (st == Episode0State.State.RETURN_BADGE
					and not Episode0State.all_items_collected()):
			# 이모지 대신 이름으로 쓴다. 📓 는 기기 폰트에 없어 깨진 네모로
			# 나왔고, "…" 은 처음 본 사람에게 "아직" 인지 "여러 개" 인지
			# 알 수 없는 기호였다.
			_items_row.text = "카메라 %s   수첩 %s   가방 %s" % [
				"✓" if Episode0State.has_camera else "·",
				"✓" if Episode0State.has_notebook else "·",
				"✓" if Episode0State.has_travel_bag else "·"]
		else:
			_items_row.text = ""


## 선택지가 열리면 조작을 감추고, 닫히면 되돌린다.
func _on_choice_visibility() -> void:
	if _touch == null or choice_box == null:
		return
	_touch.visible = not choice_box.visible
	if choice_box.visible:
		# 감추기 전에 눌린 것들을 놓아 준다. 안 그러면 감춰진 채로
		# 계속 걷는다 — 선택지를 고르고 나면 혼자 벽으로 걸어가 있다.
		_touch.release_all()


func _open_settings() -> void:
	var sv: Node = get_tree().get_first_node_in_group("settings_ui")
	if sv == null:
		sv = load("res://scenes/ui/SettingsUI.tscn").instantiate()
		add_child(sv)
		await get_tree().process_frame
	sv.open()


func _mk_label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.07, 0.06, 0.11))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 대사 한 줄 띄우고 기다린다.
func say(text: String, secs := 2.2) -> void:
	if dialogue_box != null:
		dialogue_box.show_text(text)
	if secs > 0.0:
		await get_tree().create_timer(secs).timeout


func hide_say() -> void:
	if dialogue_box != null and dialogue_box.has_method("hide_box"):
		dialogue_box.hide_box()
