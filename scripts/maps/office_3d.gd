extends Node3D

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var dialogue_box = $DialogueBox
@onready var choice_box = $ChoiceBox
@onready var partner = $PartnerQuokka3D

const CAM_OFFSET = Vector3(0, 5.0, 5.4)
const CAM_LERP = 5.0
const CAM_LOOK_OFFSET = Vector3(0, 1.0, -1.6)

func _ready() -> void:
	_build_scene()
	player.add_to_group("player")
	if Episode0State.partner_joined:
		partner.join_player()
	$PartnerInteract.interacted.connect(talk_to_partner)
	$CameraItemInteract.interacted.connect(_pick_camera)
	$NotebookInteract.interacted.connect(_pick_notebook)
	$TravelBagInteract.interacted.connect(_pick_bag)
	$ToBossDoorInteract.interacted.connect(_go_boss_door)
	$ToLobbyInteract.interacted.connect(_go_lobby)
	_refresh_item_visibility()

func _process(delta: float) -> void:
	var target_pos = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target_pos, CAM_LERP * delta)
	camera.look_at(player.global_position + CAM_LOOK_OFFSET, Vector3.UP)

func talk_to_partner() -> void:
	if Episode0State.current_state == Episode0State.State.FIND_PARTNER:
		Episode0State.advance_to(Episode0State.State.TALK_PARTNER)
		dialogue_box.show_text("애인: \"아직 안 갔어? 나도 지금 막 퇴근하려던 참이야.\"")
		await get_tree().create_timer(2.0).timeout
		dialogue_box.hide_box()
		choice_box.show_choices("지금 같이 나가자", "조금만 더 이야기해보자")
		choice_box.choice_made.connect(_on_choice, CONNECT_ONE_SHOT)
	elif Episode0State.current_state == Episode0State.State.RETURN_TO_PARTNER:
		dialogue_box.show_text("애인: \"대표님이 뭐라고 하시던? ...괜찮아, 우리 그냥 나가자.\"")
		await get_tree().create_timer(2.0).timeout
		dialogue_box.hide_box()
		Episode0State.advance_to(Episode0State.State.COLLECT_TRAVEL_ITEMS)
	elif Episode0State.current_state == Episode0State.State.COLLECT_TRAVEL_ITEMS:
		if Episode0State.all_items_collected():
			dialogue_box.show_text("애인: \"다 챙겼어? 그럼 가자!\"")
			Episode0State.advance_to(Episode0State.State.RETURN_BADGE)
		else:
			dialogue_box.show_text("애인: \"여행 물품 3가지 챙기는 거 잊지 마.\"")
	elif Episode0State.current_state == Episode0State.State.RETURN_BADGE:
		dialogue_box.show_text("애인: \"사원증 반납했어? 그럼 나가자!\"")
		if Episode0State.badge_returned:
			Episode0State.partner_joined = true
			Episode0State.advance_to(Episode0State.State.PARTNER_JOINED)
			partner.join_player()
			SceneTransition.go_to("res://scenes/maps/CompanyFront3D.tscn")

func _on_choice(index: int) -> void:
	if index == 0:
		Episode0State.advance_to(Episode0State.State.COLLECT_TRAVEL_ITEMS)
		dialogue_box.show_text("\"그래, 여행 물품 먼저 챙기고 같이 나가자.\"")
	else:
		Episode0State.advance_to(Episode0State.State.CHOICE_WAIT)
		dialogue_box.show_text("\"잠깐, 대표실 쪽에서 뭔가 소리가 나는 것 같아...\"")
		await get_tree().create_timer(2.0).timeout
		dialogue_box.hide_box()
		Episode0State.advance_to(Episode0State.State.EAVESDROP_BOSS)
		SceneTransition.go_to("res://scenes/maps/BossDoorHallway3D.tscn")

func _build_scene() -> void:
	# 바닥, 벽, 천장
	_box(self, Vector3(0, -0.05, 0), Vector3(10, 0.1, 8), "#43566A", "Floor")
	_box(self, Vector3(-5.1, 2.5, 0), Vector3(0.2, 5, 8), "#2D3A4A", "WallLeft")
	_box(self, Vector3(5.1, 2.5, 0), Vector3(0.2, 5, 8), "#2D3A4A", "WallRight")
	_box(self, Vector3(0, 2.5, -4.1), Vector3(10, 5, 0.2), "#2D3A4A", "WallBack")
	# 파트너 책상
	_box(self, Vector3(-2, 0.4, -2), Vector3(2, 0.8, 1.2), "#43566A", "PartnerDesk")
	_box(self, Vector3(-2, 0.85, -2), Vector3(2.2, 0.06, 1.3), "#2D3A4A", "PartnerDeskTop")
	_box(self, Vector3(-2, 1.3, -2.5), Vector3(1.0, 0.65, 0.06), "#17283A", "Monitor")
	_box(self, Vector3(-2, 0.92, -2.45), Vector3(0.08, 0.12, 0.06), "#4A5568", "MonitorStand")
	_box(self, Vector3(-2, 0.35, -1.2), Vector3(0.5, 0.7, 0.5), "#2D3A4A", "Chair")
	_box(self, Vector3(-2, 0.72, -0.98), Vector3(0.5, 0.7, 0.06), "#1E2733", "ChairBack")
	var partner_lamp = OmniLight3D.new()
	partner_lamp.position = Vector3(-2, 2.0, -2)
	partner_lamp.light_color = Color("#FFD76D")
	partner_lamp.light_energy = 1.5
	partner_lamp.omni_range = 3.5
	self.add_child(partner_lamp)
	# 아이템 책상
	_box(self, Vector3(2, 0.4, -2), Vector3(2, 0.8, 1.2), "#43566A", "ItemDesk")
	_box(self, Vector3(2, 0.85, -2), Vector3(2.2, 0.06, 1.3), "#2D3A4A", "ItemDeskTop")
	# 창문, 문
	for col in range(3):
		_box(self, Vector3(-3 + col * 2.5, 2.5, -4.0), Vector3(1.2, 1.0, 0.06), "#17283A", "Win%d" % col)
	_box(self, Vector3(4, 1.5, -3.9), Vector3(1.2, 3.0, 0.15), "#1E2733", "BossDoor")
	_box(self, Vector3(4, 1.5, -3.75), Vector3(1.0, 2.8, 0.05), "#3E6278", "BossGlass")
	_box(self, Vector3(-4, 1.5, -3.9), Vector3(1.2, 3.0, 0.15), "#1E2733", "LobbyDoor")
	_box(self, Vector3(-4, 1.5, -3.75), Vector3(1.0, 2.8, 0.05), "#3E6278", "LobbyGlass")
	# 여행 물품 3가지 (아이템 책상 위)
	_build_travel_items()
	# 책상 소품 및 실내 디테일 추가
	_add_desk_props()

## 여행 물품 3가지를 아이템 책상 위에 놓는다
func _build_travel_items() -> void:
	# 1. 오래된 카메라
	var cam := Node3D.new(); cam.name = "CameraItem"; cam.position = Vector3(1.3, 0.95, -2.0)
	add_child(cam)
	_box(cam, Vector3.ZERO, Vector3(0.26, 0.17, 0.14), "#1F2636", "CamBody")
	_cylinder(cam, Vector3(0, 0, 0.09), 0.06, 0.06, "#0D1322", "CamLens")
	_box(cam, Vector3(-0.08, 0.11, 0), Vector3(0.07, 0.05, 0.06), "#7488B8", "CamFlash")

	# 2. 비어 있는 여행 수첩
	var nb := Node3D.new(); nb.name = "NotebookItem"; nb.position = Vector3(2.0, 0.92, -2.0)
	add_child(nb)
	_box(nb, Vector3.ZERO, Vector3(0.24, 0.05, 0.30), "#C9934B", "NbCover")
	_box(nb, Vector3(0, 0.03, 0), Vector3(0.21, 0.02, 0.27), "#F8EAC8", "NbPages")
	_box(nb, Vector3(-0.09, 0.04, 0), Vector3(0.02, 0.03, 0.28), "#8A5C2E", "NbSpine")

	# 3. 작은 여행 가방
	var bag := Node3D.new(); bag.name = "TravelBagItem"; bag.position = Vector3(2.7, 1.02, -2.0)
	add_child(bag)
	_box(bag, Vector3.ZERO, Vector3(0.32, 0.26, 0.18), "#B17A3E", "BagBody")
	_box(bag, Vector3(0, 0.15, 0), Vector3(0.10, 0.05, 0.04), "#8A5C2E", "BagHandle")
	_box(bag, Vector3(0, 0.02, 0.10), Vector3(0.30, 0.04, 0.02), "#E8C868", "BagStrap")

func _add_desk_props() -> void:
	# ─── 커피컵 ───
	# 파트너 책상 위 커피컵 (컵 바디: 원기둥, 윗면: 눌린 구)
	_cylinder(self, Vector3(-2.3, 0.935, -1.85), 0.055, 0.09, "#C8A87A", "CupBody1")
	_squashed_sphere(self, Vector3(-2.3, 0.975, -1.85), 0.052, "#F5E8D8", "CupTop1")
	# 아이템 책상 위 커피컵
	_cylinder(self, Vector3(1.7, 0.935, -1.85), 0.055, 0.09, "#C8A87A", "CupBody2")
	_squashed_sphere(self, Vector3(1.7, 0.975, -1.85), 0.052, "#F5E8D8", "CupTop2")

	# ─── 스티커 메모지들 ───
	# 파트너 책상 위 노란 메모지 (약간 기울임)
	var memo1 = _box(self, Vector3(-2.1, 0.856, -2.3), Vector3(0.12, 0.003, 0.12), "#FFE87A", "Memo1")
	memo1.rotation_degrees.y = 8.0
	# 파트너 모니터 옆 분홍 메모지
	var memo2 = _box(self, Vector3(-1.47, 1.35, -2.48), Vector3(0.003, 0.12, 0.12), "#FFB0B8", "Memo2")
	memo2.rotation_degrees.z = -5.0
	# 아이템 책상 위 하늘색 메모지
	var memo3 = _box(self, Vector3(2.2, 0.856, -2.25), Vector3(0.12, 0.003, 0.12), "#B0E8FF", "Memo3")
	memo3.rotation_degrees.y = -12.0
	# 왼쪽 벽 가까이 노란 메모지 하나 더
	var memo4 = _box(self, Vector3(-1.85, 0.856, -2.1), Vector3(0.12, 0.003, 0.12), "#FFE87A", "Memo4")
	memo4.rotation_degrees.y = 20.0

	# ─── 천장 형광등 ───
	# 형광등 3개를 천장에 배치 (발광 소재)
	var light_positions = [
		Vector3(-3.0, 4.98, -1.5),
		Vector3(0.0, 4.98, -1.5),
		Vector3(3.0, 4.98, -1.5),
	]
	for i in range(light_positions.size()):
		var fl = MeshInstance3D.new()
		fl.name = "FluorescentLight%d" % i
		var fl_mesh = BoxMesh.new()
		fl_mesh.size = Vector3(1.2, 0.06, 0.25)
		fl.mesh = fl_mesh
		var fl_mat = StandardMaterial3D.new()
		fl_mat.albedo_color = Color("#FFFFFF")
		fl_mat.emission_enabled = true
		fl_mat.emission = Color("#FFFAE8")
		fl_mat.emission_energy_multiplier = 1.5
		fl_mat.roughness = 0.8
		fl.material_override = fl_mat
		fl.position = light_positions[i]
		self.add_child(fl)
		# 형광등 조명 (약한 흰 빛)
		var fl_light = OmniLight3D.new()
		fl_light.position = light_positions[i] + Vector3(0, -0.1, 0)
		fl_light.light_color = Color("#F5F5FF")
		fl_light.light_energy = 0.6
		fl_light.omni_range = 3.0
		self.add_child(fl_light)

	# ─── 쓰레기통 ───
	# 아이템 책상 오른쪽 아래
	_cylinder(self, Vector3(3.2, 0.175, -1.3), 0.15, 0.35, "#6A6A72", "TrashCan")
	# 쓰레기통 옆 구겨진 종이 (흰 구)
	var paper = MeshInstance3D.new()
	paper.name = "CrumpledPaper"
	var paper_mesh = SphereMesh.new()
	paper_mesh.radius = 0.06
	paper_mesh.height = 0.09
	paper.mesh = paper_mesh
	var paper_mat = StandardMaterial3D.new()
	paper_mat.albedo_color = Color("#E8E8EC")
	paper_mat.roughness = 0.95
	paper.material_override = paper_mat
	paper.position = Vector3(3.45, 0.06, -1.1)
	self.add_child(paper)

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, hex: String, label: String = "") -> MeshInstance3D:
	# 원기둥 메시 헬퍼
	var mi = MeshInstance3D.new()
	if label != "": mi.name = label
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _squashed_sphere(parent: Node3D, pos: Vector3, radius: float, hex: String, label: String = "") -> MeshInstance3D:
	# 납작한 구 (커피 거품/뚜껑 표현)
	var mi = MeshInstance3D.new()
	if label != "": mi.name = label
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 0.7  # 세로로 납작하게
	mi.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.9
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _box(parent: Node3D, pos: Vector3, size: Vector3, hex: String, label: String = "") -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	if label != "": mi.name = label
	var mesh = BoxMesh.new(); mesh.size = size; mi.mesh = mesh
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat; mi.position = pos; parent.add_child(mi); return mi


# ── 여행 물품 3가지 ──
func _pick_camera() -> void:
	if not _can_collect(): return
	Episode0State.has_camera = true
	dialogue_box.show_text("오래된 카메라를 챙겼어요.")
	_after_collect()

func _pick_notebook() -> void:
	if not _can_collect(): return
	Episode0State.has_notebook = true
	dialogue_box.show_text("비어 있는 여행 수첩을 챙겼어요. 앞으로 채워나가면 돼요.")
	_after_collect()

func _pick_bag() -> void:
	if not _can_collect(): return
	Episode0State.has_travel_bag = true
	dialogue_box.show_text("작은 여행 가방을 챙겼어요.")
	_after_collect()

func _can_collect() -> bool:
	if Episode0State.current_state < Episode0State.State.COLLECT_TRAVEL_ITEMS:
		dialogue_box.show_text("아직은 챙길 때가 아니에요.")
		return false
	return true

func _after_collect() -> void:
	_refresh_item_visibility()
	if Episode0State.all_items_collected():
		await get_tree().create_timer(1.6).timeout
		dialogue_box.show_text("세 가지를 다 챙겼어요. 애인에게 말을 걸어보세요.")

## 이미 챙긴 물품은 책상에서 사라진다
func _refresh_item_visibility() -> void:
	var map := {
		"CameraItem": Episode0State.has_camera,
		"NotebookItem": Episode0State.has_notebook,
		"TravelBagItem": Episode0State.has_travel_bag,
	}
	for item_name in map.keys():
		var mi := get_node_or_null(item_name)
		if mi: mi.visible = not map[item_name]
	for area_name in ["CameraItemInteract", "NotebookInteract", "TravelBagInteract"]:
		var a := get_node_or_null(area_name)
		if a == null: continue
		var taken := false
		match area_name:
			"CameraItemInteract": taken = Episode0State.has_camera
			"NotebookInteract": taken = Episode0State.has_notebook
			"TravelBagInteract": taken = Episode0State.has_travel_bag
		a.visible = not taken
		a.monitoring = not taken

func _go_boss_door() -> void:
	SceneTransition.go_to("res://scenes/maps/BossDoorHallway3D.tscn", "tense")

func _go_lobby() -> void:
	SceneTransition.go_to("res://scenes/maps/CompanyLobby3D.tscn")
