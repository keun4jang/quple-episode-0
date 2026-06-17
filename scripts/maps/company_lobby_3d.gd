extends Node3D

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var dialogue_box = $DialogueBox

const CAM_OFFSET = Vector3(0, 6, 6)
const CAM_LERP = 5.0

func _ready() -> void:
	_build_scene()
	player.add_to_group("player")
	if Episode0State.current_state == Episode0State.State.ENTER_COMPANY:
		Episode0State.advance_to(Episode0State.State.FIND_PARTNER)

func _process(delta: float) -> void:
	var target_pos = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target_pos, CAM_LERP * delta)
	camera.look_at(player.global_position + Vector3(0, 0.5, 0), Vector3.UP)

func _build_scene() -> void:
	_box(self, Vector3(0, -0.05, 0), Vector3(14, 0.1, 10), "#7F8790", "Floor")
	_box(self, Vector3(-7.1, 3, 0), Vector3(0.2, 6, 10), "#43566A", "WallLeft")
	_box(self, Vector3(7.1, 3, 0), Vector3(0.2, 6, 10), "#43566A", "WallRight")
	_box(self, Vector3(0, 3, -5.1), Vector3(14, 6, 0.2), "#43566A", "WallBack")
	_box(self, Vector3(0, 6.1, 0), Vector3(14, 0.2, 10), "#2D3A4A", "Ceiling")
	_box(self, Vector3(0, 0.6, -2), Vector3(4, 1.2, 1), "#43566A", "Desk")
	_box(self, Vector3(0, 1.25, -2), Vector3(4.2, 0.1, 1.1), "#2D3A4A", "DeskTop")
	var lamp = OmniLight3D.new()
	lamp.position = Vector3(0, 1.8, -2)
	lamp.light_color = Color("#FFE7A8")
	lamp.light_energy = 1.2
	lamp.omni_range = 3.0
	self.add_child(lamp)
	_box(self, Vector3(-5, 0.6, -3), Vector3(0.6, 0.8, 0.4), "#6D7D8F", "BadgeBox")
	_box(self, Vector3(-5, 1.0, -3), Vector3(0.5, 0.05, 0.35), "#2D3A4A", "BadgeBoxTop")
	_box(self, Vector3(4, 1.5, -4.9), Vector3(1.5, 3.0, 0.15), "#1E2733", "ElevDoor")
	_box(self, Vector3(4, 1.5, -4.75), Vector3(1.3, 2.8, 0.05), "#3E6278", "ElevGlass")
	_box(self, Vector3(-4, 1.5, -4.9), Vector3(1.5, 3.0, 0.15), "#1E2733", "ExitDoor")
	_box(self, Vector3(-4, 1.5, -4.75), Vector3(1.3, 2.8, 0.05), "#3E6278", "ExitGlass")
	_planter(self, Vector3(6, 0, -4))
	_planter(self, Vector3(-6, 0, -4))
	_box(self, Vector3(0, 0.01, 0), Vector3(0.05, 0.01, 10), "#6D7D8F", "FloorLine")

func _box(parent: Node3D, pos: Vector3, size: Vector3, hex: String, label: String = "") -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	if label != "": mi.name = label
	var mesh = BoxMesh.new(); mesh.size = size; mi.mesh = mesh
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat; mi.position = pos; parent.add_child(mi); return mi

func _planter(parent: Node3D, pos: Vector3) -> void:
	_box(parent, pos + Vector3(0, 0.15, 0), Vector3(0.5, 0.3, 0.5), "#6D7D8F", "PlanterBox")
	var mi = MeshInstance3D.new()
	var mesh = SphereMesh.new(); mesh.radius = 0.22; mesh.height = 0.44; mi.mesh = mesh
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color("#72B48D"); mat.roughness = 0.9
	mi.material_override = mat; mi.position = pos + Vector3(0, 0.55, 0); parent.add_child(mi)
