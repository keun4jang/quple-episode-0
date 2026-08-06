extends Node3D

## 프롭 라이브러리. class_name 대신 preload 로 잡는다 — 이유는 prop_kit.gd 머리말 참고.
const PropKit := preload("res://scripts/systems/prop_kit.gd")

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var warm_window_light: OmniLight3D = $WarmWindowLight
@onready var dialogue_box = $DialogueBox

const CAM_OFFSET = Vector3(0, 4.0, 8.2)    # 쿼카가 화면에서 읽히는 거리까지 당긴다
const CAM_LERP = 5.0
const CAM_LOOK_OFFSET = Vector3(0, 2.2, -2.0)  # 쿼카와 건물 입구가 같이 잡히는 높이

var _light_time: float = 0.0
var _lit_window: MeshInstance3D = null

## 화면 무드는 실제 시각을 따라가지만 이 씬만은 아니다.
## 에피소드 0 은 "늦은 밤 야근" 으로 각본이 짜여 있다. 아침에 켰다고 회사 앞이
## 환해지면 대사도 조명도 전부 어긋난다. 그래서 밤으로 고정한다.
##
## _ready 가 아니라 _enter_tree 인 이유: _ready 는 자식이 먼저 돌아서
## CinematicLook 이 이미 실시간 무드를 발라 버린 뒤다. _enter_tree 는 부모가 먼저다.
func _enter_tree() -> void:
	$CinematicLook.mood = "night_office"

func _ready() -> void:
	_build_scene()
	player.add_to_group("player")
	AudioManager.play_bgm("episode0")
	AudioManager.play_ambient("wind")
	$EntranceInteract.interacted.connect(_enter_company)
	$PhotoSpot.interacted.connect(_try_photo)
	PartnerSpawner.ensure(self, player, Vector3(1.1, 0, 0.3))
	_setup_photo_stage()
	if Episode0State.current_state == Episode0State.State.START:
		_show_opening()
	elif Episode0State.current_state >= Episode0State.State.PARTNER_JOINED \
		and not Episode0State.first_photo_taken:
		Episode0State.advance_to(Episode0State.State.FIRST_PHOTO)
		_spawn_partner()
		await get_tree().create_timer(0.8).timeout
		dialogue_box.show_text("애인: \"오늘이 그 언젠가야.\"")
		await get_tree().create_timer(2.4).timeout
		dialogue_box.show_text("빛나는 자리에 서서 📷 를 눌러요.")

func _process(delta: float) -> void:
	var target_pos = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target_pos, CAM_LERP * delta)
	camera.look_at(player.global_position + CAM_LOOK_OFFSET, Vector3.UP)
	# 켜진 창문: 2.5초 주기로 아주 약하게 숨 쉬듯
	_light_time += delta
	var breathe := sin(_light_time * TAU / 2.5)
	warm_window_light.light_energy = 1.0 + breathe * 0.06
	if _lit_window and _lit_window.material_override:
		_lit_window.material_override.emission_energy_multiplier = 2.2 + breathe * 0.25
	# 사진 지점 반짝임
	if _photo_ring and _photo_ring.visible:
		_photo_t += delta
		_photo_ring.scale = Vector3.ONE * (1.0 + sin(_photo_t * 2.0) * 0.05)
		for i in range(_photo_sparks.size()):
			var sp: MeshInstance3D = _photo_sparks[i]
			if sp: sp.position.y = 0.55 + sin(_photo_t * 2.4 + float(i)) * 0.12

func _show_opening() -> void:
	await get_tree().create_timer(0.8).timeout
	dialogue_box.show_text("늦은 밤, 쿼카전자에는 딱 하나의 불빛만 남아 있어요.")
	Episode0State.advance_to(Episode0State.State.ENTER_COMPANY)

func _build_scene() -> void:
	# 도로, 인도, 횡단보도
	# 바닥 베이스(가장자리 잘림 방지)
	_box(self, Vector3(0, -0.12, 0), Vector3(60, 0.1, 60), "#2F3242", "GroundBase")
	_box(self, Vector3(0, -0.04, 6), Vector3(60, 0.08, 16), "#3B3E46", "Road")
	_box(self, Vector3(0, 0, -1), Vector3(60, 0.1, 6), "#7F8790", "Sidewalk")
	for i in range(-2, 3):
		_box(self, Vector3(i * 0.9, 0.01, 3.5), Vector3(0.45, 0.01, 2.5), "#F2EEE2", "Crosswalk%d" % i)
	# 건물 본체 및 창문
	_box(self, Vector3(0, 9, -6), Vector3(10, 18, 2), "#2D3A4A", "Building")
	_box(self, Vector3(-5.1, 9, -6), Vector3(0.2, 18, 2.5), "#1E2733", "BuildingLeft")
	_box(self, Vector3(5.1, 9, -6), Vector3(0.2, 18, 2.5), "#1E2733", "BuildingRight")
	# 창문 6칸 x 11줄. 단 하나만 따뜻하게 켜져 있다 (중간보다 위쪽)
	for row in range(11):
		for col in range(6):
			var wx = -4.25 + col * 1.7
			var wy = 2.2 + row * 1.4
			var is_lit = (row == 6 and col == 3)
			var color = "#FFD76D" if is_lit else "#17283A"
			var win = _box(self, Vector3(wx, wy, -4.95), Vector3(0.95, 0.75, 0.05), color, "Win_%d_%d" % [row, col])
			if is_lit:
				var lm = StandardMaterial3D.new()
				lm.albedo_color = Color("#FFE7A8")
				lm.emission_enabled = true
				lm.emission = Color("#FFD76D")
				lm.emission_energy_multiplier = 2.2
				win.material_override = lm
				_lit_window = win
				# 켜진 창문 바로 앞에 따뜻한 빛
				warm_window_light.position = Vector3(wx, wy, -4.3)
	# 간판, 출입문
	_box(self, Vector3(0, 18.5, -5.1), Vector3(5, 0.6, 0.3), "#FFD76D", "SignBG")
	_box(self, Vector3(0, 1.2, -5.0), Vector3(2.2, 2.4, 0.15), "#182533", "EntranceDoor")
	_box(self, Vector3(0, 1.2, -4.84), Vector3(2.0, 2.2, 0.05), "#3E6278", "DoorGlass")
	# 가로등, 볼라드, 벤치, 화분, 나무
	_lamppost(self, Vector3(-6, 0, -2))
	_lamppost(self, Vector3(6, 0, -2))
	for bx in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		_box(self, Vector3(bx, 0.2, 0.8), Vector3(0.18, 0.4, 0.18), "#6D7D8F", "Bollard")
	_bench(self, Vector3(-7, 0, -0.5))
	_planter(self, Vector3(3.5, 0, -2))
	_planter(self, Vector3(-3.5, 0, -2))
	_tree(self, Vector3(-8, 0, 0))
	_tree(self, Vector3(8, 0, 0))
	# 거리 소품 추가
	_add_street_details()
	# 밤거리 실루엣·소품 보강 (옥상 / 외벽 / 스카이라인 / 인도)
	_add_night_props()

func _add_street_details() -> void:
	# 쓰레기통 2개 (원기둥 형태)
	_cylinder(self, Vector3(-2.5, 0.28, 0.5), 0.18, 0.55, "#4A4A52", "Trashcan1")
	_cylinder(self, Vector3(3.2, 0.28, -0.8), 0.18, 0.55, "#4A4A52", "Trashcan2")

	# 자전거 거치대 (가로 바 + 세로 기둥 2개)
	_box(self, Vector3(-4.0, 0.35, 0.2), Vector3(1.2, 0.08, 0.12), "#888890", "BikeRackBar")
	_box(self, Vector3(-4.0 - 0.55, 0.35, 0.2), Vector3(0.08, 0.7, 0.08), "#888890", "BikeRackPostL")
	_box(self, Vector3(-4.0 + 0.55, 0.35, 0.2), Vector3(0.08, 0.7, 0.08), "#888890", "BikeRackPostR")

	# 버스 정류장 표지판 (폴 + 표지판)
	_cylinder(self, Vector3(5.0, 0.9, 0.2), 0.04, 1.8, "#C8C8D0", "BusStopPole")
	_box(self, Vector3(5.0, 1.95, 0.2), Vector3(0.4, 0.3, 0.06), "#4A7ACC", "BusStopSign")

	# 바닥 물웅덩이 반사 (얇은 원반, 반투명)
	var puddle_data = [
		[Vector3(-1.5, 0.002, 2.5), 0.6],
		[Vector3(2.8, 0.002, 3.2), 0.45],
		[Vector3(-3.5, 0.002, 3.8), 0.75],
		[Vector3(1.0, 0.002, 1.8), 0.4],
	]
	for i in range(puddle_data.size()):
		var pd = puddle_data[i]
		var mi = _cylinder(self, pd[0], pd[1], 0.005, "#7AB8D0", "Puddle%d" % i)
		# 물 반사 느낌: 낮은 roughness, 약간의 metallic
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.478, 0.722, 0.816, 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.1
		mat.metallic = 0.2
		mi.material_override = mat

	# 신호등 (기둥 + 함체 + 빨강/노랑/초록)
	_cylinder(self, Vector3(-6.8, 1.3, 1.4), 0.05, 2.6, "#4A5058", "TrafficPole")
	_box(self, Vector3(-6.8, 2.75, 1.4), Vector3(0.28, 0.72, 0.22), "#2C3138", "TrafficBox")
	var tl_colors = ["#E8544A", "#FFD76D", "#6FCF7F"]
	for ti in range(3):
		var lamp = _sphere_mi(self, Vector3(-6.8, 3.0 - ti * 0.22, 1.29), 0.07, tl_colors[ti], "TrafficLamp%d" % ti)
		var tm = StandardMaterial3D.new()
		tm.albedo_color = Color(tl_colors[ti])
		tm.emission_enabled = true
		tm.emission = Color(tl_colors[ti])
		tm.emission_energy_multiplier = 1.6 if ti == 2 else 0.25
		lamp.material_override = tm

	# CCTV 처럼 보이는 작은 박스 (건물 입구 위)
	_box(self, Vector3(-1.6, 3.05, -4.8), Vector3(0.1, 0.1, 0.26), "#3A4048", "CctvBody")
	_box(self, Vector3(-1.6, 3.22, -4.72), Vector3(0.06, 0.16, 0.06), "#3A4048", "CctvMount")

	# 안내 표지판 (기둥 + 판)
	_cylinder(self, Vector3(2.2, 0.7, 0.9), 0.04, 1.4, "#8A9099", "InfoPole")
	_box(self, Vector3(2.2, 1.5, 0.9), Vector3(0.62, 0.42, 0.05), "#43566A", "InfoSign")
	_box(self, Vector3(2.2, 1.58, 0.86), Vector3(0.46, 0.06, 0.02), "#F2EEE2", "InfoLine1")
	_box(self, Vector3(2.2, 1.44, 0.86), Vector3(0.34, 0.05, 0.02), "#F2EEE2", "InfoLine2")

	# 네온사인 "QUOKKA CORP" (건물 파사드 상단에 발광 박스)
	var neon_mi = MeshInstance3D.new()
	neon_mi.name = "NeonSign"
	var neon_mesh = BoxMesh.new()
	neon_mesh.size = Vector3(2.2, 0.35, 0.08)
	neon_mi.mesh = neon_mesh
	var neon_mat = StandardMaterial3D.new()
	neon_mat.albedo_color = Color("#88DDFF")
	neon_mat.emission_enabled = true
	neon_mat.emission = Color("#88DDFF")
	neon_mat.emission_energy_multiplier = 2.5
	neon_mat.roughness = 0.3
	neon_mi.material_override = neon_mat
	neon_mi.position = Vector3(0, 3.5, -4.9)
	self.add_child(neon_mi)

## 밤거리 실루엣·소품 보강.
## 회사 건물이 창문 격자만 붙은 18m 상자라, 하늘과 만나는 선에 아무 정보가 없었다.
## 옥상에 물건을 얹고, 외벽에 배관과 세로 간판을 붙이고, 좌우로 낮은 건물을 세운다.
##
## 규칙 하나만 지킨다 — 밝은 것을 늘리지 않는다.
## 이 씬의 주인공은 6층에 딱 하나 켜진 창이다. 새 조명(OmniLight)은 하나도 넣지 않고,
## 발광은 PropKit 이 원래 갖고 있는 작은 것들(간판 글자칸, 자판기 유리, 항공장애등)만 쓴다.
func _add_night_props() -> void:
	# ── 옥상 (건물 지붕면이 y=18) ──
	# 난간은 z 로 조금 물린다. 기존 간판 SignBG(z=-5.25) 와 부딪히지 않게.
	PropKit.parapet(self, Vector3(0, 18.0, -6.18), Vector2(10.0, 1.6), 0.5, "#3A4658")
	# 옥상 폭이 2m 뿐이라 기계실·물탱크는 작게 줄여 난간 안쪽에 앉힌다.
	PropKit.rooftop_unit(self, Vector3(-2.3, 18.0, -6.2), "#4E5A6E", 0.75)
	PropKit.water_tank(self, Vector3(2.7, 18.0, -6.16), "#8E9AA8", 0.7)
	# 안테나는 왼쪽 끝. 하늘로 그어진 선 하나가 건물 키를 알려 준다.
	PropKit.antenna(self, Vector3(-4.0, 18.0, -6.2), 3.0, "#96A0AE")

	# ── 외벽 ──
	# 정면은 창문 격자로 꽉 차 있다. 그래서 배관은 창을 피해
	# 왼쪽 코너 기둥(BuildingLeft, x=-5.1 / 앞면 z=-4.75) 을 타고 오른다.
	PropKit.pipe_run(self, Vector3(-5.1, 0.0, -4.72), 7.0, "#7E8898")
	# 오른쪽 코너에 세로 간판. 판은 은은하고 글자칸만 밝아서 켜진 창을 덮지 않는다.
	PropKit.vertical_sign(self, Vector3(5.15, 9.0, -4.76), 2.8, "#FFD76D")
	# 실외기는 왼쪽 옆 건물 벽면(z=-5.2)에. 띠창 사이 높이라 창을 가리지 않는다.
	PropKit.ac_units(self, Vector3(-9.6, 5.2, -5.19), 3, Vector2(2.8, 1.0), "#AEB7C3")

	# ── 좌우 스카이라인 ──
	# 회사 건물(x -5~5) 바깥으로만 물려 세운다. 높이를 다르게 줘야 톱니처럼 읽힌다.
	# 높이를 본관(18m)의 절반 아래로 낮추고 뒤로 물린다.
	# 처음엔 11~13m 로 세웠더니 좌우 하늘을 다 막아서, 이 씬의 감정을 만드는
	# 노을 그라데이션이 사라졌다. 실루엣은 살리되 하늘을 돌려준다.
	_skyline_block("A", -11.6, -9.4, Vector3(8.4, 7.2, 5.2), "#334053", "#2A3542")
	_skyline_block("B", -19.4, -10.4, Vector3(7.0, 4.8, 5.6), "#2B3648", "#232D3A")
	_skyline_block("C", 12.4, -9.6, Vector3(9.0, 8.4, 5.4), "#37435A", "#2C3645")

	# ── 인도 소품 ──
	# 자판기는 왼쪽 옆 건물 벽에 붙인다. 유리창이 약하게만 빛나는 물건이다.
	PropKit.vending_machine(self, Vector3(-7.6, 0.0, -4.83), "#C98BA0")
	PropKit.trash_bin(self, Vector3(-6.55, 0.0, -4.6), "#5E6A78")
	# 기존 거치대(x=-4) 와 겹치지 않게 한 벌 더 왼쪽에.
	PropKit.bicycle_rack(self, Vector3(-9.3, 0.0, 0.15), 2, "#96A0AC")
	# 기존 정류장 폴(x=5) 옆에 노선 표지판을 하나 더. 머리띠만 살짝 빛난다.
	PropKit.bus_sign(self, Vector3(6.9, 0.0, 0.55), "#8FA9C9")
	# 가로수는 종류를 섞는다. 기존 둥근 나무(x=±8) 바깥쪽으로 침엽수와 활엽수 하나씩.
	PropKit.tree_tall(self, Vector3(-11.2, 0.0, -0.4), "#5F9E86", "#6B4A34", 1.1)
	PropKit.tree_round(self, Vector3(10.8, 0.0, -0.6), "#72B48D", "#6B4A34", 1.05)

## 옆 건물 실루엣 한 채. 단순 박스 + 갓돌 + 띠창 3줄.
## 창은 전부 꺼진 색으로 둔다 — 이 거리에서 켜진 창은 회사 6층 하나뿐이어야 한다.
func _skyline_block(tag: String, cx: float, cz: float, size: Vector3, hex: String, cap_hex: String) -> void:
	var front := cz + size.z * 0.5
	_box(self, Vector3(cx, size.y * 0.5, cz), size, hex, "Skyline%s" % tag)
	# 갓돌 한 줄. 위가 그냥 잘려 있으면 종이를 오려 붙인 것처럼 보인다.
	_box(self, Vector3(cx, size.y + 0.16, cz), Vector3(size.x + 0.34, 0.32, size.z + 0.34),
		cap_hex, "Skyline%sCap" % tag)
	# 층을 알려 주는 띠창. 창을 한 칸씩 찍으면 메시가 금방 불어난다.
	for i in range(3):
		var wy := size.y * (0.34 + float(i) * 0.2)
		_box(self, Vector3(cx, wy, front + 0.04), Vector3(size.x * 0.74, 0.4, 0.06),
			"#1B2A3C", "Skyline%sWin%d" % [tag, i])

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

func _enter_company() -> void:
	SceneTransition.go_to("res://scenes/maps/CompanyLobby3D.tscn")


# ── 첫 사진 지점 ──
var _photo_ring: MeshInstance3D = null
var _photo_sparks: Array = []
var _photo_t: float = 0.0
var _photo_done: bool = false

func _setup_photo_stage() -> void:
	var active := Episode0State.current_state >= Episode0State.State.FIRST_PHOTO \
		and not Episode0State.first_photo_taken
	# 바닥의 노란 원형 빛
	_photo_ring = _cylinder(self, Vector3(0, 0.02, 1.4), 0.95, 0.02, "#FFD76D", "PhotoRing")
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1, 0.843, 0.427, 0.55)
	rm.emission_enabled = true
	rm.emission = Color("#FFD76D")
	rm.emission_energy_multiplier = 1.6
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_photo_ring.material_override = rm
	# 주변 반짝임
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var sp := _sphere_mi(self, Vector3(cos(a) * 1.15, 0.55, 1.4 + sin(a) * 1.15), 0.055, "#FFE7A8", "PhotoSpark%d" % i)
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color("#FFE7A8")
		sm.emission_enabled = true
		sm.emission = Color("#FFE7A8")
		sm.emission_energy_multiplier = 2.4
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sp.material_override = sm
		_photo_sparks.append(sp)
	_set_photo_stage_visible(active)

func _set_photo_stage_visible(v: bool) -> void:
	if _photo_ring: _photo_ring.visible = v
	for sp in _photo_sparks: sp.visible = v

## 합류한 애인을 회사 앞에 세운다
func _spawn_partner() -> void:
	var partner = PartnerSpawner.ensure(self, player, Vector3(1.1, 0, 0.3))
	if partner and partner.has_method("set_emotion"):
		partner.set_emotion("happy")
	_set_photo_stage_visible(true)

## F 로 첫 사진 찍기
func _try_photo() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("photo"): return
	if _photo_done: return
	if Episode0State.current_state < Episode0State.State.FIRST_PHOTO: return
	if player.global_position.distance_to(Vector3(0, player.global_position.y, 1.4)) > 1.6:
		dialogue_box.show_text("빛나는 자리로 가서 📷 를 눌러보세요.")
		return
	get_viewport().set_input_as_handled()
	_take_photo()

func _take_photo() -> void:
	_photo_done = true
	Episode0State.first_photo_taken = true
	AudioManager.shutter()
	# 0.2초 화면 플래시
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl := CanvasLayer.new(); cl.layer = 15
	cl.add_child(flash); add_child(cl)
	var tw := create_tween()
	tw.tween_property(flash, "color", Color(1, 1, 1, 0.0), 0.2)
	dialogue_box.show_text("찰칵!")
	await get_tree().create_timer(0.9).timeout
	cl.queue_free()
	_set_photo_stage_visible(false)

	# 앨범 첫 페이지 + 자동 저장
	Episode0State.advance_to(Episode0State.State.ALBUM_CREATED)
	dialogue_box.show_text("앨범의 첫 페이지가 생겼어요.")
	await get_tree().create_timer(1.6).timeout
	SaveManager.autosave("res://scenes/maps/CompanyFront3D.tscn", player.global_position)
	dialogue_box.show_text("여행 기록 저장 완료")
	await get_tree().create_timer(1.6).timeout
	dialogue_box.hide_box()

	# 0편 클리어
	Episode0State.advance_to(Episode0State.State.CLEAR)
	SaveManager.mark_episode0_cleared()
	SaveManager.autosave("res://scenes/maps/CompanyFront3D.tscn", player.global_position)
	var cs := load("res://scenes/ui/ClearScreen.tscn") as PackedScene
	if cs: add_child(cs.instantiate())
