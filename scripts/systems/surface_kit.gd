extends RefCounted
## 노드 이름 → 표면. "이 노드는 무엇으로 만들어졌나" 하나만 답한다.
##
## 지금 씬의 물체는 전부 텍스처 없는 단색이다. 표면에 정보가 0이라 아무리 색을
## 잘 맞춰도 플라스틱 장난감처럼 보인다. 그렇다고 컬러 텍스처를 씌우면 지금까지
## 맞춰 온 파스텔 팔레트가 통째로 무너진다
## (색 설계는 scripts/systems/mood_palette.gd 와 scripts/travel/palette.gd 에 있고,
##  쿼카 스카프색인 산호 #FF6F61 계열을 배경에서 금지하는 규칙까지 걸려 있다).
##
## 그래서 색은 그대로 두고 결만 얹는다. tools/texture/gen_textures.py 가 구운
## 흑백 두 장을 쓴다.
##
##   <이름>_d.png   디테일. 평균 0.5 인 흑백. 기존 albedo 에 곱한다 (0.5 = 손대지 않음).
##   <이름>_n.png   노멀. 같은 높이 맵에서 뽑았다. 빛이 표면 요철에 걸리게 하는
##                  쪽이라, 눈에 보이는 효과는 사실 이쪽이 절반 이상을 한다.
##
## 이 파일은 "어떤 표면인가" 까지만 답한다. 재질을 실제로 만드는 건 depth_shading.gd 다.
##
##   const SurfaceKit := preload("res://scripts/systems/surface_kit.gd")
##   var kit := SurfaceKit.for_node(mi.name, mat.albedo_color)
##   if not kit.is_empty():
##       # kit["detail"] kit["normal"] kit["uv_scale"]
##       # kit["strength"] kit["normal_strength"] kit["roughness"]
##
## class_name 을 일부러 쓰지 않는다 — 이유는 prop_kit.gd 머리말 참고.
## .godot 은 gitignore 대상이라 새 클론에서 'Identifier not declared' 로 죽는다.
##
##
## 세 가지 규칙으로 만들었다.
##
##   1. uv_scale 은 물체 크기가 아니라 **월드 기준**이다. 단위는 "월드 1미터당
##      반복 횟수". 이 게임의 물체는 BoxMesh/CylinderMesh 를 크기만 바꿔 쓰기
##      때문에 UV 를 그대로 쓰면 18m 짜리 건물에서는 늘어나고 0.2m 짜리 볼라드에서는
##      뭉갠다. 삼중평면(triplanar) + 월드 좌표라야 크기와 무관하게 결 밀도가 같다.
##
##   2. 세기는 아주 약하게. 힐링 게임이다. 결이 눈에 띄면 그 시점에 과한 것이다.
##      "자세히 보면 결이 있다" 수준이지 "무늬가 보인다" 가 아니다.
##      그래서 strength 는 STRENGTH_MAX(0.7) 를 넘지 않게 잘라 둔다.
##
##   3. 모르는 이름에는 아무것도 붙이지 않는다. 빈 Dictionary 를 돌려주면
##      그 물건은 지금 모습 그대로 남는다. 애매하면 안 붙이는 쪽이 항상 낫다.
##
## 아래 규칙표는 추측이 아니라 실제로 씬을 뒤져서 만들었다.
## scripts/maps/*.gd, scripts/travel/souvenir_room_3d.gd, scripts/systems/prop_kit.gd
## 가 MeshInstance3D 에 붙이는 label 을 전부 뽑아 이름 그대로 적었다.
## 이름을 바꾸면 그 물체의 결이 조용히 사라진다 — LivingScene 의 잎사귀 이름 규칙과 같다.


const TEX_DIR := "res://assets/textures/"

## 힐링 게임의 상한. 규칙표가 이 값을 넘겨도 여기서 잘린다.
const STRENGTH_MAX := 0.7


# ── 표면 아홉 가지 ──────────────────────────────────────────────────────
#
# uv_scale : 월드 1미터당 반복 횟수. 클수록 촘촘하다.
#            1.6 이면 한 타일이 62cm 라는 뜻이다.
# strength : 디테일 맵 세기 0~1. 디테일 맵 자체의 표준편차가 이미 0.03 이하라
#            (gen_textures.py 의 SURFACES 참고) 여기 0.55 를 줘도 밝기 편차는 ±1.7% 다.
# normal_strength : 노멀 세기. 결이 조명에 걸리는 정도.
# roughness: 이 표면의 거칠기. 지금 씬은 전부 0.85~0.9 로 칠해져 있는데,
#            금속만 좀 낮춰 두면 가로등과 실외기가 벽과 다른 물건으로 읽힌다.
#
# 밀도의 근거는 각 텍스처가 한 장에 담고 있는 것이다.
#   tile   은 한 장에 4x4 칸  → 0.45 면 한 칸이 55cm. 실내 바닥 타일 크기.
#   wood   는 한 장에 나이테 13줄 → 1.8 이면 나이테 간격 4cm. 가구/줄기 결.
#   fabric 은 한 장에 올 32가닥 → 4.0 이면 한 올이 8mm. 러그와 커튼의 성긴 짜임.

const SURFACES := {
	"concrete": {"uv_scale": 1.60, "strength": 0.55, "normal_strength": 0.70, "roughness": 0.95},
	"asphalt":  {"uv_scale": 1.20, "strength": 0.60, "normal_strength": 0.70, "roughness": 0.97},
	"wood":     {"uv_scale": 1.80, "strength": 0.55, "normal_strength": 0.60, "roughness": 0.85},
	"metal":    {"uv_scale": 3.00, "strength": 0.35, "normal_strength": 0.35, "roughness": 0.65},
	"fabric":   {"uv_scale": 4.00, "strength": 0.55, "normal_strength": 0.50, "roughness": 0.95},
	"foliage":  {"uv_scale": 0.90, "strength": 0.45, "normal_strength": 0.40, "roughness": 0.90},
	"tile":     {"uv_scale": 0.45, "strength": 0.50, "normal_strength": 0.60, "roughness": 0.75},
	"plaster":  {"uv_scale": 1.10, "strength": 0.35, "normal_strength": 0.35, "roughness": 0.92},
	"paper":    {"uv_scale": 4.50, "strength": 0.30, "normal_strength": 0.25, "roughness": 0.90},
}


# ── 이름 → 표면 규칙표 ──────────────────────────────────────────────────
#
# [접두사, 표면이름] 또는 [접두사, 표면이름, 세기배율].
# 표면이름이 "" 면 **일부러 붙이지 않는다** 는 뜻이다. 모르는 이름(표에 없음)과
# 결과는 같지만, "봤고 안 붙이기로 했다" 를 남겨 두려고 따로 적는다.
#
# 매칭은 접두사다. 여러 개가 걸리면 **제일 긴 접두사가 이긴다** —
# "DeskMonitorStand" 는 "Desk" 가 아니라 "DeskMonitorStand" 로 간다.
# 그래서 표의 줄 순서는 결과에 영향을 주지 않는다. 읽기 좋게만 묶어 뒀다.
#
# 빛나는 것(창문·간판·네온·모니터 화면), 유리, 물웅덩이, 반투명 오로라에는
# 붙이지 않는다. DepthShading 이 발광·반투명 재질을 원본 그대로 두기 때문에
# 어차피 여기까지 오지 않는 것도 많지만, 표에 적어 두면 나중에 그 물건이
# 발광을 잃어도 실수로 결이 생기지 않는다.

const RULES := [
	# ── 바닥 / 지면 ──
	["Floor", "tile"],                   # 색이 나무빛이면 wood 로 바뀐다. _is_wood_tone 참고
	["FloorSeam", "tile"],
	["FloorRunner", "fabric"],           # 복도 러너는 바닥이 아니라 천이다
	["FloorLamp", "metal"],              # 기념품 방 스탠드
	["FloorLampShade", ""],              # 발광
	["FloorLampGlow", ""],               # 발광
	["Road", "asphalt"],
	["GroundBase", "asphalt", 0.6],      # 거의 가려지는 밑판. 약하게만
	["Crosswalk", "asphalt", 0.55],      # 도료가 덮인 자리라 결이 눌린다
	["Sidewalk", "concrete"],

	# ── 건물 외피 ──
	["Building", "concrete"],            # Building / BuildingLeft / BuildingRight
	["Skyline", "concrete"],             # 옆 건물 실루엣 + 갓돌
	["SkylineAWin", ""],                 # 띠창. 태그는 A/B/C 세 개뿐이다
	["SkylineBWin", ""],
	["SkylineCWin", ""],
	["CityBlock", "concrete", 0.5],      # 창밖 도시. 유리 너머라 반만
	["CityLight", ""],                   # 발광
	["Parapet", "concrete"],
	["Pillar", "concrete"],
	["Pilaster", "plaster"],
	["PlanterBox", "concrete"],

	# ── 실내 벽 / 천장 ──
	["Wall", "plaster"],                 # WallLeft / WallRight / WallBack
	["BackWall", "plaster"],
	["LeftWall", "plaster"],
	["RightWall", "plaster"],
	["EndWall", "plaster"],
	["WallShelf", "wood"],               # 벽 선반. Wall 로 잡히면 안 된다
	["Baseboard", "wood"],
	["Crown", "wood"],                   # CrownMold / CrownBack / CrownLeft / CrownRight
	["CeilPanel", "metal"],

	# ── 창 ──
	# "Win" 으로 시작하는 것 중 유리는 붙이지 않고, 창틀·창살·창턱만 붙인다.
	["Win", ""],                         # Win0.. / Win_0_0 / WindowGlass
	["WinBar", "wood"],
	["WinCross", "wood"],
	["WindowSill", "wood"],
	["WinMullion", "metal"],
	["WinSill", "metal"],

	# ── 문 ──
	["Door", "wood"],                    # DoorCase / DoorLeaf
	["DoorKnob", "metal"],
	["DoorPlate", "metal"],
	["DoorMat", "fabric"],
	["DoorSlit", ""],                    # 문틈 빛
	["DoorGlass", ""],
	["SideDoor", "wood"],
	["BossDoor", "wood"],                # 문틀 + 문짝 두 짝
	["BossGlass", ""],
	["BossKnob", "metal"],
	["BossPlate", "metal"],
	["BossNamePlate", "metal"],
	["BossNameLine", "paper"],
	["EntranceDoor", "metal"],
	["FrontDoor", "metal"],
	["FrontGlass", ""],
	["LobbyDoor", "metal"],
	["LobbyGlass", ""],
	["Elev", "metal"],                   # ElevFrame / ElevDoorL / ElevDoorR
	["ElevSign", "paper"],
	["Gate", "metal"],                   # 출입 게이트

	# ── 가구 ──
	["Desk", "wood"],                    # Desk / DeskTop / DeskBody
	["DeskTray", "metal"],
	["DeskChair", "fabric"],             # DeskChair / DeskChairBack
	["DeskMonitor", ""],                 # 화면
	["DeskMonitorStand", "metal"],
	["DeskMonitorFoot", "metal"],
	["PartnerDesk", "wood"],
	["ItemDesk", "wood"],
	["Table", "wood"],                   # TableTop / TableLeg
	["Chair", "fabric"],                 # ChairSeat / ChairBack
	["ChairLeg", "metal"],
	["Shelf", "wood"],                   # ShelfBoard / ShelfLeg / ShelfSide / ShelfPhoto ...
	["ShelfBook", "paper"],
	["ShelfPot", "plaster"],
	["Cab", "metal"],                    # CabBody / CabTop / CabDrawer / CabHandle / CabCase / CabDoor
	["CabGlass", ""],
	["CabLabel", "paper"],
	["CabinetPaper", "paper"],           # 캐비닛 위 서류 더미
	["Partition", "fabric"],             # 칸막이 천 패널
	["PartitionRail", "metal"],
	["Stool", "wood"],
	["Bench", "metal"],                  # 좌판까지 전부 회청색이라 나무로 읽히지 않는다
	["Basket", "fabric"],                # 엮은 바구니
	["NoticeFrame", "wood"],
	["NoticeCork", "fabric"],
	["NoticePaper", "paper"],
	["Frame", "wood"],                   # 액자 테두리
	["FrameArt", "paper"],
	["FrameStand", "wood"],

	# ── 기둥 / 봉 / 금속 기물 ──
	["Post", "metal"],                   # 가로등 기둥
	["Arm", "metal"],                    # 가로등 팔
	["Pole", "metal"],                   # PoleShaft / PoleCross / PoleTransformer ...
	["Bollard", "metal"],
	["BikeRack", "metal"],
	["Rack", "metal"],                   # RackLeg / RackTop / RackRail
	["Trash", "metal"],                  # Trashcan1 / TrashCan / TrashBin
	["Bin", "metal"],                    # BinBody / BinRing / BinLid / BinSlot
	["Traffic", "metal"],
	["TrafficLamp", ""],                 # 발광
	["Cctv", "metal"],
	["Extinguisher", "metal"],
	["Cooler", "metal"],                 # 정수기
	["CoolerBottle", ""],                # 물통
	["BadgeBox", "metal"],
	["BadgeSlot", "metal"],
	["Clock", "metal"],                  # ClockBody / 바늘들
	["ClockFace", "paper"],

	# ── 옥상 / 외벽 설비 ──
	["Unit", "metal"],                   # 옥상 기계실
	["Tank", "metal"],                   # 물탱크
	["Ant", "metal"],                    # 안테나
	["AntBeacon", ""],                   # 항공장애등
	["Pipe", "metal"],                   # 외벽 배관
	["AcBody", "metal"],                 # 실외기
	["AcFan", "metal"],
	["AcBracket", "metal"],
	["AcUnits", "metal"],
	["Vend", "metal"],                   # 자판기 몸통 / 음료 / 버튼 / 발
	["VendGlass", ""],
	["VendHeader", ""],
	["Awning", "fabric"],                # 차양 천
	["AwningBrace", "metal"],

	# ── 간판 / 표지 ──
	# "Sign" 하나로 묶지 않는다. 간판은 판(종이)과 팔(금속)과 글자칸(발광)이 섞여 있다.
	["SignBG", "paper"],
	["SignBoard", "paper"],
	["SignPole", "metal"],
	["SignArm", "metal"],
	["SignFrame", "metal"],
	["SignFace", ""],                    # 발광
	["SignGlyph", ""],                   # 발광
	["NeonSign", ""],                    # 발광
	["BusBase", "metal"],
	["BusPole", "metal"],
	["BusBoard", "paper"],
	["BusLine", "paper"],
	["BusHeader", ""],                   # 발광
	["BusStopPole", "metal"],
	["BusStopSign", "paper"],
	["InfoPole", "metal"],
	["InfoSign", "paper"],
	["InfoLine", "paper"],
	["ExitSign", "paper"],               # 로비 정문 위 표지판(발광 아님)
	["ExitCase", "metal"],
	["ExitFace", ""],                    # 발광
	["ExitArrow", ""],                   # 발광

	# ── 조명 기구 ──
	# 빛나는 판은 빼고 몸통과 봉만.
	["LightMount", "metal"],
	["LightEndCap", "metal"],
	["LightRod", "metal"],
	["LightPanel", ""],                  # 발광
	["DarkLightPanel", "metal"],         # 꺼진 등
	["DarkLightRod", "metal"],
	["LampStem", "metal"],
	["LampShade", ""],                   # 발광
	["Fluorescent", ""],                 # 발광
	["StandbyLed", ""],                  # 발광
	["StringCord", "metal"],
	["StringBulb", ""],                  # 발광

	# ── 자연 / 화분 ──
	# 잎사귀 이름은 living_scene.gd 의 FOLIAGE 와 같은 목록이다. 한쪽만 고치지 말 것.
	["Canopy", "foliage"],
	["Plant", "foliage"],                # Plant / PlantLeaf / PlantHang / PlantSmall
	["PlanterLeaf", "foliage"],
	["PotLeaf", "foliage"],
	["Leaf", "foliage"],
	["Bush", "foliage"],
	["Trunk", "wood"],
	["Branch", "wood"],
	["CornerStem", "wood"],
	["Pot", "plaster"],                  # 화분 몸통·테. 유약 바른 도기
	["PotSoil", "asphalt", 0.7],         # 흙. 알갱이 결만 빌려 쓴다
	["PlanterPot", "plaster"],
	["CornerPot", "plaster"],
	["CornerPotSoil", "asphalt", 0.7],
	["HangPot", "plaster"],
	["SillPot", "plaster"],
	["HangBracket", "metal"],
	["HangCord", "metal"],

	# ── 천 ──
	["Curtain", "fabric"],               # 밸런스 / 패널 / 주름 / 묶은 띠
	["CurtainRod", "wood"],
	["CurtainFinial", "wood"],
	["CurtainBracket", "metal"],
	["Cushion", "fabric"],
	["Rug", "fabric"],                   # RugEdge / RugInner / RugCore
	["LobbyRug", "fabric"],
	["Mat", "fabric"],                   # MatRound / MatRing
	["Blanket", "fabric"],

	# ── 여행 물품 ──
	["Bag", "fabric"],                   # BagBody / BagHandle / BagStrap
	["NbCover", "fabric"],               # 수첩 표지
	["NbSpine", "fabric"],
	["NbPages", "paper"],
	# "Cam" 으로 뭉뚱그리면 안 된다. 씬마다 있는 Camera3D 가 그대로 걸린다.
	["CamBody", "metal"],
	["CamFlash", "metal"],
	["CamLens", ""],                     # 렌즈 유리

	# ── 종이 ──
	["Poster", "paper"],                 # PosterPaper / PosterArt / PosterLine
	["PosterFrame", "wood"],
	["Memo", "paper"],
	["CrumpledPaper", "paper"],
	["PartnerPaper", "paper"],
	["ItemPaper", "paper"],
	["LeftDeskPaper", "paper"],

	# ── 화면 / 발광 / 특수 ──
	["Monitor", ""],                     # 꺼진 화면도 결은 안 붙인다
	["MonitorStand", "metal"],
	["MonitorScreen", ""],
	["ScreenLine", ""],
	["Puddle", ""],                      # 물
	["Photo", ""],                       # PhotoRing / PhotoSpark / 액자 속 사진
	["Star", ""],
	["Aurora", ""],
	["EmptySlot", ""],
]


# ── 바깥에서 부르는 것 ──────────────────────────────────────────────────

## 이 노드가 어떤 표면인지 답한다. 해당 없으면 빈 Dictionary.
##
## albedo 는 보조 판단용이다 — 이름이 같아도 색이 다르면 다른 물건인 경우가 있다.
## 이름이 항상 우선이고, 색은 표면이 이미 정해진 뒤에만 끼어든다.
static func for_node(node_name: String, albedo: Color) -> Dictionary:
	var rule := _match(node_name)
	if rule.is_empty():
		return {}
	var key := _tune(str(rule[1]), albedo)
	if key == "" or not SURFACES.has(key):
		return {}

	var card: Dictionary = SURFACES[key]
	var w: float = float(rule[2]) if rule.size() > 2 else 1.0
	# 매번 새 Dictionary 를 만든다. 부르는 쪽이 값을 고쳐도 다음 호출이 안 흔들리게.
	return {
		"detail": TEX_DIR + key + "_d.png",
		"normal": TEX_DIR + key + "_n.png",
		"uv_scale": float(card["uv_scale"]),
		"strength": clampf(float(card["strength"]) * w, 0.0, STRENGTH_MAX),
		"normal_strength": clampf(float(card["normal_strength"]) * w, 0.0, 1.0),
		"roughness": float(card["roughness"]),
	}


## 표면 이름만. 로그와 테스트용. 해당 없으면 "".
static func surface_of(node_name: String, albedo: Color) -> String:
	var rule := _match(node_name)
	if rule.is_empty():
		return ""
	return _tune(str(rule[1]), albedo)


# ── 안쪽 ────────────────────────────────────────────────────────────────

## 제일 긴 접두사가 이긴다. 표의 줄 순서에 결과가 끌려다니지 않게 하려는 것이다.
## "BuildingWindow" 같은 이름이 나중에 생겨도 "Building" 을 이기고 제 규칙으로 간다.
static func _match(node_name: String) -> Array:
	var best: Array = []
	var best_len := 0
	for rule in RULES:
		var prefix: String = rule[0]
		if prefix.length() <= best_len:
			continue
		if node_name.begins_with(prefix):
			best = rule
			best_len = prefix.length()
	return best


## 색 보조 판단.
##
## 지금 걸리는 건 바닥 하나다. 사무실(#43566A)·로비(#3F4550)·복도(#3B4250) 바닥은
## 푸른 회색 타일이고, 기념품 방 바닥(#6B5744)만 나무다. 그런데 넷 다 이름이
## "Floor" 라서 이름만으로는 갈라지지 않는다. 나무 바닥에 타일 이음새가 그어지면
## 그 방이 통째로 화장실처럼 보인다.
static func _tune(key: String, albedo: Color) -> String:
	if key == "tile" and _is_wood_tone(albedo):
		return "wood"
	return key


## 나무빛 갈색인가.
## 아래끝을 0.03 에서 자르는 건 스카프색(산호 #FF6F61, h≈0.01) 근처를 건드리지
## 않으려는 것이다. 위끝 0.7 도 같은 이유 — 이 게임의 나무색은 전부 탁하다.
static func _is_wood_tone(c: Color) -> bool:
	return c.s >= 0.15 and c.s <= 0.70 and c.h >= 0.03 and c.h <= 0.14
