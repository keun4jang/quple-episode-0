extends CanvasLayer
## 화면 아무 데나 톡 치면 그 자리에 반응이 생긴다.
##
## 지금까지 이 게임은 정해진 버튼과 상호작용 지점 말고는 아무리 만져도
## 아무 일이 없었다. 힐링 게임에서 "만졌더니 뭔가 일어났다" 는 가장 작은
## 단위이고, 그게 없으면 화면이 죽은 것으로 느껴진다.
##
## 하는 일
##   1) 톡 친 자리에 작은 파장(고리)과 점 몇 개가 퍼졌다 사라진다
##   2) 소리 하나 (AudioManager.touch_tap — 들릴락 말락 하게)
##   3) 3D 물체를 쳤고 그게 상호작용 지점이면 아주 살짝 기울었다 돌아온다
##
## 세기 기준은 "있는지 모르겠지만 없으면 허전한" 정도다.
## 고리는 반투명 흰빛, 지름은 손가락 하나보다 조금 크고, 0.5 초면 사라진다.
##
## 안 하는 곳
##   - 끌기(카메라 돌리기). 24px 이상 움직이면 반응하지 않는다 —
##     dialogue_box.gd / free_look.gd 와 같은 판정이다
##   - 버튼·⟲ 위 (touch_controls.blocks_look)
##   - 조이스틱 자리 (터치 UI 가 보일 때의 화면 왼쪽 절반)
##   - 대화상자·앨범 등 화면을 덮는 UI 가 열려 있을 때

const D := preload("res://scripts/ui/design.gd")

const TAP_SLOP := 24.0          # 이만큼 움직이면 끌기로 본다
const LIFE := 0.52              # 파장이 사라지기까지
const R_FROM := 16.0            # 고리 반지름 시작
const R_TO := 62.0              # 끝
const ALPHA := 0.30             # 제일 진할 때의 투명도. 이 이상은 과하다
const SPARKS := 5               # 같이 퍼지는 점 개수
const MAX_RIPPLES := 6          # 연타해도 화면이 하얘지지 않게
const RAY_LEN := 60.0
const TILT_DEG := 1.2           # 물체가 기우는 각도. 눈에 띄면 과한 것이다
const TILT_TIME := 0.14

## 화면을 덮는 UI. 하나라도 보이면 톡은 그 UI 의 몫이다.
## 화면을 덮는 UI. 하나라도 열려 있으면 톡은 그 UI 의 몫이다.
## tutorial 은 넣지 않는다 — 작은 안내판이라 화면을 덮지 않는다.
const BLOCKING := ["dialogue_box", "choice_box", "album_ui", "settings_ui",
	"wind_note", "ending_screen", "clear_screen"]

@export var enabled := true

var _draw: Control
var _ripples: Array = []        # {pos, t}
var _from := {}                 # 손가락 id → 누른 자리 (-1 은 마우스)
var _busy := {}                 # 지금 기울고 있는 노드


func _ready() -> void:
	add_to_group("touch_feedback")
	layer = 5                    # 3D 위, 퀘스트 표식(6)·터치 UI(8) 아래
	_draw = Control.new()
	_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_on_draw)
	add_child(_draw)
	set_process_input(true)
	set_process(false)


# ── 입력 ───────────────────────────────────────────────────────────────
#
# 이벤트를 먹지 않는다(set_input_as_handled 를 부르지 않는다).
# 이건 곁들이는 반응이지, 조작을 가로채는 물건이 아니다.

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_from[event.index] = event.position
		else:
			_release(event.index, event.position)
	elif event is InputEventScreenDrag:
		_check_slop(event.index, event.position)
	# 터치를 마우스로 흉내 낸 이벤트(device == -1)는 무시한다.
	# 안 그러면 폰에서 한 번 친 것이 두 번으로 세어져 파장이 겹친다.
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != -1:
		if event.pressed:
			_from[-1] = event.position
		else:
			_release(-1, event.position)
	elif event is InputEventMouseMotion and event.device != -1 \
			and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_check_slop(-1, event.position)


func _check_slop(index: int, pos: Vector2) -> void:
	if _from.has(index) and pos.distance_to(_from[index]) >= TAP_SLOP:
		_from.erase(index)       # 끌기로 판정. 이 손가락은 더 안 본다.


func _release(index: int, pos: Vector2) -> void:
	if not _from.has(index):
		return
	var start: Vector2 = _from[index]
	_from.erase(index)
	if pos.distance_to(start) >= TAP_SLOP:
		return
	if _blocked(pos):
		return
	tap(pos)


func _blocked(pos: Vector2) -> bool:
	for g in BLOCKING:
		for n in get_tree().get_nodes_in_group(g):
			if _ui_open(n):
				return true
	var tc := get_tree().get_first_node_in_group("touch_controls")
	if tc != null and tc is CanvasLayer and tc.visible:
		if tc.has_method("blocks_look") and tc.blocks_look(pos):
			return true
		# 왼쪽 절반은 조이스틱 자리. 여기 손가락은 걷겠다는 뜻이다.
		if pos.x < get_viewport().get_visible_rect().size.x * 0.5:
			return true
	return false


## 이 UI 가 지금 화면을 덮고 있는가.
##
## CanvasLayer 의 visible 만 보면 안 된다. 바람 노트는 왼쪽 위 작은 딱지를
## 늘 띄워 두려고 CanvasLayer 자체는 계속 visible 이고, 펼친 화면(Full)만
## 껐다 켠다. 그걸 "열려 있다" 로 읽으면 어디를 톡 쳐도 반응이 없다.
## (실제로 처음 만들었을 때 이 이유로 전부 먹혔다.)
func _ui_open(n: Node) -> bool:
	if not ("visible" in n) or not n.visible:
		return false
	var full := n.get_node_or_null("Full")
	if full != null and full is CanvasItem:
		return full.visible
	return true


## 그 자리에 반응을 만든다. 밖에서도 부를 수 있다(연출용).
func tap(pos: Vector2) -> void:
	_ripples.append({"pos": pos, "t": 0.0})
	while _ripples.size() > MAX_RIPPLES:
		_ripples.pop_front()
	set_process(true)
	_draw.queue_redraw()

	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("touch_tap"):
		am.touch_tap()

	_nudge(pos)


# ── 3D 물체 반응 ───────────────────────────────────────────────────────
#
# 무엇을 쳤는지는 레이캐스트로 안다. 다만 아무거나 흔들면 벽이 흔들린다.
# 상호작용 지점(interactable)만 아주 살짝 기울었다 돌아온다.

func _nudge(pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var space := cam.get_world_3d().direct_space_state
	if space == null:
		return
	var q := PhysicsRayQueryParameters3D.create(
		cam.project_ray_origin(pos),
		cam.project_ray_origin(pos) + cam.project_ray_normal(pos) * RAY_LEN)
	q.collide_with_areas = true
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var node := _interactable_of(hit.get("collider"))
	if node == null or _busy.has(node):
		return
	_busy[node] = true
	var base := node.rotation
	var tw := create_tween()
	tw.tween_property(node, "rotation",
		base + Vector3(0, 0, deg_to_rad(TILT_DEG)), TILT_TIME) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "rotation", base, TILT_TIME * 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: _busy.erase(node))


func _interactable_of(collider: Variant) -> Node3D:
	var n := collider as Node
	while n != null:
		if n.is_in_group("interactable") and n is Node3D:
			return n as Node3D
		n = n.get_parent()
	return null


# ── 그리기 ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	var alive := []
	for r in _ripples:
		r["t"] += delta
		if r["t"] < LIFE:
			alive.append(r)
	_ripples = alive
	_draw.queue_redraw()
	if _ripples.is_empty():
		set_process(false)


func _on_draw() -> void:
	for r in _ripples:
		var k: float = clampf(r["t"] / LIFE, 0.0, 1.0)
		var ease_out := 1.0 - pow(1.0 - k, 3.0)     # 빠르게 퍼지고 천천히 멎는다
		var pos: Vector2 = r["pos"]
		var radius: float = lerpf(R_FROM, R_TO, ease_out)
		var fade: float = (1.0 - k) * (1.0 - k)
		var col := Color(D.ACCENT_SOFT.r, D.ACCENT_SOFT.g, D.ACCENT_SOFT.b,
			ALPHA * fade)
		_draw.draw_arc(pos, radius, 0.0, TAU, 32, col,
			lerpf(2.6, 1.0, ease_out), true)
		# 가운데가 살짝 밝아졌다 꺼진다
		if k < 0.5:
			var c2 := Color(1, 1, 1, ALPHA * 0.5 * (1.0 - k * 2.0))
			_draw.draw_circle(pos, lerpf(7.0, 2.0, k * 2.0), c2)
		# 같이 퍼지는 점. 각도는 고정 — 실행마다 달라지면 확인이 안 된다.
		for i in SPARKS:
			var ang := TAU * float(i) / float(SPARKS) + 0.4
			var p := pos + Vector2(cos(ang), sin(ang)) * (radius * 0.86)
			_draw.draw_circle(p, lerpf(2.4, 0.8, ease_out),
				Color(col.r, col.g, col.b, ALPHA * fade * 0.9))
