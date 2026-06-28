extends Node3D

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var dialogue_box = $DialogueBox

const CAM_OFFSET = Vector3(0, 8, 5)
const CAM_LERP = 5.0

var _eavesdrop_done: bool = false
var _red_light: OmniLight3D = null
var _tension_time: float = 0.0

func _ready() -> void:
	_build_scene()
	if AudioManager: AudioManager.play_bgm("tense")
	player.add_to_group("player")
	$EavesdropTrigger.interacted.connect(eavesdrop)

func _process(delta: float) -> void:
	var target_pos = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target_pos, CAM_LERP * delta)
	camera.look_at(player.global_position + Vector3(0, 0.5, 0), Vector3.UP)
	_tension_time += delta
	if _red_light:
		_red_light.light_energy = 0.12 + sin(_tension_time * 7.3) * 0.04

func eavesdrop() -> void:
	if _eavesdrop_done:
		return
	_eavesdrop_done = true
	dialogue_box.show_text("대표: \"요즘 애들은 끈기가 없어. 어차피 도구일 뿐인데...\"")
	await get_tree().create_timer(2.5).timeout
	dialogue_box.show_text("\"이 회사는... 사람을 도구처럼 쓰는구나.\"")
	await get_tree().create_timer(2.5).timeout
	dialogue_box.show_text("\"...그래, 여기서 더 있을 필요가 없어. 나가자.\"")
	await get_tree().create_timer(2.5).timeout
	dialogue_box.hide_box()
	Episode0State.advance_to(Episode0State.State.RETURN_TO_PARTNER)
	SceneTransition.go_to("res://scenes/maps/Office3D.tscn")

func _build_scene() -> void:
	_box(self, Vector3(0, -0.05, 1), Vector3(6, 0.1, 14), "#1E2733", "Floor")
	_box(self, Vector3(-3.1, 2, 1), Vector3(0.2, 4, 14), "#17283A", "WallLeft")
	_box(self, Vector3(3.1, 2, 1), Vector3(0.2, 4, 14), "#17283A", "WallRight")
	_box(self, Vector3(0, 2, -4.1), Vector3(6, 4, 0.2), "#17283A", "WallBack")
	# 앞쪽 낮은 벽
	_box(self, Vector3(0, 1.0, 7.9), Vector3(6, 2, 0.2), "#17283A", "WallFront")
	# Ceiling 제거 - 위에서 내려다보는 카메라 구조
	_box(self, Vector3(0, 1.5, -3.9), Vector3(1.8, 3.0, 0.2), "#2D3A4A", "BossDoor")
	_box(self, Vector3(0, 1.5, -3.7), Vector3(1.6, 2.8, 0.05), "#1E2A3A", "BossDoorGlass")
	var glow = OmniLight3D.new()
	glow.position = Vector3(0, 0.1, -3.8)
	glow.light_color = Color("#FFD76D")
	glow.light_energy = 0.4
	glow.omni_range = 1.5
	self.add_child(glow)
	# 복도 조명 (어두워서 밝게 보강, 여러 개)
	for hz in [-2.0, 1.0, 4.0]:
		var hall_light = OmniLight3D.new()
		hall_light.position = Vector3(0, 3.5, hz)
		hall_light.light_color = Color("#B0C0D8")
		hall_light.light_energy = 1.0
		hall_light.omni_range = 6.0
		self.add_child(hall_light)
	_box(self, Vector3(0, 1.5, 3.9), Vector3(1.8, 3.0, 0.2), "#2D3A4A", "ExitDoor")
	# Red tension light near boss door
	_red_light = OmniLight3D.new()
	_red_light.position = Vector3(0, 0.3, -3.5)
	_red_light.light_color = Color("#FF1010")
	_red_light.light_energy = 0.12
	_red_light.omni_range = 2.5
	self.add_child(_red_light)
	# Light bleeding under door
	_box(self, Vector3(0, 0.005, -3.82), Vector3(1.5, 0.01, 0.08), "#FF6020", "DoorLight")
	# Door number plate
	_box(self, Vector3(-0.95, 2.3, -3.88), Vector3(0.14, 0.1, 0.02), "#C8A840", "DoorPlate")

func _box(parent: Node3D, pos: Vector3, size: Vector3, hex: String, label: String = "") -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	if label != "": mi.name = label
	var mesh = BoxMesh.new(); mesh.size = size; mi.mesh = mesh
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat; mi.position = pos; parent.add_child(mi); return mi
