extends Node3D
## 대표실 앞 복도. 문 너머에서 목소리가 들린다. 보스는 등장하지 않는다.

## 프롭 라이브러리. class_name 대신 preload 로 잡는다 — 이유는 prop_kit.gd 머리말 참고.
const PropKit := preload("res://scripts/systems/prop_kit.gd")

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var dialogue_box = $DialogueBox

const CAM_OFFSET = Vector3(0, 4.6, 6.4)
const CAM_LOOK_OFFSET = Vector3(0, 1.2, -4.0)
const CAM_LERP = 5.0

var _door_light: OmniLight3D = null
var _t: float = 0.0
var _listening: bool = false

## 밤 야근 각본이라 시간대를 따라가면 안 된다. 실내 밤으로 고정한다.
## _ready 가 아니라 _enter_tree 인 이유는 company_front_3d.gd 주석 참고.
func _enter_tree() -> void:
	$CinematicLook.mood = "night_office_indoor"

func _ready() -> void:
	_build_scene()
	player.add_to_group("player")
	AudioManager.play_bgm("episode0")
	$BossDoorInteract.interacted.connect(_eavesdrop)
	$BackInteract.interacted.connect(_go_back)
	PartnerSpawner.ensure(self, player)
	await get_tree().create_timer(0.5).timeout
	dialogue_box.show_text("문 너머에서 목소리가 새어 나와요.")

func _process(delta: float) -> void:
	var target_pos = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target_pos, CAM_LERP * delta)
	camera.look_at(player.global_position + CAM_LOOK_OFFSET, Vector3.UP)
	# 문틈 빛이 아주 약하게 흔들린다
	_t += delta
	if _door_light:
		_door_light.light_energy = 0.8 + sin(_t * 2.2) * 0.08

## 엿듣기 — 0편의 감정 전환점
func _eavesdrop() -> void:
	if _listening:
		return
	_listening = true
	var lines := [
		"대표: \"사람은 도구처럼 쓰면 돼.\"",
		"대표: \"지치면 바꾸면 그만이지.\"",
		"……",
		"이제 정말 나가야 해.",
	]
	for line in lines:
		dialogue_box.show_text(line)
		await get_tree().create_timer(2.2).timeout
	dialogue_box.hide_box()
	Episode0State.advance_to(Episode0State.State.RETURN_TO_PARTNER)
	await get_tree().create_timer(0.3).timeout
	SceneTransition.go_to("res://scenes/maps/Office3D.tscn", "tense")

func _go_back() -> void:
	SceneTransition.go_to("res://scenes/maps/Office3D.tscn")

func _build_scene() -> void:
	# 복도 바닥 / 벽 / 천장
	_box(self, Vector3(0, -0.05, 0), Vector3(7, 0.1, 22), "#3B4250", "Floor")
	_box(self, Vector3(0, 0.005, 0), Vector3(4.4, 0.02, 22), "#4A5364", "FloorRunner")
	_box(self, Vector3(-3.4, 1.8, 0), Vector3(0.3, 3.8, 22), "#2D3A4A", "LeftWall")
	_box(self, Vector3(3.4, 1.8, 0), Vector3(0.3, 3.8, 22), "#2D3A4A", "RightWall")
	_box(self, Vector3(0, 1.8, -8.6), Vector3(7, 3.8, 0.3), "#2D3A4A", "EndWall")

	# 대표실 큰 문
	_box(self, Vector3(0, 1.45, -8.35), Vector3(2.9, 3.0, 0.16), "#1E2733", "BossDoorFrame")
	_box(self, Vector3(-0.72, 1.4, -8.24), Vector3(1.3, 2.8, 0.07), "#43566A", "BossDoorL")
	_box(self, Vector3(0.72, 1.4, -8.24), Vector3(1.3, 2.8, 0.07), "#43566A", "BossDoorR")
	_box(self, Vector3(0, 3.15, -8.24), Vector3(1.5, 0.24, 0.05), "#FFD76D", "BossPlate")
	_sphere(self, Vector3(-0.22, 1.25, -8.18), 0.07, "#C8C8D0", "BossKnobL")
	_sphere(self, Vector3(0.22, 1.25, -8.18), 0.07, "#C8C8D0", "BossKnobR")

	# 문틈에서 새어 나오는 빛 (안에 사람이 있다는 신호)
	var slit := _box(self, Vector3(0, 0.06, -8.12), Vector3(2.5, 0.06, 0.05), "#FFD76D", "DoorSlit")
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("#FFE7A8")
	sm.emission_enabled = true
	sm.emission = Color("#FFD76D")
	sm.emission_energy_multiplier = 2.2
	slit.material_override = sm
	_door_light = OmniLight3D.new()
	_door_light.light_color = Color("#FFD76D")
	_door_light.light_energy = 0.8
	_door_light.omni_range = 4.5
	_door_light.position = Vector3(0, 0.5, -7.7)
	add_child(_door_light)

	# 차가운 복도 조명
	for lz in [-6.0, -2.0, 2.0, 6.0]:
		_box(self, Vector3(0, 3.55, lz), Vector3(1.2, 0.06, 0.35), "#C7D4E4", "CeilPanel")
		var cl := OmniLight3D.new()
		cl.light_color = Color("#8FA6C4")
		cl.light_energy = 0.5
		cl.omni_range = 7.0
		cl.position = Vector3(0, 3.3, lz)
		add_child(cl)

	# 복도 소품: 화분, 소화기, 액자
	_cylinder(self, Vector3(-2.7, 0.26, -6.0), 0.28, 0.5, "#6D7D8F", "PlanterPot")
	_sphere(self, Vector3(-2.7, 0.78, -6.0), 0.4, "#5E9B80", "PlanterLeaf")
	_cylinder(self, Vector3(2.8, 0.32, -4.0), 0.11, 0.62, "#C0504A", "Extinguisher")
	for fz in [-3.0, 1.0]:
		_box(self, Vector3(-3.2, 2.0, fz), Vector3(0.05, 0.7, 1.0), "#43566A", "Frame")
		_box(self, Vector3(-3.16, 2.0, fz), Vector3(0.02, 0.56, 0.86), "#5A6B80", "FrameArt")

	# 빈 복도 채우기
	_add_hallway_details()

# ── 복도 소품 ──
#
# 복도가 폭 6.5 짜리 상자 하나라 걸어도 걷는 느낌이 안 났다. 좁은 대신 원근이
# 세니까, 같은 요소를 일정 간격으로 반복해서 통로가 저 혼자 깊어 보이게 한다 —
# 벽기둥 / 바닥 이음매 / 옆문. 시선은 끝의 대표실 문에 모여야 하므로
# 문 쪽만 밝고 촘촘하게 두고 뒤로 갈수록 성기게 둔다.
#
# 천장 판은 만들지 않는다. 카메라가 y 4.7 에서 18도로 내려다보기 때문에
# 3.7 높이를 덮으면 복도가 통째로 가려진다. 폭을 다 가로지르는 들보도 같은 이유로
# 안 쓴다 — 화면 한가운데를 잘라 버린다. 벽 윗단 몰딩으로 천장선만 암시한다.
#
# 전부 장식이라 충돌체는 붙이지 않는다(기존 복도도 전부 MeshInstance3D 다).
# 대신 통로(러너 폭 4.4)를 비우고 |x| > 2.4 에만 놓는다. 안 그러면 쿼카가
# 화분을 뚫고 지나간다.

const WALL_X := 3.25      # 좌우 벽 안쪽 면
const END_Z := -8.45      # 복도 끝 벽 안쪽 면

func _add_hallway_details() -> void:
	_add_wall_trim()
	_add_side_doors()
	_add_hall_props()
	_add_boss_door_focus()

## 걸레받이 + 윗단 몰딩 + 벽기둥 + 바닥 이음매.
## 긴 선 몇 줄과 반복만으로 복도가 깊어 보인다. 소품보다 이게 효과가 크다.
func _add_wall_trim() -> void:
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		_box(self, Vector3(_wall_x(side, 0.03), 0.11, 0), Vector3(0.08, 0.22, 22), "#26313F", "Baseboard")
		_box(self, Vector3(_wall_x(side, 0.05), 3.34, 0), Vector3(0.14, 0.16, 22), "#39485C", "CrownMold")
	# 벽기둥. 좌우를 어긋나게 세워야 좁은 통로가 더 좁아 보이지 않는다.
	var left_z: Array[float] = [-7.7, -4.2, -0.8, 2.6, 6.0]
	var right_z: Array[float] = [-6.0, -2.6, 0.8, 4.2, 7.6]
	for i in range(left_z.size()):
		_box(self, Vector3(_wall_x(-1.0, 0.07), 1.66, left_z[i]), Vector3(0.16, 3.32, 0.28), "#37455A", "PilasterL%d" % i)
	for i in range(right_z.size()):
		_box(self, Vector3(_wall_x(1.0, 0.07), 1.66, right_z[i]), Vector3(0.16, 3.32, 0.28), "#37455A", "PilasterR%d" % i)
	# 바닥 이음매. 발밑에 가로선이 지나가면 걷는 속도가 눈에 보인다.
	var seams: Array[float] = [-6.6, -3.6, -0.6, 2.4, 5.4, 8.4]
	for i in range(seams.size()):
		_box(self, Vector3(0, 0.018, seams[i]), Vector3(4.4, 0.012, 0.05), "#333D4E", "FloorSeam%d" % i)

## 옆문 넷. 같은 문이 이어져야 "대표실 하나"가 아니라 "사무실 복도"로 읽힌다.
## 두 개만 불이 남아 있다 — 아직 못 간 사람이 있는 방.
func _add_side_doors() -> void:
	_side_door(0, -1.0, -5.3, "#43566A", true)
	_side_door(1, 1.0, -0.9, "#405264", false)
	_side_door(2, -1.0, 4.3, "#47596D", false)
	_side_door(3, 1.0, 5.9, "#42546A", true)
	# 비상구. 복도에서 유일하게 초록빛이 도는 것이라 끝쪽 문과 균형이 맞는다.
	_exit_sign(Vector3(_wall_x(-1.0, 0.06), 3.0, 4.3), 90.0)

func _side_door(idx: int, side: float, z: float, hex: String, lit: bool) -> void:
	var g := _group("SideDoor%d" % idx, Vector3(0, 0, z))
	_box(g, Vector3(_wall_x(side, 0.04), 1.30, 0), Vector3(0.10, 2.52, 1.52), "#36445A", "DoorCase")
	_box(g, Vector3(_wall_x(side, 0.05), 1.25, 0), Vector3(0.05, 2.30, 1.26), hex, "DoorLeaf")
	_sphere(g, Vector3(_wall_x(side, 0.13), 1.12, -0.46), 0.055, "#C8C8D0", "DoorKnob")
	# 문패는 문짝이 아니라 옆 벽에. 문짝에 붙이면 문 열릴 때 같이 도는 물건이 된다.
	_box(g, Vector3(_wall_x(side, 0.02), 2.05, -0.98), Vector3(0.02, 0.20, 0.34), "#D6DEE9", "DoorPlate")
	var glass := _box(g, Vector3(_wall_x(side, 0.07), 1.86, 0), Vector3(0.02, 0.52, 0.80), "#CFE0EE", "DoorGlass")
	if lit:
		_glow(glass, "#DCE9F2", 0.75)

## 복도 소품 — 소화전함, 화분, 액자, 대기 의자, 쓰레기통.
## 벽에 붙는 건 벽기둥 사이 빈 칸에만 건다.
func _add_hall_props() -> void:
	# 소화전함. 원색 빨강은 안 쓴다. 벽돌빛으로 낮춘다.
	_fire_cabinet(1.0, -6.6)

	# 액자. 기존 왼쪽 벽 두 개(z -3.0 / 1.0) 사이와 오른쪽 벽에 더 건다.
	PropKit.poster_panel(self, Vector3(-3.21, 2.00, -1.7), "#F2EEE2", 90.0)
	PropKit.poster_panel(self, Vector3(3.21, 1.96, 2.5), "#EFE9F4", -90.0)

	# 화분 하나 더. 기존 것(-2.7, -6.0)과 같은 톤으로.
	_pot_plant(0, Vector3(-2.80, 0.0, 1.9), "#5E9B80", "#6FA98A", 1.0, 118.0)

	# 대기 의자. 앉을 일은 없지만, 문 앞에서 기다리는 복도라는 뜻이 된다.
	_hall_chair(Vector3(-2.65, 0.0, -2.9), 90.0)

	# 쓰레기통. 발밑에 덩어리가 하나 있으면 바닥이 덜 비어 보인다.
	PropKit.trash_bin(self, Vector3(2.88, 0.0, 3.4), "#5E6A78")

## 대표실 문 주변. 여기가 이 씬의 전부라 문 자체는 비워 두고 둘레만 채운다.
## 화분 두 개로 문을 감싸고, 위에서 조명 하나를 더 내려 눈이 문으로 떨어지게 한다.
func _add_boss_door_focus() -> void:
	# 문 앞 매트. 바닥에 밝은 사각형이 하나 있으면 시선이 거기서 멈춘다.
	_box(self, Vector3(0, 0.016, -7.45), Vector3(2.30, 0.02, 1.05), "#4F5A73", "DoorMat")
	_box(self, Vector3(0, 0.024, -7.45), Vector3(2.02, 0.02, 0.83), "#5D6A85", "DoorMatInner")

	# 문 양옆 화분. 쿼카가 지나는 러너(폭 4.4) 밖으로 물려 둔다 — 충돌체가 없어서
	# 안쪽에 두면 잎을 뚫고 걸어간다. 곁잎도 벽 쪽으로 돌려 통로를 비운다.
	_pot_plant(1, Vector3(-2.68, 0.0, -7.50), "#5E9B80", "#6FA98A", 1.12, -152.0)
	_pot_plant(2, Vector3(2.68, 0.0, -7.55), "#5A9880", "#6BA486", 1.04, 34.0)

	# 문 위 천장 조명. 기존 복도 조명보다 밝게 해서 문만 도드라지게 한다.
	# 광원은 하나만 더 얹는다 — gl_compatibility 는 오브젝트 하나가 받는 광원이
	# 8개까지고 이 복도엔 이미 천장 4 + 문틈 1 이 있다.
	PropKit.ceiling_light(self, Vector3(0, 3.50, -7.80), "#CFE0F2", 0.6)

	# 끝 벽 — 문 좌우 빈 벽면. 여기가 비면 문이 허공에 뜬 것처럼 보인다.
	PropKit.poster_panel(self, Vector3(-2.35, 1.95, END_Z + 0.04), "#F2EEE2", 0.0)
	_notice_board(Vector3(2.45, 1.95, END_Z + 0.04))

	# 문 옆 명패. 큰 금색 판(BossPlate)은 문 위에 있으니 이건 작게.
	_box(self, Vector3(1.72, 2.30, END_Z + 0.05), Vector3(0.34, 0.22, 0.03), "#D6DEE9", "BossNamePlate")
	_box(self, Vector3(1.72, 2.35, END_Z + 0.07), Vector3(0.22, 0.035, 0.01), "#6E7684", "BossNameLine0")
	_box(self, Vector3(1.72, 2.27, END_Z + 0.07), Vector3(0.16, 0.03, 0.01), "#8A9099", "BossNameLine1")

# ── 복도 소품 헬퍼 ──

## 벽면에서 d 만큼 복도 안쪽으로 나온 x. side 는 -1(왼벽) / +1(오른벽).
func _wall_x(side: float, d: float) -> float:
	return (WALL_X - d) * side

## 프롭 하나를 담는 뿌리.
## 이름이 겹치면 Godot 이 "@PotLeaf@7" 로 바꿔 버려서 LivingScene 이 잎사귀를
## 못 알아본다. 그래서 프롭마다 뿌리를 따로 두고 안에서만 이름을 맞춘다.
func _group(label: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = label
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	return n

## 빛나는 면. DepthShading 이 발광 재질만 원본 그대로 남겨 둔다.
func _glow(mi: MeshInstance3D, hex: String, energy: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.emission_enabled = true
	m.emission = Color(hex)
	m.emission_energy_multiplier = energy
	m.roughness = 0.5
	mi.material_override = m

## 소화전함. 복도마다 하나씩 있는 붉은 상자.
func _fire_cabinet(side: float, z: float) -> void:
	var g := _group("FireCabinet", Vector3(0, 0, z))
	var y := 1.55
	_box(g, Vector3(_wall_x(side, 0.05), y, 0), Vector3(0.12, 0.98, 0.64), "#36445A", "CabCase")
	_box(g, Vector3(_wall_x(side, 0.12), y, 0), Vector3(0.06, 0.88, 0.56), "#C0736B", "CabDoor")
	_box(g, Vector3(_wall_x(side, 0.16), y + 0.16, 0), Vector3(0.02, 0.40, 0.42), "#E4D6C6", "CabGlass")
	_box(g, Vector3(_wall_x(side, 0.16), y - 0.30, 0), Vector3(0.02, 0.10, 0.34), "#F0E4D2", "CabLabel")
	_cylinder(g, Vector3(_wall_x(side, 0.17), y - 0.05, -0.22), 0.02, 0.14, "#C8C8D0", "CabHandle")

## 복도 화분. 잎 이름이 PotLeaf 로 시작해야 LivingScene 이 바람에 흔들어 준다.
## yaw 로 곁잎이 뻗는 쪽을 돌린다. 셋 다 같은 쪽으로 뻗으면 복사한 티가 난다.
func _pot_plant(idx: int, pos: Vector3, hex: String, hex2: String, s: float, yaw: float) -> void:
	var g := _group("PotPlant%d" % idx, pos, yaw)
	var ph := 0.46 * s
	_cylinder(g, Vector3(0, ph * 0.5, 0), 0.26 * s, ph, "#6D7D8F", "PotBody")
	_cylinder(g, Vector3(0, ph - 0.02, 0), 0.29 * s, 0.07, "#7C8B9D", "PotRim")
	_cylinder(g, Vector3(0, ph + 0.015, 0), 0.24 * s, 0.03, "#4A3E36", "PotSoil")
	# 잎은 위로 길쭉하게 눌러 둔다. 완전한 구는 화분이 아니라 사탕처럼 보인다.
	var l0 := _sphere(g, Vector3(0, ph + 0.40 * s, 0), 0.34 * s, hex, "PotLeafMain")
	l0.scale = Vector3(1.0, 1.3, 1.0)
	var l1 := _sphere(g, Vector3(0.17 * s, ph + 0.22 * s, -0.09 * s), 0.22 * s, hex2, "PotLeafSide")
	l1.scale = Vector3(1.15, 0.9, 1.0)

## 복도 대기 의자.
func _hall_chair(pos: Vector3, yaw: float) -> void:
	var g := _group("HallChair", pos, yaw)
	_box(g, Vector3(0, 0.44, 0), Vector3(0.50, 0.06, 0.48), "#7A8798", "ChairSeat")
	_box(g, Vector3(0, 0.71, -0.21), Vector3(0.50, 0.50, 0.06), "#7A8798", "ChairBack")
	for i in range(4):
		var lx := (float(i % 2) * 2.0 - 1.0) * 0.20
		var lz := (floorf(float(i) / 2.0) * 2.0 - 1.0) * 0.19
		_box(g, Vector3(lx, 0.22, lz), Vector3(0.045, 0.44, 0.045), "#5A6472", "ChairLeg%d" % i)

## 게시판. 종이 몇 장만 붙어 있어도 사람이 드나드는 복도가 된다.
func _notice_board(pos: Vector3) -> void:
	var g := _group("NoticeBoard", pos)
	_box(g, Vector3(0, 0, 0), Vector3(1.10, 0.80, 0.05), "#5E4A38", "NoticeFrame")
	_box(g, Vector3(0, 0, 0.032), Vector3(1.00, 0.70, 0.02), "#4F6152", "NoticeCork")
	var offs: Array[Vector3] = [Vector3(-0.27, 0.13, 0), Vector3(0.11, 0.15, 0), Vector3(-0.03, -0.17, 0)]
	var sizes: Array[Vector2] = [Vector2(0.26, 0.30), Vector2(0.30, 0.26), Vector2(0.34, 0.22)]
	var cols: Array[String] = ["#EDE7DA", "#D9E4F0", "#F2E3D0"]
	for i in range(3):
		# 살짝 비뚤어야 손으로 붙인 것처럼 보인다
		var p := _box(g, offs[i] + Vector3(0, 0, 0.044), Vector3(sizes[i].x, sizes[i].y, 0.01), cols[i], "NoticePaper%d" % i)
		p.rotation_degrees.z = (float(i) - 1.0) * 2.6

## 비상구 표시. 파스텔 민트로 낮춘다. 형광 초록은 이 톤에서 혼자 튄다.
func _exit_sign(pos: Vector3, yaw: float) -> void:
	var g := _group("ExitSign", pos, yaw)
	_box(g, Vector3(0, 0, 0), Vector3(0.44, 0.20, 0.06), "#3C4A56", "ExitCase")
	var face := _box(g, Vector3(0, 0, 0.04), Vector3(0.38, 0.15, 0.02), "#A8D5C2", "ExitFace")
	_glow(face, "#A8D5C2", 1.3)
	var arrow := _box(g, Vector3(0.10, 0, 0.055), Vector3(0.10, 0.07, 0.01), "#EAF6EF", "ExitArrow")
	_glow(arrow, "#EAF6EF", 0.9)

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
