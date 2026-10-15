class_name IdleData
extends RefCounted
## 진짜 행복 (키우기)의 표와 공식 (`docs/redesign-idle.md`). **숫자는 여기 한 곳에만 둔다** - 시뮬레이션
## (`tools/sim/sim_idle.gd`)이 이 표를 그대로 읽어서 곡선을 맞춘다.
##
## 정적 클래스다. 자동 로드를 늘리지 않는다 - `project.godot` 의 부팅 설정은 OTA 로 못 바꾼다.

# ── 구역과 스테이지 ──────────────────────────────────────────────────

## 구역 열: 이름 · 우두머리 · 졸개 · 장비 단계 이름 · 하늘 빛깔 둘(위·아래).
const ZONES := [
	{"name": "윤슬", "boss": "drop_king", "mobs": ["drop", "ember"], "tier": "물결",
		"sky": ["#9ADBE8", "#E6F6F2"]},
	{"name": "볕뉘", "boss": "dokkaebi", "mobs": ["ember", "sprout", "drop"], "tier": "햇살",
		"sky": ["#FFD59A", "#FFF1D6"]},
	{"name": "가풀재", "boss": "golem", "mobs": ["pebble", "sprout", "ember"], "tier": "바위",
		"sky": ["#C9B79C", "#EFE5D3"]},
	{"name": "하늬섬", "boss": "gull", "mobs": ["gust", "pebble", "drop"], "tier": "바람",
		"sky": ["#A9D8F5", "#EAF6FF"]},
	{"name": "굽이나루", "boss": "carp", "mobs": ["whirl", "gust", "sprout"], "tier": "강물",
		"sky": ["#8FC9D9", "#DDF1F4"]},
	{"name": "방울못", "boss": "lotus", "mobs": ["thorn", "whirl", "pebble"], "tier": "연꽃",
		"sky": ["#C9B3E6", "#F1E8FA"]},
	{"name": "갈밭머리", "boss": "thorn_queen", "mobs": ["thorn", "mole", "gust"], "tier": "갈대",
		"sky": ["#D8D58F", "#F6F4D6"]},
	{"name": "솔은재", "boss": "mole_king", "mobs": ["storm", "mole", "thorn"], "tier": "솔잎",
		"sky": ["#8FB89A", "#DDEFE0"]},
	{"name": "꽃눈벌", "boss": "deer", "mobs": ["blaze", "storm"], "tier": "꽃눈",
		"sky": ["#F5B8C8", "#FDE8EE"]},
	{"name": "잿마루", "boss": "night", "mobs": ["paper", "memo", "vending", "bat"], "tier": "꿈결",
		"sky": ["#6E6A8C", "#B9B5D0"]},
]
const STAGES_PER_ZONE := 10
## 스테이지 하나에 잡는 몬스터 수 (열 번째 스테이지는 우두머리 한 마리).
const WAVE := 5
const ZONE_COUNT := 10
const STAGE_MAX := 100          ## 이 뒤로는 잿마루가 끝없이 이어진다 (무한 모드)

## 몬스터 이름 (그림 `assets/sprites/s-<kind>-walk.png`).
const MOB_NAMES := {
	"drop": "물방울뭉", "ember": "불똥콩", "sprout": "새싹뭉치", "pebble": "조약돌이",
	"gust": "산들이", "whirl": "소용돌이", "thorn": "가시덤불", "mole": "두더지",
	"storm": "폭풍새", "blaze": "화르륵", "paper": "결재 서류 골렘", "memo": "회의록 유령",
	"vending": "커피 자판기 미믹", "bat": "메신저 박쥐",
	"drop_king": "물방울 대왕", "dokkaebi": "불꽃 도깨비", "golem": "바위 거인",
	"gull": "태풍 갈매기", "carp": "소용돌이 잉어왕", "lotus": "연꽃 정령",
	"thorn_queen": "가시덩굴 여왕", "mole_king": "산골 두더지왕", "deer": "화염 꽃사슴",
	"night": "야근 대마왕",
}


## 스테이지 번호(1~)가 어느 구역·몇 번째·우두머리인지. 101 번부터는 잿마루 끝없이.
static func stage_info(n: int) -> Dictionary:
	var s := maxi(1, n)
	var zi := clampi((s - 1) / STAGES_PER_ZONE, 0, ZONE_COUNT - 1)
	var idx := ((s - 1) % STAGES_PER_ZONE) + 1
	if s > STAGE_MAX:
		zi = ZONE_COUNT - 1
		idx = ((s - 1) % STAGES_PER_ZONE) + 1
	var z: Dictionary = ZONES[zi]
	var boss := idx == STAGES_PER_ZONE
	var mobs: Array = z["mobs"]
	return {"stage": s, "zone": zi, "zone_name": String(z["name"]), "idx": idx, "boss": boss,
		"kind": String(z["boss"]) if boss else String(mobs[(idx - 1) % mobs.size()]),
		"count": 1 if boss else WAVE, "tier": zone_tier(s), "endless": s > STAGE_MAX}


## 이 스테이지에서 나오는 장비 단계 (1~10).
static func zone_tier(n: int) -> int:
	return clampi(((maxi(1, n) - 1) / STAGES_PER_ZONE) + 1, 1, ZONE_COUNT)


static func stage_label(n: int) -> String:
	var i := stage_info(n)
	if bool(i["endless"]):
		return "%s · %d" % [String(i["zone_name"]), n - STAGE_MAX]
	return "%s %d-%d" % [String(i["zone_name"]), int(i["zone"]) + 1, int(i["idx"])]


# ── 몬스터 ───────────────────────────────────────────────────────────

const MON_HP := 26.0
const MON_HP_GROW := 1.072
const MON_ATK := 4.2
const MON_ATK_GROW := 1.060
const BOSS_HP := 6.0
const BOSS_ATK := 1.35
const MON_EXP := 5.0
const MON_EXP_GROW := 1.050
const MON_COIN := 2.5
const MON_COIN_GROW := 1.066
## 몬스터가 때리는 박자(초). 우두머리는 느리지만 무겁다.
const MON_EVERY := 1.5
const BOSS_EVERY := 1.8


static func monster(n: int, boss: bool) -> Dictionary:
	var k := float(maxi(1, n) - 1)
	var hp := MON_HP * pow(MON_HP_GROW, k) * (BOSS_HP if boss else 1.0)
	var atk := MON_ATK * pow(MON_ATK_GROW, k) * (BOSS_ATK if boss else 1.0)
	return {"hp": int(round(hp)), "atk": atk, "def": 1.0 + 0.8 * float(n),
		"exp": int(round(MON_EXP * pow(MON_EXP_GROW, k) * (3.0 if boss else 1.0))),
		"coin": int(round(MON_COIN * pow(MON_COIN_GROW, k) * (4.0 if boss else 1.0))),
		"every": BOSS_EVERY if boss else MON_EVERY}


# ── 캐릭터 ───────────────────────────────────────────────────────────

const LEVEL_MAX := 60
const JOB_LV := 5
## 이 레벨부터 자동사냥(쿼카가 알아서 때린다). 그 전에는 화면을 톡톡 쳐서 싸운다.
const AUTO_LV := 5

const HERO_HP := 100.0
const HERO_HP_PER := 20.0
const HERO_ATK := 11.0
const HERO_ATK_PER := 3.2
const HERO_DEF := 3.0
const HERO_DEF_PER := 1.0


## 다음 레벨까지 경험.
static func exp_need(level: int) -> int:
	return 30 + 14 * level + int(1.1 * float(level * level))


## 직업. hp/atk/def 는 몸 배율, every 는 기본 공격 박자(초), crit 은 치명타 확률, skill 은 필살기.
##   skill: name · every 몇 초마다 · power 몇 배 · hits 몇 번 · crit 확정 · guard 받는 피해 배율(guard_secs 동안)
const JOBS := {
	"novice": {"name": "꿈나그네", "hp": 1.0, "atk": 1.0, "def": 1.0, "every": 1.0, "crit": 0.05,
		"desc": "아직 직업이 없어요", "skill": {}},
	"warrior": {"name": "전사", "hp": 1.3, "atk": 1.30, "def": 1.3, "every": 1.0, "crit": 0.05,
		"desc": "튼튼해서 잘 안 쓰러져요",
		"skill": {"name": "방패치기", "every": 5.0, "power": 2.0, "hits": 1, "guard": 0.5, "guard_secs": 3.0}},
	"mage": {"name": "마법사", "hp": 0.95, "atk": 1.40, "def": 0.95, "every": 1.1, "crit": 0.05,
		"desc": "한 방이 아주 커요",
		"skill": {"name": "별똥별", "every": 6.0, "power": 5.2, "hits": 1}},
	"archer": {"name": "궁수", "hp": 0.95, "atk": 0.60, "def": 0.95, "every": 0.75, "crit": 0.08,
		"desc": "빠르게 여러 번 쏴요",
		"skill": {"name": "연사", "every": 5.0, "power": 0.85, "hits": 4}},
	"thief": {"name": "도적", "hp": 0.9, "atk": 0.55, "def": 0.9, "every": 0.9, "crit": 0.15,
		"desc": "치명타가 자주 터져요",
		"skill": {"name": "급소 찌르기", "every": 5.0, "power": 2.2, "hits": 1, "crit": true}},
}
const JOB_ORDER := ["warrior", "mage", "archer", "thief"]
const CRIT_MULT := 2.0

# ── 장비 ─────────────────────────────────────────────────────────────

## 여섯 칸. 칸마다 올려 주는 것 하나 (`docs/redesign-idle.md`).
const SLOTS := ["weapon", "gloves", "hat", "charm", "top", "shoes"]
const SLOT_NAME := {"weapon": "무기", "gloves": "장갑", "hat": "모자", "charm": "장신구",
	"top": "옷", "shoes": "신발"}
const SLOT_STAT := {"weapon": "atk", "gloves": "atk", "hat": "hp", "charm": "hp",
	"top": "def", "shoes": "def"}
## 단계 1·강화 0 일 때 한 칸이 주는 값.
const SLOT_BASE := {"weapon": 9.0, "gloves": 5.0, "hat": 45.0, "charm": 28.0, "top": 5.0, "shoes": 3.0}
const TIER_GROW := 1.55          ## 한 단계 오를 때마다 곱
const PLUS_MAX := 30
const PLUS_STEP := 0.10          ## 강화 한 칸마다 기본값의 이만큼
const WEAPON_NAME := {"novice": "막대기", "warrior": "검", "mage": "지팡이", "archer": "활", "thief": "단검"}
const SLOT_ITEM := {"gloves": "장갑", "hat": "모자", "charm": "목걸이", "top": "옷", "shoes": "신발"}

## 강화 값 (꿈조각) - 단계와 현재 강화에 따라 오른다.
const ENH_BASE := 14.0
const ENH_TIER := 1.50
const ENH_STEP := 1.16


static func tier_mult(tier: int) -> float:
	return pow(TIER_GROW, float(maxi(1, tier) - 1))


static func slot_value(slot: String, tier: int, plus: int) -> float:
	return float(SLOT_BASE[slot]) * tier_mult(tier) * (1.0 + PLUS_STEP * float(plus))


static func enhance_cost(tier: int, plus: int) -> int:
	return int(round(ENH_BASE * pow(ENH_TIER, float(maxi(1, tier) - 1)) * pow(ENH_STEP, float(plus))))


static func item_name(slot: String, tier: int, job: String) -> String:
	var t := String(ZONES[clampi(tier - 1, 0, ZONE_COUNT - 1)]["tier"])
	var base := String(WEAPON_NAME.get(job, "막대기")) if slot == "weapon" else String(SLOT_ITEM[slot])
	return "%s %s" % [t, base]


# ── 수련 (끝판 꿈조각 쓰는 곳) ──────────────────────────────────────

## 장비가 다 차도 꿈조각을 쓸 곳. 공격·체력·방어를 한 단계마다 1% 씩 끝없이 올린다.
## 굽이나루(5구역) 우두머리를 물리치면 열린다 - 그 전엔 장비 강화가 훨씬 이득이라 헷갈리지 않게.
const TRAIN_STATS := ["atk", "hp", "def"]
const TRAIN_NAME := {"atk": "공격 수련", "hp": "체력 수련", "def": "방어 수련"}
const TRAIN_STEP := 0.01
const TRAIN_BASE := 5000.0
const TRAIN_GROW := 1.15
const TRAIN_OPEN := 51           ## 이 스테이지가 열리면 (= 50번 우두머리를 깨면)


static func train_cost(lv: int) -> int:
	return int(round(TRAIN_BASE * pow(TRAIN_GROW, float(maxi(0, lv)))))


# ── 보상 ─────────────────────────────────────────────────────────────

## 몬스터가 장비를 떨어뜨릴 확률 (그 구역 단계가 지금 칸보다 높을 때만 뜻이 있다).
const DROP_CHANCE := 0.05
## 자는 동안: 분당 이만큼의 "지금 스테이지 몬스터 한 마리 값" × 보너스, 최대 8시간.
const IDLE_KILLS_PER_MIN := 2.0
const IDLE_MAX_MIN := 480
const IDLE_MIN_MIN := 5
