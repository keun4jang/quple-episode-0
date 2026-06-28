extends Node3D

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var warm_window_light: OmniLight3D = $WarmWindowLight
@onready var dialogue_box = $DialogueBox
@onready var partner = $PartnerQuokka3D
@onready var dir_light: DirectionalLight3D = $DirectionalLight3D

const CAM_OFFSET = Vector3(0, 13, 9)
const CAM_LERP = 5.0

var _light_time: float = 0.0
var _dawn_progress: float = 0.0

func _ready() -> void:
	_build_scene()
	if AudioManager: AudioManager.play_bgm("night")
	player.add_to_group("player")
	if Episode0State.current_state == Episode0State.State.START:
		_show_opening()
	elif Episode0State.current_state == Episode0State.State.PARTNER_JOINED:
		Episode0State.advance_to(Episode0State.State.FIRST_PHOTO)
	if Episode0State.partner_joined:
		partner.join_player()

func _process(delta: float) -> void:
	var target_pos = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target_pos, CAM_LERP * delta)
	camera.look_at(player.global_position + Vector3(0, 0.5, 0), Vector3.UP)
	_light_time += delta
	warm_window_light.light_energy = 1.0 + sin(_light_time * TAU / 2.5) * 0.06
	if Episode0State.current_state >= Episode0State.State.FIRST_PHOTO:
		_dawn_progress = min(_dawn_progress + delta * 0.04, 1.0)
		if dir_light:
			dir_light.light_color = Color("#2030A0").lerp(Color("#FF8060"), _dawn_progress)
			dir_light.light_energy = lerp(0.6, 1.4, _dawn_progress)

func _show_opening() -> void:
	await get_tree().create_timer(0.8).timeout
	dialogue_box.show_text("늦은 밤, 쿼카전자에는 딱 하나의 불빛만 남아 있어요.")
	Episode0State.advance_to(Episode0State.State.ENTER_COMPANY)

func _build_scene() -> void:
	_box(self, Vector3(0, -0.04, 7), Vector3(28, 0.08, 16), "#3B3E46", "Road")
	_box(self, Vector3(0, 0, -1), Vector3(28, 0.1, 6), "#7F8790", "Sidewalk")
	for i in range(-2, 3):
		_box(self, Vector3(i * 0.9, 0.01, 3.5), Vector3(0.45, 0.01, 2.5), "#F2EEE2", "Crosswalk%d" % i)
	# 건물 높이 축소 (18→10) - 카메라가 지붕 위에서 볼 수 있도록
	_box(self, Vector3(0, 5, -6), Vector3(10, 10, 2), "#2D3A4A", "Building")
	_box(self, Vector3(-5.1, 5, -6), Vector3(0.2, 10, 2.5), "#1E2733", "BuildingLeft")
	_box(self, Vector3(5.1, 5, -6), Vector3(0.2, 10, 2.5), "#1E2733", "BuildingRight")
	# 옥상 테두리 디테일
	_box(self, Vector3(0, 10.1, -6), Vector3(10.4, 0.2, 2.4), "#1A2530", "RoofEdge")
	for row in range(6):
		for col in range(5):
			var wx = -4.0 + col * 1.8
			var wy = 1.5 + row * 1.4
			var color = "#17283A" if not (row == 4 and col == 2) else "#FFD76D"
			_box(self, Vector3(wx, wy, -4.95), Vector3(1.0, 0.8, 0.05), color, "Win_%d_%d" % [row, col])
	# 발광 네온 간판 (QUOKKA CORP 느낌의 빛나는 사인)
	var sign_bg = _box(self, Vector3(0, 10.6, -5.0), Vector3(5.4, 0.9, 0.25), "#101820", "SignBG")
	_emit(sign_bg, "#101820", 0.0)
	for sx in range(-2, 3):
		var letter = _box(self, Vector3(sx * 0.9, 10.6, -4.85), Vector3(0.5, 0.55, 0.1), "#54E0FF", "SignLetter%d" % sx)
		_emit(letter, "#54E0FF", 3.0)
	var sign_light = OmniLight3D.new()
	sign_light.position = Vector3(0, 10.6, -4.4)
	sign_light.light_color = Color("#54E0FF")
	sign_light.light_energy = 1.2
	sign_light.omni_range = 5.0
	self.add_child(sign_light)
	# 창문마다 얇은 창틀 디테일
	for row in range(6):
		for col in range(5):
			var fwx = -4.0 + col * 1.8
			var fwy = 1.5 + row * 1.4
			_box(self, Vector3(fwx, fwy, -4.92), Vector3(1.12, 0.06, 0.04), "#0E1822", "WinFrameT_%d_%d" % [row, col])
			_box(self, Vector3(fwx, fwy - 0.43, -4.92), Vector3(1.12, 0.06, 0.04), "#0E1822", "WinFrameB_%d_%d" % [row, col])
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
	# Bus stop shelter at left
	_box(self, Vector3(-9, 1.5, 1), Vector3(0.1, 3.0, 0.1), "#4A5568", "BusPost1")
	_box(self, Vector3(-7, 1.5, 1), Vector3(0.1, 3.0, 0.1), "#4A5568", "BusPost2")
	_box(self, Vector3(-8, 3.1, 1), Vector3(2.2, 0.1, 1.0), "#4A5568", "BusRoof")
	# Bike rack
	for bi in range(3):
		_box(self, Vector3(7.5, 0.5, 0.3 + bi * 0.45), Vector3(0.05, 1.0, 0.05), "#5A6472", "Bike%d" % bi)
	_box(self, Vector3(7.5, 1.05, 0.75), Vector3(0.05, 0.05, 1.4), "#5A6472", "BikeRail")
	# Puddle reflections on road
	for pi in range(3):
		var pr = _box(self, Vector3(-3.0 + pi * 2.5, -0.02, 4.5), Vector3(0.7, 0.01, 0.45), "#50607A", "Puddle%d" % pi)
		if pr and pr.material_override:
			pr.material_override.roughness = 0.05
	# Moon in background
	var moon = MeshInstance3D.new()
	var moon_mesh = SphereMesh.new(); moon_mesh.radius = 0.6; moon_mesh.height = 1.2
	moon.mesh = moon_mesh
	var moon_mat = StandardMaterial3D.new()
	moon_mat.albedo_color = Color("#E8E8F0")
	moon_mat.emission_enabled = true
	moon_mat.emission = Color("#E8E8F0")
	moon_mat.emission_energy_multiplier = 0.6
	moon.material_override = moon_mat
	moon.position = Vector3(8, 16, -10)
	self.add_child(moon)

func _box(parent: Node3D, pos: Vector3, size: Vector3, hex: String, label: String = "") -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	if label != "": mi.name = label
	var mesh = BoxMesh.new(); mesh.size = size; mi.mesh = mesh
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat; mi.position = pos; parent.add_child(mi); return mi

func _emit(mi: MeshInstance3D, hex: String, energy: float) -> void:
	var mat = mi.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.emission_enabled = energy > 0.0
	mat.emission = Color(hex)
	mat.emission_energy_multiplier = energy

func _lamppost(parent: Node3D, pos: Vector3) -> void:
	_box(parent, pos + Vector3(0, 2.5, 0), Vector3(0.12, 5.0, 0.12), "#4A5568", "Post")
	_box(parent, pos + Vector3(0, 5.1, 0), Vector3(0.5, 0.12, 0.12), "#4A5568", "Arm")
	var spot = SpotLight3D.new()
	spot.position = pos + Vector3(0.25, 5.0, 0)
	spot.rotation_degrees.z = -15
	spot.light_color = Color("#FFE7A8")
	spot.light_energy = 1.8
	spot.spot_range = 7.0
	spot.spot_angle = 35.0
	parent.add_child(spot)

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
