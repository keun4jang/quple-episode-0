extends Node3D

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var warm_window_light: OmniLight3D = $WarmWindowLight
@onready var dialogue_box = $DialogueBox

const CAM_OFFSET = Vector3(0, 8, 8)
const CAM_LERP = 5.0

var _light_time: float = 0.0

func _ready() -> void:
	_build_scene()
	player.add_to_group("player")
	if Episode0State.current_state == Episode0State.State.START:
		_show_opening()
	elif Episode0State.current_state == Episode0State.State.PARTNER_JOINED:
		Episode0State.advance_to(Episode0State.State.FIRST_PHOTO)

func _process(delta: float) -> void:
	var target_pos = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target_pos, CAM_LERP * delta)
	camera.look_at(player.global_position + Vector3(0, 0.5, 0), Vector3.UP)
	_light_time += delta
	warm_window_light.light_energy = 1.0 + sin(_light_time * TAU / 2.5) * 0.06

func _show_opening() -> void:
	await get_tree().create_timer(0.8).timeout
	dialogue_box.show_text("늦은 밤, 쿼카전자에는 딱 하나의 불빛만 남아 있어요.")
	Episode0State.advance_to(Episode0State.State.ENTER_COMPANY)

func _build_scene() -> void:
	_box(self, Vector3(0, -0.04, 4), Vector3(24, 0.08, 8), "#3B3E46", "Road")
	_box(self, Vector3(0, 0, -1), Vector3(24, 0.1, 6), "#7F8790", "Sidewalk")
	for i in range(-2, 3):
		_box(self, Vector3(i * 0.9, 0.01, 3.5), Vector3(0.45, 0.01, 2.5), "#F2EEE2", "Crosswalk%d" % i)
	_box(self, Vector3(0, 9, -6), Vector3(10, 18, 2), "#2D3A4A", "Building")
	_box(self, Vector3(-5.1, 9, -6), Vector3(0.2, 18, 2.5), "#1E2733", "BuildingLeft")
	_box(self, Vector3(5.1, 9, -6), Vector3(0.2, 18, 2.5), "#1E2733", "BuildingRight")
	for row in range(10):
		for col in range(5):
			var wx = -4.0 + col * 1.8
			var wy = 2.5 + row * 1.5
			var color = "#17283A" if not (row == 6 and col == 2) else "#FFD76D"
			_box(self, Vector3(wx, wy, -4.95), Vector3(1.0, 0.8, 0.05), color, "Win_%d_%d" % [row, col])
	_box(self, Vector3(0, 18.5, -5.1), Vector3(5, 0.6, 0.3), "#FFD76D", "SignBG")
	_box(self, Vector3(0, 1.2, -5.0), Vector3(2.2, 2.4, 0.15), "#182533", "EntranceDoor")
	_box(self, Vector3(0, 1.2, -4.84), Vector3(2.0, 2.2, 0.05), "#3E6278", "DoorGlass")
	_lamppost(self, Vector3(-6, 0, -2))
	_lamppost(self, Vector3(6, 0, -2))
	for bx in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		_box(self, Vector3(bx, 0.2, 0.8), Vector3(0.18, 0.4, 0.18), "#6D7D8F", "Bollard")
	_bench(self, Vector3(-7, 0, -0.5))
	_planter(self, Vector3(3.5, 0, -2))
	_planter(self, Vector3(-3.5, 0, -2))
	_tree(self, Vector3(-8, 0, 0))
	_tree(self, Vector3(8, 0, 0))

func _box(parent: Node3D, pos: Vector3, size: Vector3, hex: String, label: String = "") -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	if label != "": mi.name = label
	var mesh = BoxMesh.new(); mesh.size = size; mi.mesh = mesh
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat; mi.position = pos; parent.add_child(mi); return mi

func _lamppost(parent: Node3D, pos: Vector3) -> void:
	_box(parent, pos + Vector3(0, 2.5, 0), Vector3(0.12, 5.0, 0.12), "#4A5568", "Post")
	_box(parent, pos + Vector3(0, 5.1, 0), Vector3(0.5, 0.12, 0.12), "#4A5568", "Arm")
	var light = OmniLight3D.new()
	light.position = pos + Vector3(0, 5.2, 0)
	light.light_color = Color("#FFE7A8")
	light.light_energy = 0.8
	light.omni_range = 4.0
	parent.add_child(light)

func _bench(parent: Node3D, pos: Vector3) -> void:
	_box(parent, pos + Vector3(0, 0.2, 0), Vector3(1.4, 0.1, 0.4), "#7F8790", "BenchSeat")
	_box(parent, pos + Vector3(-0.6, 0.1, 0), Vector3(0.08, 0.2, 0.4), "#6D7D8F", "BenchLegL")
	_box(parent, pos + Vector3(0.6, 0.1, 0), Vector3(0.08, 0.2, 0.4), "#6D7D8F", "BenchLegR")

func _planter(parent: Node3D, pos: Vector3) -> void:
	_box(parent, pos + Vector3(0, 0.15, 0), Vector3(0.5, 0.3, 0.5), "#6D7D8F", "PlanterBox")
	_sphere_mi(parent, pos + Vector3(0, 0.55, 0), 0.22, "#72B48D", "Plant")

func _tree(parent: Node3D, pos: Vector3) -> void:
	_box(parent, pos + Vector3(0, 0.6, 0), Vector3(0.2, 1.2, 0.2), "#5B3A29", "Trunk")
	_sphere_mi(parent, pos + Vector3(0, 1.5, 0), 0.7, "#72B48D", "Canopy")

func _sphere_mi(parent: Node3D, pos: Vector3, radius: float, hex: String, label: String = "") -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	if label != "": mi.name = label
	var mesh = SphereMesh.new(); mesh.radius = radius; mesh.height = radius * 2; mi.mesh = mesh
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat; mi.position = pos; parent.add_child(mi); return mi
