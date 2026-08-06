extends Area3D
class_name Interactable
## 상호작용 지점. 플레이어가 가까이 오면 노란 표시가 떠오르고, Space 로 상호작용한다.
## 표시는 위아래로 0.15m 천천히 움직이며 아주 약하게 회전한다.

signal interacted

const INDICATOR_COLOR := "#FFD76D"

@export var prompt_text: String = "조사하기"
@export var one_shot: bool = false
@export var show_indicator: bool = true
@export var indicator_height: float = 1.5

var _player_inside: bool = false
var _used: bool = false
var _indicator: Node3D = null
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

func _process(delta: float) -> void:
	if _indicator == null:
		return
	_t += delta
	var active := _player_inside and not (_used and one_shot)
	_indicator.visible = not (_used and one_shot)
	# 위아래 0.0~0.15m 천천히, 아주 약한 회전
	_indicator.position.y = indicator_height + (sin(_t * 2.0) * 0.5 + 0.5) * 0.15
	_indicator.rotation.y += delta * 0.6
	var s := 1.25 if active else 1.0
	_indicator.scale = _indicator.scale.lerp(Vector3.ONE * s, delta * 6.0)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
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
