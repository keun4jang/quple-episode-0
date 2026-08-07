extends Node2D
class_name SideMap
## 옆에서 본 맵 하나. 걷고, 뛰고, 사다리를 타고, 계단을 오르고,
## 엘리베이터로 층을 옮기고, 문으로 나간다.
##
## 이 화면이 판단 대상이다 — 캡처 백 장보다 직접 한 번 걸어 보는 쪽이
## 3D 를 계속 갈지 옆에서 보는 2D 로 갈지를 훨씬 빨리 정해 준다.
##
## 배경은 그려 둔 여행지 그림을 겹으로 나눠 쓴다. 뒤로 갈수록 흐리고
## 옅게, 천천히 따라오게 해서 깊이를 만든다.

const Parts := preload("res://scripts/side/side_parts.gd")
const Scenery := preload("res://scripts/travel/scenery.gd")

## 맵 가로 길이. 화면보다 넉넉히 넓어야 걸어 다니는 맛이 난다.
const MAP_W := 5200.0
## 1층 바닥 높이.
const FLOOR_Y := 900.0
## 캐릭터가 올라앉는 물리 레이어. 엘리베이터와 문이 이걸 보고 알아본다.
const WALKER_LAYER := 4

var walker: SideWalker
var _cam: Camera2D
var _layers: Array = []
## 어느 막의 풍경 위에서 걷는가. korea / world / space / beyond
@export var chapter: String = "korea"
## 씬을 바꾸기 전에 밖에서 정해 주는 막. 씬 파일 하나로 여러 풍경을 쓴다.
static var next_chapter := ""
## 걷기를 마치면 돌아갈 곳.
static var return_to := "res://scenes/travel/TravelHub.tscn"


func _ready() -> void:
	if next_chapter != "":
		chapter = next_chapter
	_build_terrain()
	_build_walker()
	_build_camera()
	_build_background()
	_sync_layers()
	_build_hud()
	# 폰에는 키보드가 없다. 없으면 이 화면은 폰에서 아무것도 못 한다.
	add_child(SideTouch.new())


# ─────────────────────────────── 배경 ───────────────────────────────

## 겹마다 다른 속도로 따라오게 한다. 이 어긋남 하나가 평평한 그림을
## 공간으로 만든다 — 멀리 있는 것일수록 천천히 지나간다.
##
## 겹 그림은 `tools/side/make-layers.py` 가 미리 만들어 둔다. 한 장을
## 실행 중에 잡아 늘이면 뭉개지고, 겹마다 필요한 폭도 다르다.
##
## factor 는 "얼마나 가까운가" 다. 0 에 가까울수록 카메라를 그대로
## 따라와서 안 움직이는 것처럼 보이고 — 그게 멀다는 뜻이다.
const LAYERS := [
	{"suffix": "sky", "factor": 0.10, "y": 0.0, "follow_y": true},
	{"suffix": "mid", "factor": 0.42, "y": FLOOR_Y - 560.0, "follow_y": false},
]

func _build_background() -> void:
	for spec in LAYERS:
		var path := "res://assets/side/%s-%s.png" % [chapter, spec["suffix"]]
		var tex := Scenery.tex(path)
		if tex == null:
			continue
		var tr := TextureRect.new()
		tr.name = "Layer_" + str(spec["suffix"])
		tr.texture = tex
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.z_index = -50
		add_child(tr)
		_layers.append({
			"node": tr, "factor": spec["factor"],
			"y": spec["y"], "follow_y": spec["follow_y"],
			"w": float(tex.get_width()),
		})


## 겹을 카메라에 맞춰 되민다.
##
## 카메라가 x 만큼 갔을 때 겹을 x·(1-f) 만큼 같이 밀면, 화면에서는 x·f
## 만큼만 지나간 것으로 보인다. f 가 작을수록 덜 움직이니 멀어 보인다.
## 화면 절반만큼 왼쪽으로 당겨 두는 것은, 카메라가 원점에 있을 때 겹의
## 왼쪽 끝이 화면 안으로 들어와 검은 띠가 생기는 것을 막기 위해서다.
func _sync_layers() -> void:
	var vp := get_viewport_rect().size
	for l in _layers:
		var n: CanvasItem = l["node"]
		var f: float = l["factor"]
		n.position.x = _cam.global_position.x * (1.0 - f) - vp.x * 0.5
		if l["follow_y"]:
			n.position.y = _cam.global_position.y - vp.y * 0.5
		else:
			n.position.y = l["y"]


# ─────────────────────────────── 지형 ───────────────────────────────

func _build_terrain() -> void:
	var t := Node2D.new()
	t.name = "Terrain"
	add_child(t)

	# 1층 바닥 — 계단 자리를 비워 두고 두 토막으로 깐다
	Parts.platform(t, -400, FLOOR_Y, 2500, 400)
	Parts.stairs(t, 2100, FLOOR_Y - 240, 520, 240, 7, true)
	Parts.platform(t, 2620, FLOOR_Y - 240, 1200, 640)
	Parts.stairs(t, 3820, FLOOR_Y - 240, 460, 240, 7, false)
	Parts.platform(t, 4280, FLOOR_Y, 1600, 400)

	# 2층 — 사다리로 올라가는 선반
	Parts.platform(t, 620, FLOOR_Y - 470, 900, 40, true)
	Parts.ladder(t, 700, FLOOR_Y - 470, 470)

	# 공중 발판 — 점프로만 닿는다
	Parts.platform(t, 1650, FLOOR_Y - 300, 300, 34, true)
	Parts.platform(t, 2060, FLOOR_Y - 520, 300, 34, true)

	# 엘리베이터 — 계단 위 층에서 더 높은 곳으로.
	#
	# 아래층에서 설 때 발판 윗면이 통로와 **딱 맞아야** 한다. 10px 만
	# 솟아 있어도 걸어가던 발이 턱에 걸려 길이 막힌다 — 실제로 그래서
	# 계단을 내려가지 못했다. 발판은 20 두께에 가운데가 원점이므로
	# 통로 높이보다 10 아래에 세운다.
	Parts.elevator(t, 3300, FLOOR_Y - 790, FLOOR_Y - 230)
	# 위층 내리는 자리는 엘리베이터 **옆**에 둔다. 겹쳐 놓으면 도착하는
	# 순간 그 발판으로 올라서 버려서, 다시 내려갈 방법이 없어진다.
	Parts.platform(t, 3450, FLOOR_Y - 800, 420, 34, true)

	# 문 — 다음 맵으로
	var d := Parts.door(t, 5100, FLOOR_Y, "다음 길")
	d.collision_mask = WALKER_LAYER
	d.body_entered.connect(func(b): if b is SideWalker: _door_body = d; _say("위를 누르면 다음 길로"))
	d.body_exited.connect(func(b): if b is SideWalker: _door_body = null; _say(""))


# ─────────────────────────────── 캐릭터 ───────────────────────────────

func _build_walker() -> void:
	walker = SideWalker.new()
	walker.name = "Leader"
	walker.position = Vector2(240, FLOOR_Y - 10)
	# 캐릭터도 어느 레이어엔가 있어야 엘리베이터·문이 알아본다.
	walker.collision_layer = WALKER_LAYER
	walker.collision_mask = Parts.L_SOLID | Parts.L_ONEWAY

	var art := Sprite2D.new()
	art.name = "Art"
	walker.add_child(art)
	var cs := CollisionShape2D.new()
	cs.name = "Shape"
	cs.shape = CapsuleShape2D.new()
	walker.add_child(cs)

	# 사다리를 감지하는 더듬이. 사다리 자신이 아니라 이쪽이 찾는다.
	var probe := Area2D.new()
	probe.name = "LadderProbe"
	probe.collision_mask = Parts.L_SOLID   # 사다리 Area 가 여기 올라 있다
	probe.monitoring = true
	var pcs := CollisionShape2D.new()
	var prs := RectangleShape2D.new()
	prs.size = Vector2(40, 170)
	pcs.shape = prs
	pcs.position = Vector2(0, -85)
	probe.add_child(pcs)
	walker.add_child(probe)
	probe.area_entered.connect(func(a: Area2D):
		if a.name == "Ladder":
			walker.ladder_entered(a))
	probe.area_exited.connect(func(a: Area2D):
		if a.name == "Ladder":
			walker.ladder_exited(a))

	add_child(walker)
	walker.landed.connect(_on_landed)


func _on_landed(strength: float) -> void:
	if strength > 0.45:
		_puff(walker.global_position)


## 착지 먼지. 세게 떨어졌다는 것을 몸의 눌림만으로는 다 못 말한다.
func _puff(at: Vector2) -> void:
	for i in range(5):
		var p := ColorRect.new()
		p.color = Color(1, 1, 1, 0.55)
		p.size = Vector2(16, 16)
		p.position = at + Vector2(randf_range(-30, 30), -8)
		p.z_index = 5
		add_child(p)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(p, "position", p.position + Vector2(randf_range(-70, 70), -34), 0.4)
		tw.tween_property(p, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(p.queue_free)


# ─────────────────────────────── 카메라 ───────────────────────────────

func _build_camera() -> void:
	_cam = Camera2D.new()
	_cam.name = "Cam"
	# 캐릭터를 화면 한가운데 못박아 두면 앞이 안 보인다. 조금 앞을 보게
	# 하고, 따라오는 속도를 늦춰 걸음이 화면을 끄는 느낌을 만든다.
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 6.0
	_cam.limit_left = -300
	_cam.limit_right = int(MAP_W + 300)
	_cam.limit_bottom = 1300
	add_child(_cam)


func _process(delta: float) -> void:
	if walker == null or _cam == null:
		return
	var look := walker.facing * 190.0
	var want := walker.global_position + Vector2(look, -230.0)
	_cam.global_position = _cam.global_position.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
	_sync_layers()
	_at_door(delta)


## 문 앞에서 위를 누르면 나간다.
var _door_body: Area2D = null

func _at_door(_d: float) -> void:
	if _door_body == null:
		return
	if Input.is_action_just_pressed("move_up"):
		_say("다음 길로! (이 예시에서는 처음으로 돌아가요)")
		walker.global_position = Vector2(240, FLOOR_Y - 10)
		walker.velocity = Vector2.ZERO


# ─────────────────────────────── 안내 ───────────────────────────────

var _hint: Label


func _build_hud() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 9
	add_child(cl)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 34)
	_hint.add_theme_color_override("font_color", Color("#FDFBD4"))
	_hint.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.12))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.position = Vector2(-600, 40)
	_hint.size = Vector2(1200, 44)
	cl.add_child(_hint)
	_say("좌우로 걷고, 점프로 뛰고, 위아래로 사다리와 엘리베이터를 탄다")

	# 돌아가는 길. 없으면 폰에서 이 화면에 갇힌다.
	var back := Button.new()
	back.text = "← 돌아가기"
	back.add_theme_font_size_override("font_size", 30)
	back.position = Vector2(32, 28)
	back.custom_minimum_size = Vector2(220, 76)
	back.pressed.connect(func(): SceneTransition.go_to(return_to, "quiet"))
	cl.add_child(back)


func _say(s: String) -> void:
	if _hint != null:
		_hint.text = s
