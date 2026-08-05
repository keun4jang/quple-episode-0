extends Node3D
## 쿼카전자 로비. 조용하고 차갑지만 무섭지는 않게.

## 프롭 라이브러리. class_name 대신 preload 로 잡는다 — 이유는 prop_kit.gd 머리말 참고.
const PropKit := preload("res://scripts/systems/prop_kit.gd")

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var dialogue_box = $DialogueBox

const CAM_OFFSET = Vector3(0, 6.4, 8.6)
const CAM_LOOK_OFFSET = Vector3(0, 1.6, -2.2)
const CAM_LERP = 5.0

## 밤 야근 각본이라 시간대를 따라가면 안 된다. 실내 밤으로 고정한다.
## _ready 가 아니라 _enter_tree 인 이유는 company_front_3d.gd 주석 참고.
func _enter_tree() -> void:
	$CinematicLook.mood = "night_office_indoor"

func _ready() -> void:
	_build_scene()
	player.add_to_group("player")
	AudioManager.play_bgm("episode0")
	$ToOfficeInteract.interacted.connect(_go_office)
	$ToFrontInteract.interacted.connect(_go_front)
	$BadgeBoxInteract.interacted.connect(_return_badge)
	PartnerSpawner.ensure(self, player)
	if Episode0State.current_state == Episode0State.State.ENTER_COMPANY:
		Episode0State.advance_to(Episode0State.State.FIND_PARTNER)
		await get_tree().create_timer(0.5).timeout
		dialogue_box.show_text("조용한 로비. 위층에만 불이 켜져 있어요.")

func _process(delta: float) -> void:
	var target_pos = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target_pos, CAM_LERP * delta)
	camera.look_at(player.global_position + CAM_LOOK_OFFSET, Vector3.UP)

func _go_office() -> void:
	SceneTransition.go_to("res://scenes/maps/Office3D.tscn")

func _go_front() -> void:
	SceneTransition.go_to("res://scenes/maps/CompanyFront3D.tscn")

func _return_badge() -> void:
	if Episode0State.current_state < Episode0State.State.RETURN_BADGE:
		dialogue_box.show_text("사원증 반납함이에요. 아직은 반납할 때가 아니에요.")
		return
	if Episode0State.badge_returned:
		dialogue_box.show_text("사원증은 이미 반납했어요.")
		return
	Episode0State.badge_returned = true
	dialogue_box.show_text("사원증을 반납했어요. 이제 정말 나가는 거예요.")
	Episode0State.partner_joined = true
	Episode0State.advance_to(Episode0State.State.PARTNER_JOINED)
	PartnerSpawner.ensure(self, player)

func _build_scene() -> void:
	# 바닥 / 벽 / 천장
	_box(self, Vector3(0, -0.05, 0), Vector3(20, 0.1, 20), "#3F4550", "Floor")
	_box(self, Vector3(0, 0.005, 0), Vector3(11, 0.02, 12), "#59616E", "FloorInner")
	_box(self, Vector3(0, 2.6, -7.0), Vector3(20, 5.4, 0.3), "#2D3A4A", "BackWall")
	_box(self, Vector3(-7.5, 2.6, 0), Vector3(0.3, 5.4, 14), "#2D3A4A", "LeftWall")
	_box(self, Vector3(7.5, 2.6, 0), Vector3(0.3, 5.4, 14), "#2D3A4A", "RightWall")

	# 안내 데스크
	_box(self, Vector3(-2.6, 0.55, -3.4), Vector3(3.4, 1.1, 0.9), "#43566A", "Desk")
	_box(self, Vector3(-2.6, 1.14, -3.4), Vector3(3.6, 0.08, 1.05), "#7F8790", "DeskTop")
	# 데스크 작은 램프 (따뜻한 점광)
	_cylinder(self, Vector3(-1.5, 1.28, -3.3), 0.05, 0.2, "#8A9099", "LampStem")
	var shade := _cylinder(self, Vector3(-1.5, 1.46, -3.3), 0.13, 0.16, "#FFD76D", "LampShade")
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("#FFD76D")
	lm.emission_enabled = true
	lm.emission = Color("#FFE7A8")
	lm.emission_energy_multiplier = 2.0
	shade.material_override = lm
	var lamp_light := OmniLight3D.new()
	lamp_light.light_color = Color("#FFD76D")
	lamp_light.light_energy = 1.1
	lamp_light.omni_range = 4.0
	lamp_light.position = Vector3(-1.5, 1.5, -3.3)
	add_child(lamp_light)

	# 출입 게이트 2개
	for gx in [-1.1, 1.1]:
		_box(self, Vector3(gx, 0.5, -1.0), Vector3(0.35, 1.0, 1.5), "#43566A", "Gate")
		_box(self, Vector3(gx, 1.02, -1.0), Vector3(0.4, 0.06, 1.6), "#7F8790", "GateTop")

	# 엘리베이터 문 (사무실로 가는 길)
	_box(self, Vector3(2.8, 1.5, -6.75), Vector3(2.2, 3.0, 0.14), "#1E2733", "ElevFrame")
	_box(self, Vector3(2.24, 1.45, -6.66), Vector3(1.0, 2.8, 0.06), "#43566A", "ElevDoorL")
	_box(self, Vector3(3.36, 1.45, -6.66), Vector3(1.0, 2.8, 0.06), "#43566A", "ElevDoorR")
	_box(self, Vector3(2.8, 3.15, -6.66), Vector3(0.5, 0.16, 0.05), "#FFD76D", "ElevSign")

	# 정문 (밖으로) — 왼쪽 벽에 두어 카메라 시야를 막지 않게 한다
	_box(self, Vector3(-7.35, 1.3, 3.2), Vector3(0.16, 2.6, 2.4), "#182533", "FrontDoor")
	_box(self, Vector3(-7.24, 1.3, 3.2), Vector3(0.05, 2.3, 2.1), "#3E6278", "FrontGlass")
	_box(self, Vector3(-7.24, 2.85, 3.2), Vector3(0.05, 0.22, 1.0), "#FFD76D", "ExitSign")

	# 사원증 반납함
	_box(self, Vector3(4.9, 0.55, -2.2), Vector3(0.7, 1.1, 0.5), "#43566A", "BadgeBoxBody")
	_box(self, Vector3(4.9, 1.13, -2.2), Vector3(0.75, 0.07, 0.55), "#7F8790", "BadgeBoxTop")
	_box(self, Vector3(4.9, 0.95, -1.96), Vector3(0.42, 0.05, 0.03), "#17283A", "BadgeSlot")

	# 벽시계 (22:47 느낌)
	_cylinder(self, Vector3(0, 3.6, -6.8), 0.42, 0.08, "#F2EEE2", "ClockFace")
	_box(self, Vector3(-0.10, 3.68, -6.72), Vector3(0.22, 0.035, 0.02), "#2D3A4A", "ClockHourHand")
	_box(self, Vector3(0.03, 3.50, -6.72), Vector3(0.035, 0.30, 0.02), "#2D3A4A", "ClockMinHand")

	# 화분 / 안내 표지판
	for px in [-6.2, 6.2]:
		_cylinder(self, Vector3(px, 0.28, -5.2), 0.32, 0.55, "#6D7D8F", "PlanterPot")
		_sphere(self, Vector3(px, 0.85, -5.2), 0.45, "#6FA98A", "PlanterLeaf")
	_cylinder(self, Vector3(-5.4, 0.8, 1.2), 0.04, 1.6, "#8A9099", "SignPole")
	_box(self, Vector3(-5.4, 1.68, 1.2), Vector3(0.6, 0.4, 0.05), "#43566A", "SignBoard")

	# 은은한 천장 조명
	for lz in [-4.0, 0.0, 4.0]:
		var cl := OmniLight3D.new()
		cl.light_color = Color("#B9A7E8")
		cl.light_energy = 0.55
		cl.omni_range = 9.0
		cl.position = Vector3(0, 4.2, lz)
		add_child(cl)

	# 빈 공간 채우기
	_add_lobby_details()

# ── 로비 소품 ──
#
# 로비가 바닥과 벽만 있어서 텅 비어 보였다. 천장 조명 / 기둥 / 선반 / 포스터 /
# 화분을 넣어 눈이 머물 데를 만든다. 전부 장식이라 충돌체는 붙이지 않는다
# (기존 로비도 전부 MeshInstance3D 다).
#
# 천장 판은 만들지 않는다. 카메라가 y 6.4 에서 27도로 내려다보는데 5.3 높이에
# 판을 덮으면 쿼카가 통째로 가려진다. 조명 기구와 매다는 봉으로 암시만 한다.
func _add_lobby_details() -> void:
	_add_ceiling_lights()
	_add_pillars()
	_add_reception_back()
	_add_wall_posters()
	_add_greenery()
	_add_lounge()

# 천장 조명 2줄 x 3칸. 줄을 맞춰야 천장이 있다고 읽힌다.
func _add_ceiling_lights() -> void:
	var y := 4.45                 # 벽 윗선(5.3) 바로 아래
	var hex := "#E8E2F4"          # 차가운 라벤더 로비에 맞춘 흰빛. 따뜻한 건 데스크 램프 하나면 된다.
	var xs: Array[float] = [-4.2, 4.2]
	var zs: Array[float] = [-5.4, -2.2, 1.0]
	var i := 0
	for lx in xs:
		for lz in zs:
			var p := Vector3(lx, y, lz)
			var fx := PropKit.ceiling_light(self, p, hex, 0.5)
			# 발광판은 6개 다 켜지만 진짜 광원은 지그재그로 3개만 남긴다.
			# gl_compatibility 는 오브젝트 하나가 받는 광원이 8개까지라
			# 기존 조명(천장 3 + 데스크 램프 1)에 6개를 더 얹으면 넘쳐서 깜빡인다.
			if i % 2 == 1:
				var omni := fx.get_node_or_null("LightOmni")
				if omni != null: omni.queue_free()
			# 매다는 봉. 천장 판이 없으니 벽 윗선까지만 올린다.
			_cylinder(self, p + Vector3(0, 0.45, 0), 0.028, 0.86, "#6E7684", "LightRod%d" % i)
			i += 1

# 기둥은 벽 쪽으로 물려 세운다. 가운데에 세우면 카메라와 쿼카 사이를 가린다.
func _add_pillars() -> void:
	var xs: Array[float] = [-6.0, 6.0]
	var zs: Array[float] = [-4.2, 0.6]
	for px in xs:
		for pz in zs:
			# 벽 윗선과 같은 5.3 까지 올려야 천장에 닿은 것처럼 보인다
			PropKit.pillar(self, Vector3(px, 0.0, pz), 5.3, "#6F7889", 0.3)

# 안내 데스크 뒤 선반 + 데스크 위 소품
func _add_reception_back() -> void:
	# 데스크(x -4.3~-0.9)가 앞을 가리므로 선반은 뒷벽(z -6.85)에 바짝 붙인다.
	# 나무색을 하나 섞어 두면 파랑 일색인 로비가 덜 차갑다.
	PropKit.shelf_unit(self, Vector3(-2.9, 0.0, -6.45), "#8A7159", 0.0)
	PropKit.shelf_unit(self, Vector3(-4.95, 0.0, -6.42), "#8A7159", 0.0)

	# 데스크 위 모니터. 사람은 없는데 대기 화면만 켜져 있다.
	var foot := _box(self, Vector3(-3.7, 1.21, -3.42), Vector3(0.26, 0.07, 0.18), "#6E7684", "DeskMonitorFoot")
	var scr := _box(self, Vector3(-3.7, 1.45, -3.46), Vector3(0.6, 0.4, 0.05), "#3E5468", "DeskMonitor")
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("#3E5468")
	sm.emission_enabled = true
	sm.emission = Color("#7FA8C8")
	sm.emission_energy_multiplier = 0.55   # 램프보다 훨씬 약하게. 밤 로비에서 화면만 튀면 안 된다.
	scr.material_override = sm
	foot.rotation_degrees.y = 14.0
	scr.rotation_degrees.y = 14.0
	# 서류 트레이
	_box(self, Vector3(-2.3, 1.225, -3.32), Vector3(0.42, 0.09, 0.3), "#8A9099", "DeskTray")

# 벽 포스터. 정문(왼쪽 벽 z 2.0~4.4)과 기둥 자리는 피해서 건다.
func _add_wall_posters() -> void:
	# 왼쪽 벽 — 기둥 두 개 사이 빈 구간
	PropKit.poster_panel(self, Vector3(-7.30, 2.05, -2.8), "#F2EEE2", 90.0)
	PropKit.poster_panel(self, Vector3(-7.30, 1.98, -0.8), "#EFE9F4", 90.0)
	# 오른쪽 벽 — 벤치 위
	PropKit.poster_panel(self, Vector3(7.30, 2.05, -0.9), "#F2EEE2", -90.0)
	# 뒷벽 — 선반과 엘리베이터 사이 빈 칸
	PropKit.poster_panel(self, Vector3(0.55, 2.15, -6.78), "#EFE9F4", 0.0)

# 화분. 기존 두 개(±6.2, -5.2)와 같은 모양으로 뒷벽과 앞쪽 구석에 더 놓는다.
func _add_greenery() -> void:
	_planter_pot(Vector3(1.05, 0.0, -6.25), 1.0)
	_planter_pot(Vector3(4.55, 0.0, -6.25), 0.85)
	_planter_pot(Vector3(6.6, 0.0, 2.4), 1.1)

# 대기 벤치와 러그. 앉을 자리가 보이면 로비가 로비처럼 읽힌다.
func _add_lounge() -> void:
	# 오른쪽 벽에 바짝. 통로 한가운데는 비워 둔다.
	var bp := Vector3(6.9, 0.0, -1.6)
	_box(self, bp + Vector3(0, 0.42, 0), Vector3(0.56, 0.09, 2.0), "#4E5C70", "BenchSeat")
	_box(self, bp + Vector3(0.28, 0.72, 0), Vector3(0.07, 0.5, 2.0), "#43566A", "BenchBack")
	var bzs: Array[float] = [-0.8, 0.8]
	for bz in bzs:
		_box(self, bp + Vector3(0, 0.2, bz), Vector3(0.4, 0.4, 0.09), "#6D7D8F", "BenchLeg")
	# 데스크 앞 러그. 게이트(x -1.275 부터)에 걸리지 않게 왼쪽으로 물린다.
	_box(self, Vector3(-2.8, 0.02, -2.0), Vector3(2.8, 0.02, 1.5), "#6E6478", "LobbyRug")

# 화분 하나. 잎은 이름을 PlanterLeaf 로 시작해야 LivingScene 이 흔들어 준다.
func _planter_pot(pos: Vector3, s: float) -> void:
	_cylinder(self, pos + Vector3(0, 0.28 * s, 0), 0.3 * s, 0.56 * s, "#6D7D8F", "PotBody")
	_cylinder(self, pos + Vector3(0, 0.57 * s, 0), 0.33 * s, 0.07 * s, "#7F8790", "PotRim")
	_sphere(self, pos + Vector3(0, 0.92 * s, 0), 0.34 * s, "#6FA98A", "PlanterLeafLow")
	_sphere(self, pos + Vector3(0.2 * s, 1.2 * s, -0.1 * s), 0.24 * s, "#7FBF97", "PlanterLeafTop")

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
