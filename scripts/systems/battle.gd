class_name Battle
extends RefCounted
## 꿈결의 싸움 — 수치와 규칙의 표 (`docs/redesign-dream.md`, `docs/elements.md`).
##
## **오토로드가 아니라 정적 싱글턴이다.** 오토로드 목록은
## `project.godot` 에 있고 그건 APK 를 새로 깔아야 바뀐다 — 리소스 팩
## 갱신(`tools/publish-update.sh`)만으로는 폰에 전달되지 않는다.
## `class_name` + `static var` 는 그냥 스크립트라 갱신으로 간다.
##
## 여기는 **누가 얼마나 센가**만 든다: 속성 상성, 레벨·능력치·직업,
## 스킬, 몬스터 종과 구역별 레벨, 성장과 저장. 실제로 치고받는 것은
## `Field` 가 마을 한가운데서 실시간으로 한다. 무기·방어구는 `Gear`.
##
## 규칙은 셋만 지킨다:
## 1. **손을 통째로 묶는 상태는 안 만든다** (기절·속박). 느려지게는 해도
##    손을 놓고 맞기만 하는 시간은 없다.
## 2. **되돌릴 수 없는 벌은 없다.** 쓰러지면 그 자리에서 일어나고 꿈조각을
##    조금 잃는다(`Field.fall`). 레벨·장비는 안 잃는다.
## 3. **예고는 실제와 반드시 같다.** 몬스터의 수는 무작위가 아니라 몇 번째
##    덤비는지로만 정해지므로(`plan_for`), 머리 위 예고와 실제가 어긋날 수 없다.

# ── 속성 ─────────────────────────────────────────────────────────────
#
# 포켓몬스터처럼 **한 바퀴로 물고 물린다.** 이름만 봐도 무엇으로 때려야
# 할지 짐작하게 - 외울 표가 아니라 상식이다 (`docs/elements.md` 1절).
#   물 > 불 > 나무 > 땅 > 바람 > 물
const ELEMS := {
	"none": {"name": "무", "col": "#E4DCCF"},
	"water": {"name": "물", "col": "#4DABF7"},
	"fire": {"name": "불", "col": "#FF7043"},
	"wood": {"name": "나무", "col": "#51CF66"},
	"earth": {"name": "땅", "col": "#C9955C"},
	"wind": {"name": "바람", "col": "#9BE7F5"},
	"dark": {"name": "어둠", "col": "#B197FC"},
}
const ELEM_ORDER := ["water", "fire", "wood", "earth", "wind"]
const BEATS := {"water": "fire", "fire": "wood", "wood": "earth",
	"earth": "wind", "wind": "water"}
const SUPER := 1.5
const RESIST := 0.6
const SAME := 0.8


## `atk` 속성으로 `dfn` 속성을 치면 몇 배. 무·어둠은 누구와도 1배.
static func matchup(atk: String, dfn: String) -> float:
	if not BEATS.has(atk) or not BEATS.has(dfn):
		return 1.0
	if BEATS[atk] == dfn:
		return SUPER
	if BEATS[dfn] == atk:
		return RESIST
	if atk == dfn:
		return SAME
	return 1.0


static func elem_name(e: String) -> String:
	return String(ELEMS.get(e, ELEMS["none"])["name"])


static func elem_col(e: String) -> Color:
	return Color(String(ELEMS.get(e, ELEMS["none"])["col"]))


# ── 사람 쪽 ──────────────────────────────────────────────────────────

const LEVEL_MAX := 50
## 첫 전직을 할 수 있는 레벨.
const JOB_LV := 10
## 레벨이 오를 때마다 받는 능력치 점수·스킬 점수.
const AP_PER := 5
const SP_PER := 1

static var level := 1
static var xp := 0
## 레벨 1 의 가득 찬 값으로 시작한다. 오토로드가 아니라 `_ready()` 가
## 없어서 여기서 바로 채워 둬야 한다 — 0 으로 두면 시작하자마자 쓰러진 상태다.
static var hp := 58
static var mp := 26
static var job := "novice"
## 힘·민첩·지능·행운. 다 4 에서 시작한다.
static var stats: Dictionary = {"str": 4, "dex": 4, "int": 4, "luk": 4}
## 아직 안 나눈 능력치 점수 · 스킬 점수.
static var ap := 0
static var sp := 0
## 배운 스킬의 레벨 (1~10). 없으면 안 배운 것.
static var skill_lv: Dictionary = {"tap": 1, "breathe": 1}
## 점수를 알아서 나눌까. **기본은 켜져 있다** - 잘못 나눌 일이 없게.
static var auto_ap := true
static var auto_sp := true
## 오늘 걷어낸 자리. "마을:x,y" → true
static var cleared: Dictionary = {}
static var cleared_day := 0

const STAT_NAME := {"str": "힘", "dex": "민첩", "int": "지능", "luk": "행운"}
const STAT_ORDER := ["str", "dex", "int", "luk"]

## 직업. 처음엔 모두 꿈나그네, LV 10 에 넷 중 하나를 고른다.
##   main    공격력에 쓰는 능력치
##   auto    자동 배분 비율 (점수 5 를 어떻게 나누나)
##   hp/mp   전직 뒤 레벨마다 더 붙는 체력·마음력
##   weapon  들 수 있는 무기 (`Gear`)
const JOBS := {
	"novice": {"name": "꿈나그네", "main": "str", "weapon": "",
		"auto": {"str": 2, "dex": 1, "int": 1, "luk": 1}, "hp": 0, "mp": 0,
		"desc": "갓 꿈결에 떨어진 모험가. LV 10 에 직업을 고른다."},
	"warrior": {"name": "전사", "main": "str", "weapon": "sword",
		"auto": {"str": 4, "dex": 1}, "hp": 8, "mp": 0,
		"desc": "앞에서 맞고 버틴다. 둘레를 한꺼번에 벤다. 체력이 가장 많다."},
	"mage": {"name": "마법사", "main": "int", "weapon": "staff",
		"auto": {"int": 4, "luk": 1}, "hp": 1, "mp": 5,
		"desc": "멀리서 물·불·나무·땅·바람을 다 쓴다. 몸은 약하지만 늘 약점을 찌른다."},
	"archer": {"name": "궁수", "main": "dex", "weapon": "bow",
		"auto": {"dex": 4, "str": 1}, "hp": 3, "mp": 2,
		"desc": "멀리서 연사한다. 치고 빠진다. 치명타가 잘 터진다."},
	"thief": {"name": "도적", "main": "luk", "weapon": "dagger",
		"auto": {"luk": 3, "dex": 2}, "hp": 3, "mp": 2,
		"desc": "빠른 연타와 급소 찌르기. 치명타 피해가 가장 크다."},
}
const JOB_ORDER := ["warrior", "mage", "archer", "thief"]


static func stat(s: String) -> int:
	return int(stats.get(s, 0)) + Gear.bonus(s)


static func main_stat() -> int:
	return stat(String(JOBS[job]["main"]))


## **지닌 것이 보태는 힘**(`Catalog.bonus`)과 장비(`Gear.bonus`)가 여기서 더해진다.
static func hp_max() -> int:
	var j: Dictionary = JOBS.get(job, JOBS["novice"])
	return 50 + 12 * (level - 1) + 2 * stat("str") + int(j["hp"]) * maxi(0, level - JOB_LV) \
		+ Catalog.bonus("hp") + Gear.bonus("hp") + Loop.title_hp()


static func mp_max() -> int:
	var j: Dictionary = JOBS.get(job, JOBS["novice"])
	return 18 + 4 * (level - 1) + 2 * stat("int") + int(j["mp"]) * maxi(0, level - JOB_LV) \
		+ Catalog.bonus("mp") + Gear.bonus("mp")


## 공격력 = 무기 + 주 능력치 x0.8 + 레벨 (+ 버프·지닌 것·장비 옵션).
static func attack_power() -> int:
	return Gear.weapon_atk() + int(main_stat() * 0.8) + level + Field.atk_bonus() \
		+ Catalog.bonus("atk") + Gear.bonus("atk")


static func defense() -> int:
	return Gear.bonus("def") + level / 2 + int(stat("str") * 0.3) + Catalog.bonus("def")


## 치명타 확률 (0~1). 민첩이 올린다. 궁수·도적은 기본이 조금 높다.
static func crit_rate() -> float:
	var base := 0.08 if job in ["archer", "thief"] else 0.05
	return clampf(base + stat("dex") * 0.002 + Gear.bonus("crit") * 0.01, 0.0, 0.75)


## 치명타 배율. 행운이 올린다.
static func crit_mult() -> float:
	return 1.5 + stat("luk") * 0.005 + (0.3 if job == "thief" else 0.0)


## 다음 레벨까지. 앞은 빠르고(LV 10 까지 30분 남짓) 뒤로 갈수록 무겁다.
static func xp_need() -> int:
	return 20 + 12 * (level - 1) + level * level


## 피해 경감은 뺄셈이 아니라 비율이다. 뺄셈으로 두면 방어가 공격력을
## 넘는 순간 피해가 0 이 되어 싸움이 통째로 무의미해진다.
static func _mitigation(d: int) -> float:
	return 100.0 / (100.0 + float(maxi(0, d)) * 2.0)


# ── 스킬 ─────────────────────────────────────────────────────────────
#
# 직업마다 다섯 남짓. 꿈나그네 것(톡 치기·심호흡·몸통 박치기)은 전직해도 남는다.
#   job     누가 쓰나 ("*" 모두)
#   elem    "weapon" 이면 든 무기의 속성으로 친다 (`Gear.weapon_elem`)
#   hits    몇 번 치나 · range 닿는 거리(px) · aoe 둘레를 한꺼번에(반지름)
#   line    겨눈 쪽 한 줄을 다 꿰뚫는다 · dash 그 앞까지 달려든다
#   grants  내게 남기는 상태 · foe 몬스터에게 거는 상태 · cd 다시 쓰기까지(초)
const SKILLS := {
	"tap": {"name": "톡 치기", "job": "*", "lv": 1, "mp": 0, "type": "attack",
		"elem": "weapon", "mult": 1.0, "cd": 0.45},
	"breathe": {"name": "심호흡", "job": "*", "lv": 1, "mp": 4, "type": "heal",
		"amount": 0.3, "grants": "warm", "cd": 7.0},
	"bump": {"name": "몸통 박치기", "job": "*", "lv": 4, "mp": 3, "type": "attack",
		"elem": "weapon", "mult": 1.7, "cd": 2.5},
	# 전사 - 앞에서 벤다
	"power": {"name": "강하게 베기", "job": "warrior", "lv": 10, "mp": 3,
		"type": "attack", "elem": "weapon", "mult": 2.0, "cd": 1.3},
	"spin": {"name": "회전 베기", "job": "warrior", "lv": 13, "mp": 6, "type": "attack",
		"elem": "weapon", "mult": 1.4, "aoe": 46.0, "cd": 3.5},
	"charge": {"name": "돌진", "job": "warrior", "lv": 16, "mp": 5, "type": "attack",
		"elem": "weapon", "mult": 1.8, "range": 64.0, "dash": true, "cd": 4.0},
	"iron": {"name": "철벽", "job": "warrior", "lv": 20, "mp": 6, "type": "buff",
		"grants": "firm", "cd": 14.0},
	"quake": {"name": "대지 가르기", "job": "warrior", "lv": 25, "mp": 12,
		"type": "attack", "elem": "earth", "mult": 2.6, "aoe": 60.0, "cd": 8.0},
	# 마법사 - 속성 다섯을 다 쓴다 (`docs/elements.md` 2절)
	"splash": {"name": "물총", "job": "mage", "lv": 10, "mp": 3, "type": "attack",
		"elem": "water", "mult": 1.8, "range": 72.0, "foe": "wet", "cd": 1.2},
	"flame": {"name": "불꽃", "job": "mage", "lv": 10, "mp": 3, "type": "attack",
		"elem": "fire", "mult": 1.8, "range": 72.0, "foe": "burn", "cd": 1.2},
	"leaf": {"name": "나뭇잎 날리기", "job": "mage", "lv": 12, "mp": 3, "type": "attack",
		"elem": "wood", "mult": 1.8, "range": 72.0, "foe": "tangle", "cd": 1.2},
	"rock": {"name": "돌멩이 던지기", "job": "mage", "lv": 14, "mp": 3, "type": "attack",
		"elem": "earth", "mult": 1.8, "range": 72.0, "grants": "firm", "cd": 1.2},
	"breeze": {"name": "산들바람", "job": "mage", "lv": 16, "mp": 3, "type": "attack",
		"elem": "wind", "mult": 1.8, "range": 72.0, "foe": "sway", "cd": 1.2},
	"rainbow": {"name": "무지개 한 방", "job": "mage", "lv": 22, "mp": 14,
		"type": "attack", "elem": "none", "mult": 2.6, "aoe": 64.0, "cd": 6.0},
	# 궁수 - 멀리서 쏜다
	"double": {"name": "연속 쏘기", "job": "archer", "lv": 10, "mp": 2, "type": "attack",
		"elem": "weapon", "mult": 1.0, "hits": 2, "range": 84.0, "cd": 0.9},
	"pierce": {"name": "꿰뚫기", "job": "archer", "lv": 13, "mp": 5, "type": "attack",
		"elem": "weapon", "mult": 1.7, "range": 96.0, "line": true, "cd": 2.5},
	"leap": {"name": "뒤로 뛰기", "job": "archer", "lv": 16, "mp": 3, "type": "buff",
		"back": true, "grants": "keen", "cd": 5.0},
	"rain": {"name": "화살비", "job": "archer", "lv": 20, "mp": 8, "type": "attack",
		"elem": "weapon", "mult": 1.3, "hits": 2, "aoe": 50.0, "range": 90.0, "cd": 5.0},
	"snipe": {"name": "저격", "job": "archer", "lv": 25, "mp": 10, "type": "attack",
		"elem": "weapon", "mult": 3.4, "range": 120.0, "cd": 7.0},
	# 도적 - 빠른 연타, 급소
	"flurry": {"name": "빠른 찌르기", "job": "thief", "lv": 10, "mp": 2, "type": "attack",
		"elem": "weapon", "mult": 0.7, "hits": 3, "cd": 0.9},
	"star": {"name": "표창 던지기", "job": "thief", "lv": 13, "mp": 3, "type": "attack",
		"elem": "weapon", "mult": 1.1, "hits": 2, "range": 80.0, "cd": 1.5},
	"shadow": {"name": "그림자 걸음", "job": "thief", "lv": 16, "mp": 5, "type": "buff",
		"grants": "keen", "guard": 1.2, "cd": 10.0},
	"vital": {"name": "급소 찌르기", "job": "thief", "lv": 20, "mp": 6, "type": "attack",
		"elem": "weapon", "mult": 2.4, "crit": true, "cd": 5.0},
	"fan": {"name": "표창 부채", "job": "thief", "lv": 25, "mp": 12, "type": "attack",
		"elem": "weapon", "mult": 1.2, "hits": 3, "aoe": 52.0, "cd": 7.0},
}

## 화면에 보여 줄 차례. 딕셔너리는 순서를 믿을 수 없어서 따로 적는다.
const SKILL_ORDER := ["tap", "breathe", "bump",
	"power", "spin", "charge", "iron", "quake",
	"splash", "flame", "leaf", "rock", "breeze", "rainbow",
	"double", "pierce", "leap", "rain", "snipe",
	"flurry", "star", "shadow", "vital", "fan"]
const SKILL_MAX := 10


## 이 직업이 쓸 수 있는 스킬 (레벨은 안 따진다).
static func job_skills(j: String = "") -> Array:
	var jj := j if j != "" else job
	var out: Array = []
	for id in SKILL_ORDER:
		var o := String(SKILLS[id]["job"])
		if o == "*" or o == jj:
			out.append(id)
	return out


## 지금 쓸 수 있는 스킬 (배운 것).
static func skills() -> Array:
	var out: Array = []
	for id in job_skills():
		if int(skill_lv.get(id, 0)) > 0:
			out.append(id)
	return out


## 스킬 칸에 설 것 - 배운 것 중 [공격] 버튼(톡 치기) 말고.
static func slot_skills() -> Array:
	var out: Array = []
	for id in skills():
		if id != "tap":
			out.append(id)
	return out


## 다음에 풀리는 스킬 id. 없으면 "".
static func next_skill() -> String:
	for id in job_skills():
		if int(SKILLS[id]["lv"]) > level:
			return id
	return ""


## 스킬 레벨 한 칸마다 10% 세진다.
static func skill_power(id: String) -> float:
	return 1.0 + 0.1 * float(maxi(1, int(skill_lv.get(id, 1))) - 1)


## 스킬이 치는 속성. "weapon" 이면 든 무기의 것.
static func skill_elem(id: String) -> String:
	var e := String(SKILLS.get(id, {}).get("elem", "none"))
	return Gear.weapon_elem() if e == "weapon" else e


# ── 상태 ─────────────────────────────────────────────────────────────
#
# 싸우는 동안만 붙는다 (저장 안 한다). 시간은 `Field.BEAT` 박자로 센다.
const STATUSES := {
	"warm": {"name": "온기", "turns": 3, "hp_pct": 0.04, "good": true},
	"firm": {"name": "굳건함", "turns": 4, "good": true},
	"keen": {"name": "날카로움", "turns": 2, "good": true},
	"shrink": {"name": "위축", "turns": 3, "good": false},
	"numb": {"name": "먹먹함", "turns": 3, "good": false},
}

## 몬스터에게 거는 것 - 마법사의 속성 스킬이 건다.
const ENEMY_STATUSES := {
	"wet": {"name": "젖음", "turns": 3},                      # 주는 피해 -25%
	"burn": {"name": "화상", "turns": 3, "hp_pct": 0.05},     # 박자마다 깎인다
	"tangle": {"name": "휘감김", "turns": 3},                 # 느려진다
	"sway": {"name": "휘청", "turns": 3},                     # 받는 피해 +30%
	"shake": {"name": "흔들림", "turns": 3},                  # 잘 드는 속성에 맞았다 +30%
}


# ── 몬스터 ───────────────────────────────────────────────────────────
#
# 꿈결의 몬스터. 야근 대마왕의 그림자가 번져 사나워진 꿈속 생물이다.
# 이름은 감정 대신 **생김새**로 짓는다 - 물방울뭉은 물방울처럼 생겼다.
#
# **종마다 몸집(비율)만 적고, 실제 수치는 레벨에서 나온다**(`foe_stats`).
# 같은 물방울뭉이 윤슬에선 LV 2, 하늬섬에선 LV 18 로 선다 - 종 열 가지로
# 구역 아홉을 채우는 방법이다.
#   hp/atk/def  레벨 수치에 곱하는 몸집 · xp 경험 몸집
#   pattern     덤비는 버릇 (`plan_for`) · drop 늘 남기는 먹을 것
const ENEMIES := {
	"drop": {"name": "물방울뭉", "elem": "water", "hp": 0.9, "atk": 0.9, "def": 0.8,
		"xp": 1.0, "sheet": "drop", "drop": "b-barleytea",
		"pattern": {"kind": "multi", "times": 2, "mult": 0.55}, "desc": "톡톡 두 번 튄다"},
	"ember": {"name": "불똥콩", "elem": "fire", "hp": 0.9, "atk": 1.0, "def": 0.9,
		"xp": 1.0, "sheet": "ember", "drop": "b-sikhye",
		"pattern": {"kind": "escalate", "step": 0.18, "cap": 2.0}, "desc": "갈수록 뜨거워진다"},
	"sprout": {"name": "새싹뭉치", "elem": "wood", "hp": 1.0, "atk": 0.9, "def": 1.0,
		"xp": 1.0, "sheet": "sprout", "drop": "b-citron-tea",
		"pattern": {"kind": "inflict", "every": 3, "status": "shrink"}, "desc": "세 번째마다 얽어 위축"},
	"pebble": {"name": "조약돌이", "elem": "earth", "hp": 1.3, "atk": 1.0, "def": 1.5,
		"xp": 1.15, "sheet": "pebble", "drop": "b-sweetpotato",
		"pattern": {"kind": "burst", "rest": 2, "mult": 2.2, "inflict": "numb"},
		"desc": "두 번 쉬고 굴러와 쾅"},
	"gust": {"name": "회오리뭉", "elem": "wind", "hp": 0.8, "atk": 1.0, "def": 0.8,
		"xp": 1.0, "sheet": "gust", "drop": "b-honeycake",
		"pattern": {"kind": "multi", "times": 3, "mult": 0.42}, "desc": "세 번 스친다"},
	"whirl": {"name": "소용돌이", "elem": "water", "hp": 1.1, "atk": 1.0, "def": 1.0,
		"xp": 1.1, "sheet": "whirl", "drop": "b-candy",
		"pattern": {"kind": "reflect", "back": 0.35}, "desc": "맞은 만큼 되받아친다"},
	"thorn": {"name": "가시덩굴", "elem": "wood", "hp": 1.2, "atk": 1.05, "def": 1.2,
		"xp": 1.15, "sheet": "thorn", "drop": "b-citron-tea",
		"pattern": {"kind": "inflict", "every": 3, "status": "shrink"}, "desc": "세 번째마다 옭아맨다"},
	"mole": {"name": "모래두더지", "elem": "earth", "hp": 1.2, "atk": 1.1, "def": 1.3,
		"xp": 1.2, "sheet": "mole", "drop": "b-riceball",
		"pattern": {"kind": "heavy", "every": 3, "mult": 1.9}, "desc": "세 번째마다 크게"},
	"storm": {"name": "돌개바람", "elem": "wind", "hp": 1.0, "atk": 1.15, "def": 1.0,
		"xp": 1.2, "sheet": "storm", "drop": "b-cookie",
		"pattern": {"kind": "escalate", "step": 0.2, "cap": 2.2}, "desc": "갈수록 거세진다"},
	"blaze": {"name": "화르륵", "elem": "fire", "hp": 1.1, "atk": 1.2, "def": 1.0,
		"xp": 1.25, "sheet": "blaze", "drop": "b-yakgwa",
		"pattern": {"kind": "burst", "rest": 2, "mult": 2.3, "inflict": "numb"},
		"desc": "두 번 쉬고 활활"},
	# ── 구역 보스 - 구역마다 하나. 쓰러뜨리면 꿈의 문이 열린다 (`docs/redesign-dream.md` 2절).
	"drop_king": {"name": "물방울 대왕", "elem": "water", "hp": 0.8, "atk": 0.9, "def": 1.0,
		"xp": 1.0, "sheet": "drop_king", "boss": true, "drop": "b-lunchbox",
		"pattern": {"kind": "multi", "times": 3, "mult": 0.6}, "desc": "세 번 연달아 튄다"},
	"dokkaebi": {"name": "불꽃 도깨비", "elem": "fire", "hp": 0.85, "atk": 1.0, "def": 1.0,
		"xp": 1.0, "sheet": "dokkaebi", "boss": true, "drop": "b-lunchbox",
		"pattern": {"kind": "escalate", "step": 0.25, "cap": 2.4}, "desc": "갈수록 불붙는다"},
	"golem": {"name": "바위 거인", "elem": "earth", "hp": 1.1, "atk": 1.0, "def": 1.5,
		"xp": 1.0, "sheet": "golem", "boss": true, "drop": "b-lunchbox",
		"pattern": {"kind": "burst", "rest": 2, "mult": 2.6, "inflict": "numb"},
		"desc": "두 번 쉬고 내리찍는다"},
	"gull": {"name": "태풍 갈매기", "elem": "wind", "hp": 0.8, "atk": 1.05, "def": 0.9,
		"xp": 1.0, "sheet": "gull", "boss": true, "drop": "b-lunchbox",
		"pattern": {"kind": "multi", "times": 4, "mult": 0.45}, "desc": "네 번 휘몰아친다"},
	"carp": {"name": "소용돌이 잉어왕", "elem": "water", "hp": 0.95, "atk": 1.0, "def": 1.1,
		"xp": 1.0, "sheet": "carp", "boss": true, "drop": "b-lunchbox",
		"pattern": {"kind": "reflect", "back": 0.45}, "desc": "맞은 만큼 되받아친다"},
	"lotus": {"name": "연꽃 정령", "elem": "wood", "hp": 0.95, "atk": 1.0, "def": 1.1,
		"xp": 1.0, "sheet": "lotus", "boss": true, "drop": "b-lunchbox",
		"pattern": {"kind": "inflict", "every": 3, "status": "numb"}, "desc": "세 번째마다 먹먹하게"},
	"thorn_queen": {"name": "가시덩굴 여왕", "elem": "wood", "hp": 1.0, "atk": 1.05, "def": 1.2,
		"xp": 1.0, "sheet": "thorn_queen", "boss": true, "drop": "b-lunchbox",
		"pattern": {"kind": "inflict", "every": 3, "status": "shrink"}, "desc": "세 번째마다 옭아맨다"},
	"mole_king": {"name": "산골 두더지왕", "elem": "earth", "hp": 1.05, "atk": 1.1, "def": 1.3,
		"xp": 1.0, "sheet": "mole_king", "boss": true, "drop": "b-lunchbox",
		"pattern": {"kind": "heavy", "every": 3, "mult": 2.2}, "desc": "세 번째마다 땅이 꺼진다"},
	"deer": {"name": "화염 꽃사슴", "elem": "fire", "hp": 1.0, "atk": 1.15, "def": 1.1,
		"xp": 1.0, "sheet": "deer", "boss": true, "drop": "b-lunchbox",
		"pattern": {"kind": "burst", "rest": 2, "mult": 2.6, "inflict": "numb"},
		"desc": "두 번 숨 고르고 활활"},
	# ── 회사 몬스터 - 꿈이 금 간 뒤 꿈속 잿마루 타워에만 선다 (`TOWER_SPAWNS`).
	"paper": {"name": "결재 서류 골렘", "elem": "earth", "hp": 1.2, "atk": 1.05, "def": 1.3,
		"xp": 1.2, "sheet": "paper", "drop": "b-riceball",
		"pattern": {"kind": "heavy", "every": 3, "mult": 2.0}, "desc": "세 번째마다 서류 더미로 짓누른다"},
	"memo": {"name": "회의록 유령", "elem": "wind", "hp": 1.0, "atk": 1.0, "def": 1.0,
		"xp": 1.2, "sheet": "memo", "drop": "b-sikhye",
		"pattern": {"kind": "inflict", "every": 3, "status": "numb"}, "desc": "세 번째마다 회의가 길어진다"},
	"vending": {"name": "커피 자판기 미믹", "elem": "fire", "hp": 1.1, "atk": 1.15, "def": 1.2,
		"xp": 1.25, "sheet": "vending", "drop": "b-candy",
		"pattern": {"kind": "escalate", "step": 0.25, "cap": 2.4}, "desc": "마실수록 뜨거워진다"},
	"bat": {"name": "메신저 박쥐", "elem": "water", "hp": 0.8, "atk": 1.0, "def": 0.9,
		"xp": 1.15, "sheet": "bat", "drop": "b-cookie",
		"pattern": {"kind": "multi", "times": 4, "mult": 0.4}, "desc": "알림이 네 번 연달아 온다"},
	# 끝판 - 떨어진 사람들의 "야근하는 마음" 이 뭉친 것. 꿈속 잿마루 타워 꼭대기.
	"night": {"name": "야근 대마왕", "elem": "dark", "hp": 1.2, "atk": 1.1, "def": 1.3,
		"xp": 1.5, "sheet": "night", "boss": true, "drop": "b-lunchbox",
		"pattern": {"kind": "heavy", "every": 4, "mult": 2.1}, "desc": "네 번째마다 무거운 한 방"},
}

## 구역마다의 보스 (차례대로). 쓰러뜨리면 `JourneyState.quest_flags` 에
## "보스:<구역>" 이 남는다 - 꿈의 문이 열린 표시.
const REGION_BOSS := {
	"윤슬": "drop_king", "볕뉘": "dokkaebi", "가풀재": "golem", "하늬섬": "gull",
	"굽이나루": "carp", "방울못": "lotus", "갈밭머리": "thorn_queen", "솔은재": "mole_king",
	"꽃눈벌": "deer",
}

## 우두머리는 몸집이 다르다.
const BOSS_HP := 10.0
const BOSS_ATK := 1.4
const BOSS_XP := 20.0

## 옛 이름(감정 그늘) → 새 종. 옛 세이브의 조각·퇴치 기록을 옮긴다.
## 옛 밤그늘(꽃눈벌 우두머리)은 그 자리의 새 보스 화염 꽃사슴으로 간다.
const OLD_KINDS := {"worry": "drop", "hurry": "ember", "lonely": "gust",
	"tired": "pebble", "regret": "thorn", "envy": "blaze", "night": "deer"}


## 그 종이 그 레벨일 때의 몸. 레벨 곡선은 **같은 레벨의 사람이 기본
## 공격 네댓 번에 쓰러뜨리고, 아홉 번쯤 맞으면 쓰러지는** 데 맞췄다
## (`docs/redesign-dream.md` 3절).
static func foe_stats(kind: String, lv: int) -> Dictionary:
	var e: Dictionary = ENEMIES.get(kind, ENEMIES["drop"])
	var boss := bool(e.get("boss", false))
	var d := int(round((1.0 + lv / 4.0) * float(e["def"])))
	var hp_v := 4.5 * (3.0 + 5.4 * lv) * _mitigation(d) * float(e["hp"])
	var atk_v := (62.0 + 12.0 * lv) / 9.0 * (1.0 + 2.2 * lv / 100.0) * float(e["atk"])
	var xp_v := (3.0 + 1.1 * pow(float(lv), 1.3)) * float(e["xp"])
	if boss:
		hp_v *= BOSS_HP
		atk_v *= BOSS_ATK
		xp_v *= BOSS_XP
	return {"hp": maxi(1, int(round(hp_v))), "atk": maxi(1, int(round(atk_v))),
		"def": d, "xp": maxi(1, int(round(xp_v)))}


## 구역마다 서는 몬스터 `[종, 레벨]`. **주 속성 하나 + 섞이는 것** -
## 스킬 하나만 연타해서는 안 되고, 몬스터를 보고 고른다.
## 뒷구역일수록 레벨이 높다 (`docs/redesign-dream.md` 2절 표).
##
## 프롤로그(잿마루)와 고향에는 없다 - 거기는 현실이다.
const SPAWNS := {
	"윤슬": [["drop", 2], ["drop", 3], ["drop", 5], ["ember", 7], ["drop_king", 8]],
	"볕뉘": [["ember", 10], ["ember", 11], ["drop", 9], ["sprout", 12], ["dokkaebi", 13]],
	"가풀재": [["pebble", 14], ["pebble", 15], ["sprout", 13], ["ember", 16], ["golem", 17]],
	"하늬섬": [["gust", 18], ["gust", 19], ["pebble", 17], ["drop", 18], ["sprout", 20],
		["gull", 21]],
	"굽이나루": [["whirl", 22], ["whirl", 23], ["sprout", 21], ["gust", 24], ["carp", 25]],
	"방울못": [["thorn", 26], ["thorn", 27], ["whirl", 25], ["pebble", 28], ["lotus", 29]],
	"갈밭머리": [["thorn", 30], ["mole", 31], ["mole", 32], ["gust", 29], ["thorn_queen", 33]],
	"솔은재": [["storm", 34], ["storm", 35], ["mole", 33], ["thorn", 36], ["whirl", 34],
		["mole_king", 37]],
	"꽃눈벌": [["blaze", 38], ["blaze", 40], ["storm", 39], ["deer", 42]],
}

## 꿈이 금 간 뒤의 꿈속 잿마루 타워 (`docs/redesign-dream.md` 2절 "전·결").
## 현실의 회사가 거꾸로 선 곳 - 회사 몬스터들과 꼭대기의 야근 대마왕.
## `SPAWNS` 에 안 넣는다: 잿마루는 프롤로그(현실)라 평소엔 싸움이 없다.
const TOWER_SPAWNS := [["paper", 44], ["memo", 45], ["vending", 46], ["bat", 45],
	["paper", 47], ["night", 50]]


static func tower_spawns() -> Array:
	var out: Array = []
	for i in 4:
		for k in TOWER_SPAWNS:
			var boss := bool(ENEMIES[String(k[0])].get("boss", false))
			if i > 0 and boss:
				continue
			out.append([String(k[0]), int(k[1]) + (0 if boss else (i % 3) - 1)])
	return out


## 그 구역의 보스를 쓰러뜨렸나 - 꿈의 문이 열렸나.
static func boss_down(village: String) -> bool:
	return JourneyState.quest_done("보스:" + village)


## **여섯 배.** 표는 구역마다의 비율로 두고 실제로 서는 수는 여기서 곱한다.
## 우두머리는 곱하지 않는다.
const SPAWN_MULT := 6


## 그 구역에 실제로 서는 몬스터들 `[종, 레벨]`. 되풀이할 때마다 레벨을
## 조금씩 흔든다(-1, 0, +1) - 한 무리가 다 같은 레벨이면 밋밋하다.
##
## **우두머리는 마을에 안 선다.** 마을 한쪽의 "우두머리의 길"
## (`BossRoad`, 졸개들)을 지나 "우두머리 방"(`BossLair`)에서 기다린다.
## 마을 한가운데 서 있으면 지나가다 건드려 버리고, 만나러 가는 맛이 없다.
static func spawns(village: String) -> Array:
	var base: Array = SPAWNS.get(village, [])
	var out: Array = []
	for i in SPAWN_MULT:
		for k in base:
			var kind := String(k[0])
			if bool(ENEMIES.get(kind, {}).get("boss", false)):
				continue
			out.append([kind, clampi(int(k[1]) + (i % 3) - 1, 1, LEVEL_MAX)])
	return out


## 그 구역의 우두머리 종 ("" 이면 없다).
static func boss_of(village: String) -> String:
	return String(REGION_BOSS.get(village, ""))


## 그 구역 우두머리의 레벨 (`SPAWNS` 에 적힌 것).
static func boss_lv(village: String) -> int:
	var b := boss_of(village)
	for k in SPAWNS.get(village, []):
		if String(k[0]) == b:
			return int(k[1])
	return 1


## 우두머리의 길에 서는 졸개 수. 마을보다 적고 조금 세다 - 한 번에 훑고 지나가는 길이다.
const ROAD_COUNT := 10


## 우두머리의 길(`BossRoad`)의 졸개들 `[종, 레벨]`. 그 구역 몬스터가
## 마을보다 한두 레벨 높게 선다 - 우두머리 앞이라 기가 올라 있다.
static func road_spawns(village: String) -> Array:
	var kinds: Array = []
	var top := 1
	for k in SPAWNS.get(village, []):
		if bool(ENEMIES.get(String(k[0]), {}).get("boss", false)):
			continue
		kinds.append(String(k[0]))
		top = maxi(top, int(k[1]))
	if kinds.is_empty():
		return []
	var out: Array = []
	for i in ROAD_COUNT:
		out.append([String(kinds[i % kinds.size()]), clampi(top - 1 + i % 3, 1, LEVEL_MAX)])
	return out


## 우두머리 방(`BossLair`) - 우두머리 하나와 곁을 지키는 졸개 둘.
static func lair_spawns(village: String) -> Array:
	var b := boss_of(village)
	if b == "":
		return []
	var road := road_spawns(village)
	var out: Array = [[b, boss_lv(village)]]
	for i in mini(2, road.size()):
		out.append([String(road[i][0]), int(road[i][1]) + 1])
	return out


## 그 구역에 서는 종들 (차례대로, 겹치지 않게).
static func kinds_in(village: String) -> Array:
	var out: Array = []
	for k in SPAWNS.get(village, []):
		if not out.has(String(k[0])):
			out.append(String(k[0]))
	return out


# ── 손에 쥐고 쓰는 것 ────────────────────────────────────────────────
#
# 주운 것 몇몇은 먹거나 쥐어 볼 수 있다. 퀘스트가 쓰는 것(바다유리·미역·
# 소라)은 여기 안 넣는다 - 써 버리면 매듭이 막힌다.
const FOODS := {
	"p-persimmon": {"hp": 30, "verb": "먹었다"},
	"p-tangerine": {"hp": 24, "verb": "까 먹었다"},
	"p-mushroom": {"hp": 18, "verb": "먹었다"},
	"p-flower": {"mp": 10, "verb": "들여다봤다"},
	"p-reed-plume": {"mp": 8, "verb": "들여다봤다"},
	"p-feather": {"mp": 7, "verb": "쓸어 봤다"},
	"p-pebble": {"hp": 10, "verb": "쥐어 봤다"},
	"p-acorn": {"hp": 12, "verb": "쥐어 봤다"},
	"p-pinecone": {"hp": 14, "verb": "쥐어 봤다"},
	"p-citrus-leaf": {"mp": 5, "verb": "코에 대 봤다"},
	"p-persimmon-leaf": {"mp": 5, "verb": "코에 대 봤다"},
	"p-pine-needle": {"mp": 6, "verb": "코에 대 봤다"},
	"p-reed-leaf": {"hp": 8, "verb": "만지작거렸다"},
	"p-shell": {"hp": 8, "verb": "귀에 대 봤다"},
}


## 먹으면 무엇이 되나. 주운 것은 `FOODS`, 받은 먹을 것은 `Catalog` 에 적혀 있다.
static func food_effect(id: String) -> Dictionary:
	if FOODS.has(id):
		return FOODS[id]
	return Catalog.of(id)


## 먹을 것의 숫자는 **LV 1 기준**으로 적혀 있다. 레벨이 오르면 체력이
## 열 배 넘게 불어나 "체력 +30" 이 티도 안 나므로, 가득 찬 양에 맞춰 늘린다.
static func food_hp(v: int) -> int:
	return int(round(float(v) * float(hp_max()) / 58.0))


static func food_mp(v: int) -> int:
	return int(round(float(v) * float(mp_max()) / 26.0))


## 배낭 설명 판의 [먹기]가 부른다 (싸우는 중에도 - 배낭을 열면 몬스터가 멈춘다).
## 다 차 있으면 안 먹는다. 먹은 뒤 한 줄을 돌려준다 (빈 문자열이면 못 먹은 것).
static func eat(id: String) -> String:
	if not Catalog.edible(id) or JourneyState.count(id) <= 0:
		return ""
	var f := food_effect(id)
	var full := bool(f.get("full", false))
	var need_hp := hp < hp_max() and (full or int(f.get("hp", 0)) > 0)
	var need_mp := mp < mp_max() and (full or int(f.get("mp", 0)) > 0)
	# **풀기**(유자차·매실차·솔잎차)는 나쁜 상태가 걸려 있으면 배가
	# 불러도 먹는다 - 위축·먹먹함을 푸는 길이 이것뿐이다.
	var bad := false
	for st in Field.my_status.keys():
		if not bool(STATUSES.get(st, {}).get("good", false)):
			bad = true
	var need_cure := bad and bool(f.get("cure", false))
	if not need_hp and not need_mp and not need_cure:
		return ""
	JourneyState.use(id)
	var hp0 := hp
	var mp0 := mp
	if full:
		hp = hp_max()
		mp = mp_max()
	else:
		hp = mini(hp_max(), hp + food_hp(int(f.get("hp", 0))))
		mp = mini(mp_max(), mp + food_mp(int(f.get("mp", 0))))
	var parts: Array = []
	if hp > hp0:
		parts.append("체력 +%d" % (hp - hp0))
	if mp > mp0:
		parts.append("마음력 +%d" % (mp - mp0))
	if need_cure:
		for st in Field.my_status.keys():
			if not bool(STATUSES.get(st, {}).get("good", false)):
				Field.my_status.erase(st)
		parts.append("마음이 풀렸다")
	# **온기**(꿀떡·군밤)는 먹은 뒤로 한동안 체력이 조금씩 찬다.
	if bool(f.get("warm", false)):
		Field.my_status["warm"] = float(STATUSES["warm"]["turns"]) * Field.BEAT
		parts.append("온기")
	return "%s, %s" % [Catalog.name_of(id), " · ".join(parts)]


## 몬스터가 `t` 번째로 덤빌 때 무엇을 하나.
##
## **무작위가 아니라 몇 번째인지로만 정한다.** 그래야 머리 위 예고
## (`Field.foe_intent`)와 실제가 어긋날 수 없다. `dealt` 는 지난번 덤빈
## 뒤로 맞은 피해의 합(소용돌이가 되받아친다).
static func plan_for(kind: String, t: int, dealt: int) -> Dictionary:
	var p: Dictionary = ENEMIES.get(kind, {}).get("pattern", {})
	match String(p.get("kind", "")):
		"multi":
			return {"act": "attack", "times": int(p.get("times", 2)),
				"mult": float(p.get("mult", 0.55))}
		"escalate":
			var m: float = minf(1.0 + float(p.get("step", 0.18)) * float(t - 1),
				float(p.get("cap", 2.2)))
			return {"act": "attack", "times": 1, "mult": m}
		"burst":
			var rest := int(p.get("rest", 2))
			if t % (rest + 1) != 0:
				return {"act": "rest"}
			return {"act": "attack", "times": 1, "mult": float(p.get("mult", 2.0)),
				"inflict": String(p.get("inflict", ""))}
		"inflict":
			if t % int(p.get("every", 3)) == 0:
				return {"act": "inflict", "status": String(p.get("status", "shrink"))}
			return {"act": "attack", "times": 1, "mult": 1.0}
		"reflect":
			if dealt > 0:
				return {"act": "reflect", "back": float(p.get("back", 0.35))}
			return {"act": "attack", "times": 1, "mult": 1.0}
		"heavy":
			if t % int(p.get("every", 4)) == 0:
				return {"act": "attack", "times": 1, "mult": float(p.get("mult", 2.1))}
			return {"act": "attack", "times": 1, "mult": 1.0}
	return {"act": "attack", "times": 1, "mult": 1.0}


# ── 자란다 ───────────────────────────────────────────────────────────

## 경험을 얻는다. 싸워도, 할 일을 마쳐도(`Rewards`) 같은 길로 온다.
## 레벨이 오른 만큼 `level_up` 사건을 돌려준다 (새로 배운 스킬 이름과 함께).
static func gain_xp(got: int) -> Array:
	var evs: Array = []
	if level >= LEVEL_MAX:
		return evs
	xp += maxi(0, got)
	while level < LEVEL_MAX and xp >= xp_need():
		xp -= xp_need()
		level += 1
		ap += AP_PER
		sp += SP_PER
		if auto_ap:
			auto_spend_ap()
		var learned := _learn_new()
		if auto_sp:
			auto_spend_sp()
		# 레벨이 오르면 그 자리에서 몸도 마음도 가득 찬다.
		hp = hp_max()
		mp = mp_max()
		var names: Array = []
		for id in learned:
			names.append(String(SKILLS[id]["name"]))
		evs.append({"kind": "level_up", "level": level, "skill": ", ".join(names),
			"job_ready": level == JOB_LV and job == "novice"})
	if level >= LEVEL_MAX:
		xp = 0
	return evs


## 레벨이 닿은 스킬을 1 레벨로 배운다. 새로 배운 것을 돌려준다.
static func _learn_new() -> Array:
	var out: Array = []
	for id in job_skills():
		if int(SKILLS[id]["lv"]) <= level and int(skill_lv.get(id, 0)) <= 0:
			skill_lv[id] = 1
			out.append(id)
	return out


## 능력치 점수를 직업 비율대로 나눈다 - 비율에서 가장 모자란 것부터 하나씩.
static func auto_spend_ap() -> void:
	var ratio: Dictionary = JOBS.get(job, JOBS["novice"])["auto"]
	var total := 0
	for s in ratio:
		total += int(ratio[s])
	while ap > 0:
		var best := ""
		var best_gap := -INF
		var got := 0
		for s in ratio:
			got += int(stats[s]) - 4
		for s in ratio:
			var want := float(ratio[s]) / float(total) * float(got + 1)
			var gap := want - float(int(stats[s]) - 4)
			if gap > best_gap:
				best_gap = gap
				best = s
		stats[best] = int(stats[best]) + 1
		ap -= 1


static func _stat_sum() -> int:
	var n := 0
	for s in stats:
		n += int(stats[s])
	return n


## 스킬 점수를 알아서 쓴다 - 공격 스킬 중 레벨이 가장 낮은 것부터.
static func auto_spend_sp() -> void:
	while sp > 0:
		var best := ""
		var best_lv := SKILL_MAX
		for id in skills():
			var l := int(skill_lv[id])
			if l < best_lv and String(SKILLS[id]["type"]) == "attack":
				best_lv = l
				best = id
		if best == "":
			for id in skills():
				if int(skill_lv[id]) < SKILL_MAX:
					best = id
					break
		if best == "":
			return
		skill_lv[best] = int(skill_lv[best]) + 1
		sp -= 1


static func spend_ap(s: String) -> bool:
	if ap <= 0 or not stats.has(s):
		return false
	stats[s] = int(stats[s]) + 1
	ap -= 1
	return true


static func spend_sp(id: String) -> bool:
	if sp <= 0 or int(skill_lv.get(id, 0)) <= 0 or int(skill_lv[id]) >= SKILL_MAX:
		return false
	skill_lv[id] = int(skill_lv[id]) + 1
	sp -= 1
	return true


## 능력치를 처음으로 되돌린다 (초기화 물약). 점수는 돌려준다.
static func reset_stats() -> void:
	var spent := _stat_sum() - 16
	stats = {"str": 4, "dex": 4, "int": 4, "luk": 4}
	ap += maxi(0, spent)
	hp = mini(hp, hp_max())
	mp = mini(mp, mp_max())


## 전직. LV 10 이상 꿈나그네만. 그 직업의 스킬을 배우고 무기를 하나 받는다.
## 전직하면 능력치를 그 직업에 맞게 다시 나눈다 (꿈나그네 때 나눈 것은 돌려받는다).
static func set_job(j: String) -> bool:
	if not JOBS.has(j) or j == "novice" or job != "novice" or level < JOB_LV:
		return false
	job = j
	if auto_ap:
		reset_stats()
		auto_spend_ap()
	_learn_new()
	if auto_sp:
		auto_spend_sp()
	Gear.starter_weapon(j)
	hp = hp_max()
	mp = mp_max()
	return true


static func job_name() -> String:
	return String(JOBS.get(job, JOBS["novice"])["name"])


# ── 저장 ─────────────────────────────────────────────────────────────

static func to_dict() -> Dictionary:
	return {
		"level": level, "xp": xp, "hp": hp, "mp": mp,
		"job": job, "stats": stats.duplicate(), "ap": ap, "sp": sp,
		"skill_lv": skill_lv.duplicate(), "auto_ap": auto_ap, "auto_sp": auto_sp,
		"cleared": cleared.duplicate(), "cleared_day": cleared_day, "v": 3,
	}


static func from_dict(d: Dictionary) -> void:
	level = clampi(int(d.get("level", 1)), 1, LEVEL_MAX)
	xp = maxi(0, int(d.get("xp", 0)))
	job = String(d.get("job", "novice"))
	if not JOBS.has(job):
		job = "novice"
	stats = {"str": 4, "dex": 4, "int": 4, "luk": 4}
	var st = d.get("stats")
	if st is Dictionary:
		for s in stats:
			stats[s] = maxi(4, int(st.get(s, 4)))
	ap = maxi(0, int(d.get("ap", 0)))
	sp = maxi(0, int(d.get("sp", 0)))
	auto_ap = bool(d.get("auto_ap", true))
	auto_sp = bool(d.get("auto_sp", true))
	skill_lv = {}
	var sl = d.get("skill_lv")
	if sl is Dictionary:
		for id in sl:
			if SKILLS.has(String(id)):
				skill_lv[String(id)] = clampi(int(sl[id]), 1, SKILL_MAX)
	# **옛 세이브**(레벨 하나로만 크던 때, `v` 없음)는 그 레벨까지 받았을
	# 점수를 한꺼번에 준다 - 레벨은 그대로, 능력치·스킬만 새로 채운다.
	var old := int(d.get("v", 1)) < 2
	if old:
		ap = AP_PER * (level - 1)
		sp = SP_PER * (level - 1)
		auto_spend_ap()
	_learn_new()
	if old:
		auto_spend_sp()
	hp = clampi(int(d.get("hp", hp_max())), 1, hp_max())
	mp = clampi(int(d.get("mp", mp_max())), 0, mp_max())
	cleared = d.get("cleared", {}).duplicate() if d.get("cleared") is Dictionary else {}
	cleared_day = int(d.get("cleared_day", 0))


static func reset() -> void:
	level = 1
	xp = 0
	job = "novice"
	stats = {"str": 4, "dex": 4, "int": 4, "luk": 4}
	ap = 0
	sp = 0
	skill_lv = {}
	auto_ap = true
	auto_sp = true
	cleared = {}
	cleared_day = 0
	Field.reset()
	Gear.reset()
	Gear.starter_stick()
	_learn_new()
	hp = hp_max()
	mp = mp_max()


# ── 걷어낸 자리 기억 ─────────────────────────────────────────────────
#
# 쓰러뜨린 몬스터는 그날 하루 안 선다. 날이 바뀌면 다시 선다.
static func clear_key(place: String, t: Vector2i) -> String:
	return "%s:%d,%d" % [place, t.x, t.y]


static func is_cleared(place: String, t: Vector2i) -> bool:
	_check_day()
	return bool(cleared.get(clear_key(place, t), false))


static func mark_cleared(place: String, t: Vector2i) -> void:
	_check_day()
	cleared[clear_key(place, t)] = true


static func _check_day() -> void:
	if cleared_day != JourneyState.day:
		cleared_day = JourneyState.day
		cleared = {}


## 잠자리에서 하루를 마치면 몸과 마음이 돌아온다.
static func rest_full() -> void:
	hp = hp_max()
	mp = mp_max()
