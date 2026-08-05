extends Node3D

## 프롭 라이브러리. class_name 대신 preload 로 잡는다 — 이유는 prop_kit.gd 머리말 참고.
const PropKit := preload("res://scripts/systems/prop_kit.gd")

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
	AudioManager.play_bgm("episode0")
	if Episode0State.partner_joined:
		# 합류했으면 책상이 아니라 플레이어 옆에서 따라온다
		partner.global_position = player.global_position + Vector3(1.1, 0, 0.7)
		partner.join_player()
	elif partner.has_method("set_emotion"):
		partner.set_emotion("tired")
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
	elif Episode0State.current_state >= Episode0State.State.PARTNER_JOINED:
		dialogue_box.show_text("애인: \"이제 나가자. 밖에서 사진 한 장 찍고.\"")
	elif Episode0State.current_state == Episode0State.State.RETURN_BADGE:
		if not Episode0State.badge_returned:
			dialogue_box.show_text("애인: \"로비에서 사원증만 반납하고 오면 돼.\"")
		else:
			dialogue_box.show_text("애인: \"사원증 반납했구나. 그럼 나가자!\"")
		if Episode0State.badge_returned:
			Episode0State.partner_joined = true
			Episode0State.advance_to(Episode0State.State.PARTNER_JOINED)
			partner.join_player()
			SceneTransition.go_to("res://scenes/maps/CompanyFront3D.tscn")

## 어느 쪽을 골라도 대표실 앞을 지나간다. 그 장면이 0편의 전환점이기 때문이다.
func _on_choice(index: int) -> void:
	Episode0State.advance_to(Episode0State.State.CHOICE_WAIT)
	if index == 0:
		dialogue_box.show_text("애인: \"그래, 가자. ...근데 대표님께 말은 하고 가야 하지 않을까?\"")
	else:
		dialogue_box.show_text("애인: \"잠깐, 아까부터 대표실 쪽에서 소리가 나는 것 같아...\"")
	await get_tree().create_timer(2.4).timeout
	dialogue_box.hide_box()
	Episode0State.advance_to(Episode0State.State.EAVESDROP_BOSS)
	SceneTransition.go_to("res://scenes/maps/BossDoorHallway3D.tscn", "tense")

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
	# 야근 사무실 밀도 (파티션·빈 자리·캐비닛·창밖 도시·매달린 조명)
	_build_night_office()

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


# ══ 야근 사무실 밀도 ══════════════════════════════════════════════════
#
# 책상 두 개에 벽 세 장이면 사무실이 아니라 빈 방이다. 사람이 있었던 흔적을
# 채워야 "혼자 남았다" 가 읽힌다. 파티션으로 자리를 나누고, 아무도 없는 책상과
# 서류 더미를 늘리고, 창밖에 도시를 세워 여기가 몇 층인지 알려 준다.
#
# 어두운 씬이라 새로 켜는 불은 두 개뿐이고 세기도 낮게 준다. 나머지 천장 등은
# 꺼진 채로 매달아 둔다 — 그게 야근이다.
#
# 전부 MeshInstance3D 라 충돌체가 없다. 플레이어는 그대로 지나다닌다.

## _build_scene 끝에서 한 번만 부른다.
func _build_night_office() -> void:
	_build_partitions()
	_build_empty_desks()
	_build_cabinets()
	_build_paper_piles()
	_build_window_city()
	_build_ceiling_row()
	_build_night_props()


# ─── 파티션 ───

## 책상 뒤와 옆을 낮은 칸막이로 두른다. 자리가 "누구의 자리" 로 읽힌다.
## 창(y 2.0 위)은 가리면 안 되니 높이를 1.3 아래로 묶어 둔다.
func _build_partitions() -> void:
	_partition(Vector3(-2.0, 0, -2.78), 2.40, 1.30, 0.0, 0)    # 파트너 자리 뒤
	_partition(Vector3(-3.24, 0, -2.16), 1.30, 1.15, 90.0, 1)  # 파트너 자리 왼쪽 날개
	_partition(Vector3(2.0, 0, -2.78), 2.40, 1.20, 0.0, 2)     # 아이템 책상 뒤
	_partition(Vector3(3.24, 0, -2.16), 1.30, 1.10, 90.0, 3)   # 아이템 책상 오른쪽 날개

## 칸막이 한 장. 천 패널 + 위에 얹힌 밝은 마감재. 메시 2개.
func _partition(pos: Vector3, width: float, height: float, yaw: float, idx: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Partition%d" % idx
	root.position = pos
	root.rotation_degrees.y = yaw
	add_child(root)
	_box(root, Vector3(0, height * 0.5, 0), Vector3(width, height, 0.06), "#4B5C73", "PartitionPanel")
	# 마감재를 한 톤 밝게. 위쪽에 선이 하나 생겨서 판의 두께가 읽힌다.
	_box(root, Vector3(0, height + 0.025, 0), Vector3(width + 0.05, 0.05, 0.10), "#6C7C93", "PartitionRail")
	return root


# ─── 아무도 없는 동료 책상 ───

## 빈 자리가 두 개 더 있어야 "다들 퇴근했다" 가 보인다. 양쪽 벽에 붙인다.
func _build_empty_desks() -> void:
	var left := _empty_desk(Vector3(-4.25, 0, -0.4), 90.0, "EmptyDeskLeft")
	var right := _empty_desk(Vector3(4.25, 0, 0.6), -90.0, "EmptyDeskRight")
	# 왼쪽 자리엔 서류가 그대로 남아 있다
	_paper_stack(left, Vector3(0.45, 0.83, 0.06), 3, "#E6E1D2", "LeftDeskPaper")
	# 오른쪽 모니터는 꺼졌는데 대기 등만 남아 있다. 아주 작게.
	_glow_box(right, Vector3(0.05, 0.965, -0.248), Vector3(0.03, 0.018, 0.012), "#F2A6A0", 0.8, "StandbyLed")

## 아무도 없는 동료 책상. 모니터는 꺼져 있다. 메시 6개.
func _empty_desk(pos: Vector3, yaw: float, label: String) -> Node3D:
	var root := Node3D.new()
	root.name = label
	root.position = pos
	root.rotation_degrees.y = yaw
	add_child(root)
	_box(root, Vector3(0, 0.38, 0), Vector3(1.50, 0.76, 0.90), "#3E5064", "DeskBody")
	_box(root, Vector3(0, 0.79, 0), Vector3(1.66, 0.06, 1.00), "#29354A", "DeskTop")
	_box(root, Vector3(-0.20, 1.16, -0.28), Vector3(0.72, 0.44, 0.05), "#1B2634", "DeskMonitor")
	_box(root, Vector3(-0.20, 0.87, -0.24), Vector3(0.07, 0.10, 0.05), "#4A5568", "DeskMonitorStand")
	# 의자는 책상에서 조금 물러나 있다. 딱 붙여 두면 아직 사람이 앉은 것처럼 보인다.
	_box(root, Vector3(0.18, 0.33, 0.46), Vector3(0.46, 0.66, 0.46), "#2D3A4A", "DeskChair")
	_box(root, Vector3(0.18, 0.68, 0.66), Vector3(0.46, 0.62, 0.06), "#1E2733", "DeskChairBack")
	return root


# ─── 캐비닛 ───

## 뒷벽 가운데는 파티션 사이로 뻥 뚫려 있어서 캐비닛 두 짝을 놓기 딱 좋다.
func _build_cabinets() -> void:
	_cabinet(Vector3(-0.55, 0, -3.62), Vector3(0.90, 1.15, 0.46), 3, 0.0, "FileCabinetA")
	_cabinet(Vector3(0.50, 0, -3.66), Vector3(0.86, 1.30, 0.44), 3, 0.0, "FileCabinetB")
	# 오른쪽 벽 낮은 수납장. 벽면이 통째로 비어 있으면 방이 반쪽으로 보인다.
	_cabinet(Vector3(4.40, 0, -0.80), Vector3(1.00, 0.75, 0.42), 2, -90.0, "FileCabinetC")

## 서류 캐비닛. 서랍 앞판과 손잡이가 있어야 상자가 아니라 캐비닛으로 읽힌다.
## 메시 2 + 서랍당 2개.
func _cabinet(pos: Vector3, size: Vector3, drawers: int, yaw: float, label: String) -> Node3D:
	var root := Node3D.new()
	root.name = label
	root.position = pos
	root.rotation_degrees.y = yaw
	add_child(root)
	_box(root, Vector3(0, size.y * 0.5, 0), size, "#54637A", "CabBody")
	# 상판이 조금 튀어나와야 위에 뭘 얹어 둘 자리로 보인다
	_box(root, Vector3(0, size.y + 0.02, 0), Vector3(size.x + 0.06, 0.04, size.z + 0.06), "#3B4A5E", "CabTop")
	var step := size.y / float(drawers)
	for i in range(drawers):
		var dy := step * (float(i) + 0.5)
		_box(root, Vector3(0, dy, size.z * 0.5 + 0.016), Vector3(size.x - 0.08, step - 0.07, 0.03), "#495A70", "CabDrawer%d" % i)
		_box(root, Vector3(0, dy + step * 0.24, size.z * 0.5 + 0.04), Vector3(size.x * 0.34, 0.045, 0.03), "#8C99AA", "CabHandle%d" % i)
	return root


# ─── 서류 더미 ───

## 야근의 이유. 책상 위와 캐비닛 위에 흩어 둔다.
func _build_paper_piles() -> void:
	_paper_stack(self, Vector3(-2.72, 0.89, -2.28), 3, "#E9E4D6", "PartnerPaper")
	_paper_stack(self, Vector3(1.15, 0.89, -2.42), 3, "#E4E0D2", "ItemPaper")
	_paper_stack(self, Vector3(-0.55, 1.21, -3.62), 3, "#E9E4D6", "CabinetPaper")

## 종이를 조금씩 어긋나게 쌓는다. 반듯하게 쌓으면 서류가 아니라 상자다.
## 메시 = sheets 개.
func _paper_stack(parent: Node3D, pos: Vector3, sheets: int, hex: String, label: String) -> void:
	for i in range(sheets):
		var w := 0.30 - float(i) * 0.012
		var s := _box(parent, pos + Vector3(0, 0.021 * float(i), 0), Vector3(w, 0.02, w * 1.28), hex, "%s%d" % [label, i])
		s.rotation_degrees.y = -10.0 + float(i) * 8.0


# ─── 창밖 도시 ───

## 벽에 구멍을 뚫는 대신 창유리(z=-4.0, 두께 0.06) 바로 앞에 얇게 겹쳐 세운다.
## 11m 떨어진 카메라에서는 2cm 차이가 안 보이고, 시커먼 사각형이던 창에 윤곽이 생긴다.
## 건물은 창유리보다 한 톤만 밝게 — 밤이라 실루엣만 겨우 보이는 게 맞다.
## 창당 메시 7개.
func _build_window_city() -> void:
	var win_x := [-3.0, -0.5, 2.0]
	# 창마다 스카이라인을 다르게. 같은 모양이 세 번 반복되면 바로 티가 난다.
	var heights := [
		[0.34, 0.56, 0.22],
		[0.46, 0.26, 0.62],
		[0.24, 0.58, 0.40],
	]
	var tone := ["#233650", "#1C2A3E", "#2A3D55"]
	for c in range(3):
		var cx: float = win_x[c]
		for b in range(3):
			var h: float = heights[c][b]
			var bw := 0.24 + float((b + c) % 3) * 0.07
			var bx := cx - 0.36 + float(b) * 0.36
			_box(self, Vector3(bx, 2.02 + h * 0.5, -3.955), Vector3(bw, h, 0.02),
				tone[(b + c) % 3], "CityBlock%d_%d" % [c, b])
			# 아직 불이 켜진 남의 사무실. 건물 두 채에만 준다 — 다 켜면 창이 하얗게 뜬다.
			if b < 2:
				_glow_box(self, Vector3(bx + 0.02, 2.02 + h * 0.62, -3.938),
					Vector3(0.045, 0.03, 0.01), "#FFD9A0", 0.8, "CityLight%d_%d" % [c, b])
		# 창틀 세로 살. 유리 한 장이 두 짝으로 나뉘어야 창으로 읽힌다.
		_box(self, Vector3(cx, 2.5, -3.920), Vector3(0.035, 1.0, 0.02), "#5A6B82", "WinMullion%d" % c)
		# 창턱. 뒤끝은 벽면(z=-4.0)에 물리고, 앞끝은 문 앞면(z=-3.825)까지 안 나오게 한다.
		# 왼쪽 창은 로비 문과 x 가 겹치는데, 문이 앞에 있어서 가려 준다.
		_box(self, Vector3(cx, 1.965, -3.940), Vector3(1.0, 0.06, 0.13), "#4E5F76", "WinSill%d" % c)


# ─── 천장 조명 ───

## 기존 형광등 3개는 y=4.98 이라 카메라 시야(위쪽 끝이 수평보다 2도 아래) 밖으로
## 거의 나간다. 천장(y=5)에서 봉으로 내려 매달아야 화면에 걸리고, 빛도 바닥까지 닿는다.
## 켜진 건 두 개뿐이고 세기도 0.35 — 야근이니 대부분 꺼져 있다.
func _build_ceiling_row() -> void:
	var lit: Array[Vector3] = [Vector3(-3.0, 4.1, 1.0), Vector3(3.0, 4.1, 1.0)]
	for p in lit:
		PropKit.ceiling_light(self, p, "#FFF3D8", 0.35)
		_box(self, p + Vector3(0, 0.46, 0), Vector3(0.05, 0.88, 0.05), "#6B7382", "LightRod")
	# 꺼진 등. 사람 없는 자리 위는 불이 꺼져 있다. 발광 없음, 라이트도 없음.
	var dark: Array[Vector3] = [Vector3(0.0, 4.1, 1.0), Vector3(0.0, 4.1, -3.3)]
	for p in dark:
		_box(self, p, Vector3(1.10, 0.05, 0.28), "#3D4A5C", "DarkLightPanel")
		_box(self, p + Vector3(0, 0.46, 0), Vector3(0.05, 0.88, 0.05), "#6B7382", "DarkLightRod")


# ─── 남은 소품 ───

func _build_night_props() -> void:
	# 파트너 모니터 화면. 야근 중이라 이 방에서 여기만 켜져 있다.
	# 세기를 0.45 로 낮게 준다 — 글로우가 켜져 있어서 조금만 올려도 얼굴이 탄다.
	_glow_box(self, Vector3(-2, 1.32, -2.462), Vector3(0.86, 0.50, 0.015), "#4E7A94", 0.45, "MonitorScreen")
	_box(self, Vector3(-2.18, 1.46, -2.448), Vector3(0.36, 0.028, 0.012), "#20313F", "ScreenLine0")
	_box(self, Vector3(-2.26, 1.39, -2.448), Vector3(0.20, 0.028, 0.012), "#20313F", "ScreenLine1")
	# 키보드와 마우스. 책상 위가 너무 깨끗하면 일하던 자리로 안 보인다.
	_box(self, Vector3(-2.0, 0.90, -1.74), Vector3(0.44, 0.02, 0.16), "#C3C9D3", "KeyboardPartner")
	_box(self, Vector3(-1.60, 0.905, -1.72), Vector3(0.07, 0.03, 0.11), "#C3C9D3", "MousePartner")
	_box(self, Vector3(2.30, 0.90, -1.68), Vector3(0.44, 0.02, 0.16), "#C3C9D3", "KeyboardItem")
	# 정수기. 뒷벽 캐비닛 옆.
	_cylinder(self, Vector3(1.70, 0.04, -3.60), 0.18, 0.08, "#5D6978", "CoolerBase")
	_cylinder(self, Vector3(1.70, 0.55, -3.60), 0.17, 0.94, "#C6CCD6", "CoolerBody")
	_cylinder(self, Vector3(1.70, 1.24, -3.60), 0.15, 0.44, "#A6C2D6", "CoolerBottle")
	_box(self, Vector3(1.70, 0.74, -3.42), Vector3(0.10, 0.08, 0.06), "#5D6978", "CoolerTap")
	# 왼쪽 벽 포스터. 빈 벽이 있으면 사무실이 아니라 창고로 보인다.
	PropKit.poster_panel(self, Vector3(-4.975, 2.30, -1.40), "#EDE7D8", 90.0)
	# 구석 화분
	_office_plant(Vector3(-4.60, 0, 2.40))

## 구석 관엽식물. 잎 이름이 "Plant" 로 시작해야 LivingScene 이 바람에 흔들어 준다.
## 메시 5개.
func _office_plant(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "OfficePlant"
	root.position = pos
	add_child(root)
	_cylinder(root, Vector3(0, 0.20, 0), 0.20, 0.40, "#8A6A54", "PotBody")
	_cylinder(root, Vector3(0, 0.42, 0), 0.22, 0.05, "#9C7A62", "PotRim")
	# 잎 세 장. 위로 길게 늘이고 바깥으로 살짝 눕혀야 관엽식물처럼 보인다.
	for i in range(3):
		var ang := 120.0 * float(i)
		var rad := deg_to_rad(ang)
		var leaf := _blob(root, Vector3(cos(rad) * 0.12, 0.82, sin(rad) * 0.12), 0.16, "#5E8F74", "PlantLeaf%d" % i)
		leaf.scale = Vector3(0.85, 2.6, 0.45)
		leaf.rotation_degrees = Vector3(0, -ang, -18.0)


# ─── 지역 메시 헬퍼 ───

## 발광 상자. 창밖 불빛과 모니터 화면처럼 정말 빛나야 하는 것에만 쓴다.
## DepthShading 은 발광 재질만 원본 그대로 남겨 둔다.
func _glow_box(parent: Node3D, pos: Vector3, size: Vector3, hex: String, energy: float, label: String) -> MeshInstance3D:
	var mi := _box(parent, pos, size, hex, label)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.emission_enabled = true
	mat.emission = Color(hex)
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.6
	mi.material_override = mat
	return mi

## 분할을 낮춘 구. 모바일이라 SphereMesh 기본값(64x32)을 그대로 쓰면
## 잎 한 장에 수천 폴리곤이 들어간다. 이 크기에서는 차이가 안 보인다.
func _blob(parent: Node3D, pos: Vector3, radius: float, hex: String, label: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = label
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.9
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


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
