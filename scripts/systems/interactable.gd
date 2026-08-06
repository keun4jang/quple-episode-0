extends Area3D
class_name Interactable
## 상호작용 지점. 플레이어가 가까이 오면 노란 표시가 떠오르고, Space 로 상호작용한다.
## 표시는 위아래로 0.15m 천천히 움직이며 아주 약하게 회전한다.

signal interacted

const INDICATOR_COLOR := "#FFD76D"

@export var prompt_text: String = "조사하기"
## 아직 때가 아닌 지점을 잠가 둔다.
##
## 회사 앞 사진 지점이 시작 위치 바로 앞(1.4m)에 켜져 있어서, 게임을 켜자마자
## 액션 버튼이 "사진 찍기" 로 떴다. 카메라를 아직 얻지도 않았고, 눌러도
## 아무 일도 일어나지 않았다. 버튼이 거짓말을 하고 있었던 셈이다.
## 잠긴 지점은 표시도 안 뜨고 버튼 글자도 가져가지 않는다.
@export var locked: bool = false: set = set_locked
@export var one_shot: bool = false
@export var show_indicator: bool = true
@export var indicator_height: float = 1.5

var _player_inside: bool = false
var _used: bool = false
var _indicator: Node3D = null
var _ring: MeshInstance3D = null
var _t: float = 0.0

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if show_indicator:
		_build_indicator()
		_build_floor_ring()
	set_locked(locked)


## 바닥에 깔리는 빛나는 원.
##
## 지금까지 표시는 공중에 뜬 마름모 하나뿐이었다. 그건 "여기 뭔가 있다" 는
## 말은 하지만 **어디까지 가야 하는지** 는 말해 주지 않는다. 문 앞에서
## 얼마나 더 붙어야 열리는지 몰라 서성이게 된다.
## 바닥 원은 상호작용이 닿는 범위를 그대로 그려 준다 — 원 안에 들어가면 된다.
func _build_floor_ring() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "FloorRing"
	var t := TorusMesh.new()
	var r := _reach()
	t.inner_radius = maxf(r - 0.09, 0.14)
	t.outer_radius = r
	t.rings = 40
	t.ring_segments = 6
	mi.mesh = t

	var m := StandardMaterial3D.new()
	m.albedo_color = Color(INDICATOR_COLOR)
	m.emission_enabled = true
	m.emission = Color(INDICATOR_COLOR)
	m.emission_energy_multiplier = 2.2
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.72
	m.disable_receive_shadows = true
	mi.material_override = m
	# 바닥에 아주 살짝 띄운다. 0 이면 바닥과 겹쳐 지글거린다.
	mi.position.y = 0.03
	add_child(mi)
	_ring = mi


## 상호작용 범위. 콜리전 모양에서 읽어 온다 — 눈에 보이는 원과
## 실제로 닿는 거리가 다르면 표시가 거짓말이 된다.
func _reach() -> float:
	for c in get_children():
		if c is CollisionShape3D and c.shape != null:
			var sh = c.shape
			if sh is SphereShape3D:
				return maxf(sh.radius, 0.4)
			if sh is BoxShape3D:
				return maxf(maxf(sh.size.x, sh.size.z) * 0.5, 0.4)
			if sh is CylinderShape3D:
				return maxf(sh.radius, 0.4)
	return 0.9


func set_locked(v: bool) -> void:
	locked = v
	monitoring = not v
	if v:
		_player_inside = false
	if _indicator != null:
		_indicator.visible = not v
	if _ring != null:
		_ring.visible = not v

func _process(delta: float) -> void:
	if _indicator == null:
		return
	_t += delta
	var active := _player_inside and not (_used and one_shot)
	_indicator.visible = not locked and not (_used and one_shot)
	if locked:
		return
	# 위아래 0.0~0.15m 천천히, 아주 약한 회전
	_indicator.position.y = indicator_height + (sin(_t * 2.0) * 0.5 + 0.5) * 0.15
	_indicator.rotation.y += delta * 0.6
	var s := 1.25 if active else 1.0
	_indicator.scale = _indicator.scale.lerp(Vector3.ONE * s, delta * 6.0)

	# 바닥 원은 천천히 숨쉬고, 플레이어가 들어오면 또렷해진다.
	if _ring != null:
		_ring.visible = not (_used and one_shot)
		var m := _ring.material_override as StandardMaterial3D
		if m != null:
			var base := 0.85 if active else 0.45
			m.albedo_color.a = base + sin(_t * 2.4) * 0.12
			m.emission_energy_multiplier = (3.2 if active else 1.6) + sin(_t * 2.4) * 0.4

func _unhandled_input(event: InputEvent) -> void:
	if locked or not _player_inside:
		return
	if _used and one_shot:
		return
	if event.is_action_pressed("interact"):
		_used = true
		# 한 번 쓰고 사라지는 지점은 대개 무언가를 집는 것이다.
		# 계속 쓸 수 있는 곳(문·통로)은 확인음이 맞다.
		if one_shot and AudioManager.has_method("pickup"):
			AudioManager.pickup()
		else:
			AudioManager.ui_confirm()
		interacted.emit()
		get_viewport().set_input_as_handled()

func reset() -> void:
	_used = false

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false

func _build_indicator() -> void:
	_indicator = Node3D.new()
	_indicator.name = "Indicator"
	add_child(_indicator)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(INDICATOR_COLOR)
	mat.emission_enabled = true
	mat.emission = Color(INDICATOR_COLOR)
	mat.emission_energy_multiplier = 2.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# 느낌표 몸통
	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.075, 0.22, 0.075)
	bar.mesh = bm
	bar.material_override = mat
	bar.position = Vector3(0, 0.09, 0)
	_indicator.add_child(bar)

	# 느낌표 점
	var dot := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.10
	dot.mesh = sm
	dot.material_override = mat
	dot.position = Vector3(0, -0.07, 0)
	_indicator.add_child(dot)

	_indicator.position.y = indicator_height
