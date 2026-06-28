extends Node3D

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var dialogue_box = $DialogueBox

const CAM_OFFSET = Vector3(0, 10, 6)
const CAM_LERP = 5.0

func _ready() -> void:
	_build_scene()
	if AudioManager: AudioManager.play_bgm("indoor")
	player.add_to_group("player")
	if Episode0State.current_state == Episode0State.State.ENTER_COMPANY:
		Episode0State.advance_to(Episode0State.State.FIND_PARTNER)

func _process(delta: float) -> void:
	var target_pos = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target_pos, CAM_LERP * delta)
	camera.look_at(player.global_position + Vector3(0, 0.5, 0), Vector3.UP)

func _build_scene() -> void:
	_box(self, Vector3(0, -0.05, 1), Vector3(14, 0.1, 16), "#7F8790", "Floor")
	_box(self, Vector3(-7.1, 3, 1), Vector3(0.2, 6, 16), "#43566A", "WallLeft")
	_box(self, Vector3(7.1, 3, 1), Vector3(0.2, 6, 16), "#43566A", "WallRight")
	_box(self, Vector3(0, 3, -5.1), Vector3(14, 6, 0.2), "#43566A", "WallBack")
	# 앞쪽 낮은 벽 (파란 빈 공간 가림)
	_box(self, Vector3(0, 1.0, 8.9), Vector3(14, 2, 0.2), "#43566A", "WallFront")
	# Ceiling 제거 - 위에서 내려다보는 카메라 구조
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
	# Ceiling OmniLights for lobby ambiance
	for lx in [-4.0, 0.0, 4.0]:
		var cl = OmniLight3D.new()
		cl.position = Vector3(lx, 5.5, -2)
		cl.light_color = Color("#C8D0E8")
		cl.light_energy = 0.6
		cl.omni_range = 5.0
		self.add_child(cl)
	# Small plant on reception desk
	var plant_stem = MeshInstance3D.new()
	var sm = SphereMesh.new(); sm.radius = 0.12; sm.height = 0.24; plant_stem.mesh = sm
	var pm = StandardMaterial3D.new(); pm.albedo_color = Color("#72B48D"); pm.roughness = 0.9
	plant_stem.material_override = pm; plant_stem.position = Vector3(1.5, 1.45, -2.2)
	self.add_child(plant_stem)
	# Floor center stripe more visible
	_box(self, Vector3(0, 0.01, -2), Vector3(0.05, 0.01, 6), "#8A9AA8", "FloorStripe2")
	# Elevator indicator panel
	_box(self, Vector3(4, 3.2, -4.85), Vector3(0.4, 0.3, 0.05), "#1E2733", "ElevPanel")
	_box(self, Vector3(4, 3.3, -4.82), Vector3(0.1, 0.1, 0.03), "#FFD76D", "ElevBtnUp")
	_box(self, Vector3(4, 3.1, -4.82), Vector3(0.1, 0.1, 0.03), "#2A3A4A", "ElevBtnDown")
	# 안내 카펫 (입구→데스크 레드카펫 느낌으로 동선 유도)
	_box(self, Vector3(0, 0.01, 3), Vector3(2.2, 0.02, 11), "#6B5560", "EntryCarpet")
	_box(self, Vector3(0, 0.02, 3), Vector3(1.6, 0.02, 11), "#8A6E78", "EntryCarpetInner")
	# 천장 매달린 안내 표지판
	_box(self, Vector3(0, 4.5, -0.5), Vector3(2.5, 0.5, 0.1), "#1E2733", "SignBoard")
	var sb = _box(self, Vector3(0, 4.5, -0.42), Vector3(2.2, 0.35, 0.05), "#54E0FF", "SignBoardGlow")
	var sbm = sb.material_override as StandardMaterial3D
	if sbm:
		sbm.emission_enabled = true; sbm.emission = Color("#54E0FF"); sbm.emission_energy_multiplier = 2.0

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
