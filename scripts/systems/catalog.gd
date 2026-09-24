class_name Catalog
extends RefCounted
## 이 게임에 나오는 **물건 전부**의 표. 이름 · 그림 · 종류 · 설명 · 효과.
##
## 여태 이름은 `JourneyHud.NAMES`, 그림은 `JourneyHud.ICONS`, 전투에서
## 먹는 효과는 `Battle.FOODS`, 선반 물건은 `Items.SHELF` 에 흩어져 있었다.
## 스무 가지일 땐 버텼는데 백 가지를 넘기면 한 곳이 빠지는 순간 이름 없는
## 칸이나 빈 그림이 뜬다. 그래서 **여기 한 곳**에 적고 다른 데서는 묻기만
## 한다 (`docs/items-rewards.md`).
##
## **값이 없다.** 이 표에도 값·재고 같은 칸이 없다 — 물건은 여행에서 한
## 일로 받는다 (`Items` 주석).
##
## 칸:
##   name  : 화면에 뜨는 이름
##   kind  : pick 주운 것 · tool 여행 도구 · snack 먹을 것 · keep 기념품 ·
##           stamp 여행 도장 · shade 그늘 조각 · food 가게 먹거리
##   icon  : 그림 이름 (없으면 id 그대로 `assets/sprites/<id>.png`)
##   at    : 어느 마을 것인지 (설명 판에 "○○에서 온 것")
##   desc  : 한 줄 설명
##   먹을 것 효과 : hp · mp · warm(온기) · cure(나쁜 상태 풀기) · full(가득)
##   지닌 힘      : bonus = {hp|mp|atk|def: n}
##   그늘 조각    : guard = 그늘 id (그 그늘이 주는 피해가 준다)

## 도감에 늘어놓는 차례.
const KIND_ORDER := ["pick", "snack", "keep", "stamp", "shade", "food", "tool"]

const KIND_NAME := {
	"pick": "주운 것", "tool": "여행 도구", "snack": "먹을 것",
	"keep": "기념품", "stamp": "여행 도장", "shade": "몬스터 조각",
	"food": "가게 먹거리",
}

## 지닌 힘의 이름. `Battle` 의 마음 칸과 같은 낱말을 쓴다.
const STAT_NAME := {
	"hp": "체력 최대", "mp": "마음력 최대", "atk": "마음의 힘", "def": "버팀",
}

## 그늘 조각이 덜어 주는 몫. `Battle._enemy_out()` 한 곳에서 곱한다.
const GUARD_MULT := 0.8

const ITEMS := {
	# ── 주운 것 ───────────────────────────────────────────────────────
	"p-shell": {"name": "조개", "kind": "pick", "desc": "백사장에 널렸는데, 줍는 사람은 드물다."},
	"p-seaglass": {"name": "바다유리", "kind": "pick", "desc": "오래 굴러야 이렇게 둥글어진다."},
	"p-pebble": {"name": "조약돌", "kind": "pick", "desc": "손에 쥐면 조금 따뜻해진다."},
	"p-pinecone": {"name": "솔방울", "kind": "pick", "desc": "비가 오면 오므리고 볕이 나면 벌어진다."},
	"p-acorn": {"name": "도토리", "kind": "pick", "desc": "다람쥐가 깜빡 잊고 간 것 같다."},
	"p-flower": {"name": "들꽃", "kind": "pick", "desc": "이름은 몰라도 예쁘다."},
	"p-feather": {"name": "깃털", "kind": "pick", "desc": "누가 떨어뜨리고 날아갔을까."},
	"p-seaweed": {"name": "미역", "kind": "pick", "desc": "갯바위에서 걷어 온 것. 아직 바다 냄새가 난다."},
	"p-conch": {"name": "소라", "kind": "pick", "desc": "귀에 대면 파도 소리가 난다고들 한다."},
	"p-reed-leaf": {"name": "갈댓잎", "kind": "pick", "desc": "길고 곧은 잎. 바람에 사각거린다."},
	"p-reed-plume": {"name": "갈꽃", "kind": "pick", "desc": "솜처럼 부푼 이삭 끝."},
	"p-tangerine": {"name": "귤", "kind": "pick", "desc": "나무에서 떨어진 것만 주웠다."},
	"p-citrus-leaf": {"name": "귤잎", "kind": "pick", "desc": "손끝으로 비비면 새콤한 냄새."},
	"p-persimmon": {"name": "감", "kind": "pick", "desc": "고향 마당의 감나무에서 떨어졌다."},
	"p-persimmon-leaf": {"name": "감잎", "kind": "pick", "desc": "붉게 물든 잎 한 장."},
	"p-mushroom": {"name": "버섯", "kind": "pick", "desc": "먹어도 되는 버섯이라고 들었다."},
	"p-pine-needle": {"name": "솔잎", "kind": "pick", "desc": "뾰족하지만 향은 부드럽다."},

	# ── 여행 도구 ─────────────────────────────────────────────────────
	"map": {"name": "지도", "kind": "tool", "icon": "i-notebook", "at": "윤슬",
		"desc": "가게 할머니가 건네준 지도. 낯선 데서 길 잃지 말라고."},
	"camera": {"name": "카메라", "kind": "tool", "icon": "i-camera", "at": "윤슬",
		"desc": "갈매기 소년이 두 개라며 하나 준 카메라."},

	# ── 먹을 것 — 어디서나 ────────────────────────────────────────────
	"b-riceball": {"name": "주먹밥", "kind": "snack", "hp": 35,
		"desc": "소금만 살짝. 걷다가 먹기에 제일 좋다."},
	"b-barleytea": {"name": "보리차", "kind": "snack", "mp": 12,
		"desc": "구수한 냄새에 마음이 가라앉는다."},
	"b-sweetpotato": {"name": "군고구마", "kind": "snack", "hp": 45,
		"desc": "껍질째 호호 불어 먹는다."},
	"b-sikhye": {"name": "식혜", "kind": "snack", "mp": 18,
		"desc": "밥알이 동동 뜬 달큰한 한 잔."},
	"b-yakgwa": {"name": "약과", "kind": "snack", "hp": 25, "mp": 8,
		"desc": "꿀이 스민 작은 과자. 한 입에 달다."},
	"b-honeycake": {"name": "꿀떡", "kind": "snack", "hp": 30, "warm": true,
		"desc": "깨물면 꿀이 톡 터진다. 속이 따뜻해진다."},
	"b-citron-tea": {"name": "유자차", "kind": "snack", "mp": 6, "cure": true,
		"desc": "새콤한 향에 굳은 마음이 풀린다."},
	"b-cookie": {"name": "과자 한 봉지", "kind": "snack", "hp": 15, "mp": 5,
		"desc": "회사 서랍에 남아 있던 것. 이제는 여행 간식이다."},
	"b-candy": {"name": "알사탕", "kind": "snack", "mp": 10,
		"desc": "천천히 녹여 먹으면 오래 간다."},

	# ── 먹을 것 — 고향 ────────────────────────────────────────────────
	"b-lunchbox": {"name": "엄마 도시락", "kind": "snack", "full": true, "at": "고향",
		"desc": "뚜껑을 열면 좋아하는 것만 들어 있다. 몸도 마음도 가득 찬다."},
	"b-apple": {"name": "아빠가 깎은 사과", "kind": "snack", "hp": 30, "mp": 6, "at": "고향",
		"desc": "말없이 내민 접시. 모양은 삐뚤다."},

	# ── 먹을 것 — 마을마다 둘 ─────────────────────────────────────────
	"b-fishcake": {"name": "어묵꼬치", "kind": "snack", "hp": 28, "at": "윤슬",
		"desc": "바닷바람 맞으며 먹는 뜨끈한 꼬치."},
	"b-gimbap": {"name": "김밥", "kind": "snack", "hp": 38, "at": "윤슬",
		"desc": "소풍 가는 날 같은 맛."},
	"b-redbean-bread": {"name": "단팥빵", "kind": "snack", "hp": 30, "at": "볕뉘",
		"desc": "빵집 아주머니가 제일 먼저 굽는 빵."},
	"b-garaetteok": {"name": "가래떡", "kind": "snack", "hp": 26, "mp": 4, "at": "볕뉘",
		"desc": "쫀득하게 늘어난다. 조청에 찍어 먹는다."},
	"b-noodle": {"name": "잔치국수", "kind": "snack", "hp": 40, "at": "가풀재",
		"desc": "국물까지 다 마시면 고개를 하나 더 넘을 수 있다."},
	"b-potato": {"name": "찐감자", "kind": "snack", "hp": 30, "at": "가풀재",
		"desc": "포슬포슬하게 부서진다."},
	"b-citrus-juice": {"name": "귤즙", "kind": "snack", "mp": 15, "at": "하늬섬",
		"desc": "섬 바람만큼 상큼하다."},
	"b-citrus-bread": {"name": "귤빵", "kind": "snack", "hp": 24, "mp": 6, "at": "하늬섬",
		"desc": "귤 모양으로 구운 작은 빵."},
	"b-corn": {"name": "찐옥수수", "kind": "snack", "hp": 32, "at": "굽이나루",
		"desc": "한 알씩 뜯어 먹다 보면 강이 한 굽이 돈다."},
	"b-plum-tea": {"name": "매실차", "kind": "snack", "mp": 5, "cure": true, "at": "굽이나루",
		"desc": "시큼한 한 모금에 얹힌 것이 내려간다."},
	"b-cream-bread": {"name": "크림빵", "kind": "snack", "hp": 34, "at": "방울못",
		"desc": "연못가 빵집의 자랑. 크림이 넘치게 들었다."},
	"b-lotus-tea": {"name": "연잎차", "kind": "snack", "mp": 16, "at": "방울못",
		"desc": "잔잔한 연못 같은 맛."},
	"b-chestnut": {"name": "군밤", "kind": "snack", "hp": 28, "warm": true, "at": "갈밭머리",
		"desc": "종이 봉투째 품에 안으면 따뜻하다."},
	"b-sujeonggwa": {"name": "수정과", "kind": "snack", "mp": 14, "at": "갈밭머리",
		"desc": "계피 향이 코끝을 찡하게 한다."},
	"b-pine-tea": {"name": "솔잎차", "kind": "snack", "mp": 8, "cure": true, "at": "솔은재",
		"desc": "숲 냄새가 목을 타고 내려간다."},
	"b-acorn-jelly": {"name": "도토리묵", "kind": "snack", "hp": 36, "at": "솔은재",
		"desc": "탱글탱글, 젓가락으로 집기가 어렵다."},
	"b-strawberry": {"name": "딸기", "kind": "snack", "hp": 22, "mp": 8, "at": "꽃눈벌",
		"desc": "밭머리에서 막 딴 것."},
	"b-hwajeon": {"name": "화전", "kind": "snack", "hp": 30, "mp": 10, "at": "꽃눈벌",
		"desc": "꽃잎을 얹어 부친 찹쌀 떡."},

	# ── 기념품 — 지니고만 있어도 작은 힘 ─────────────────────────────
	"k-marble": {"name": "유리구슬", "kind": "keep", "icon": "i-marble", "at": "윤슬",
		"bonus": {"mp": 2}, "desc": "윤슬의 저녁 바다를 닮은 구슬."},
	"k-lens": {"name": "등대 렌즈 조각", "kind": "keep", "at": "윤슬",
		"bonus": {"atk": 1}, "desc": "빛은 한 번에 보이지 않는다. 그래도 여기 있다."},
	"k-rope": {"name": "부두 밧줄 매듭", "kind": "keep", "at": "윤슬",
		"bonus": {"hp": 3}, "desc": "부두 끝 말뚝에 묶여 있던 매듭 하나."},
	"k-roof-tile": {"name": "기와 조각", "kind": "keep", "at": "볕뉘",
		"bonus": {"def": 1}, "desc": "천 년 된 지붕에서 떨어진 한 귀퉁이."},
	"k-clay-bell": {"name": "흙방울", "kind": "keep", "at": "볕뉘",
		"bonus": {"mp": 2}, "desc": "흔들면 토독, 흙마당 소리가 난다."},
	"k-bookmark": {"name": "말린 들꽃 책갈피", "kind": "keep", "at": "볕뉘",
		"bonus": {"hp": 3}, "desc": "빵집 아주머니가 봉투에 끼워 준 것."},
	"k-ridge-stone": {"name": "능선 돌", "kind": "keep", "at": "가풀재",
		"bonus": {"atk": 1}, "desc": "노을을 끝까지 본 날 주머니에 넣었다."},
	"k-anchor": {"name": "작은 닻", "kind": "keep", "at": "가풀재",
		"bonus": {"def": 1}, "desc": "마을을 올려다본 부두 끝에서."},
	"k-chopsticks": {"name": "나무 젓가락", "kind": "keep", "at": "가풀재",
		"bonus": {"hp": 3}, "desc": "국수집 아저씨가 손수 깎은 것."},
	"k-basket": {"name": "작은 대바구니", "kind": "keep", "at": "하늬섬",
		"bonus": {"hp": 3}, "desc": "시장 할머니들이 쓰는 것과 똑같이 생겼다."},
	"k-pinwheel": {"name": "바람개비", "kind": "keep", "at": "하늬섬",
		"bonus": {"mp": 2}, "desc": "언덕 위에서는 쉬지 않고 돈다."},
	"k-citrus-bell": {"name": "귤 방울", "kind": "keep", "at": "하늬섬",
		"bonus": {"atk": 1}, "desc": "귤 모양 방울. 딸랑, 새콤한 소리."},
	"k-oar": {"name": "작은 노", "kind": "keep", "at": "굽이나루",
		"bonus": {"atk": 1}, "desc": "강 굽이 데크에 기대 있던 장난감 노."},
	"k-river-stone": {"name": "물굽이 조약돌", "kind": "keep", "at": "굽이나루",
		"bonus": {"hp": 3}, "desc": "물이 오래 다듬은 둥근 돌."},
	"k-straw-hat": {"name": "밀짚모자", "kind": "keep", "at": "굽이나루",
		"bonus": {"def": 1}, "desc": "나루 가게 아저씨가 볕 가리라고 준 것."},
	"k-lotus-leaf": {"name": "연잎", "kind": "keep", "at": "방울못",
		"bonus": {"mp": 2}, "desc": "빗방울이 굴러다니는 커다란 잎."},
	"k-wind-chime": {"name": "물방울 풍경", "kind": "keep", "at": "방울못",
		"bonus": {"mp": 2}, "desc": "데크 끝 물소리를 닮은 소리가 난다."},
	"k-rolling-pin": {"name": "밀대", "kind": "keep", "at": "방울못",
		"bonus": {"hp": 3}, "desc": "빵집에서 오래 쓴 손때 묻은 밀대."},
	"k-reed-flute": {"name": "갈대 피리", "kind": "keep", "at": "갈밭머리",
		"bonus": {"mp": 2}, "desc": "불면 바람 소리가 난다."},
	"k-nest": {"name": "빈 새 둥지", "kind": "keep", "at": "갈밭머리",
		"bonus": {"def": 1}, "desc": "갈대 사이 빈자리에 남아 있던 것. 새들은 날아갔다."},
	"k-straw-mat": {"name": "작은 돗자리", "kind": "keep", "at": "갈밭머리",
		"bonus": {"hp": 3}, "desc": "어디서든 앉아 쉬어 가라고."},
	"k-gold-cone": {"name": "금빛 솔방울", "kind": "keep", "at": "솔은재",
		"bonus": {"atk": 1}, "desc": "전망 바위에 볕이 들 때만 금빛으로 보인다."},
	"k-pine-sachet": {"name": "솔잎 향주머니", "kind": "keep", "at": "솔은재",
		"bonus": {"mp": 2}, "desc": "솔그늘 샛길 냄새를 담아 왔다."},
	"k-walking-stick": {"name": "지팡이", "kind": "keep", "at": "솔은재",
		"bonus": {"def": 1}, "desc": "고개 넘는 사람들이 쉬어 가며 두고 간 것."},
	"k-petal-jar": {"name": "꽃잎 병", "kind": "keep", "at": "꽃눈벌",
		"bonus": {"mp": 2}, "desc": "도랑에 뜬 꽃잎을 조금 담아 왔다."},
	"k-scarecrow": {"name": "작은 허수아비", "kind": "keep", "at": "꽃눈벌",
		"bonus": {"def": 1}, "desc": "밭 사잇길 끝에서 들판을 지키던 것."},
	"k-seed-pouch": {"name": "씨앗 주머니", "kind": "keep", "at": "꽃눈벌",
		"bonus": {"hp": 3}, "desc": "어디든 심으면 내년엔 거기도 꽃밭이다."},
	"k-family-photo": {"name": "가족사진", "kind": "keep", "at": "고향",
		"bonus": {"hp": 3}, "desc": "평상에 앉아 넷이 찍은 사진. 다들 표정이 어색하다."},
	"k-ticket": {"name": "첫 차표", "kind": "keep", "at": "잿마루",
		"bonus": {"atk": 1}, "desc": "퇴근이 아니라 출발이었던 날의 표."},
	"k-lanyard": {"name": "빈 목걸이 줄", "kind": "keep", "at": "잿마루",
		"bonus": {"def": 1}, "desc": "사원증을 반납하고 나니 줄만 남았다."},

	# ── 여행 도장 — 마을 하나를 다 돌면 ──────────────────────────────
	"st-yunseul": {"name": "윤슬 도장", "kind": "stamp", "at": "윤슬",
		"bonus": {"hp": 2}, "desc": "파도 무늬. 처음 떠나온 곳은 넓었다."},
	"st-byeotnwi": {"name": "볕뉘 도장", "kind": "stamp", "at": "볕뉘",
		"bonus": {"hp": 2}, "desc": "기와 무늬. 천 년 옆에서 걸음이 느려졌다."},
	"st-gapuljae": {"name": "가풀재 도장", "kind": "stamp", "at": "가풀재",
		"bonus": {"hp": 2}, "desc": "능선 무늬. 고개 너머에 노을이 있었다."},
	"st-hanuiseom": {"name": "하늬섬 도장", "kind": "stamp", "at": "하늬섬",
		"bonus": {"hp": 2}, "desc": "바람 무늬. 바람이 세도 귤은 달았다."},
	"st-gubinaru": {"name": "굽이나루 도장", "kind": "stamp", "at": "굽이나루",
		"bonus": {"hp": 2}, "desc": "물굽이 무늬. 서두를 것 없었다."},
	"st-bangulmot": {"name": "방울못 도장", "kind": "stamp", "at": "방울못",
		"bonus": {"hp": 2}, "desc": "물방울 무늬. 연못은 동그랗게 퍼졌다."},
	"st-galbatmeori": {"name": "갈밭머리 도장", "kind": "stamp", "at": "갈밭머리",
		"bonus": {"hp": 2}, "desc": "갈대 무늬. 틈 사이로 하늘이 보였다."},
	"st-soleunjae": {"name": "솔은재 도장", "kind": "stamp", "at": "솔은재",
		"bonus": {"hp": 2}, "desc": "솔잎 무늬. 숲 냄새가 오래 남았다."},
	"st-kkonnunbeol": {"name": "꽃눈벌 도장", "kind": "stamp", "at": "꽃눈벌",
		"bonus": {"hp": 2}, "desc": "꽃잎 무늬. 들판 한가운데서 멈춰 섰다."},

	# ── 몬스터 조각 — 처음 쓰러뜨릴 때 하나 (`docs/elements.md`) ────────
	"m-drop": {"name": "물방울뭉 조각", "kind": "shade", "guard": "drop",
		"desc": "톡 건드리면 찰랑 소리가 난다."},
	"m-ember": {"name": "불똥콩 조각", "kind": "shade", "guard": "ember",
		"desc": "아직 따뜻하다. 손난로로 딱이다."},
	"m-sprout": {"name": "새싹뭉치 조각", "kind": "shade", "guard": "sprout",
		"desc": "물을 주면 다시 싹이 날 것 같다."},
	"m-pebble": {"name": "조약돌이 조각", "kind": "shade", "guard": "pebble",
		"desc": "동글동글. 주머니에 넣고 굴리게 된다."},
	"m-gust": {"name": "회오리뭉 조각", "kind": "shade", "guard": "gust",
		"desc": "귀에 대면 바람 소리가 난다."},
	"m-whirl": {"name": "소용돌이 조각", "kind": "shade", "guard": "whirl",
		"desc": "들여다보면 조금 어지럽다."},
	"m-thorn": {"name": "가시덩굴 조각", "kind": "shade", "guard": "thorn",
		"desc": "가시는 빠지고 덩굴만 남았다."},
	"m-mole": {"name": "모래두더지 조각", "kind": "shade", "guard": "mole",
		"desc": "쥐면 모래가 사르르 흘러내린다."},
	"m-storm": {"name": "돌개바람 조각", "kind": "shade", "guard": "storm",
		"desc": "병에 담아 두면 병 속에서 돈다."},
	"m-blaze": {"name": "화르륵 조각", "kind": "shade", "guard": "blaze",
		"desc": "꺼질 듯 꺼지지 않는 불씨."},
	"m-night": {"name": "밤그늘 대왕 조각", "kind": "shade", "guard": "night",
		"desc": "긴 밤도 결국 아침이 된다."},

	# ── 가게 먹거리 — 그 자리에서 맛본다 (배낭에 안 들어간다) ─────────
	"f-icecream": {"name": "아이스크림", "kind": "food", "icon": "i-icecream", "at": "윤슬",
		"desc": "차가운 게 혀에서 천천히 녹는다."},
	"f-tea": {"name": "따뜻한 차", "kind": "food", "icon": "i-tea", "at": "윤슬",
		"desc": "김이 안경도 없는 얼굴로 올라온다."},
	"f-white-bread": {"name": "갓 구운 식빵", "kind": "food", "at": "볕뉘",
		"desc": "결대로 찢으면 김이 난다."},
	"f-milk": {"name": "따뜻한 우유", "kind": "food", "at": "볕뉘",
		"desc": "빵이랑 같이 먹으라고 데워 줬다."},
	"f-anchovy-soup": {"name": "멸치 국물 한 모금", "kind": "food", "at": "가풀재",
		"desc": "국수 삶기 전에 맛보라고 떠 준 국물."},
	"f-kimchi": {"name": "겉절이 한 점", "kind": "food", "at": "가풀재",
		"desc": "아삭하고 매콤하다."},
	"f-fresh-tangerine": {"name": "갓 딴 귤", "kind": "food", "at": "하늬섬",
		"desc": "껍질이 얇아 손으로 쉽게 까진다."},
	"f-peel-tea": {"name": "귤피차", "kind": "food", "at": "하늬섬",
		"desc": "말린 귤껍질로 우린 차. 바람에 언 손이 녹는다."},
	"f-snail-soup": {"name": "다슬기국", "kind": "food", "at": "굽이나루",
		"desc": "강 냄새가 나는 푸른 국물."},
	"f-grilled-ricecake": {"name": "구운 떡", "kind": "food", "at": "굽이나루",
		"desc": "겉은 바삭, 속은 말랑."},
	"f-cream-puff": {"name": "슈크림", "kind": "food", "at": "방울못",
		"desc": "한 입 베어 물면 크림이 삐져나온다."},
	"f-cocoa": {"name": "코코아", "kind": "food", "at": "방울못",
		"desc": "달고 뜨겁다. 연못을 보며 마신다."},
	"f-steamed-bun": {"name": "찐빵", "kind": "food", "at": "갈밭머리",
		"desc": "쉼터 솥에서 막 꺼낸 것."},
	"f-barley-rice": {"name": "보리밥 한 술", "kind": "food", "at": "갈밭머리",
		"desc": "할머니가 한 숟갈만 먹어 보라며 떠 준 것."},
	"f-songpyeon": {"name": "송편", "kind": "food", "at": "솔은재",
		"desc": "솔잎에 쪄서 솔 향이 밴다."},
	"f-mushroom-soup": {"name": "버섯국", "kind": "food", "at": "솔은재",
		"desc": "숲에서 난 것만 넣었다."},
	"f-cucumber": {"name": "오이 한 조각", "kind": "food", "at": "꽃눈벌",
		"desc": "밭에서 막 따 시원하다."},
	"f-flower-tea": {"name": "꽃차", "kind": "food", "at": "꽃눈벌",
		"desc": "찻잔 안에서 꽃이 다시 핀다."},
}


static func has(id: String) -> bool:
	return ITEMS.has(id)


static func of(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func name_of(id: String) -> String:
	return String(of(id).get("name", id))


## 그림 이름. 없으면 id 그대로 — 주운 것(`p-*`)은 이름이 곧 그림이다.
static func icon_of(id: String) -> String:
	return String(of(id).get("icon", id))


static func icon_path(id: String) -> String:
	return "res://assets/sprites/%s.png" % icon_of(id)


static func kind_of(id: String) -> String:
	return String(of(id).get("kind", ""))


static func ids_of(kind: String) -> Array:
	var out: Array = []
	for id in ITEMS:
		if String(ITEMS[id].get("kind", "")) == kind:
			out.append(id)
	return out


## 배낭에서 먹을 수 있나. 먹을 것(`b-*`)과, 전투에서 쥐고 쓰던 주운 것
## (`Battle.FOODS`) 둘 다다.
static func edible(id: String) -> bool:
	return kind_of(id) == "snack" or Battle.FOODS.has(id)


## 먹으면 무엇이 되나 — 한 줄. 설명 판과 전투 목록이 같이 쓴다.
static func effect_text(id: String) -> String:
	var e: Dictionary = of(id)
	if Battle.FOODS.has(id):
		e = Battle.FOODS[id]
	var parts: Array = []
	if bool(e.get("full", false)):
		parts.append("체력·마음력 가득")
	# 지금 레벨에 맞춰 늘어난 양으로 적는다 (`Battle.food_hp`).
	if int(e.get("hp", 0)) > 0:
		parts.append("체력 +%d" % Battle.food_hp(int(e["hp"])))
	if int(e.get("mp", 0)) > 0:
		parts.append("마음력 +%d" % Battle.food_mp(int(e["mp"])))
	if bool(e.get("warm", false)):
		parts.append("온기")
	if bool(e.get("cure", false)):
		parts.append("나쁜 상태 풀기")
	var b: Dictionary = of(id).get("bonus", {})
	for st in b:
		parts.append("%s +%d" % [String(STAT_NAME.get(st, st)), int(b[st])])
	var g := String(of(id).get("guard", ""))
	if g != "":
		# 퍼센트 기호는 폰트에 없다 (`CLAUDE.md` 폰트 규칙) - 말로 적는다.
		parts.append("%s이(가) 주는 피해가 줄어든다"
			% String(Battle.ENEMIES.get(g, {}).get("name", g)))
	return " · ".join(parts)


## 지니고 있는 것들이 보태는 힘. 배낭에서 **그때그때 다시 센다** —
## 저장해 두면 물건이 빠질 때 되돌리는 걸 잊는 순간 중복으로 붙는다.
## 같은 것을 둘 가져도 한 번만 친다(지니는 것이지 쌓는 것이 아니다).
static func bonus(stat: String) -> int:
	var n := 0
	for id in JourneyState.bag:
		var b: Dictionary = of(String(id)).get("bonus", {})
		n += int(b.get(stat, 0))
	return n


## 그 그늘의 조각을 지녔나.
static func guards(enemy_id: String) -> bool:
	return JourneyState.count("m-" + enemy_id) > 0


## 도감에 채워졌나. 먹어 없앤 것도 남는다 (`JourneyState.seen_items`).
## 가게 먹거리는 배낭에 안 들어가니 맛본 기록으로 본다.
static func found(id: String) -> bool:
	if JourneyState.seen_items.has(id) or JourneyState.count(id) > 0:
		return true
	if kind_of(id) == "food":
		var at := String(of(id).get("at", ""))
		return JourneyState.quest_done("%s:맛봄:%s" % [at, id])
	return false
