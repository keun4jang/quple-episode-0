extends Node
## 표면 킷 — 순수 로직 테스트.
##
## 씬을 띄우지 않는다. 결이 예쁜지는 눈으로 봐야 알지만, 그 전에 못 박을 수
## 있는 것들이 있다. 씬에 실제로 있는 이름이 표면을 받는가, 그 텍스처 파일이
## 정말 있는가, 세기가 힐링 게임 한도를 넘지 않는가, 그리고 무엇보다
## **모르는 이름과 빛나는 것에 아무거나 붙이지 않는가**.
##
## 아래 이름은 지어낸 것이 아니다. scripts/maps/*.gd,
## scripts/travel/souvenir_room_3d.gd, scripts/systems/prop_kit.gd 에서
## MeshInstance3D 에 실제로 붙는 label 과 그때 쓰는 색을 그대로 옮겼다.

const SurfaceKit := preload("res://scripts/systems/surface_kit.gd")

## 계약이 정한 키. 하나라도 빠지면 depth_shading.gd 가 셰이더에 넣을 게 없다.
const KEYS := ["detail", "normal", "uv_scale", "strength", "normal_strength", "roughness"]

var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)


func _ready() -> void:
	print("=== 표면 킷 테스트 ===")
	_t_textures()
	_t_scene_names()
	_t_contract()
	_t_no_shiny()
	_t_unknown()
	_t_characters()
	_t_specific_wins()
	_t_color_hint()
	_t_fresh_dictionary()
	_done()


func _done() -> void:
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(0 if fail_n == 0 else 1)


# ── 1. 텍스처 ───────────────────────────────────────────────────────────

## 경로만 맞고 파일이 없으면 실행할 때까지 모른다. 아홉 표면 × 두 장을 다 확인한다.
func _t_textures() -> void:
	print("\n[1] 표면마다 흑백 두 장이 실제로 있는가")
	var missing := ""
	for key in SurfaceKit.SURFACES:
		for path in [SurfaceKit.TEX_DIR + str(key) + "_d.png", SurfaceKit.TEX_DIR + str(key) + "_n.png"]:
			if not _tex_exists(str(path)):
				missing += " " + str(path)
	ck("텍스처 %d 종 × 2장이 전부 있다" % SurfaceKit.SURFACES.size(), missing == "", missing)


## ResourceLoader 는 .import 가 있어야 찾는다. 에디터를 한 번도 안 돌린 새 클론이나
## CI 에서는 아직 없을 수 있어서, 원본 파일도 같이 본다. 둘 중 하나면 통과다.
func _tex_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


# ── 2. 실제 씬 이름 ─────────────────────────────────────────────────────

## [노드 이름, 그 노드에 실제로 칠해진 색, 기대하는 표면]
const EXPECT := [
	# 회사 앞 (company_front_3d.gd)
	["Road", "#3B3E46", "asphalt"],
	["Sidewalk", "#7F8790", "concrete"],
	["Crosswalk0", "#F2EEE2", "asphalt"],
	["Building", "#2D3A4A", "concrete"],
	["BuildingLeft", "#1E2733", "concrete"],
	["SkylineA", "#334053", "concrete"],
	["SkylineACap", "#2A3542", "concrete"],
	["EntranceDoor", "#182533", "metal"],
	["Post", "#4A5568", "metal"],
	["Bollard", "#6D7D8F", "metal"],
	["BenchSeat", "#7F8790", "metal"],
	["Trunk", "#5B3A29", "wood"],
	["Canopy", "#72B48D", "foliage"],
	["Plant", "#72B48D", "foliage"],
	["PlanterBox", "#6D7D8F", "concrete"],
	["Trashcan1", "#4A4A52", "metal"],
	["TrafficPole", "#4A5058", "metal"],
	["SignBG", "#FFD76D", "paper"],
	["InfoSign", "#43566A", "paper"],
	["InfoLine1", "#F2EEE2", "paper"],

	# 프롭 라이브러리 (prop_kit.gd)
	["ParapetWall0", "#3A4658", "concrete"],
	["UnitBody", "#4E5A6E", "metal"],
	["TankBody", "#8E9AA8", "metal"],
	["AntMast", "#96A0AE", "metal"],
	["PipeVert0", "#7E8898", "metal"],
	["AcBody0", "#AEB7C3", "metal"],
	["VendBody", "#C98BA0", "metal"],
	["BinBody", "#5E6A78", "metal"],
	["RackTop0", "#96A0AC", "metal"],
	["BusBoard", "#8FA9C9", "paper"],
	["CanopyTier0", "#5F9E86", "foliage"],
	["Bush0", "#6FA98A", "foliage"],
	["PillarShaft", "#6F7889", "concrete"],
	["ShelfBoard0", "#9A7B5A", "wood"],
	["ShelfBook0", "#C08A8A", "paper"],
	["PosterPaper", "#F2EEE2", "paper"],
	["PosterFrame", "#5E4A38", "wood"],
	["AwningPanel", "#C98BA0", "fabric"],

	# 사무실 (office_3d.gd)
	["Floor", "#43566A", "tile"],
	["WallLeft", "#2D3A4A", "plaster"],
	["PartnerDesk", "#43566A", "wood"],
	["PartnerDeskTop", "#2D3A4A", "wood"],
	["Chair", "#2D3A4A", "fabric"],
	["ChairBack", "#1E2733", "fabric"],
	["PartitionPanel", "#4B5C73", "fabric"],
	["PartitionRail", "#6C7C93", "metal"],
	["DeskBody", "#3E5064", "wood"],
	["DeskChair", "#2D3A4A", "fabric"],
	["DeskMonitorStand", "#4A5568", "metal"],
	["CabBody", "#54637A", "metal"],
	["CabDrawer0", "#495A70", "metal"],
	["PartnerPaper0", "#E9E4D6", "paper"],
	["CabinetPaper0", "#E9E4D6", "paper"],
	["Memo1", "#FFE87A", "paper"],
	["CrumpledPaper", "#E8E8EC", "paper"],
	["WinMullion0", "#5A6B82", "metal"],
	["WinSill0", "#4E5F76", "metal"],
	["LightRod", "#6B7382", "metal"],
	["DarkLightPanel", "#3D4A5C", "metal"],
	["CoolerBody", "#C6CCD6", "metal"],
	["PotBody", "#8A6A54", "plaster"],
	["PlantLeaf0", "#5E8F74", "foliage"],
	["BagBody", "#B17A3E", "fabric"],
	["NbCover", "#C9934B", "fabric"],
	["NbPages", "#F8EAC8", "paper"],
	["CamBody", "#1F2636", "metal"],
	["TrashCan", "#6A6A72", "metal"],

	# 로비 (company_lobby_3d.gd)
	["FloorInner", "#59616E", "tile"],
	["BackWall", "#2D3A4A", "plaster"],
	["Desk", "#43566A", "wood"],
	["DeskTop", "#7F8790", "wood"],
	["LampStem", "#8A9099", "metal"],
	["Gate", "#43566A", "metal"],
	["ElevDoorL", "#43566A", "metal"],
	["ElevSign", "#FFD76D", "paper"],
	["FrontDoor", "#182533", "metal"],
	["ExitSign", "#FFD76D", "paper"],
	["BadgeBoxBody", "#43566A", "metal"],
	["ClockFace", "#F2EEE2", "paper"],
	["ClockHourHand", "#2D3A4A", "metal"],
	["PlanterPot", "#6D7D8F", "plaster"],
	["PlanterLeaf", "#6FA98A", "foliage"],
	["SignPole", "#8A9099", "metal"],
	["SignBoard", "#43566A", "paper"],
	["LobbyRug", "#6E6478", "fabric"],
	["ShelfSide0", "#8A7159", "wood"],

	# 대표실 앞 복도 (boss_door_hallway_3d.gd)
	["FloorRunner", "#4A5364", "fabric"],
	["EndWall", "#2D3A4A", "plaster"],
	["BossDoorL", "#43566A", "wood"],
	["BossPlate", "#FFD76D", "metal"],
	["BossKnobL", "#C8C8D0", "metal"],
	["BossNamePlate", "#D6DEE9", "metal"],
	["BossNameLine0", "#6E7684", "paper"],
	["Baseboard", "#26313F", "wood"],
	["CrownMold", "#39485C", "wood"],
	["PilasterL0", "#37455A", "plaster"],
	["FloorSeam0", "#333D4E", "tile"],
	["DoorCase", "#36445A", "wood"],
	["DoorLeaf", "#43566A", "wood"],
	["DoorKnob", "#C8C8D0", "metal"],
	["DoorPlate", "#D6DEE9", "metal"],
	["DoorMat", "#4F5A73", "fabric"],
	["CeilPanel", "#C7D4E4", "metal"],
	["Extinguisher", "#C0504A", "metal"],
	["Frame", "#43566A", "wood"],
	["FrameArt", "#5A6B80", "paper"],
	["CabDoor", "#C0736B", "metal"],
	["CabLabel", "#F0E4D2", "paper"],
	["PotSoil", "#4A3E36", "asphalt"],
	["PotLeafMain", "#5E9B80", "foliage"],
	["ChairSeat", "#7A8798", "fabric"],
	["ChairLeg0", "#5A6472", "metal"],
	["NoticeFrame", "#5E4A38", "wood"],
	["NoticeCork", "#4F6152", "fabric"],
	["NoticePaper0", "#EDE7DA", "paper"],
	["ExitCase", "#3C4A56", "metal"],

	# 기념품 방 (souvenir_room_3d.gd)
	["Floor", "#6B5744", "wood"],        # 여기만 나무 바닥이다. 색으로 갈린다
	["Rug", "#8A6E58", "fabric"],
	["RugEdge", "#7A5F4B", "fabric"],
	["MatRound", "#9A7E66", "fabric"],
	["TableTop", "#8A6A4A", "wood"],
	["TableLeg", "#6E5238", "wood"],
	["WinBar", "#5E4A38", "wood"],
	["WinCrossV", "#5E4A38", "wood"],
	["WindowSill", "#6E5238", "wood"],
	["CurtainPanel0", "#E3CDBE", "fabric"],
	["CurtainValance", "#D8C0AE", "fabric"],
	["CurtainRod", "#6E5238", "wood"],
	["CurtainBracket0", "#5E4A38", "metal"],
	["Cushion", "#C98BA0", "fabric"],
	["BasketBody", "#B39B78", "fabric"],
	["BlanketRoll", "#D9B7C4", "fabric"],
	["StoolTop", "#9A7B5A", "wood"],
	["WallShelfBoard", "#9A7B5A", "wood"],
	["ShelfPhoto0", "#5E4A38", "wood"],
	["ShelfPot", "#A9705A", "plaster"],
	["CornerPotBody", "#A9705A", "plaster"],
	["CornerPotSoil", "#4E3A2C", "asphalt"],
	["CornerStem", "#7A6A4E", "wood"],
	["PlantLeafBig", "#6FA98A", "foliage"],
	["PlantHang0", "#6FA98A", "foliage"],
	["HangBracket", "#6E7684", "metal"],
	["HangPot", "#A9705A", "plaster"],
	["FloorLampStem", "#8A9099", "metal"],
	["ClockBody", "#8A9099", "metal"],
	["FrameStand", "#4A3A2C", "wood"],
	["Baseboard", "#3A4A5E", "wood"],
	["CrownBack", "#56697F", "wood"],
]

func _t_scene_names() -> void:
	print("\n[2] 실제 씬에 있는 이름 %d 개가 기대한 표면을 얻는가" % EXPECT.size())
	var wrong := ""
	var empty := ""
	for e in EXPECT:
		var got := SurfaceKit.surface_of(str(e[0]), Color(str(e[1])))
		if got == "":
			empty += " " + str(e[0])
		elif got != e[2]:
			wrong += " %s(%s→%s)" % [str(e[0]), str(e[2]), got]
	ck("표면을 못 받은 이름이 없다", empty == "", empty)
	ck("전부 기대한 표면이다", wrong == "", wrong)


# ── 3. 계약 ─────────────────────────────────────────────────────────────

func _t_contract() -> void:
	print("\n[3] 계약대로 돌려주는가")
	var bad_key := ""
	var bad_path := ""
	var bad_uv := ""
	var too_strong := ""
	for e in EXPECT:
		var kit := SurfaceKit.for_node(str(e[0]), Color(str(e[1])))
		if kit.is_empty():
			continue
		for k in KEYS:
			if not kit.has(k):
				bad_key += " %s.%s" % [str(e[0]), str(k)]
		if not _tex_exists(str(kit.get("detail", ""))) or not _tex_exists(str(kit.get("normal", ""))):
			bad_path += " " + str(e[0])
		if float(kit.get("uv_scale", 0.0)) <= 0.0:
			bad_uv += " " + str(e[0])
		var s := float(kit.get("strength", 1.0))
		var ns := float(kit.get("normal_strength", 1.0))
		if s < 0.0 or s > SurfaceKit.STRENGTH_MAX or ns < 0.0 or ns > 1.0:
			too_strong += " %s(%.2f/%.2f)" % [str(e[0]), s, ns]
	ck("키가 다 있다", bad_key == "", bad_key)
	ck("돌려준 텍스처 경로의 파일이 실제로 있다", bad_path == "", bad_path)
	ck("uv_scale 이 양수다", bad_uv == "", bad_uv)
	ck("strength 0~%.1f, normal_strength 0~1" % SurfaceKit.STRENGTH_MAX, too_strong == "", too_strong)

	# 규칙표 자체도 훑는다. EXPECT 에 안 적은 표면이 슬쩍 세지면 안 된다.
	var loud := ""
	for key in SurfaceKit.SURFACES:
		var card: Dictionary = SurfaceKit.SURFACES[key]
		if float(card["strength"]) > SurfaceKit.STRENGTH_MAX:
			loud += " %s(%.2f)" % [str(key), float(card["strength"])]
	ck("표면 %d 종의 기본 세기가 전부 한도 안" % SurfaceKit.SURFACES.size(), loud == "", loud)

	var bad_weight := ""
	for rule in SurfaceKit.RULES:
		if rule.size() > 2 and (float(rule[2]) < 0.0 or float(rule[2]) > 1.0):
			bad_weight += " %s" % str(rule[0])
	ck("규칙 세기배율이 0~1 이다", bad_weight == "", bad_weight)

	var unknown_surface := ""
	for rule in SurfaceKit.RULES:
		var sname := str(rule[1])
		if sname != "" and not SurfaceKit.SURFACES.has(sname):
			unknown_surface += " %s→%s" % [str(rule[0]), sname]
	ck("규칙이 가리키는 표면이 전부 존재한다", unknown_surface == "", unknown_surface)


# ── 4. 붙이면 안 되는 것 ────────────────────────────────────────────────

## 빛나는 것 / 유리 / 물 / 반투명. 여기에 결을 얹으면 빛이 죽거나 유리가 벽이 된다.
const SHINY := [
	["Win_6_3", "#FFD76D"],          # 켜진 창문
	["Win0", "#17283A"],             # 꺼진 창문도 유리다
	["WindowGlass", "#16243C"],
	["DoorGlass", "#3E6278"],
	["BossGlass", "#3E6278"],
	["LobbyGlass", "#3E6278"],
	["FrontGlass", "#3E6278"],
	["CabGlass", "#E4D6C6"],
	["VendGlass", "#DCEEF6"],
	["CamLens", "#0D1322"],
	["NeonSign", "#88DDFF"],
	["SignFace", "#FFD76D"],
	["SignGlyph0", "#FFF6DC"],
	["BusHeader", "#FFE7A8"],
	["VendHeader", "#FFE7A8"],
	["AntBeacon", "#F2726F"],
	["TrafficLamp0", "#6FCF7F"],
	["LightPanel", "#FFF3D8"],
	["LampShade", "#FFD76D"],
	["FloorLampShade", "#FFD76D"],
	["FloorLampGlow", "#FFE7A8"],
	["FluorescentLight0", "#FFFFFF"],
	["StandbyLed", "#F2A6A0"],
	["CityLight0_0", "#FFD9A0"],
	["MonitorScreen", "#4E7A94"],
	["ScreenLine0", "#20313F"],
	["Monitor", "#17283A"],
	["DeskMonitor", "#1B2634"],
	["DoorSlit", "#FFE7A8"],
	["ExitFace", "#A8D5C2"],
	["ExitArrow", "#EAF6EF"],
	["StringBulb0", "#FFE7A8"],
	["Star0", "#FFF3C8"],
	["Aurora0", "#9FE8D6"],
	["Photo", "#C8BEE8"],
	["PhotoRing", "#FFD76D"],
	["PhotoSpark0", "#FFE7A8"],
	["Puddle0", "#7AB8D0"],           # 물
	["CoolerBottle", "#A6C2D6"],
	["EmptySlot", "#FFD76D"],
	["SkylineAWin0", "#1B2A3C"],
	["SkylineBWin1", "#1B2A3C"],
	["SkylineCWin2", "#1B2A3C"],
]

func _t_no_shiny() -> void:
	print("\n[4] 빛나는 것·유리·물에는 붙지 않는가 (%d 개)" % SHINY.size())
	var got := ""
	for e in SHINY:
		var nm := str(e[0])
		var col := Color(str(e[1]))
		if not SurfaceKit.for_node(nm, col).is_empty():
			got += " %s(%s)" % [nm, SurfaceKit.surface_of(nm, col)]
	ck("전부 빈 Dictionary 를 받는다", got == "", got)


# ── 5. 모르는 이름 ──────────────────────────────────────────────────────

func _t_unknown() -> void:
	print("\n[5] 모르는 이름에는 아무것도 붙이지 않는가")
	# Camera3D 를 빼먹지 말 것. "Cam" 으로 규칙을 잡으면 씬마다 있는 카메라가 걸린다.
	var unknown := ["", "Zzz", "무언가", "Node3D", "@Node3D@12", "Interact3",
		"CollisionShape3D", "DialogueBox", "Camera3D", "CinematicLook", "LightOmni",
		"WarmWindowLight", "PlayerQuokka3D", "PartnerQuokka3D", "Sprite", "Thing_42"]
	var got := ""
	for n in unknown:
		if not SurfaceKit.for_node(n, Color(0.5, 0.55, 0.62)).is_empty():
			got += " %s(%s)" % [n, SurfaceKit.surface_of(n, Color(0.5, 0.55, 0.62))]
	ck("전부 빈 Dictionary 를 받는다", got == "", got)


# ── 6. 캐릭터 ───────────────────────────────────────────────────────────

## 쿼카 커플은 배경이 아니다. 몸에 콘크리트 결이 생기면 그 순간 끝이다.
## 특히 BadgeMesh — 사원증 반납함(BadgeBox) 과 이름이 닮아서 규칙을
## "Badge" 로 잡았다가는 쿼카 몸에 금속 결이 붙는다.
func _t_characters() -> void:
	print("\n[6] 쿼카 커플에는 붙지 않는가")
	var body := ["BodyMesh", "HeadMesh", "BellyMesh", "NoseMesh", "BadgeMesh", "BackpackMesh",
		"LeftArmMesh", "RightArmMesh", "LeftLegMesh", "RightLegMesh",
		"LeftEarMesh", "RightEarMesh", "LeftEyeMesh", "RightEyeMesh",
		"LeftCheekMesh", "RightCheekMesh", "_Tail"]
	var got := ""
	for n in body:
		if not SurfaceKit.for_node(n, Color("#C8A882")).is_empty():
			got += " %s(%s)" % [n, SurfaceKit.surface_of(n, Color("#C8A882"))]
	ck("몸 %d 부위 전부 빈 Dictionary" % body.size(), got == "", got)


# ── 7. 더 구체적인 이름이 이긴다 ────────────────────────────────────────

func _t_specific_wins() -> void:
	print("\n[7] 더 구체적인 접두사가 이기는가")
	var g := Color("#6E7684")
	var pairs := [
		["Desk", "wood", "DeskMonitorStand", "metal"],
		["Wall", "plaster", "WallShelfBoard", "wood"],
		["Pot", "plaster", "PotLeafMain", "foliage"],
		["Shelf", "wood", "ShelfBook0", "paper"],
		["Cab", "metal", "CabLabel", "paper"],
		["Clock", "metal", "ClockFace", "paper"],
		["Floor", "tile", "FloorRunner", "fabric"],
		["Curtain", "fabric", "CurtainRod", "wood"],
		["Poster", "paper", "PosterFrame", "wood"],
		["Plant", "foliage", "PlanterBox", "concrete"],
	]
	var wrong := ""
	for p in pairs:
		if SurfaceKit.surface_of(str(p[0]), g) != str(p[1]):
			wrong += " %s" % str(p[0])
		if SurfaceKit.surface_of(str(p[2]), g) != str(p[3]):
			wrong += " %s" % str(p[2])
	ck("짧은 쪽과 긴 쪽이 각자 제 규칙으로 간다", wrong == "", wrong)


# ── 8. 색 보조 판단 ─────────────────────────────────────────────────────

func _t_color_hint() -> void:
	print("\n[8] 이름이 같아도 색이 나무면 나무로 보는가")
	ck("사무실 바닥(#43566A) → tile", SurfaceKit.surface_of("Floor", Color("#43566A")) == "tile")
	ck("로비 바닥(#3F4550) → tile", SurfaceKit.surface_of("Floor", Color("#3F4550")) == "tile")
	ck("복도 바닥(#3B4250) → tile", SurfaceKit.surface_of("Floor", Color("#3B4250")) == "tile")
	ck("기념품 방 바닥(#6B5744) → wood", SurfaceKit.surface_of("Floor", Color("#6B5744")) == "wood")
	# 색이 이름을 이기지는 않는다. 갈색 벽은 여전히 벽이다.
	ck("갈색이어도 벽은 plaster", SurfaceKit.surface_of("BackWall", Color("#6B5744")) == "plaster")
	# 스카프색(산호)은 나무빛으로 오해하지 않는다 — 쿼카가 배경에 묻히는 그 색이다.
	ck("산호(#FF6F61)를 나무로 보지 않는다", SurfaceKit.surface_of("Floor", Color("#FF6F61")) == "tile")


# ── 9. 매번 새 Dictionary ───────────────────────────────────────────────

## 상수를 그대로 돌려주면 부르는 쪽이 값 하나만 고쳐도 그 뒤의 모든 물체가 같이 바뀐다.
func _t_fresh_dictionary() -> void:
	print("\n[9] 돌려준 것을 고쳐도 다음 호출이 안 흔들리는가")
	var a: Dictionary = SurfaceKit.for_node("Sidewalk", Color("#7F8790"))
	var before := float(a["strength"])
	a["strength"] = 9.9
	var b: Dictionary = SurfaceKit.for_node("Sidewalk", Color("#7F8790"))
	ck("두 번째 호출이 원래 값을 준다", is_equal_approx(float(b["strength"]), before),
		"%.2f → %.2f" % [before, float(b["strength"])])
