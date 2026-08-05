extends Node3D
## 기념품 방. 여행에서 모아온 사진이 선반에 하나씩 쌓인다.
## 방문할수록 방이 채워지는 게 눈에 보이는 것이 이 화면의 목적이다.

## 프롭 라이브러리. class_name 대신 preload 로 잡는다 — 이유는 prop_kit.gd 머리말 참고.
const PropKit := preload("res://scripts/systems/prop_kit.gd")

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var dialogue_box = $DialogueBox

const CAM_OFFSET = Vector3(0, 3.9, 5.4)
const CAM_LOOK_OFFSET = Vector3(0, 1.5, -3.0)
const CAM_LERP = 5.0

## 선반 슬롯 (한 줄에 5개, 최대 3줄 = 15개)
const SLOTS_PER_ROW := 5
const SLOT_X_START := -2.0
const SLOT_X_STEP := 1.0
const SHELF_Y := [1.05, 1.75, 2.45]
const SHELF_Z := -3.35

var _lamp: OmniLight3D = null
var _t: float = 0.0

## 여행 진행도(0~1). 방의 시간대·창밖 밝기·별 개수가 전부 여기서 파생된다.
## "얼마나 왔는지"를 숫자 UI 대신 공간의 빛으로 보여주기 위한 값.
var _progress: float = 0.0
## time_of_day_shift 와 같은 축(0 새벽 → 0.5 낮 → 1 노을)으로 맞춘 시간대 값.
var _tod: float = 0.0
var _aurora: Array[MeshInstance3D] = []

func _ready() -> void:
	_progress = _compute_progress()
	_tod = _time_of_day_for(_progress)
	_build_room()
	_build_souvenirs()
	player.add_to_group("player")
	AudioManager.play_bgm("room")
	AudioManager.play_ambient("room")
	PartnerSpawner.ensure(self, player, Vector3(1.0, 0, 0.7))
	$ExitInteract.interacted.connect(_go_hub)
	await get_tree().create_timer(0.4).timeout
	dialogue_box.show_text(_progress_line())

func _process(delta: float) -> void:
	var target = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target, CAM_LERP * delta)
	camera.look_at(player.global_position + CAM_LOOK_OFFSET, Vector3.UP)
	_t += delta
	if _lamp:
		_lamp.light_energy = _lamp_base_energy() + sin(_t * 1.6) * 0.06
	# 오로라는 아주 느리게 흔들려야 "은은한" 인상이 된다. 빠르면 장식이 아니라 이펙트가 된다.
	for i in range(_aurora.size()):
		var band := _aurora[i]
		var ph := _t * 0.35 + float(i) * 0.9
		band.position.x = 2.9 + sin(ph) * 0.10
		band.scale.y = 1.0 + sin(ph * 0.8) * 0.12

func _lamp_base_energy() -> float:
	# 밤일수록 램프가 방의 주광원이라 밝고, 낮이 될수록 존재감을 줄인다.
	return lerpf(1.45, 0.85, clampf(_progress, 0.0, 1.0))

# ── 진행도 ──────────────────────────────────────────────────────────────
## 다녀온 "고유" 여행지 수 / 전체 여행지 수. 같은 곳을 여러 번 가도 방은 그만큼만 밝아진다.
func _compute_progress() -> float:
	var total: int = TravelState.DESTINATIONS.size()
	if total <= 0:
		return 0.0
	var seen := {}
	for s in TravelState.collection:
		var did := str((s as Dictionary).get("dest_id", ""))
		if did != "":
			seen[did] = true
	return clampf(float(seen.size()) / float(total), 0.0, 1.0)

func _visited_rift() -> bool:
	for s in TravelState.collection:
		if str((s as Dictionary).get("dest_id", "")) == "rift":
			return true
	return false

## 진행도 → time_of_day_shift 와 같은 축(0 새벽, 0.5 낮, 1 노을)으로 옮긴다.
## 초반은 밤이라 새벽 이전이지만, 팔레트에는 밤이 없으므로 0.0 에 붙여 두고
## 어둡기는 _night_amount() 로 따로 눌러 준다.
func _time_of_day_for(p: float) -> float:
	if p < 0.25:
		return 0.0
	if p < 0.65:
		return inverse_lerp(0.25, 0.65, p) * 0.5
	return 0.5 + inverse_lerp(0.65, 1.0, p) * 0.5

## 1 = 완전한 밤, 0 = 밤기운 없음. 창밖 어둡기와 별 개수를 정한다.
func _night_amount() -> float:
	return clampf(inverse_lerp(0.40, 0.0, _progress), 0.0, 1.0)

func _progress_line() -> String:
	# 숫자 대신 창밖이 어떻게 변했는지로 말한다. 진행 상황이 곧 풍경이라는 인상을 주기 위해.
	if _visited_rift():
		return "창밖에 못 보던 빛이 흘러요. 우리, 갈 수 있는 데까지 갔네요."
	if TravelState.collection.is_empty():
		return "아직 밤이에요. 여행을 다녀오면 이 방에도 아침이 와요."
	if _progress < 0.25:
		return "창밖은 아직 깜깜하지만, 램프 옆이 조금 따뜻해졌어요."
	if _progress < 0.65:
		return "창밖이 조금 밝아졌어요. 푸른 빛이 들어오네요."
	if _progress < 0.95:
		return "이제 방이 꽤 찼네요. 햇빛이 선반까지 닿아요."
	return "노을이 방 안까지 들어와요. 참 멀리도 다녀왔어요."

func _hex(c: Color) -> String:
	return "#%02X%02X%02X" % [int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)]

func _go_hub() -> void:
	SceneTransition.go_to("res://scenes/travel/TravelHub.tscn", "hopeful")

# ── 방 ──────────────────────────────────────────────────────────────────
func _build_room() -> void:
	# 바닥 / 러그 / 벽
	_box(self, Vector3(0, -0.05, 0), Vector3(9, 0.1, 9), "#6B5744", "Floor")
	_box(self, Vector3(0, 0.01, 0.6), Vector3(5.2, 0.02, 4.4), "#8A6E58", "Rug")
	_box(self, Vector3(0, 1.9, -4.4), Vector3(9, 4.0, 0.25), "#4A5D74", "BackWall")
	_box(self, Vector3(-4.4, 1.9, 0), Vector3(0.25, 4.0, 9), "#41526A", "LeftWall")
	_box(self, Vector3(4.4, 1.9, 0), Vector3(0.25, 4.0, 9), "#41526A", "RightWall")
	# 걸레받이
	_box(self, Vector3(0, 0.12, -4.25), Vector3(9, 0.24, 0.06), "#3A4A5E", "Baseboard")

	# 선반 3단
	for i in range(SHELF_Y.size()):
		var y: float = SHELF_Y[i] - 0.06
		_box(self, Vector3(0, y, SHELF_Z), Vector3(5.8, 0.09, 0.42), "#9A7B5A", "ShelfBoard%d" % i)
		for sx in [-2.9, 2.9]:
			_box(self, Vector3(sx, y - 0.32, SHELF_Z), Vector3(0.10, 0.62, 0.40), "#7E6248", "ShelfLeg")

	# 창문 — 창밖 색은 진행도가 만든 시간대에서 뽑는다.
	# 여행을 다닐수록 이 방에도 아침이 오는 것이 이 화면의 핵심 연출.
	var night := _night_amount()
	var pal := TravelPalette.time_of_day_shift(
		TravelPalette.CHAPTER_PALETTES["world"] as Dictionary, _tod)
	var sky: Color = pal["sky_top"]
	# 밤에는 팔레트 색을 거의 잠재워 짙은 남색으로 떨어뜨린다.
	var glass_col := sky.lerp(Color(0.086, 0.141, 0.235), night)
	var glass := _box(self, Vector3(2.9, 2.2, -4.26), Vector3(1.7, 1.4, 0.03), _hex(glass_col), "WindowGlass")
	# 낮일수록 창이 스스로 빛나 보이게 (발광 세기로 "바깥이 밝다"를 표현)
	_emissive(glass, _hex(glass_col.lerp(Color(1, 1, 1), 0.18)), lerpf(2.2, 0.35, night))

	# 별: 밤일수록 많고 밝다. 낮에는 하나도 남지 않는다.
	var star_count := int(round(lerpf(0.0, 12.0, night)))
	for i in range(star_count):
		var a := float(i) * 1.9
		var st := _sphere(self, Vector3(2.9 + cos(a) * 0.62, 2.2 + sin(a * 1.4) * 0.46, -4.245), 0.032, "#FFF3C8", "Star%d" % i)
		_emissive(st, "#FFF3C8", lerpf(0.6, 3.4, night))

	if _visited_rift():
		_build_aurora()
	# 테두리
	for off in [Vector3(0, 0.74, 0), Vector3(0, -0.74, 0)]:
		_box(self, Vector3(2.9, 2.2, -4.235) + off, Vector3(1.84, 0.09, 0.05), "#5E4A38", "WinBar")
	for off in [Vector3(0.88, 0, 0), Vector3(-0.88, 0, 0)]:
		_box(self, Vector3(2.9, 2.2, -4.235) + off, Vector3(0.09, 1.58, 0.05), "#5E4A38", "WinBar")
	# 창살
	_box(self, Vector3(2.9, 2.2, -4.235), Vector3(0.055, 1.4, 0.04), "#5E4A38", "WinCrossV")
	_box(self, Vector3(2.9, 2.2, -4.235), Vector3(1.7, 0.055, 0.04), "#5E4A38", "WinCrossH")
	# 창으로 들어오는 빛. 밤에는 차가운 달빛, 진행할수록 푸른 새벽빛 → 따뜻한 낮/노을빛.
	var win_light := OmniLight3D.new()
	win_light.light_color = Color("#9FB6E8").lerp(pal["light_color"], 1.0 - night)
	win_light.light_energy = lerpf(0.55, 2.1, clampf(_progress, 0.0, 1.0))
	win_light.omni_range = lerpf(6.0, 11.0, clampf(_progress, 0.0, 1.0))
	win_light.position = Vector3(2.9, 2.2, -3.9)
	add_child(win_light)

	# 작은 탁자 + 램프
	_box(self, Vector3(-3.0, 0.55, -2.4), Vector3(1.1, 0.1, 0.9), "#8A6A4A", "TableTop")
	for tx in [-3.45, -2.55]:
		for tz in [-2.75, -2.05]:
			_box(self, Vector3(tx, 0.27, tz), Vector3(0.08, 0.55, 0.08), "#6E5238", "TableLeg")
	_cylinder(self, Vector3(-3.0, 0.72, -2.4), 0.05, 0.26, "#8A9099", "LampStem")
	var shade := _cylinder(self, Vector3(-3.0, 0.94, -2.4), 0.22, 0.24, "#FFD76D", "LampShade")
	_emissive(shade, "#FFE7A8", 2.0)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color("#FFD3A0")
	_lamp.light_energy = _lamp_base_energy()
	_lamp.omni_range = 7.5
	_lamp.position = Vector3(-3.0, 1.15, -2.4)
	add_child(_lamp)

	# 화분 / 쿠션
	_cylinder(self, Vector3(3.5, 0.26, -2.2), 0.30, 0.5, "#A9705A", "PotBody")
	_sphere(self, Vector3(3.5, 0.82, -2.2), 0.42, "#6FA98A", "PotLeaf")
	_box(self, Vector3(1.4, 0.16, 1.6), Vector3(0.9, 0.28, 0.9), "#C98BA0", "Cushion")
	_box(self, Vector3(-1.4, 0.16, 1.9), Vector3(0.8, 0.26, 0.8), "#8FA9C9", "Cushion2")

	# 천장 은은한 조명. 밤에는 보랏빛, 진행할수록 방 전체가 따뜻하게 물든다.
	var amb := OmniLight3D.new()
	amb.light_color = Color("#B9A7E8").lerp(Color("#FFE2B4"), clampf(_progress, 0.0, 1.0))
	amb.light_energy = lerpf(0.45, 0.95, clampf(_progress, 0.0, 1.0))
	amb.omni_range = 12.0
	amb.position = Vector3(0, 3.4, 0)
	add_child(amb)

	# 여기까지가 원래의 방이다. 꾸미기는 전부 아래 한 함수에 모아 뒀다.
	_build_room_details()

## 마지막 여행지(rift)를 다녀오면 창밖에 겹쳐지는 은은한 오로라.
## 색을 여러 개 쓰되 채도를 낮춰, 스카프의 산호색과 경쟁하지 않게 한다.
func _build_aurora() -> void:
	var cols := ["#9FE8D6", "#A8C4F0", "#C9A8E8"]
	for i in range(cols.size()):
		var y := 2.55 - float(i) * 0.26
		var band := _box(self, Vector3(2.9, y, -4.252), Vector3(1.5, 0.16, 0.01), cols[i], "Aurora%d" % i)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(cols[i], 0.28)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = Color(cols[i])
		m.emission_energy_multiplier = 1.6
		band.material_override = m
		_aurora.append(band)

# ── 방 꾸미기 ───────────────────────────────────────────────────────────
#
# 여기서부터는 전부 장식이다. 슬롯 계산과 진행도 연출에는 손대지 않는다.
#
# 이 방은 벽 세 면과 선반 하나가 전부라 어디를 봐도 같은 면이 이어졌다.
# 방은 물건이 쌓인 만큼 "사는 사람이 있는 방"이 되므로, 벽마다 높이가 다른 물건을
# 하나씩 걸어 가로선을 끊는다. 바닥 한가운데(플레이어가 걷는 길)는 비워 두고
# 벽을 따라서만 채운다. 카메라가 늘 -Z 쪽을 보므로 뒷벽과 옆벽에만 놓는다.

func _build_room_details() -> void:
	_build_trim()
	_build_curtain()
	_build_windowsill()
	_build_string_lights()
	_build_wall_shelf()
	_build_plants()
	_build_floor_lamp()
	_build_tea_corner()
	_build_rug_detail()
	_build_wall_art()

## 몰딩과 걸레받이. 벽이 바닥·천장과 만나는 선이 그냥 끊기면 벽이 판때기로 보인다.
## 가로선이 한 줄 들어가면 같은 벽도 "지어진 방"이 된다.
func _build_trim() -> void:
	_box(self, Vector3(0, 3.72, -4.20), Vector3(9, 0.16, 0.16), "#56697F", "CrownBack")
	_box(self, Vector3(-4.20, 3.72, 0), Vector3(0.16, 0.16, 9), "#4E607A", "CrownLeft")
	_box(self, Vector3(4.20, 3.72, 0), Vector3(0.16, 0.16, 9), "#4E607A", "CrownRight")
	# 걸레받이는 뒷벽에만 있었다. 옆벽에도 둘러야 바닥이 벽 밑으로 이어져 보인다.
	_box(self, Vector3(-4.22, 0.12, 0), Vector3(0.10, 0.24, 9), "#3A4A5E", "BaseboardLeft")
	_box(self, Vector3(4.22, 0.12, 0), Vector3(0.10, 0.24, 9), "#3A4A5E", "BaseboardRight")

## 창문 커튼. 창은 이 방에서 제일 말을 많이 하는 물건이다 — 진행도가 창밖 색으로 보인다.
## 그래서 커튼은 창틀 바깥에만 건다. 유리와 별은 그대로 두고 테두리만 만든다.
func _build_curtain() -> void:
	var cx := 2.9
	var rod_y := 3.06
	# 커튼봉 + 마감 구슬. 봉이 벽에서 조금 떨어져야 커튼이 벽에 발린 것처럼 보이지 않는다.
	var rod := _cylinder(self, Vector3(cx, rod_y, -4.14), 0.035, 2.36, "#6E5238", "CurtainRod")
	rod.rotation_degrees.z = 90.0
	for i in range(2):
		var s := float(i) * 2.0 - 1.0
		_blob(self, Vector3(cx + s * 1.18, rod_y, -4.14), 0.06, "#5E4A38", "CurtainFinial%d" % i)
		_box(self, Vector3(cx + s * 1.04, rod_y, -4.21), Vector3(0.05, 0.05, 0.18), "#5E4A38", "CurtainBracket%d" % i)
	# 윗단 천. 봉과 커튼 사이가 비면 커튼이 공중에 걸린 것처럼 보인다.
	_box(self, Vector3(cx, 2.94, -4.13), Vector3(2.42, 0.20, 0.09), "#D8C0AE", "CurtainValance")
	for i in range(2):
		var side := float(i) * 2.0 - 1.0
		var px := cx + side * 0.92
		var panel := _box(self, Vector3(px, 2.08, -4.10), Vector3(0.42, 1.78, 0.07), "#E3CDBE", "CurtainPanel%d" % i)
		panel.rotation_degrees.z = -side * 1.5
		# 주름 두 줄. 단색 판만 세워 두면 천이 아니라 문짝으로 읽힌다.
		for f in range(2):
			var fold := _box(self, Vector3(px + (float(f) - 0.5) * 0.17, 2.08, -4.055),
				Vector3(0.06, 1.70, 0.03), "#D2B9A8", "CurtainFold%d_%d" % [i, f])
			fold.rotation_degrees.z = -side * 1.5
		# 묶은 띠. 쿠션과 같은 색을 써서 방 안의 색이 한 가족으로 묶이게 한다.
		_box(self, Vector3(px, 1.62, -4.09), Vector3(0.46, 0.08, 0.11), "#C98BA0", "CurtainTie%d" % i)

## 창턱. 창 아래가 그냥 벽이라 창이 벽에 뚫린 구멍처럼 보였다.
## 턱이 하나 생기면 물건을 올려 둘 수 있고, 그 물건이 유리를 배경으로 실루엣이 된다.
func _build_windowsill() -> void:
	_box(self, Vector3(2.9, 1.37, -4.16), Vector3(2.24, 0.09, 0.30), "#6E5238", "WindowSill")
	_taper(self, Vector3(2.36, 1.50, -4.14), 0.11, 0.085, 0.18, "#A9705A", "SillPot")
	_blob(self, Vector3(2.36, 1.66, -4.14), 0.13, "#6FA98A", "PotLeafSill0")
	_blob(self, Vector3(2.27, 1.59, -4.09), 0.09, "#7FBF97", "PotLeafSill1")
	# 머그 두 개. 하나가 아니라 둘이라는 것만으로 "둘의 방"이 된다.
	_cylinder(self, Vector3(3.30, 1.47, -4.12), 0.055, 0.11, "#C98BA0", "SillMug0")
	_cylinder(self, Vector3(3.44, 1.47, -4.16), 0.055, 0.11, "#8FA9C9", "SillMug1")

## 선반 위 벽에 걸친 전구 줄. 그 높이가 통째로 비어 있어서 눈이 갈 곳이 없었다.
## 처진 줄 하나가 가로로 지나가면 그 위쪽이 "천장 밑"으로 읽힌다.
## 밤일수록 밝다 — 여행 초반의 깜깜한 방에서는 이 줄이 유일하게 따뜻한 선이 된다.
func _build_string_lights() -> void:
	var x0 := -4.10
	var x1 := 1.60
	var y0 := 3.34
	var sag := 0.34
	var pts: Array[Vector3] = []
	for i in range(6):
		var t := float(i) / 5.0
		pts.append(Vector3(lerpf(x0, x1, t), y0 - sag * 4.0 * t * (1.0 - t), -4.19))
	for i in range(pts.size() - 1):
		_link(self, pts[i], pts[i + 1], 0.025, "#5E6774", "StringCord%d" % i)
	# 전구는 줄의 마디가 아니라 마디 사이에 매단다. 마디에 두면 꺾인 자리가 그대로 보인다.
	# 전구는 알이 작아서 세게 주면 알맹이가 통째로 순백으로 탄다.
	# 글로우가 번져 주니 이 정도만 줘도 밤에는 충분히 따뜻하게 읽힌다.
	var glow := lerpf(1.9, 0.9, clampf(_progress, 0.0, 1.0))
	for i in range(6):
		var t := (float(i) + 0.5) / 6.0
		var p := Vector3(lerpf(x0, x1, t), y0 - sag * 4.0 * t * (1.0 - t) - 0.08, -4.19)
		var bulb := _blob(self, p, 0.055, "#FFE7A8", "StringBulb%d" % i)
		_emissive(bulb, "#FFE7A8", glow)

## 뒷벽 왼쪽의 작은 선반. 기념품 선반은 슬롯이 정해져 있어 손대지 않는다.
## 대신 그 옆 빈 벽에 하나를 더 달아, 슬롯이 아직 비어 있어도 벽이 허전하지 않게 한다.
func _build_wall_shelf() -> void:
	_box(self, Vector3(-3.55, 2.15, -4.16), Vector3(1.20, 0.06, 0.30), "#9A7B5A", "WallShelfBoard")
	for bx in [-4.05, -3.10]:
		_box(self, Vector3(bx, 2.03, -4.19), Vector3(0.05, 0.18, 0.22), "#7E6248", "WallShelfBracket")
	# 액자 둘을 기대어 세운다. 줄 맞춰 세우면 진열장이고, 기울여 놓으면 누가 놔둔 것이 된다.
	var f0 := _box(self, Vector3(-3.95, 2.32, -4.13), Vector3(0.24, 0.28, 0.03), "#5E4A38", "ShelfPhoto0")
	f0.rotation_degrees.z = 3.0
	var f1 := _box(self, Vector3(-3.72, 2.29, -4.10), Vector3(0.20, 0.22, 0.03), "#6E5238", "ShelfPhoto1")
	f1.rotation_degrees.z = -5.0
	_taper(self, Vector3(-3.24, 2.26, -4.14), 0.10, 0.08, 0.16, "#A9705A", "ShelfPot")
	_blob(self, Vector3(-3.24, 2.40, -4.14), 0.13, "#6FA98A", "PotLeafShelf")

## 화분 셋. 잎 이름은 전부 Plant / PotLeaf 로 시작한다 — LivingScene 이 이름만 보고
## 바람에 흔들어 주기 때문이다. 이름을 바꾸면 방 안의 초록이 전부 멈춘다.
func _build_plants() -> void:
	# 뒷벽 왼쪽 구석의 큰 화분. 구석이 비어 있으면 방이 상자로 보인다.
	var base := Vector3(-3.72, 0, -3.70)
	_taper(self, base + Vector3(0, 0.24, 0), 0.32, 0.24, 0.48, "#A9705A", "CornerPotBody")
	_taper(self, base + Vector3(0, 0.50, 0), 0.35, 0.34, 0.07, "#96604C", "CornerPotRim")
	_taper(self, base + Vector3(0, 0.47, 0), 0.29, 0.29, 0.04, "#4E3A2C", "CornerPotSoil")
	_cylinder(self, base + Vector3(0, 0.95, 0), 0.045, 0.9, "#7A6A4E", "CornerStem")
	_blob(self, base + Vector3(0, 1.34, 0), 0.42, "#6FA98A", "PlantLeafBig")
	_blob(self, base + Vector3(0.30, 1.12, 0.12), 0.30, "#7FBF97", "PlantLeafSide")
	_blob(self, base + Vector3(-0.26, 1.50, -0.10), 0.28, "#649D80", "PlantLeafBack")
	_blob(self, base + Vector3(0.10, 1.64, -0.18), 0.22, "#7AB894", "PlantLeafTop")

	# 왼쪽 벽에 매단 화분. 눈높이보다 위에 초록이 하나 있으면 시선이 거기까지 올라간다.
	_box(self, Vector3(-4.14, 3.30, -2.60), Vector3(0.26, 0.05, 0.05), "#6E7684", "HangBracket")
	_box(self, Vector3(-4.03, 3.08, -2.60), Vector3(0.02, 0.44, 0.02), "#5E6774", "HangCord")
	_taper(self, Vector3(-4.03, 2.78, -2.60), 0.20, 0.14, 0.24, "#A9705A", "HangPot")
	_taper(self, Vector3(-4.03, 2.92, -2.60), 0.22, 0.21, 0.05, "#96604C", "HangPotRim")
	_blob(self, Vector3(-4.03, 2.72, -2.60), 0.24, "#6FA98A", "PlantHang0")
	_blob(self, Vector3(-3.90, 2.54, -2.66), 0.17, "#7FBF97", "PlantHang1")
	_blob(self, Vector3(-4.08, 2.49, -2.50), 0.15, "#649D80", "PlantHang2")

	# 원래 있던 오른쪽 화분은 잎이 공 하나뿐이라 사탕처럼 보였다. 두 덩이만 곁들인다.
	_blob(self, Vector3(3.22, 0.66, -2.05), 0.24, "#7FBF97", "PotLeafSideA")
	_blob(self, Vector3(3.74, 0.74, -2.34), 0.20, "#649D80", "PotLeafSideB")

## 오른쪽 뒷구석의 스탠드. 왼쪽에는 탁자 램프가 있는데 오른쪽에는 빛이 없어서
## 방이 한쪽으로 기울어 보였다. 창 옆에 세로로 선 물건이 하나 생기는 효과도 있다.
## 램프와 같은 규칙으로, 밤일수록 밝고 창이 밝아질수록 존재감을 줄인다.
func _build_floor_lamp() -> void:
	var p := Vector3(4.02, 0, -3.72)
	_taper(self, p + Vector3(0, 0.03, 0), 0.20, 0.24, 0.06, "#7E858F", "FloorLampBase")
	_cylinder(self, p + Vector3(0, 0.80, 0), 0.035, 1.50, "#8A9099", "FloorLampStem")
	var shade := _taper(self, p + Vector3(0, 1.66, 0), 0.17, 0.26, 0.30, "#FFD76D", "FloorLampShade")
	_emissive(shade, "#FFE7A8", 1.2)
	# 갓 아래로 새는 빛. 갓만 빛나면 어디를 비추는지가 안 보인다.
	# 세기는 갓보다 낮게 둔다. 여기를 1.0 넘게 주면 크림색이 순백으로 타서
	# 파스텔이 깨지고, 나중에 이 방에 뭘 더 얹을 때 제일 먼저 터지는 자리가 된다.
	var disc := _taper(self, p + Vector3(0, 1.52, 0), 0.24, 0.24, 0.02, "#FFE7A8", "FloorLampGlow")
	_emissive(disc, "#FFE0AE", 0.8)
	var lamp2 := OmniLight3D.new()
	lamp2.name = "FloorLampLight"
	lamp2.light_color = Color("#FFD3A0")
	lamp2.light_energy = lerpf(0.9, 0.4, clampf(_progress, 0.0, 1.0))
	lamp2.omni_range = 5.5
	lamp2.position = p + Vector3(0, 1.58, 0)
	add_child(lamp2)

## 오른쪽 벽 앞의 작은 자리. 쿠션 두 개만 덩그러니 있던 바닥에
## 앉을 이유(찻잔 둘)와 살림(바구니)을 놔 준다. 통로가 아니라 벽 쪽에만 붙인다.
func _build_tea_corner() -> void:
	var s := Vector3(3.62, 0, 0.30)
	_taper(self, s + Vector3(0, 0.44, 0), 0.30, 0.28, 0.07, "#9A7B5A", "StoolTop")
	for i in range(3):
		var a := TAU * float(i) / 3.0 + 0.4
		_cylinder(self, s + Vector3(cos(a) * 0.20, 0.21, sin(a) * 0.20), 0.035, 0.42, "#7E6248", "StoolLeg%d" % i)
	_cylinder(self, s + Vector3(-0.10, 0.53, -0.06), 0.055, 0.11, "#C98BA0", "TeaCup0")
	_cylinder(self, s + Vector3(0.10, 0.53, 0.06), 0.055, 0.11, "#8FA9C9", "TeaCup1")

	var b := Vector3(3.92, 0, 1.58)
	_taper(self, b + Vector3(0, 0.19, 0), 0.28, 0.22, 0.38, "#B39B78", "BasketBody")
	_taper(self, b + Vector3(0, 0.39, 0), 0.30, 0.29, 0.05, "#9C8563", "BasketRim")
	# 돌돌 만 담요. 바구니 입구에서 삐져나와야 담아 둔 것으로 보인다.
	var roll := _cylinder(self, b + Vector3(0, 0.46, 0), 0.13, 0.36, "#D9B7C4", "BlanketRoll")
	roll.rotation_degrees.x = 90.0

## 러그. 큰 갈색 판 하나여서 바닥에 칠만 해 둔 것처럼 보였다.
## 테두리와 안쪽 면을 겹쳐 놓으면 같은 넓이도 짜인 천으로 읽힌다.
func _build_rug_detail() -> void:
	for e in [Vector3(0, 0.027, -1.42), Vector3(0, 0.027, 2.62)]:
		_box(self, e, Vector3(5.0, 0.012, 0.22), "#7A5F4B", "RugEdge")
	for e in [Vector3(-2.42, 0.027, 0.6), Vector3(2.42, 0.027, 0.6)]:
		_box(self, e, Vector3(0.22, 0.012, 3.6), "#7A5F4B", "RugEdge")
	_box(self, Vector3(0, 0.030, 0.6), Vector3(3.4, 0.012, 2.6), "#9A7E66", "RugInner")
	_box(self, Vector3(0, 0.033, 0.6), Vector3(1.5, 0.012, 1.1), "#A98C70", "RugCore")
	# 램프 탁자 밑 깔개. 가구가 맨바닥에 놓이면 떠 있는 것처럼 보인다.
	_taper(self, Vector3(-3.28, 0.024, -2.42), 0.73, 0.73, 0.012, "#9A7E66", "MatRound")
	_taper(self, Vector3(-3.28, 0.017, -2.42), 0.80, 0.80, 0.010, "#7A5F4B", "MatRing")

## 옆벽 장식. 뒷벽은 선반과 창이 다 차지했지만 옆벽은 완전히 비어 있었고,
## 카메라가 -Z 를 보므로 옆벽은 화면 좌우 끝을 계속 채우는 면이다.
func _build_wall_art() -> void:
	# 포스터는 PropKit 이 액자와 색면까지 만들어 준다. 높이를 서로 어긋나게 걸어야
	# 게시판처럼 줄 맞춘 인상이 안 난다. 왼쪽 벽은 yaw 90, 오른쪽 벽은 -90 이다.
	PropKit.poster_panel(self, Vector3(-4.26, 2.50, -1.50), "#F2EEE2", 90.0)
	PropKit.poster_panel(self, Vector3(-4.26, 2.05, 0.35), "#EDE6D8", 90.0)
	PropKit.poster_panel(self, Vector3(4.26, 2.35, -0.60), "#F2EEE2", -90.0)

	# 벽시계. 방에 시간이 흐른다는 표시가 하나쯤 있으면 여행에서 돌아온 방이 된다.
	var cc := Vector3(4.185, 2.78, -1.66)
	var body := _taper(self, Vector3(4.24, cc.y, cc.z), 0.19, 0.19, 0.06, "#8A9099", "ClockBody")
	body.rotation_degrees.z = 90.0
	var face := _taper(self, Vector3(4.20, cc.y, cc.z), 0.155, 0.155, 0.02, "#F2EEE2", "ClockFace")
	face.rotation_degrees.z = 90.0
	# 바늘은 X 축으로 돌려서 시계 면(YZ 평면) 안에 눕힌다. 중심에서 길이의 절반만큼 밀어야
	# 바늘이 축 반대쪽으로 튀어나오지 않는다.
	var la := deg_to_rad(25.0)
	var lh := _box(self, cc + Vector3(0, cos(la) * 0.08, sin(la) * 0.08),
		Vector3(0.018, 0.16, 0.018), "#5E6774", "ClockHandLong")
	lh.rotation_degrees.x = 25.0
	var sa := deg_to_rad(-110.0)
	var sh := _box(self, cc + Vector3(0, cos(sa) * 0.055, sin(sa) * 0.055),
		Vector3(0.018, 0.11, 0.018), "#5E6774", "ClockHandShort")
	sh.rotation_degrees.x = -110.0

# ── 기념품 배치 ─────────────────────────────────────────────────────────
func _build_souvenirs() -> void:
	var col: Array = TravelState.collection
	for i in range(col.size()):
		if i >= SLOTS_PER_ROW * SHELF_Y.size():
			break
		var s: Dictionary = col[i]
		var row := i / SLOTS_PER_ROW
		var cidx := i % SLOTS_PER_ROW
		var x := SLOT_X_START + float(cidx) * SLOT_X_STEP
		var y: float = SHELF_Y[row]
		_place_souvenir(s, Vector3(x, y, SHELF_Z), i)

	# 빈 슬롯 힌트 (다음 자리 하나만 은은하게)
	var next_i: int = col.size()
	if next_i < SLOTS_PER_ROW * SHELF_Y.size():
		var row := next_i / SLOTS_PER_ROW
		var cidx := next_i % SLOTS_PER_ROW
		var x := SLOT_X_START + float(cidx) * SLOT_X_STEP
		var ghost := _box(self, Vector3(x, SHELF_Y[row] + 0.16, SHELF_Z), Vector3(0.34, 0.30, 0.03), "#FFD76D", "EmptySlot")
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(1, 0.843, 0.427, 0.16)
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost.material_override = gm

## 기념품 하나 = 액자 + 여행지별 작은 소품
func _place_souvenir(s: Dictionary, pos: Vector3, idx: int) -> void:
	var dest_id: String = s.get("dest_id", "")
	var d := TravelState.get_destination(dest_id)
	var tint: Color = d.get("tint", Color(0.8, 0.8, 0.9))

	var root := Node3D.new()
	root.name = "Souvenir%d" % idx
	root.position = pos
	add_child(root)

	# 액자
	_box(root, Vector3(0, 0.18, 0), Vector3(0.36, 0.32, 0.035), "#5E4A38", "Frame")
	var photo := _box(root, Vector3(0, 0.18, 0.028), Vector3(0.30, 0.26, 0.01),
		"#%02X%02X%02X" % [int(tint.r * 255), int(tint.g * 255), int(tint.b * 255)], "Photo")
	_emissive(photo, "#%02X%02X%02X" % [int(tint.r * 255), int(tint.g * 255), int(tint.b * 255)], 0.55)
	# 액자 받침
	_box(root, Vector3(0, 0.015, -0.03), Vector3(0.30, 0.03, 0.14), "#4A3A2C", "FrameStand")

	# 여행지별 소품
	match dest_id:
		"seoul":
			_box(root, Vector3(0.24, 0.09, 0.02), Vector3(0.17, 0.10, 0.12), "#E6D8BE", "MiniHanok")
			_box(root, Vector3(0.24, 0.16, 0.02), Vector3(0.24, 0.045, 0.17), "#C0504A", "MiniRoof")
		"paris":
			_cylinder(root, Vector3(0.24, 0.13, 0.02), 0.035, 0.26, "#C9B08A", "MiniTower")
			_box(root, Vector3(0.24, 0.03, 0.02), Vector3(0.16, 0.035, 0.16), "#C9B08A", "MiniTowerBase")
		"moon":
			var st := _sphere(root, Vector3(0.24, 0.12, 0.02), 0.075, "#FFE7A8", "MiniMoon")
			_emissive(st, "#FFE7A8", 1.8)
		_:
			_sphere(root, Vector3(0.24, 0.09, 0.02), 0.06, "#CFC6E8", "MiniTrinket")

	# 상호작용 (가까이 가서 Space 로 일기 읽기)
	var area := Area3D.new()
	area.name = "Interact%d" % idx
	area.set_script(load("res://scripts/systems/interactable.gd"))
	area.position = Vector3(0, -pos.y + 0.4, 0.9)   # 선반 앞 바닥 높이
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.85
	cs.shape = sh
	area.add_child(cs)
	root.add_child(area)
	area.set("prompt_text", str(s.get("title", "기념품")))
	area.set("indicator_height", 1.2)
	area.interacted.connect(func(): _read_souvenir(s))

func _read_souvenir(s: Dictionary) -> void:
	AudioManager.ui_click()
	var d := TravelState.get_destination(s.get("dest_id", ""))
	dialogue_box.show_text("%s  %s\n%s" % [
		d.get("emoji", "📷"), s.get("title", ""), s.get("diary", "")])

# ── 헬퍼 ────────────────────────────────────────────────────────────────
func _emissive(mi: MeshInstance3D, hex: String, energy: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.emission_enabled = true
	m.emission = Color(hex)
	m.emission_energy_multiplier = energy
	mi.material_override = m

func _box(parent: Node3D, pos: Vector3, size: Vector3, hex: String, label := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new(); m.size = size
	mi.mesh = m; mi.position = pos
	if label != "": mi.name = label
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, hex: String, label := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new(); m.top_radius = radius; m.bottom_radius = radius; m.height = height
	mi.mesh = m; mi.position = pos
	if label != "": mi.name = label
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _sphere(parent: Node3D, pos: Vector3, radius: float, hex: String, label := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new(); m.radius = radius; m.height = radius * 2.0
	mi.mesh = m; mi.position = pos
	if label != "": mi.name = label
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi

## 위아래 반지름이 다른 통. 화분·갓·스툴처럼 살짝 벌어진 것에 쓴다.
## 분할은 12로 낮춘다. CylinderMesh 기본이 64라 화분 몇 개만 놔도 폴리곤이 쓸데없이 는다.
func _taper(parent: Node3D, pos: Vector3, r_top: float, r_bottom: float, height: float, hex: String, label := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r_top; m.bottom_radius = r_bottom; m.height = height
	m.radial_segments = 12; m.rings = 0
	mi.mesh = m; mi.position = pos
	if label != "": mi.name = label
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi

## 저분할 구. 잎사귀처럼 여러 개 겹쳐 놓는 것에 쓴다.
## 기본 SphereMesh 는 64x32 라 이 크기에서 보이지도 않는 폴리곤을 잔뜩 만든다.
func _blob(parent: Node3D, pos: Vector3, radius: float, hex: String, label := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius; m.height = radius * 2.0
	m.radial_segments = 16; m.rings = 8
	mi.mesh = m; mi.position = pos
	if label != "": mi.name = label
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi

## 두 점을 잇는 얇은 막대. 처진 줄을 여러 토막으로 그릴 때 쓴다.
## 같은 평면(z 고정) 위의 두 점만 다룬다 — 전구 줄은 벽에 붙어 있어서 그걸로 충분하다.
func _link(parent: Node3D, a: Vector3, b: Vector3, thick: float, hex: String, label := "") -> MeshInstance3D:
	var d := b - a
	var mi := _box(parent, (a + b) * 0.5, Vector3(d.length(), thick, thick), hex, label)
	mi.rotation_degrees.z = rad_to_deg(atan2(d.y, d.x))
	return mi
