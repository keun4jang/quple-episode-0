extends Node3D
## 대표실 앞 복도. 문 너머에서 목소리가 들린다. 보스는 등장하지 않는다.

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var dialogue_box = $DialogueBox

const CAM_OFFSET = Vector3(0, 4.6, 6.4)
const CAM_LOOK_OFFSET = Vector3(0, 1.2, -4.0)
const CAM_LERP = 5.0

var _door_light: OmniLight3D = null
var _t: float = 0.0
var _listening: bool = false

func _ready() -> void:
	_build_scene()
	player.add_to_group("player")
	AudioManager.play_bgm("episode0")
	$BossDoorInteract.interacted.connect(_eavesdrop)
	$BackInteract.interacted.connect(_go_back)
	PartnerSpawner.ensure(self, player)
	await get_tree().create_timer(0.5).timeout
	dialogue_box.show_text("문 너머에서 목소리가 새어 나와요. (Space로 들어보기)")

func _process(delta: float) -> void:
	var target_pos = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target_pos, CAM_LERP * delta)
	camera.look_at(player.global_position + CAM_LOOK_OFFSET, Vector3.UP)
	# 문틈 빛이 아주 약하게 흔들린다
	_t += delta
	if _door_light:
		_door_light.light_energy = 0.8 + sin(_t * 2.2) * 0.08

## 엿듣기 — 0편의 감정 전환점
func _eavesdrop() -> void:
	if _listening:
		return
	_listening = true
	var lines := [
		"대표: \"사람은 도구처럼 쓰면 돼.\"",
		"대표: \"지치면 바꾸면 그만이지.\"",
		"……",
		"이제 정말 나가야 해.",
	]
	for line in lines:
		dialogue_box.show_text(line)
		await get_tree().create_timer(2.2).timeout
	dialogue_box.hide_box()
	Episode0State.advance_to(Episode0State.State.RETURN_TO_PARTNER)
	await get_tree().create_timer(0.3).timeout
	SceneTransition.go_to("res://scenes/maps/Office3D.tscn", "tense")

func _go_back() -> void:
	SceneTransition.go_to("res://scenes/maps/Office3D.tscn")

func _build_scene() -> void:
	# 복도 바닥 / 벽 / 천장
	_box(self, Vector3(0, -0.05, 0), Vector3(7, 0.1, 22), "#3B4250", "Floor")
	_box(self, Vector3(0, 0.005, 0), Vector3(4.4, 0.02, 22), "#4A5364", "FloorRunner")
	_box(self, Vector3(-3.4, 1.8, 0), Vector3(0.3, 3.8, 22), "#2D3A4A", "LeftWall")
	_box(self, Vector3(3.4, 1.8, 0), Vector3(0.3, 3.8, 22), "#2D3A4A", "RightWall")
	_box(self, Vector3(0, 1.8, -8.6), Vector3(7, 3.8, 0.3), "#2D3A4A", "EndWall")

	# 대표실 큰 문
	_box(self, Vector3(0, 1.45, -8.35), Vector3(2.9, 3.0, 0.16), "#1E2733", "BossDoorFrame")
	_box(self, Vector3(-0.72, 1.4, -8.24), Vector3(1.3, 2.8, 0.07), "#43566A", "BossDoorL")
	_box(self, Vector3(0.72, 1.4, -8.24), Vector3(1.3, 2.8, 0.07), "#43566A", "BossDoorR")
	_box(self, Vector3(0, 3.15, -8.24), Vector3(1.5, 0.24, 0.05), "#FFD76D", "BossPlate")
	_sphere(self, Vector3(-0.22, 1.25, -8.18), 0.07, "#C8C8D0", "BossKnobL")
	_sphere(self, Vector3(0.22, 1.25, -8.18), 0.07, "#C8C8D0", "BossKnobR")

	# 문틈에서 새어 나오는 빛 (안에 사람이 있다는 신호)
	var slit := _box(self, Vector3(0, 0.06, -8.12), Vector3(2.5, 0.06, 0.05), "#FFD76D", "DoorSlit")
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("#FFE7A8")
	sm.emission_enabled = true
	sm.emission = Color("#FFD76D")
	sm.emission_energy_multiplier = 2.2
	slit.material_override = sm
	_door_light = OmniLight3D.new()
	_door_light.light_color = Color("#FFD76D")
	_door_light.light_energy = 0.8
	_door_light.omni_range = 4.5
	_door_light.position = Vector3(0, 0.5, -7.7)
	add_child(_door_light)

	# 차가운 복도 조명
	for lz in [-6.0, -2.0, 2.0, 6.0]:
		_box(self, Vector3(0, 3.55, lz), Vector3(1.2, 0.06, 0.35), "#C7D4E4", "CeilPanel")
		var cl := OmniLight3D.new()
		cl.light_color = Color("#8FA6C4")
		cl.light_energy = 0.5
		cl.omni_range = 7.0
		cl.position = Vector3(0, 3.3, lz)
		add_child(cl)

	# 복도 소품: 화분, 소화기, 액자
	_cylinder(self, Vector3(-2.7, 0.26, -6.0), 0.28, 0.5, "#6D7D8F", "PlanterPot")
	_sphere(self, Vector3(-2.7, 0.78, -6.0), 0.4, "#5E9B80", "PlanterLeaf")
	_cylinder(self, Vector3(2.8, 0.32, -4.0), 0.11, 0.62, "#C0504A", "Extinguisher")
	for fz in [-3.0, 1.0]:
		_box(self, Vector3(-3.2, 2.0, fz), Vector3(0.05, 0.7, 1.0), "#43566A", "Frame")
		_box(self, Vector3(-3.16, 2.0, fz), Vector3(0.02, 0.56, 0.86), "#5A6B80", "FrameArt")

# ── 헬퍼 ──
func _box(parent: Node3D, pos: Vector3, size: Vector3, hex: String, label: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new(); m.size = size
	mi.mesh = m; mi.position = pos
	if label != "": mi.name = label
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, hex: String, label: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new(); m.top_radius = radius; m.bottom_radius = radius; m.height = height
	mi.mesh = m; mi.position = pos
	if label != "": mi.name = label
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _sphere(parent: Node3D, pos: Vector3, radius: float, hex: String, label: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new(); m.radius = radius; m.height = radius * 2.0
	mi.mesh = m; mi.position = pos
	if label != "": mi.name = label
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi
