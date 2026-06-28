extends Node3D

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var dialogue_box = $DialogueBox
@onready var choice_box = $ChoiceBox
@onready var partner = $PartnerQuokka3D

const CAM_OFFSET = Vector3(0, 9, 6)
const CAM_LERP = 5.0

func _ready() -> void:
	_build_scene()
	player.add_to_group("player")
	if Episode0State.partner_joined:
		partner.join_player()
	$PartnerInteract.interacted.connect(talk_to_partner)

func _process(delta: float) -> void:
	var target_pos = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target_pos, CAM_LERP * delta)
	camera.look_at(player.global_position + Vector3(0, 0.5, 0), Vector3.UP)

func talk_to_partner() -> void:
	if Episode0State.current_state == Episode0State.State.FIND_PARTNER:
		partner.set_emotion("happy")
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
			partner.set_emotion("excited")
			dialogue_box.show_text("애인: \"다 챙겼어? 그럼 가자!\"")
			Episode0State.advance_to(Episode0State.State.RETURN_BADGE)
		else:
			partner.set_emotion("nervous")
			dialogue_box.show_text("애인: \"여행 물품 3가지 챙기는 거 잊지 마.\"")
	elif Episode0State.current_state == Episode0State.State.RETURN_BADGE:
		if not Episode0State.badge_returned:
			dialogue_box.show_text("애인: \"사원증 먼저 반납하고 와. 로비 입구 쪽에 반납함 있어.\"")
			return
		partner.set_emotion("happy")
		dialogue_box.show_text("애인: \"사원증 반납했구나. 그럼 이제 진짜 나가자!\"")
		if Episode0State.badge_returned:
			Episode0State.partner_joined = true
			Episode0State.advance_to(Episode0State.State.PARTNER_JOINED)
			partner.join_player()
			SceneTransition.go_to("res://scenes/maps/CompanyFront3D.tscn", "hopeful")

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
	_box(self, Vector3(0, -0.05, 1), Vector3(10, 0.1, 14), "#43566A", "Floor")
	_box(self, Vector3(-5.1, 2.5, 1), Vector3(0.2, 5, 14), "#2D3A4A", "WallLeft")
	_box(self, Vector3(5.1, 2.5, 1), Vector3(0.2, 5, 14), "#2D3A4A", "WallRight")
	_box(self, Vector3(0, 2.5, -4.1), Vector3(10, 5, 0.2), "#2D3A4A", "WallBack")
	# 앞쪽 낮은 벽 (파란 빈 공간 가림, 카메라 시야 밖)
	_box(self, Vector3(0, 1.0, 7.9), Vector3(10, 2, 0.2), "#2D3A4A", "WallFront")
	# Ceiling 제거 - 카메라가 위에서 내려다보는 구조, 천장 없어야 플레이어 보임
	_box(self, Vector3(-2, 0.4, -2), Vector3(2, 0.8, 1.2), "#43566A", "PartnerDesk")
	_box(self, Vector3(-2, 0.85, -2), Vector3(2.2, 0.06, 1.3), "#2D3A4A", "PartnerDeskTop")
	_box(self, Vector3(-2, 1.3, -2.5), Vector3(1.0, 0.65, 0.06), "#17283A", "Monitor")
	var monitor_glow = OmniLight3D.new()
	monitor_glow.position = Vector3(-2, 1.3, -2.3)
	monitor_glow.light_color = Color("#1A3A5A")
	monitor_glow.light_energy = 0.3
	monitor_glow.omni_range = 1.0
	self.add_child(monitor_glow)
	_box(self, Vector3(-2, 0.92, -2.45), Vector3(0.08, 0.12, 0.06), "#4A5568", "MonitorStand")
	_box(self, Vector3(-2, 0.35, -1.2), Vector3(0.5, 0.7, 0.5), "#2D3A4A", "Chair")
	_box(self, Vector3(-2, 0.72, -0.98), Vector3(0.5, 0.7, 0.06), "#1E2733", "ChairBack")
	var partner_lamp = OmniLight3D.new()
	partner_lamp.position = Vector3(-2, 2.0, -2)
	partner_lamp.light_color = Color("#FFD76D")
	partner_lamp.light_energy = 1.5
	partner_lamp.omni_range = 3.5
	self.add_child(partner_lamp)
	_box(self, Vector3(2, 0.4, -2), Vector3(2, 0.8, 1.2), "#43566A", "ItemDesk")
	_box(self, Vector3(2, 0.85, -2), Vector3(2.2, 0.06, 1.3), "#2D3A4A", "ItemDeskTop")
	for col in range(3):
		_box(self, Vector3(-3 + col * 2.5, 2.5, -4.0), Vector3(1.2, 1.0, 0.06), "#17283A", "Win%d" % col)
	_box(self, Vector3(4, 1.5, -3.9), Vector3(1.2, 3.0, 0.15), "#1E2733", "BossDoor")
	_box(self, Vector3(4, 1.5, -3.75), Vector3(1.0, 2.8, 0.05), "#3E6278", "BossGlass")
	_box(self, Vector3(-4, 1.5, -3.9), Vector3(1.2, 3.0, 0.15), "#1E2733", "LobbyDoor")
	_box(self, Vector3(-4, 1.5, -3.75), Vector3(1.0, 2.8, 0.05), "#3E6278", "LobbyGlass")
	# Coffee cup on partner desk
	_box(self, Vector3(-2.3, 0.94, -1.8), Vector3(0.06, 0.1, 0.06), "#6D5040", "Cup")
	# Sticky notes on wall near monitor
	_box(self, Vector3(-1.5, 1.4, -3.95), Vector3(0.14, 0.11, 0.01), "#F5E642", "Note1")
	_box(self, Vector3(-1.7, 1.55, -3.95), Vector3(0.14, 0.11, 0.01), "#F5A042", "Note2")
	_box(self, Vector3(-1.3, 1.55, -3.95), Vector3(0.14, 0.11, 0.01), "#A0D8F0", "Note3")
	# Paper stack on item desk
	_box(self, Vector3(2.2, 0.91, -1.8), Vector3(0.3, 0.04, 0.2), "#F0EEE8", "Papers")
	# Ceiling fluorescent lights (fixture)
	_box(self, Vector3(-2, 4.95, -2), Vector3(1.2, 0.06, 0.3), "#E8E8E8", "Light1")
	_box(self, Vector3(2, 4.95, -2), Vector3(1.2, 0.06, 0.3), "#E8E8E8", "Light2")
	_box(self, Vector3(0, 4.95, 0), Vector3(1.2, 0.06, 0.3), "#E8E8E8", "Light3")
	# Ceiling light sources
	for lx in [-2.0, 2.0, 0.0]:
		var ceil_light = OmniLight3D.new()
		ceil_light.position = Vector3(lx, 4.7, -1.5)
		ceil_light.light_color = Color("#C8D8F0")
		ceil_light.light_energy = 0.5
		ceil_light.omni_range = 4.0
		self.add_child(ceil_light)
	# Small trash bin
	_box(self, Vector3(1, 0.2, -0.5), Vector3(0.3, 0.4, 0.3), "#4A5568", "Trash")
	# 바닥 러그 (구역 구분 - 디자인 디테일)
	_box(self, Vector3(0, 0.01, 1.5), Vector3(5, 0.02, 5), "#3A4A66", "Rug")
	_box(self, Vector3(0, 0.02, 1.5), Vector3(4.4, 0.02, 4.4), "#46587A", "RugInner")
	# 책장 (벽면 디테일)
	_box(self, Vector3(-4.6, 1.2, 1), Vector3(0.4, 2.4, 3), "#2A3850", "Bookshelf")
	for bsy in range(3):
		_box(self, Vector3(-4.5, 0.6 + bsy * 0.7, 1), Vector3(0.35, 0.06, 3), "#1E2A3C", "Shelf%d" % bsy)

func _box(parent: Node3D, pos: Vector3, size: Vector3, hex: String, label: String = "") -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	if label != "": mi.name = label
	var mesh = BoxMesh.new(); mesh.size = size; mi.mesh = mesh
	var mat = StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat; mi.position = pos; parent.add_child(mi); return mi
