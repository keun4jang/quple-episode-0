class_name TombPathInterior
extends Place
## 능 안쪽길. 볕뉘의 그 능 — 밑동만 보이던 걸, 안쪽으로 한 바퀴 돌 수
## 있게 열었다.
##
## **무덤 안이 아니다.** 돌길이 봉분을 둥글게 두르고 지나가는, 조용한
## 둘레길이다. 지하도, 비밀도, 의례도 없다 — 오래된 자리를 천천히
## 걷는 것 하나뿐이다. 필수 인연도 안 둔다(`docs/planning/` 브레인
## 스토밍 결과) — 이 공간은 사람보다 자리 자체가 말하는 편이 맞다.

const W := 36
const H := 20
const CX := 18
const CY := 10


func place_name() -> String:
	return "능 안쪽길"


func _init() -> void:
	legend = {
		"g": "grass",       # 능을 두른 잔디
		"c": "slate-path",  # 둘레길
	}
	solid_tiles = []


## 가운데 봉분(소품으로 막는다)을 돌길이 둥글게 두른다.
func ground_map() -> String:
	var rows: Array = []
	for y in H:
		var row := ""
		for x in W:
			var dx := x - CX
			var dy := float(y - CY) * 1.7
			var d := sqrt(float(dx * dx) + dy * dy)
			row += "c" if (d >= 6.0 and d <= 7.6) else "g"
		rows.append(row)
	return "\n".join(rows)


func spawn_tile() -> Vector2i:
	return Vector2i(CX, H - 2)


func props() -> Array:
	return [
		# ── 봉분 (가운데) ────────────────────────────────────────────
		[CX, CY, "burial-mound", true],
		[CX - 4, CY - 2, "boulder", true],
		[CX + 4, CY - 2, "boulder", true],
		[CX - 4, CY + 2, "boulder", true],
		[CX + 4, CY + 2, "boulder", true],
		# ── 볕 드는 자리 (동쪽) ─────────────────────────────────────
		[CX + 8, CY, "bench", true],
		[CX + 7, CY - 1, "flower-pots", false],
		[CX + 9, CY + 1, "flower-pots", false],
		# ── 능을 두른 소나무 ─────────────────────────────────────────
		[3, 3, "pine", true],
		[W - 4, 3, "pine", true],
		[3, H - 4, "tree", true],
		[W - 4, H - 4, "pine", true],
		[CX - 10, CY, "shrub", false],
		[CX + 2, CY - 8, "shrub", false],
		# ── 낮은 돌담 (서쪽) ─────────────────────────────────────────
		[CX - 8, CY - 1, "stone-wall", true],
		[CX - 8, CY + 1, "stone-wall", true],
	]


func pickups() -> Array:
	return [
		[CX - 2, CY - 6, "p-pinecone"],
		[CX + 2, CY + 6, "p-flower"],
		[CX - 9, CY + 4, "p-pebble"],
	]


## "볕든 돌담 사진 남기기" — 동쪽, 볕 드는 자리.
func quest_zones() -> Array:
	return [["볕뉘:능안", Vector2i(CX + 8, CY), 48.0]]


## 문. 들어온 자리로 다시 나간다.
func doors() -> Array:
	return [{
		"tile": Vector2i(CX, H - 1),
		"scene": JourneyState.exit_scene,
		"spawn": JourneyState.exit_tile,
		"label": "나가기",
	}]


func on_built() -> void:
	JourneyState.here = place_name()
	# 사람보다 자리가 말한다 — 인연을 안 세운다. 볕 드는 자리 자체가
	# 한마디를 건넨다.
	put_spot(Vector2i(CX + 8, CY - 2), "볕 드는 자리", [
		"발소리가 조용한 길은 오래 남는다.",
		"여기는 멀리서 볼 때보다 가까이서 더 조용하다.",
	])


func bgm_track() -> String:
	return "wind"


func ambient_kind() -> String:
	return "wind"
