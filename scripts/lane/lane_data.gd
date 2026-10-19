class_name LaneData
extends RefCounted
## 쿼카 군단 (세로 한 줄 전투) 의 표와 공식. 숫자는 여기 한 곳에만 둔다 (`docs/redesign-lane.md`).
## 규칙만 냥코대전쟁에서 빌려 왔다 - 이름·그림은 우리 것.
##
## 길은 한 줄이다. 0 = 우리 성(화면 아래), LEN = 벌레 둥지(화면 위). 쿼카는 + 로, 벌레는 - 로 걷는다.

const LEN := 3000.0

# ── 쿼카 군단 ────────────────────────────────────────────────────────
## cost 꿈빛 · cd 다시 낼 때까지(초) · hp · atk · every 공격 간격 · range 사거리 · speed 걸음(길/초)
## kb 넉백 횟수(체력이 이만큼 나뉘어 깎일 때마다 튕긴다) · area 범위 공격 · role 화면 설명
## unlock: 이 스테이지를 깨면 생긴다 (0 = 처음부터)
const UNITS := {
	"tiny":   {"name": "꼬마 쿼카", "role": "싸고 빨리 나오는 벽", "cost": 50, "cd": 2.3, "hp": 100, "atk": 8,
		"every": 1.2, "range": 140, "speed": 120, "kb": 3, "area": false, "unlock": 0, "wall": true},
	"shield": {"name": "방패 쿼카", "role": "튼튼한 벽", "cost": 100, "cd": 4.5, "hp": 420, "atk": 3,
		"every": 2.0, "range": 110, "speed": 96, "kb": 1, "area": false, "unlock": 0, "wall": true},
	"spear":  {"name": "창 쿼카", "role": "앞에서 세게 찌른다", "cost": 200, "cd": 5.0, "hp": 200, "atk": 52,
		"every": 1.0, "range": 150, "speed": 120, "kb": 3, "area": false, "unlock": 2},
	"hammer": {"name": "망치 쿼카", "role": "붙은 벌레를 한꺼번에", "cost": 300, "cd": 8.0, "hp": 420, "atk": 70,
		"every": 2.4, "range": 160, "speed": 90, "kb": 3, "area": true, "unlock": 4},
	"runner": {"name": "날쌘 쿼카", "role": "빨리 달려가 원거리를 친다", "cost": 400, "cd": 8.0, "hp": 260, "atk": 64,
		"every": 1.4, "range": 140, "speed": 300, "kb": 3, "area": false, "unlock": 6},
	"sling":  {"name": "새총 쿼카", "role": "멀리서 쏜다", "cost": 500, "cd": 10.0, "hp": 340, "atk": 160,
		"every": 2.6, "range": 350, "speed": 96, "kb": 3, "area": true, "unlock": 11},
	"mage":   {"name": "마법 쿼카", "role": "아주 멀리서 넓게, 날벌레를 느리게", "cost": 750, "cd": 14.0, "hp": 300,
		"atk": 230, "every": 3.2, "range": 460, "speed": 90, "kb": 2, "area": true, "unlock": 21,
		"slow": {"trait": "fly", "chance": 0.3, "secs": 3.0}},
	"giant":  {"name": "거대 쿼카", "role": "느리지만 안 밀린다", "cost": 1200, "cd": 25.0, "hp": 2600, "atk": 320,
		"every": 4.0, "range": 200, "speed": 60, "kb": 1, "area": true, "unlock": 31, "no_kb": true},
	# ── 뽑기로 만나는 동물 친구 (unlock -1). strong 그 벌레에게 1.5배로 때리고 반만 맞는다 ·
	# massive 그 벌레에게 2.5배 · crit 치명타 확률(2배) · kb_hit 맞힌 벌레를 밀어낼 확률 · slow trait "all" = 모두
	"chick":    {"name": "삐약 병아리", "role": "싸고 빨리 나오는 작은 벽", "rarity": "rare", "cost": 60, "cd": 2.4,
		"hp": 110, "atk": 8, "every": 1.1, "range": 130, "speed": 130, "kb": 3, "area": false, "unlock": -1, "wall": true},
	"hedgehog": {"name": "가시 고슴도치", "role": "기어다니는 벌레에 강한 벽", "rarity": "rare", "cost": 150, "cd": 5.4,
		"hp": 450, "atk": 9, "every": 1.6, "range": 110, "speed": 90, "kb": 1, "area": false, "unlock": -1, "wall": true,
		"strong": ["crawl"]},
	"squirrel": {"name": "도토리 다람쥐", "role": "멀리서 도토리를 던진다", "rarity": "rare", "cost": 350, "cd": 9.6,
		"hp": 180, "atk": 70, "every": 2.2, "range": 320, "speed": 110, "kb": 3, "area": true, "unlock": -1},
	"frog":     {"name": "혀 개구리", "role": "날벌레에 강하다", "rarity": "rare", "cost": 300, "cd": 8.4,
		"hp": 280, "atk": 60, "every": 1.2, "range": 220, "speed": 100, "kb": 3, "area": false, "unlock": -1,
		"strong": ["fly"]},
	"rabbit":   {"name": "깡충 토끼", "role": "엄청 빠르고, 맞히면 가끔 밀어낸다", "rarity": "rare", "cost": 250, "cd": 6.0,
		"hp": 200, "atk": 50, "every": 0.9, "range": 140, "speed": 320, "kb": 3, "area": false, "unlock": -1,
		"kb_hit": 0.25},
	"duck":     {"name": "수병 오리", "role": "독벌레에 강하다", "rarity": "rare", "cost": 350, "cd": 8.4,
		"hp": 390, "atk": 70, "every": 1.6, "range": 170, "speed": 100, "kb": 3, "area": false, "unlock": -1,
		"strong": ["poison"]},
	"mole":     {"name": "광부 두더지", "role": "껍질 벌레에 강하다", "rarity": "rare", "cost": 400, "cd": 9.6,
		"hp": 450, "atk": 90, "every": 2.0, "range": 150, "speed": 90, "kb": 2, "area": false, "unlock": -1,
		"strong": ["shell"]},
	"sheep":    {"name": "몽글 양", "role": "푹신한 벽, 독에 강하다", "rarity": "rare", "cost": 250, "cd": 7.2,
		"hp": 680, "atk": 15, "every": 2.0, "range": 120, "speed": 80, "kb": 2, "area": false, "unlock": -1, "wall": true,
		"strong": ["poison"]},
	"turtle":   {"name": "든든 거북이", "role": "아주 튼튼한 벽, 껍질 벌레에 강하다", "rarity": "super", "cost": 300, "cd": 10.8,
		"hp": 1620, "atk": 20, "every": 2.2, "range": 120, "speed": 60, "kb": 1, "area": false, "unlock": -1, "wall": true,
		"strong": ["shell"]},
	"penguin":  {"name": "썰매 펭귄", "role": "미끄러져 달려가 벌레를 얼린다(느리게)", "rarity": "super", "cost": 500, "cd": 10.8,
		"hp": 340, "atk": 80, "every": 1.4, "range": 160, "speed": 260, "kb": 3, "area": false, "unlock": -1,
		"slow": {"trait": "all", "chance": 0.35, "secs": 3.0}},
	"owl":      {"name": "박사 부엉이", "role": "아주 멀리서 넓게, 날벌레에 굉장히 강하다", "rarity": "super", "cost": 800, "cd": 18.0,
		"hp": 270, "atk": 200, "every": 3.0, "range": 520, "speed": 90, "kb": 2, "area": true, "unlock": -1,
		"massive": ["fly"]},
	"panda":    {"name": "대나무 판다", "role": "튼튼하고 넓게 때린다, 기어다니는 벌레에 강하다", "rarity": "super", "cost": 900,
		"cd": 19.2, "hp": 1480, "atk": 180, "every": 2.6, "range": 190, "speed": 70, "kb": 2, "area": true, "unlock": -1,
		"strong": ["crawl"]},
	"otter":    {"name": "조개 수달", "role": "물보라로 넓게, 독벌레에 굉장히 강하다", "rarity": "super", "cost": 600, "cd": 13.2,
		"hp": 470, "atk": 130, "every": 2.0, "range": 280, "speed": 110, "kb": 3, "area": true, "unlock": -1,
		"massive": ["poison"]},
	"tiger":    {"name": "번개 호랑이", "role": "껍질을 부순다, 치명타", "rarity": "legend", "cost": 1800, "cd": 36.0,
		"hp": 1920, "atk": 360, "every": 1.8, "range": 200, "speed": 180, "kb": 2, "area": true, "unlock": -1,
		"massive": ["shell"], "crit": 0.25},
	"polar":    {"name": "눈보라 북극곰", "role": "안 밀리고, 모두를 얼린다", "rarity": "legend", "cost": 2150, "cd": 42.0,
		"hp": 3600, "atk": 300, "every": 3.0, "range": 230, "speed": 70, "kb": 1, "area": true, "unlock": -1,
		"no_kb": true, "slow": {"trait": "all", "chance": 0.3, "secs": 3.0}},
	"eagle":    {"name": "하늘 독수리", "role": "가장 멀리서, 날벌레를 떨어뜨린다, 치명타", "rarity": "legend", "cost": 1900,
		"cd": 36.0, "hp": 720, "atk": 310, "every": 2.4, "range": 650, "speed": 160, "kb": 2, "area": true, "unlock": -1,
		"massive": ["fly"], "crit": 0.25},
}
## 이 레벨에 닿으면 모습이 바뀐다 (금빛 띠 + 빨간 망토).
const EVOLVE_LV := 10
const EVOLVED_NAME := {"tiny": "용감한 꼬마 쿼카", "shield": "철벽 쿼카", "spear": "번개창 쿼카",
	"hammer": "대장장이 쿼카", "runner": "질풍 쿼카", "sling": "명사수 쿼카", "mage": "대마법 쿼카", "giant": "산만한 쿼카",
	"chick": "꼬꼬 대장", "hedgehog": "강철가시 고슴도치", "squirrel": "황금도토리 다람쥐", "frog": "개굴 왕자",
	"rabbit": "번개발 토끼", "duck": "선장 오리", "mole": "보석 두더지", "sheep": "구름 양", "turtle": "산호 거북이",
	"penguin": "빙하 펭귄", "owl": "현자 부엉이", "panda": "쿵푸 판다", "otter": "진주 수달", "tiger": "천둥 호랑이",
	"polar": "오로라 북극곰", "eagle": "태양 독수리"}


## 레벨에 맞는 이름.
static func unit_name(id: String, lv: int) -> String:
	if lv >= EVOLVE_LV and EVOLVED_NAME.has(id):
		return String(EVOLVED_NAME[id])
	return String(UNITS[id]["name"])


const UNIT_ORDER := ["tiny", "shield", "spear", "hammer", "runner", "sling", "mage", "giant"]
const ANIMAL_ORDER := ["chick", "hedgehog", "squirrel", "frog", "rabbit", "duck", "mole", "sheep",
	"turtle", "penguin", "owl", "panda", "otter", "tiger", "polar", "eagle"]
const ALL_ORDER := UNIT_ORDER + ANIMAL_ORDER
const RARITY_NAME := {"base": "기본", "rare": "희귀", "super": "특급", "legend": "전설"}
const RARITY_STARS := {"base": 0, "rare": 1, "super": 2, "legend": 3}


static func rarity(id: String) -> String:
	return String(UNITS[id].get("rarity", "base"))


## 그림 시트 - 쿼카는 quokka-, 동물 친구는 animal-, 레벨 10 부터 진화한 모습(-2).
static func sheet_path(id: String, lv: int) -> String:
	var pre := "quokka" if rarity(id) == "base" else "animal"
	return "res://assets/sprites/%s-%s%s.png" % [pre, id, "-2" if lv >= EVOLVE_LV else ""]


## 이 유닛이 벽(앞에서 막는 역할) 인가 - 자동 소환이 벽부터 깐다.
static func is_wall(id: String) -> bool:
	return bool(UNITS[id].get("wall", false))


## 특성 한 줄 ("날벌레에 강함 · 치명타 25%") - 카드·뽑기 결과에 쓴다.
static func trait_text(id: String) -> String:
	var u: Dictionary = UNITS[id]
	var out: Array = []
	for t in u.get("strong", []):
		out.append("%s에 강함" % String(TRAIT_NAME[t]))
	for t in u.get("massive", []):
		out.append("%s에 굉장히 강함" % String(TRAIT_NAME[t]))
	if u.has("slow"):
		var tr := String(u["slow"]["trait"])
		out.append("%s 느리게" % ("모두" if tr == "all" else String(TRAIT_NAME[tr])))
	if u.has("crit"):
		out.append("치명타 %d%%" % int(round(float(u["crit"]) * 100.0)))
	if u.has("kb_hit"):
		out.append("밀어내기 %d%%" % int(round(float(u["kb_hit"]) * 100.0)))
	if bool(u.get("no_kb", false)):
		out.append("안 밀림")
	return " · ".join(out)


# ── 뽑기 (꿈 캡슐) ─ 꿈별·무료 티켓만 쓴다. 진짜 돈은 없다.
const GACHA_COST := 100
const GACHA10_COST := 900          ## 10번 - 마지막 하나는 특급 이상
const GACHA_RATES := {"rare": 0.72, "super": 0.24, "legend": 0.04}
const PITY_LEGEND := 60            ## 이만큼 뽑는 동안 전설이 없으면 다음은 전설
const STRONG_MULT := 1.5
const STRONG_TAKEN := 0.5
const MASSIVE_MULT := 2.5
const CRIT_MULT := 2.0


## 이미 가진 동물이 또 나오면: 레벨 +1 (최고면 꿈조각으로).
static func dupe_xp(id: String) -> int:
	return 1500 + 1500 * int(RARITY_STARS[rarity(id)])


## 매일 선물 - 7일째는 크게.
static func daily_gift(streak: int) -> Dictionary:
	if streak % 7 == 0:
		return {"tickets": 3, "stars": 100}
	return {"tickets": 1, "stars": 30}
const LINEUP_MAX := 10

## 레벨 (꿈조각으로 올린다). 한 레벨마다 기본값의 20% 씩 (냥코와 같다).
const UNIT_LV_MAX := 20
const UNIT_LV_STEP := 0.2


static func unit_mult(lv: int) -> float:
	return 1.0 + UNIT_LV_STEP * float(maxi(1, lv) - 1)


## 다음 레벨까지 꿈조각.
static func level_cost(id: String, lv: int) -> int:
	var base := float(UNITS[id]["cost"]) * 1.2 + 80.0
	return int(round(base * pow(float(lv), 1.45)))


# ── 벌레 (악당) ──────────────────────────────────────────────────────
## trait: crawl 기어다님 · fly 날벌레 · shell 껍질 · poison 독. reward = 잡으면 꿈빛.
const BUGS := {
	"ant":        {"name": "개미", "trait": "crawl", "hp": 100, "atk": 8, "every": 1.3, "range": 110, "speed": 100, "kb": 3, "area": false, "reward": 30},
	"caterpillar":{"name": "애벌레", "trait": "crawl", "hp": 320, "atk": 14, "every": 2.0, "range": 110, "speed": 60, "kb": 2, "area": false, "reward": 60},
	"mosquito":   {"name": "모기", "trait": "fly", "hp": 120, "atk": 18, "every": 1.0, "range": 120, "speed": 180, "kb": 3, "area": false, "reward": 45},
	"fly":        {"name": "파리", "trait": "fly", "hp": 180, "atk": 20, "every": 0.9, "range": 120, "speed": 220, "kb": 3, "area": false, "reward": 55},
	"bee":        {"name": "꿀벌", "trait": "fly", "hp": 300, "atk": 45, "every": 1.5, "range": 130, "speed": 150, "kb": 3, "area": false, "reward": 80},
	"ladybug":    {"name": "무당벌레", "trait": "shell", "hp": 800, "atk": 30, "every": 2.0, "range": 120, "speed": 80, "kb": 2, "area": false, "reward": 110},
	"termite":    {"name": "흰개미", "trait": "crawl", "hp": 600, "atk": 60, "every": 1.0, "range": 110, "speed": 130, "kb": 3, "area": false, "reward": 100},
	"cricket":    {"name": "귀뚜라미", "trait": "crawl", "hp": 800, "atk": 90, "every": 1.6, "range": 130, "speed": 160, "kb": 3, "area": false, "reward": 130},
	"moth":       {"name": "나방", "trait": "fly", "hp": 560, "atk": 46, "every": 2.2, "range": 210, "speed": 110, "kb": 3, "area": true, "reward": 140},
	"spider":     {"name": "거미", "trait": "poison", "hp": 800, "atk": 60, "every": 2.2, "range": 260, "speed": 70, "kb": 2, "area": false, "reward": 160},
	"centipede":  {"name": "지네", "trait": "poison", "hp": 1200, "atk": 60, "every": 0.8, "range": 140, "speed": 140, "kb": 3, "area": false, "reward": 170},
	"stag":       {"name": "사슴벌레", "trait": "shell", "hp": 1200, "atk": 90, "every": 2.5, "range": 160, "speed": 70, "kb": 2, "area": true, "reward": 200},
	"wasp":       {"name": "말벌", "trait": "fly", "hp": 800, "atk": 90, "every": 1.5, "range": 150, "speed": 200, "kb": 3, "area": false, "reward": 210},
	"pillbug":    {"name": "공벌레", "trait": "shell", "hp": 3000, "atk": 40, "every": 3.0, "range": 110, "speed": 60, "kb": 1, "area": false, "reward": 240},
	"molecricket":{"name": "땅강아지", "trait": "shell", "hp": 1800, "atk": 100, "every": 2.4, "range": 150, "speed": 80, "kb": 2, "area": true, "reward": 260},
	"roach":      {"name": "바퀴벌레", "trait": "crawl", "hp": 700, "atk": 50, "every": 1.2, "range": 140, "speed": 200, "kb": 3, "area": false, "reward": 250},
	# 우두머리 - 나올 때 충격파로 쿼카를 전부 밀어낸다
	"queen_ant":     {"name": "여왕개미", "trait": "crawl", "hp": 6000, "atk": 60, "every": 2.0, "range": 160, "speed": 60, "kb": 1, "area": true, "reward": 600, "boss": true},
	"mosquito_king": {"name": "왕모기", "trait": "fly", "hp": 7000, "atk": 90, "every": 1.6, "range": 180, "speed": 90, "kb": 1, "area": true, "reward": 700, "boss": true},
	"hornet":        {"name": "장수말벌", "trait": "fly", "hp": 9000, "atk": 160, "every": 1.8, "range": 170, "speed": 110, "kb": 1, "area": true, "reward": 800, "boss": true},
	"rhino":         {"name": "장수풍뎅이", "trait": "shell", "hp": 14000, "atk": 180, "every": 2.6, "range": 180, "speed": 50, "kb": 1, "area": true, "reward": 900, "boss": true},
	"tarantula":     {"name": "왕거미", "trait": "poison", "hp": 13000, "atk": 200, "every": 2.6, "range": 300, "speed": 50, "kb": 1, "area": true, "reward": 1000, "boss": true},
	"fly_king":      {"name": "왕파리", "trait": "fly", "hp": 15000, "atk": 200, "every": 1.2, "range": 180, "speed": 120, "kb": 1, "area": true, "reward": 1100, "boss": true},
	"moth_queen":    {"name": "나방 여왕", "trait": "fly", "hp": 17000, "atk": 240, "every": 2.2, "range": 300, "speed": 70, "kb": 1, "area": true, "reward": 1200, "boss": true},
	"cricket_king":  {"name": "땅강아지왕", "trait": "shell", "hp": 15000, "atk": 200, "every": 2.6, "range": 190, "speed": 50, "kb": 1, "area": true, "reward": 1300, "boss": true},
	"centipede_king":{"name": "지네 대왕", "trait": "poison", "hp": 26000, "atk": 300, "every": 1.4, "range": 200, "speed": 90, "kb": 1, "area": true, "reward": 1400, "boss": true},
	"roach_king":    {"name": "바퀴벌레 대왕", "trait": "crawl", "hp": 40000, "atk": 290, "every": 1.6, "range": 220, "speed": 80, "kb": 1, "area": true, "reward": 2000, "boss": true},
}
const TRAIT_NAME := {"crawl": "기어다님", "fly": "날벌레", "shell": "껍질", "poison": "독"}

## 구역 - 벌레 셋 + 우두머리. **첫 벌레는 계속 몰려오는 졸개**(가벼운 것), 뒤의 것은 그 구역 뒤 판에서 섞인다 -
## 무거운 벌레가 졸개로 끝없이 나오면 구역이 바뀔 때마다 벽이 된다 (시뮬레이션).
## 구역 - 벌레 셋 + 우두머리, 풍경은 `IdleBackdrop.THEMES` 번호.
const ZONES := [
	{"name": "풀밭", "bugs": ["ant", "caterpillar"], "boss": "queen_ant", "theme": 1},
	{"name": "웅덩이", "bugs": ["mosquito", "ant", "caterpillar"], "boss": "mosquito_king", "theme": 4},
	{"name": "꽃밭", "bugs": ["bee", "mosquito", "caterpillar"], "boss": "hornet", "theme": 8},
	{"name": "참나무 숲", "bugs": ["ladybug", "termite", "bee"], "boss": "rhino", "theme": 7},
	{"name": "거미 굴", "bugs": ["termite", "spider", "ladybug"], "boss": "tarantula", "theme": 2},
	{"name": "쓰레기 언덕", "bugs": ["fly", "cricket", "spider"], "boss": "fly_king", "theme": 6},
	{"name": "밤 들판", "bugs": ["cricket", "moth", "fly"], "boss": "moth_queen", "theme": 5},
	{"name": "땅속 마을", "bugs": ["termite", "centipede", "molecricket", "pillbug"], "boss": "cricket_king", "theme": 3},
	{"name": "축축한 부엌", "bugs": ["roach", "centipede", "wasp"], "boss": "centipede_king", "theme": 0},
	{"name": "악몽 하수구", "bugs": ["roach", "wasp", "stag", "pillbug"], "boss": "roach_king", "theme": 9},
]
const STAGES_PER_ZONE := 10
## 우두머리는 표의 몸보다 체력은 이만큼만, 공격은 이만큼만 (표는 '느낌', 이 둘로 판 길이를 맞춘다).
const BOSS_HP := 0.25
const BOSS_ATK := 0.5
const STAGE_MAX := 100

# ── 판 ───────────────────────────────────────────────────────────────
## 꿈빛 지갑: 일꾼(꿈 우체부) 레벨마다 초당 들어오는 양과 한도가 커진다.
const WORKER_MAX := 8
const WALLET_RATE := [40.0, 52.0, 64.0, 76.0, 88.0, 100.0, 112.0, 126.0]
const WALLET_CAP := [500, 750, 1000, 1300, 1600, 2000, 2400, 3000]
const WORKER_COST := [80, 160, 240, 320, 400, 480, 560]

## 꿈 대포: 다 차면 쏜다 - 성 앞 넓게 피해 + 넉백.
const CANNON_CHARGE := 30.0
const CANNON_REACH := 900.0
const CANNON_DMG := 120.0

const OUR_BASE_HP := 3000.0
## 넉백 거리·멈춤 시간. 보스 충격파는 더 멀리.
const KB_DIST := 160.0
const KB_SECS := 0.6
const SHOCK_DIST := 420.0


static func stage_info(n: int) -> Dictionary:
	var s := clampi(n, 1, STAGE_MAX)
	var zi := (s - 1) / STAGES_PER_ZONE
	var idx := ((s - 1) % STAGES_PER_ZONE) + 1
	var z: Dictionary = ZONES[zi]
	return {"stage": s, "zone": zi, "idx": idx, "boss": idx == STAGES_PER_ZONE, "zone_name": String(z["name"]),
		"theme": int(z["theme"]), "mag": magnification(s), "base_hp": int(round(1200.0 * (1.0 + 0.05 * float(s - 1))))}


static func stage_label(n: int) -> String:
	var i := stage_info(n)
	return "%s %d-%d" % [String(i["zone_name"]), int(i["zone"]) + 1, int(i["idx"])]


## 벌레 세기 배율.
static func magnification(n: int) -> float:
	return 1.0 + 0.036 * float(maxi(1, n) - 1)


## 이 스테이지의 벌레 나오는 차례 - [{kind, first 첫 등장(초), every 간격, max 최대 마리}].
## 씨앗이 스테이지 번호라 늘 같다.
static func spawns(n: int) -> Array:
	var info := stage_info(n)
	var z: Dictionary = ZONES[int(info["zone"])]
	var bugs: Array = z["bugs"]
	var idx := int(info["idx"])
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 7919
	var out: Array = []
	# 첫 벌레는 늘 빨리, 무리로 계속 온다
	out.append({"kind": String(bugs[0]), "first": 3.0, "every": maxf(5.0, 11.0 - idx * 0.5), "max": 999})
	for k in range(1, bugs.size()):
		if idx >= 3 * k - 1:
			out.append({"kind": String(bugs[k]), "first": 8.0 + rng.randf() * 10.0,
				"every": maxf(11.0, 28.0 - idx * 1.0 - k * 2.0), "max": 999})
	if bool(info["boss"]):
		# 우두머리 판은 졸개를 덜 보낸다 - 우두머리에 집중하게
		for e in out:
			e["every"] = float(e["every"]) * 1.7
		out.append({"kind": String(z["boss"]), "first": 12.0, "every": 9999.0, "max": 1, "boss": true})
	# 둥지가 반 아래로 떨어지면 몰려온다 (냥코의 '성이 맞으면 쏟아짐')
	out.append({"kind": String(bugs[0]), "first": -1.0, "every": 2.0, "max": 4 + idx / 2, "on_half": true})
	return out


## 깨면 받는 꿈조각 (처음 깨면 더 많이) 과 꿈별(뽑기 재화).
static func reward(n: int, first: bool) -> Dictionary:
	var xp := int(round(300.0 * (1.0 + 0.14 * float(n - 1))))
	if first:
		# 뒤 구역일수록 꿈별이 많다 - 새 친구를 만나는 순간이 처음 몇 시간에 몰리지 않게
		var boss := n % STAGES_PER_ZONE == 0
		var z := (n - 1) / STAGES_PER_ZONE
		return {"xp": xp * 2, "stars": (20 + 5 * z) if boss else (6 + 2 * z), "tickets": 1 if boss else 0}
	return {"xp": xp, "stars": 1, "tickets": 0}
