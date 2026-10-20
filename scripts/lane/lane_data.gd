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
	"centipede_king":{"name": "지네 대왕", "trait": "poison", "hp": 26000, "atk": 230, "every": 1.6, "range": 200, "speed": 90, "kb": 1, "area": true, "reward": 1400, "boss": true},
	"roach_king":    {"name": "바퀴벌레 대왕", "trait": "crawl", "hp": 40000, "atk": 290, "every": 1.6, "range": 220, "speed": 80, "kb": 1, "area": true, "reward": 2000, "boss": true},
}
const TRAIT_NAME := {"crawl": "기어다님", "fly": "날벌레", "shell": "껍질", "poison": "독"}

## 구역 - 벌레 셋 + 우두머리. **첫 벌레는 계속 몰려오는 졸개**(가벼운 것), 뒤의 것은 그 구역 뒤 판에서 섞인다 -
## 무거운 벌레가 졸개로 끝없이 나오면 구역이 바뀔 때마다 벽이 된다 (시뮬레이션).
## 구역 - 벌레 셋 + 우두머리, 풍경은 `IdleBackdrop.THEMES` 번호.
const ZONES := [
	{"name": "풀밭", "bugs": ["ant", "caterpillar"], "boss": "queen_ant", "pow": 3.0, "theme": 1},
	{"name": "웅덩이", "bugs": ["mosquito", "ant", "caterpillar"], "boss": "mosquito_king", "pow": 3.2, "theme": 4},
	{"name": "꽃밭", "bugs": ["bee", "mosquito", "caterpillar"], "boss": "hornet", "pow": 1.85, "theme": 8},
	{"name": "참나무 숲", "bugs": ["bee", "termite", "ladybug"], "boss": "rhino", "pow": 1.5, "theme": 7},
	{"name": "거미 굴", "bugs": ["termite", "spider", "ladybug"], "boss": "tarantula", "pow": 1.05, "theme": 2},
	{"name": "쓰레기 언덕", "bugs": ["fly", "cricket", "spider"], "boss": "fly_king", "pow": 1.5, "theme": 6},
	{"name": "밤 들판", "bugs": ["cricket", "moth", "fly"], "boss": "moth_queen", "pow": 0.75, "theme": 5},
	{"name": "땅속 마을", "bugs": ["termite", "centipede", "molecricket", "pillbug"], "boss": "cricket_king", "pow": 0.9, "theme": 3},
	{"name": "축축한 부엌", "bugs": ["roach", "centipede", "wasp"], "boss": "centipede_king", "pow": 0.9, "theme": 0},
	{"name": "악몽 하수구", "bugs": ["roach", "wasp", "stag", "pillbug"], "boss": "roach_king", "pow": 0.9, "theme": 9},
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
## 벌레 떼 - 첫 떼(초) · 간격 · 가장 짧은 간격 · 기본 마리 수. 오기 WAVE_WARN 초 전에 알려 준다.
const WAVE_FIRST := 28.0
const WAVE_EVERY := 32.0
const WAVE_MIN := 20.0
const WAVE_BASE := 4
const WAVE_WARN := 3.0
## 위기 역전: 성 체력이 이 아래로 처음 떨어지면 대포가 바로 차고 꿈빛이 지갑의 반만큼 들어온다 (판마다 한 번).
const CRISIS_AT := 0.4
## 다시 도전 응원: 같은 판에서 질 때마다 공격·체력 +10% (최대 +30%), 이기면 사라진다.
const CHEER_STEP := 10.0
const CHEER_MAX := 30.0
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
		"theme": int(z["theme"]), "mag": magnification(s) * zone_pow(zi, idx), "base_hp": int(round(1200.0 * (1.0 + 0.05 * float(s - 1))))}


## 구역 세기 - 벌레 조합마다 어려움이 달라서 시뮬레이션으로 하나씩 맞췄다 (첫 도전 승률 70~85% 를 노린다).
## 첫 구역 앞 판들은 배우는 판이라 살살.
static func zone_pow(zi: int, idx: int) -> float:
	var p := float(ZONES[zi].get("pow", 1.0))
	if zi == 0:
		p *= minf(1.0, 0.25 + 0.15 * float(idx))
	return p


static func stage_label(n: int) -> String:
	var i := stage_info(n)
	return "%s %d-%d" % [String(i["zone_name"]), int(i["zone"]) + 1, int(i["idx"])]


## 벌레 세기 배율.
static func magnification(n: int) -> float:
	return 1.0 + 0.045 * float(maxi(1, n) - 1)


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
	# 벌레 떼: 주기적으로 한꺼번에 몰려와 전선을 민다 - 판이 한쪽으로 기울지 않고 출렁이게
	var zi := int(info["zone"])
	var wave := {"kind": String(bugs[0]), "first": WAVE_FIRST, "every": maxf(WAVE_MIN, WAVE_EVERY - float(idx) * 1.5),
		"max": 999, "burst": WAVE_BASE + idx / 2 + zi / 2, "wave": true}
	if bugs.size() > 1 and idx >= 4:
		wave["extra"] = String(bugs[1])
	out.append(wave)
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


# ── 보물 (구역마다 3개, 하급·보통·상급) ─────────────────────────────────
## 그 구역 판을 깨면 가끔 나온다 (처음 깨면 꼭). 더 좋은 등급이 나오면 바뀐다 - "한 번 더" 의 이유.
## kind: atk 공격% · hp 체력% · rate 수입% · cannon 대포 충전% · xp 꿈조각% · wallet 시작 꿈빛 · stars 꿈별(첫 클리어)
## per: 등급 하나당 효과 (상급 = ×3). icon: 그림 모양 · col: 색
const TREASURES := [
	[{"name": "이슬 방울", "kind": "atk", "per": 0.5, "icon": "drop", "col": "#8FD8FF"},
		{"name": "네잎클로버", "kind": "hp", "per": 0.5, "icon": "clover", "col": "#6CC24A"},
		{"name": "민들레 씨", "kind": "wallet", "per": 15.0, "icon": "fluff", "col": "#FFF4C8"}],
	[{"name": "물빛 조약돌", "kind": "atk", "per": 0.5, "icon": "pebble", "col": "#9AB8D8"},
		{"name": "연잎", "kind": "hp", "per": 0.5, "icon": "leaf", "col": "#4FAE6A"},
		{"name": "물방울 구슬", "kind": "rate", "per": 1.0, "icon": "orb", "col": "#7FD0FF"}],
	[{"name": "꿀 단지", "kind": "atk", "per": 0.5, "icon": "jar", "col": "#F2B33C"},
		{"name": "꽃잎 브로치", "kind": "hp", "per": 0.5, "icon": "flower", "col": "#FF8FB8"},
		{"name": "나비 리본", "kind": "xp", "per": 2.0, "icon": "ribbon", "col": "#C58CFF"}],
	[{"name": "황금 도토리", "kind": "atk", "per": 0.5, "icon": "acorn", "col": "#D9A040"},
		{"name": "이끼 반지", "kind": "hp", "per": 0.5, "icon": "ring", "col": "#7CC15A"},
		{"name": "나무 피리", "kind": "cannon", "per": 3.0, "icon": "flute", "col": "#A9754A"}],
	[{"name": "은실 타래", "kind": "atk", "per": 0.5, "icon": "spool", "col": "#D8DEE8"},
		{"name": "반딧불 등", "kind": "hp", "per": 0.5, "icon": "lantern", "col": "#F2E05A"},
		{"name": "수정 조각", "kind": "rate", "per": 1.0, "icon": "gem", "col": "#B8A6FF"}],
	[{"name": "병뚜껑 메달", "kind": "atk", "per": 0.5, "icon": "coin", "col": "#E8C050"},
		{"name": "반짝 단추", "kind": "hp", "per": 0.5, "icon": "button", "col": "#FF7A7A"},
		{"name": "낡은 열쇠", "kind": "wallet", "per": 15.0, "icon": "key", "col": "#C9A060"}],
	[{"name": "달 조각", "kind": "atk", "per": 0.5, "icon": "moon", "col": "#FFE59A"},
		{"name": "별가루 병", "kind": "hp", "per": 0.5, "icon": "bottle", "col": "#9FD8FF"},
		{"name": "밤 깃털", "kind": "xp", "per": 2.0, "icon": "feather", "col": "#8E7AC8"}],
	[{"name": "무지개 버섯", "kind": "atk", "per": 0.5, "icon": "mushroom", "col": "#FF6B8A"},
		{"name": "보석 원석", "kind": "hp", "per": 0.5, "icon": "gem", "col": "#5BD8B0"},
		{"name": "광부 램프", "kind": "cannon", "per": 3.0, "icon": "lantern", "col": "#FFB03C"}],
	[{"name": "은 숟가락", "kind": "atk", "per": 0.5, "icon": "spoon", "col": "#E0E6EE"},
		{"name": "각설탕", "kind": "hp", "per": 0.5, "icon": "cube", "col": "#FFFFFF"},
		{"name": "찻잔", "kind": "rate", "per": 1.0, "icon": "cup", "col": "#FFB6C8"}],
	[{"name": "꿈 왕관 조각", "kind": "atk", "per": 0.8, "icon": "crown", "col": "#FFD15A"},
		{"name": "새벽 종", "kind": "hp", "per": 0.8, "icon": "bell", "col": "#F2C14E"},
		{"name": "첫 햇살", "kind": "xp", "per": 3.0, "icon": "sun", "col": "#FFB84A"}],
]
## `lane-icons.png` 의 순서 (`tools/pixel/make-lane-icons.py` 와 같다).
const ICONS := ["drop", "clover", "fluff", "pebble", "leaf", "orb", "jar", "flower", "ribbon", "acorn", "ring", "flute",
	"spool", "lantern", "gem", "coin", "button", "key", "moon", "bottle", "feather", "mushroom", "spoon", "cube",
	"cup", "crown", "bell", "sun", "star", "vest", "glove", "shoe", "candy", "shield"]
const GRADE_NAME := ["", "하급", "보통", "상급"]
const GRADE_COL := ["#6A6080", "#C99466", "#D8DEE8", "#FFD15A"]
## 보물이 나올 확률 (다시 깰 때) 과 등급 확률 (상급, 보통 - 나머지 하급). 우두머리 판은 상급이 잘 나온다.
const TREASURE_DROP := 0.3
const TREASURE_FIRST := 0.6         ## 처음 깰 때
const GRADE_ROLL := [0.15, 0.35]
const GRADE_ROLL_BOSS := [0.3, 0.4]
const BONUS_NAME := {"atk": "공격", "hp": "체력", "rate": "수입", "cannon": "대포 충전", "xp": "꿈조각",
	"wallet": "시작 꿈빛", "speed": "걸음", "guard": "받는 피해", "slow": "느리게 시간"}


static func bonus_text(kind: String, v: float) -> String:
	if kind == "wallet":
		return "%s +%d" % [String(BONUS_NAME[kind]), int(round(v))]
	if kind == "guard":
		return "%s -%d%%" % [String(BONUS_NAME[kind]), int(round(v))]
	var t := ("%.1f" % v) if absf(v - round(v)) > 0.05 else str(int(round(v)))
	return "%s +%s%%" % [String(BONUS_NAME[kind]), t]


# ── 장신구 (우두머리를 처음 잡으면 하나씩, 유닛 하나에 하나 단다) ───────────────
## eff: 그 유닛에만. 레벨(1~5)마다 per 만큼 더. 레벨업은 꿈조각.
## atk·hp·speed % · every 공격 간격 -% · cd 다시 내기 -% · cost 비용 -% · guard 받는 피해 -% · crit 치명타 +%p · slow 느리게 확률 %p
const ACCESSORIES := {
	"feather_hat":  {"name": "깃털 모자", "eff": {"speed": [15.0, 4.0]}, "icon": "feather", "col": "#FF8FB8", "zone": 0},
	"star_necklace":{"name": "별 목걸이", "eff": {"atk": [6.0, 3.0]}, "icon": "star", "col": "#FFD15A", "zone": 1},
	"fluffy_vest":  {"name": "솜털 조끼", "eff": {"hp": [10.0, 4.0]}, "icon": "vest", "col": "#FFF4E0", "zone": 2},
	"clover_pin":   {"name": "네잎 브로치", "eff": {"crit": [5.0, 2.0]}, "icon": "clover", "col": "#6CC24A", "zone": 3},
	"ice_bell":     {"name": "얼음 방울", "eff": {"slow": [10.0, 3.0]}, "icon": "bell", "col": "#9FE4FF", "zone": 4},
	"bolt_gloves":  {"name": "번개 장갑", "eff": {"every": [5.0, 2.0]}, "icon": "glove", "col": "#FFE05A", "zone": 5},
	"wind_shoes":   {"name": "바람 신발", "eff": {"cd": [8.0, 3.0]}, "icon": "shoe", "col": "#7FD0FF", "zone": 6},
	"honey_candy":  {"name": "꿀 사탕", "eff": {"cost": [6.0, 2.0]}, "icon": "candy", "col": "#F2B33C", "zone": 7},
	"mirror_shield":{"name": "거울 방패", "eff": {"guard": [8.0, 3.0]}, "icon": "shield", "col": "#D8DEE8", "zone": 8},
	"dream_crown":  {"name": "꿈 왕관", "eff": {"atk": [8.0, 3.0], "hp": [8.0, 3.0]}, "icon": "crown", "col": "#FFD15A", "zone": 9},
}
const ACC_ORDER := ["feather_hat", "star_necklace", "fluffy_vest", "clover_pin", "ice_bell", "bolt_gloves",
	"wind_shoes", "honey_candy", "mirror_shield", "dream_crown"]
const ACC_LV_MAX := 5
const ACC_EFF_NAME := {"atk": "공격", "hp": "체력", "speed": "걸음", "every": "공격 간격", "cd": "다시 내기",
	"cost": "비용", "guard": "받는 피해", "crit": "치명타", "slow": "느리게 확률"}


static func acc_value(id: String, key: String, lv: int) -> float:
	var e: Array = ACCESSORIES[id]["eff"][key]
	return float(e[0]) + float(e[1]) * float(maxi(1, lv) - 1)


static func acc_text(id: String, lv: int) -> String:
	var out: Array = []
	for k in ACCESSORIES[id]["eff"].keys():
		var v := acc_value(id, String(k), lv)
		var minus: bool = k in ["every", "cd", "cost", "guard"]
		out.append("%s %s%d%%" % [String(ACC_EFF_NAME[k]), "-" if minus else "+", int(round(v))])
	return " · ".join(out)


static func acc_level_cost(lv: int) -> int:
	return int(round(3000.0 * pow(float(lv), 1.6)))


# ── 콤보 (같이 편성하면) ──────────────────────────────────────────────
const COMBOS := [
	{"name": "쿼카 삼총사", "units": ["tiny", "shield", "spear"], "kind": "hp", "v": 8.0},
	{"name": "대장간", "units": ["hammer", "giant"], "kind": "atk", "v": 8.0},
	{"name": "멀리멀리", "units": ["sling", "mage"], "kind": "cannon", "v": 15.0},
	{"name": "숲속 친구들", "units": ["squirrel", "hedgehog", "mole"], "kind": "wallet", "v": 150.0},
	{"name": "물가 친구들", "units": ["frog", "duck", "otter"], "kind": "rate", "v": 10.0},
	{"name": "하늘 친구들", "units": ["chick", "owl", "eagle"], "kind": "cannon", "v": 25.0},
	{"name": "얼음 나라", "units": ["penguin", "polar"], "kind": "slow", "v": 50.0},
	{"name": "푹신 친구들", "units": ["sheep", "rabbit", "panda"], "kind": "xp", "v": 15.0},
	{"name": "줄무늬 달리기", "units": ["tiger", "runner"], "kind": "speed", "v": 15.0},
	{"name": "단단한 등껍질", "units": ["turtle", "shield"], "kind": "guard", "v": 10.0},
]
