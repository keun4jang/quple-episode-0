extends Node
## 여행 중에 지니고 다니는 것 (오토로드 `JourneyState`).
##
## 배낭에 든 것과, 어디서 무엇을 이미 주웠는지를 기억한다.
## 한 번 주운 것은 그 자리에 다시 안 생긴다 — 같은 자리를 왔다 갔다 하며
## 퍼 담는 게임이 아니다.

signal picked(item: String, total: int)
signal heart_up(folk_id: String, heart: int)
signal day_passed(day: int)
signal letter_came(text: String)
signal postcard_came(folk_id: String)
signal photo_taken(photo: Dictionary)

## 아이템 이름 → 개수
var bag: Dictionary = {}
## 이미 주운 자리. "고향:12,7" 같은 문자열
var taken: Dictionary = {}
## 지금 어느 여행지에 있나
var here := ""

## 건물 안에 들어가 있는 동안, **나가면 돌아갈 곳.**
##
## 가게마다 안이 다르지 않다 — 문을 연 그 씬 경로와, 문 앞에 서 있던
## 칸만 기억해 두면 나올 때 그 자리 그대로 세울 수 있다.
var exit_scene := ""
var exit_tile := Vector2i(-1, -1)
## 다음 씬이 시작할 때 **여기서 시작하라**는 지시. 실내에서 나올 때만
## 쓴다. 보통의 여행(정류장 이동)은 이 값을 건드리지 않고, 그 씬은
## 늘 하던 대로 `spawn_tile()` 에서 시작한다.
var pending_spawn := Vector2i(-1, -1)

## 인연 → 마음 칸 (0~5). 숫자는 화면에 절대 안 보여 준다.
var hearts: Dictionary = {}
## 며칠째인가
var day := 1
## 지금 몇 분인가. 아침 6시에 시작해 자정에 하루가 끝난다.
##
## **타입을 적어 둔다.** `:=` 로 두면 `DAY_START` 가 int 라 minutes 도 int 가
## 되는데, 시계는 매 프레임 0.033분씩 더한다. int 면 그게 통째로 잘려 나가
## 시계가 오전 6:00 에 영영 멈춘다. 밤도 안 오고 하루도 안 끝난다.
var minutes: float = DAY_START

const DAY_START := 6 * 60
const DAY_END := 24 * 60
const HEART_MAX := 5


# ── 마음 ──────────────────────────────────────────────────────────────

func heart(folk_id: String) -> int:
	return int(hearts.get(folk_id, 0))


func warm(folk_id: String, by: int = 1) -> void:
	if folk_id == "":
		return
	var h := mini(heart(folk_id) + by, HEART_MAX)
	hearts[folk_id] = h
	heart_up.emit(folk_id, h)


## 몇 군데나 다녀왔나 (고향은 안 센다)
var visited: Dictionary = {}

# ── 여행자 ────────────────────────────────────────────────────────────
#
# 붙박이는 그 마을에 산다. **여행자는 나처럼 돌아다닌다.**
# 부산에서 만난 너구리를 파리에서 다시 만나는 것 — 이 게임은 그 한
# 순간을 위해 나머지가 다 있다 (`docs/redesign-journey.md` 5절).
#
# 우연에 맡기면 영영 안 만날 수도 있다. 그래서 **자리를 정해 놓고 옮긴다.**
# 플레이어에겐 우연으로 보이지만 실제로는 반드시 일어난다.

## 여행자가 지금 어디 있나
var wanderer_place := "윤슬"
## 어디서 만났었나
var wanderer_seen: Dictionary = {}
## 여행자가 갈 수 있는 곳 (고향은 뺀다 — 남의 고향에 갈 리 없다)
##
## **2탄 다섯 곳도 돈다.** 여기 빠져 있던 동안 게임 후반 절반에서
## 재회가 한 번도 안 일어났다 — 이 게임의 심장이 반 토막이었다.
const WANDERER_STOPS := ["윤슬", "볕뉘", "가풀재", "하늬섬",
	"굽이나루", "방울못", "갈밭머리", "솔은재", "꽃눈벌"]


func wanderer_here(place: String) -> bool:
	return wanderer_place == place


## 마지막으로 **재회 인사를 나눈** 곳. 같은 곳에서 저장을 다시 불러도
## 재회가 두 번 일어나지 않게 한다.
##
## **말을 건 순간에만 적는다.** 여태는 마을에 닿아 지도를 까는 순간
## 적었는데, 그러면 재회 대본이 통째로 증발할 수 있었다 — 대본은
## 저장되지 않는 `Folk.once` 에만 담기는데 이 줄은 저장되기 때문이다.
## 셋만 어긋나면 됐다:
##
## - 너구리를 못 보고 마을을 떠나면 그 단계 대본이 그냥 사라졌다
## - 말 걸기 전에 홈 버튼을 누르면(그 즉시 저장된다) 다시 켰을 때
##   `is_reunion` 이 거짓이라 평소 대사만 나왔다
## - 가게에 들어갔다 나오기만 해도 지도가 다시 깔리면서 같은 일이 났다
##
## 게임 전체에서 두 번뿐인 제목 대사가 든 셋째 재회 대본까지 그렇게
## 조용히 없어질 수 있었다. 이제 **말을 걸어야 소모된다** — 안 만나고
## 떠나면 다음 재회에서 같은 단계가 다시 나온다.
var last_met := ""


## 전에 만난 적이 있는 이를 또 만났나. 어디서든 재회는 재회다 —
## 단, 이미 여기서 재회 인사를 나눴으면 그냥 같이 있는 것이다.
##
## **다른 데서 만난 적이 있어야 재회다.** 여태는 이 판정을 `last_met`
## 이 겸했다 — 마을에 닿는 순간 그 줄이 적히니 첫 만남도 저절로
## 걸러졌다. 그 줄이 "말을 걸어야 적히는 것" 으로 바뀌었으므로,
## 첫 만남인지는 여기서 직접 가린다.
func is_reunion(place: String) -> bool:
	if not wanderer_here(place) or place == last_met:
		return false
	for seen in wanderer_seen:
		if String(seen) != place:
			return true
	return false


## 그 자리에 여행자가 있었다는 것만 적는다. 말은 아직 안 걸었다.
## 첫 만남 판정(`is_reunion` 의 `wanderer_seen`)이 이걸로 선다.
func meet_wanderer(place: String) -> void:
	wanderer_seen[place] = true


## 재회 인사를 실제로 나눴다. 여기서 대본 한 단계가 소모된다.
func tell_reunion(place: String) -> void:
	if place == "" or place == last_met:
		return
	last_met = place
	reunions += 1


## 이 마을에서 **재회를 알아챈 것까지** 해 둔 곳. 말은 아직 안 걸었다.
##
## 마음 한 칸은 "다시 만난 것 자체가 사건이라" 말을 안 걸어도 오른다.
## 그런데 그 판정을 `last_met` 이 겸하고 있던 것을 떼어 냈으므로
## (`last_met` 은 이제 말을 걸어야 적힌다), 지도를 다시 깔 때마다
## 마음이 오르지 않게 막을 표시가 따로 있어야 한다 — 가게에 들락거리면
## 칸이 계속 차는 셈이 된다.
var reunion_noticed := ""


## 몇 번 떠났나. 여행자를 옮기는 박자를 여기서 센다.
var departures := 0

## 완료를 이미 알린 할 일들. **저장하지 않는다** — 이번 실행에서만 쓴다.
##
## HUD 안에 두면 안 된다. "가게 들어가 보기" 는 문을 지나는 순간 끝나는데
## 그 순간 화면이 갈려 HUD 가 새로 만들어진다 — 새 HUD 는 아무것도 모르니
## **이미 끝난 것으로 치고 조용히 넘어갔다.** 그래서 그 하나만 영영
## "다 했어요" 가 안 떴다. 화면을 넘나들어도 남아 있어야 한다.
var announced: Dictionary = {}
## 첫 한 번은 조용히 기준만 잡는다 (앱을 켜자마자 우르르 뜨지 않게).
var announce_ready := false
## 몇 번 다시 만났나. 재회 대사의 단계가 이걸 따라간다.
var reunions := 0
## 마지막 재회(혹은 첫 만남) 뒤로 몇 번 떠났나.
var since_reunion := 0


## 내가 떠나면 그 사람도 떠난다.
##
## 내가 가는 곳으로 **따라오게** 하지 않는다. 그건 우연이 아니라 스토킹이다.
## 그렇다고 그냥 한 칸씩 돌게 두면 안 된다 — 한동안 그렇게 뒀는데,
## 목록 순서대로 여행하는 가장 자연스러운 진행에서 여행자가 늘 한 칸
## 앞서서 **한 번도 못 만났다.** 이 게임의 심장이 안 뛰었다.
##
## 그래서 평소엔 제 갈 길로 돌되, **세 번에 한 번은 겹친다** — 그것도
## 아직 거기서 만난 적이 없을 때만. 플레이어에겐 우연으로 보이지만
## 실제로는 반드시 일어난다. 재회 대사가 세 단계인 것과 박자를 맞췄다.
func move_wanderer(dest: String = "", from: String = "") -> void:
	# 프롤로그를 떠날 때는 안 움직인다. 여기서 한 칸 밀면 첫 여행지에서
	# 스쳐 지나가고, 그 뒤로 계속 어긋난다.
	if from == "잿마루":
		return
	departures += 1
	# **마지막 재회에서 두 번 떠나면 겹친다.** 처음엔 "세 번째 떠남마다 +
	# 안 가 본 곳에서만" 이었는데, 그러면 재회가 3·6·9번째 떠남에 왔다 —
	# 15~20분짜리 게임에서 제목이 나오는 줄이 30분 뒤에 있었다. 그리고
	# 네 곳을 다 돌면 재회가 영영 끝났다. 넷째부터는 놀람이 아니라
	# 익숙함으로 계속 만난다.
	since_reunion += 1
	if since_reunion >= 2 and WANDERER_STOPS.has(dest):
		wanderer_place = dest
		return
	var i := WANDERER_STOPS.find(wanderer_place)
	if i < 0:
		i = 0
	var n := WANDERER_STOPS.size()
	var nxt: String = WANDERER_STOPS[(i + 1) % n]
	if nxt == dest:
		# 겹칠 차례가 아닌데 겹치면 재회가 싸구려가 된다.
		nxt = WANDERER_STOPS[(i + 2) % n]
	wanderer_place = nxt


## 다음 마을에 닿으면 아침부터 시작한다.
##
## 이게 없으면 밤 11시에 회사를 나온 사람이 **첫 여행지에 밤 11시에
## 도착해서 24초 만에 시계가 자정에 멈춘다.** 거기서 빠져나오는 길은
## 자는 것뿐인데, 처음 하는 사람은 잘 줄도 모른다.
##
## 오가는 데 시간이 걸린다고 치면 아침 도착이 자연스럽기도 하다.
var arriving := false


## 몇 번 도착했나. `visited` 와 다르다 — 같은 곳에 또 와도 하나 는다.
var arrivals := 0


func visit(place: String) -> void:
	if place == "":
		return
	arrivals += 1
	if place != "고향":
		visited[place] = true


func places_visited() -> int:
	return visited.size()


# ── 편지 · 엽서 · 사진 ────────────────────────────────────────────────

## 엄마 편지. 안 읽어도 벌이 없다 (`docs/story-journey.md` 5절).
var letters: Array = []
## 마음 다섯 칸을 채운 인연에게서 온 엽서. folk_id → 이름
var postcards: Dictionary = {}
## 직접 찍은 사진
var photos: Array = []

## 마을 퀘스트가 쓰는 자유 표시. "윤슬:등대" → true 처럼 자유 키를 쓴다.
##
## 퀘스트마다 저장 필드를 새로 만들지 않으려고 한 딕셔너리에 다 담는다 —
## `docs/quest-journey.md` 8절이 세운 원칙이다. 대화·줍기·사진은 이미
## 있는 기록(마음 칸·`taken`·`photos`)에서 다시 계산하고, **새로 계산할
## 수 없는 것**(어느 자리를 밟아 봤는지, 가게에 들어가 봤는지, 그 마을
## 호스텔에서 자 봤는지)만 여기 남긴다.
var quest_flags: Dictionary = {}


## 언제 마쳤는지도 같이 적는다. "다음 날 다시 오기" 같은 약속을
## 판정하려면 **며칠째에 했는지**를 알아야 한다.
var quest_days: Dictionary = {}

## 채집터마다 **마지막으로 새로 채운 날.** 그 자리에 들어섰을 때 오늘
## 날짜와 다르면 어제 걷어 간 것을 다시 채운다 (`clear_taken_for`).
## "다시 와 보면 뭔가 있다" 는 이 게임 곳곳의 규칙과 같다 — 잠긴 편지함이
## 아니라 매일 다시 채워지는 물가다.
var gather_day: Dictionary = {}

func mark_quest(key: String) -> void:
	if not quest_flags.has(key):
		quest_days[key] = day
	quest_flags[key] = true


## 그 일을 마친 날. 아직 안 했으면 아주 큰 수.
## 지금이 하루의 어느 참인가. `Place` 에만 있던 것을 여기로 올렸다 —
## 할 일 목록도 시간대를 봐야 한다 ("저녁에 등대곶").
func day_part() -> String:
	var h := minutes / 60.0
	if h < 11.0:
		return "아침"
	if h < 17.0:
		return "낮"
	return "저녁"


func quest_day(key: String) -> int:
	return int(quest_days.get(key, 99999))


func quest_done(key: String) -> bool:
	return quest_flags.get(key, false)


## 이미 몇 통 보냈나
var letters_sent := 0

## 여행지 세 곳마다 한 통. 짧다. 엄마가 먼저고(원래 있던 다섯 통,
## 순서를 안 바꾼다), 그다음은 마을에서 만난 이들과 가족이 한 통씩
## 보낸다(`docs/planning/content_brainstorm_plan.md` 2-4절) — 붙잡는
## 말투가 아니라 "안 와도 괜찮다" 쪽으로 쓴다.
const LETTERS := [
	{"who": "엄마", "text": "밥은 먹고 다니니."},
	{"who": "엄마", "text": "김치 담갔다. 너 좋아하는 거."},
	{"who": "엄마", "text": "바쁘면 안 와도 된다."},
	{"who": "엄마", "text": "아버지가 마당 손봤다."},
	{"who": "엄마", "text": "감 익었더라."},
	{"who": "가게 할머니",
		"text": "오늘도 바람이 좋아. 지도는 잘 쓰고 있지? 없어도 그만이지만."},
	{"who": "갈매기 소년",
		"text": "등대는 밤에 더 예뻐요. 다음에 또 와서 보면 되고, 안 와도 괜찮아요."},
	{"who": "빵집 아주머니", "text": "빵은 그대로야. 자네가 없어도 여긴 똑같이 돌아가."},
	{"who": "능 지키는 아이",
		"text": "저는 아직 여기 있어요. 언젠가 나가 볼 거지만, 오늘은 아니고요."},
	{"who": "국수집 아저씨", "text": "국물은 늘 있으니 생각나면 와. 안 그래도 상관없고."},
	{"who": "부두 청년", "text": "오늘 노을이 좋았어요. 혼자 봤는데, 그것도 나쁘지 않았어요."},
	{"who": "귤 파는 할머니", "text": "바람이 세졌어. 그래도 여기는 늘 이래."},
	{"who": "자전거 탄 아이",
		"text": "섬 한 바퀴 기록 세웠어요. 다음에 같이 재 볼래요? 아님 말고요."},
	{"who": "배낭 멘 너구리", "text": "어디쯤 있어요? 나도 몰라요, 나도 어디쯤인지."},
	{"who": "엄마", "text": "국은 늘 있어. 먹고 싶을 때 와, 급할 거 없다."},
	{"who": "아빠", "text": "…잘 지내냐."},
	{"who": "동생", "text": "나도 언젠가 나가 볼래. 덕에 용기가 좀 생겼어."},
	# 2탄 선택형 서브 NPC들. 필수 인연이 아니라서 말을 안 걸어도
	# 이상하지 않게 썼다 — 도감 빈칸처럼 "놓쳤다"는 느낌을 안 주려고,
	# 조건 없이 같은 자리에 얹었다(`docs/planning/` 세 번째 브레인
	# 스토밍 결과 — 필수 재회로 만들면 너구리의 자리가 흐려진다는 판단).
	{"who": "돌 위의 수달",
		"text": "강가 돌은 오늘도 조금 더 매끈해졌어요. 가만히 있어도 물은 할 일을 하더라고요."},
	{"who": "솔숲의 다람쥐",
		"text": "솔은재 길에 솔방울을 하나 더 묻어 두었어요. 찾으러 오라는 뜻은 아니에요."},
	{"who": "물가의 개구리",
		"text": "오늘은 두 번 울었어요. 한 번은 비슷했고, 한 번은 조금 달랐어요."},
	{"who": "갈대 사이의 고라니",
		"text": "갈대 사이 자리는 오늘도 비어 있었어요. 누가 와도 놀라지 않으려고요."},
]


## 여행지를 다녀올 때마다 살핀다. 세 곳마다 한 통.
##
## 가라고 시키지 않는 대신 편지가 쌓인다. 화살표도 느낌표도 안 쓴다 —
## 세 통쯤 쌓이면 대부분 알아서 간다.
## 세는 것이 **다녀온 곳 수가 아니라 도착 횟수**인 이유:
## 1탄에 여행지가 넷뿐이라 `places_visited()` 는 아무리 다녀도 4 에서 멈춘다.
## 세 곳마다 한 통이면 편지가 평생 한 통이었다. 같은 곳에 다시 가는 것도
## 떠난 것이니, 떠난 횟수로 센다.
## 보낸 사람 이름 → folk_id. **안 만난 이의 편지는 아직 안 보낸다** —
## 모르는 사람에게서 편지가 오면 다정한 게 아니라 이상하다. 버리지는
## 않는다: 만나고 나면 다음 차례에 온다. 필수 인연·가족은 늘 보낸다.
const LETTER_NEEDS_MEET := {
	"돌 위의 수달": "gu_otter", "솔숲의 다람쥐": "so_squirrel",
	"물가의 개구리": "ba_frog", "갈대 사이의 고라니": "ga_deer",
}


func _letter_ok(entry: Dictionary) -> bool:
	var id: String = String(LETTER_NEEDS_MEET.get(
		String(entry.get("who", "")), ""))
	return id == "" or heart(id) > 0


func maybe_letter() -> void:
	var due := int(arrivals / 2)
	while letters_sent < due and letters_sent < LETTERS.size():
		# 다음 보낼 것을 고른다. 아직 못 보낼 것(안 만난 이의 것)은
		# 뒤로 미루고, 그다음 보낼 수 있는 것을 앞당긴다.
		var pick := -1
		for i in range(letters_sent, LETTERS.size()):
			if letters_skipped_has(i):
				continue
			if _letter_ok(LETTERS[i]):
				pick = i
				break
		if pick < 0:
			return          # 지금은 보낼 수 있는 게 없다. 다음 도착 때 다시.
		# 앞당겨 보냈으면 그 사이 것들은 "건너뛴 것" 으로 적어 둔다.
		for i in range(letters_sent, pick):
			if not letters_skipped.has(i):
				letters_skipped.append(i)
		var entry: Dictionary = LETTERS[pick]
		letters.append({"who": String(entry.get("who", "엄마")),
			"text": String(entry.get("text", "")), "day": day, "read": false})
		letters_sent = pick + 1
		letter_came.emit(String(entry.get("text", "")))
		AudioManager.message_arrive()
		# 건너뛰었던 것 중 이제 보낼 수 있는 게 있으면 이번에 같이 온다 —
		# 늦게 만난 인연의 편지가 밀린 채 영영 안 오지 않게.
		for i in letters_skipped.duplicate():
			if _letter_ok(LETTERS[i]):
				letters_skipped.erase(i)
				var e2: Dictionary = LETTERS[i]
				letters.append({"who": String(e2.get("who", "엄마")),
					"text": String(e2.get("text", "")), "day": day, "read": false})
				letter_came.emit(String(e2.get("text", "")))


## 건너뛴 편지 차례들. 만나면 그때 온다.
var letters_skipped: Array = []


func letters_skipped_has(i: int) -> bool:
	return letters_skipped.has(i)


func unread_letters() -> int:
	var n := 0
	for l in letters:
		if not bool(l.get("read", false)):
			n += 1
	return n


func read_letters() -> void:
	for l in letters:
		l["read"] = true


## 고향에 다녀오면 편지는 다 읽은 것으로 친다 — 직접 만났으니까.
func came_home() -> void:
	read_letters()


## 엽서에 **글이 있어야 한다.**
##
## 한동안 이름만 적어 뒀더니, 평상에 앉아 넘겨 보는 장면이 그냥
## 이름 목록이었다. 여행 끝에 읽는 것이 명단이면 안 된다.
## 여섯 줄로는 27명이 돌려 쓰다 여덟 명이 같은 문장을 받았다 —
## 여행 끝에 읽는 엽서첩이 복사지처럼 보였다. 열두 줄로 늘린다.
const POSTCARD_LINES := [
	"그때 그 자리, 아직 그대로예요.",
	"바람이 좋아서 문득 생각났어요.",
	"잘 지내요? 여긴 여전해요.",
	"다음에 오면 그거 또 해요.",
	"혼자 걷다 보면 여기 생각날 거예요.",
	"오늘 노을이 그날이랑 비슷했어요.",
	"별일은 없어요. 그게 제일 좋은 소식이죠.",
	"당신이 서 있던 자리에 오늘은 볕이 들었어요.",
	"길이 여러 갈래면 당신 생각이 나요.",
	"천천히 와요. 여긴 급한 게 없어요.",
	"그날 웃던 얼굴, 가끔 떠올라요.",
	"비 오는 날엔 손님이 없어서 좋고, 개면 개서 좋아요.",
]


func give_postcard(folk_id: String, who: String) -> void:
	if folk_id == "" or postcards.has(folk_id):
		return
	# 누가 어떤 줄을 쓰는지는 늘 같아야 한다. 다시 켰을 때 글이 바뀌면
	# 받아 둔 엽서가 아니라 매번 새로 쓰이는 종이가 된다.
	var h := 0
	for i in folk_id.length():
		h = (h * 31 + folk_id.unicode_at(i)) % 100003
	# 문장은 **받은 순서**대로 돌린다. 이름 해시로 고르던 때는 12줄로
	# 늘려도 우연히 여섯 명이 같은 줄에 몰렸다 — 순서면 열두 장까지는
	# 전부 다르다. 글은 받는 순간 저장되므로 옛 엽서는 안 바뀐다.
	postcards[folk_id] = {
		"who": who,
		"text": POSTCARD_LINES[postcards.size() % POSTCARD_LINES.size()],
		"place": here,
		"day": day,
	}
	postcard_came.emit(folk_id)
	AudioManager.souvenir_get()


## 엽서 한 장을 사람이 읽는 두 줄로. 옛 저장본(이름 문자열)도 받아 준다.
func postcard_text(folk_id: String) -> String:
	var c = postcards.get(folk_id, null)
	if c == null:
		return ""
	if c is Dictionary:
		var place := String(c.get("place", ""))
		var head := String(c.get("who", "")) + (("  ·  " + place) if place != "" else "")
		return "%s\n%s" % [head, String(c.get("text", ""))]
	return String(c)


func take_photo(place: String, subject: String) -> Dictionary:
	var p := {
		"place": place,
		"day": day,
		"time": time_text(),
		"subject": subject,
	}
	photos.append(p)
	photo_taken.emit(p)
	return p


# ── 하루 ──────────────────────────────────────────────────────────────

func time_text() -> String:
	# 하루 끝(24:00)은 1440 이다. 12 로 나눈 나머지가 0 이라 그냥 두면
	# **한낮과 똑같이 "오후 12:00"** 으로 찍힌다. 시계가 멈춘 채 정오라고
	# 우기는 꼴이라, 그때만 따로 적는다.
	if minutes >= DAY_END:
		return "자정"
	var h := int(minutes / 60.0)
	var m := int(minutes) % 60
	var ampm := "오전" if h < 12 else "오후"
	var hh := h % 12
	if hh == 0:
		hh = 12
	return "%s %d:%02d" % [ampm, hh, m]


## 밤인가 (화면을 어둡게 할지)
func night_amount() -> float:
	# 오후 5시부터 어두워지기 시작해 밤 9시에 가장 어둡다.
	if minutes < 17 * 60:
		return 0.0
	return clampf((minutes - 17 * 60) / float(4 * 60), 0.0, 1.0)


## 마을에 닿았다. 하루가 넘어갔으면 새 아침으로.
func arrive() -> void:
	if not arriving:
		return
	arriving = false
	if minutes >= 20 * 60:
		day += 1
		day_passed.emit(day)
	minutes = DAY_START


func advance_time(mins: float) -> void:
	minutes = minf(minutes + mins, DAY_END)


## 시간대 문턱으로 곧장 건너뛴다. "기다리기" 상호작용이 쓴다 —
## 등대곶에서 "저녁에 다시 오세요" 를 실시간 3분(9시간어치)을 서서
## 기다리게 했더니 무리라는 말을 들었다. 이미 그 시간대거나 지났으면
## 아무 일도 안 한다 - **되돌리지는 않는다.**
const DAY_PART_START := {"아침": 0.0, "낮": 11.0 * 60.0, "저녁": 17.0 * 60.0}

func skip_to_day_part(part: String) -> void:
	var target: float = DAY_PART_START.get(part, -1.0)
	if target < 0.0:
		return
	minutes = minf(maxf(minutes, target), DAY_END)


func day_is_over() -> bool:
	return minutes >= DAY_END


func sleep() -> void:
	day += 1
	minutes = DAY_START
	day_passed.emit(day)


func pick(item: String, count: int = 1) -> void:
	bag[item] = int(bag.get(item, 0)) + count
	picked.emit(item, bag[item])


func count(item: String) -> int:
	return int(bag.get(item, 0))


func total() -> int:
	var n := 0
	for k in bag:
		n += int(bag[k])
	return n


func kinds() -> int:
	return bag.size()


## 그 자리 것을 이미 주웠나
func is_taken(place: String, t: Vector2i) -> bool:
	return taken.has(_key(place, t))


func mark_taken(place: String, t: Vector2i) -> void:
	taken[_key(place, t)] = true


## 그 자리에서 주운 기록을 통째로 지운다. **채집터를 다시 채우는 데만
## 쓴다** — 마을 본바닥의 줍기(도토리·조약돌 같은)는 한 번 주우면
## 영영 그대로다. 문자열 접두어로 가르니, 채집터 이름과 본마을 이름이
## 겹치면 안 된다(둘 다 마을 이름을 그대로 안 쓰는 이유이기도 하다).
func clear_taken_for(place: String) -> void:
	for k in taken.keys():
		if String(k).begins_with(place + ":"):
			taken.erase(k)


func _key(place: String, t: Vector2i) -> String:
	return "%s:%d,%d" % [place, t.x, t.y]


# ── 저장 ──────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"bag": bag.duplicate(),
		"taken": taken.duplicate(),
		"gather_day": gather_day.duplicate(),
		"here": here,
		"hearts": hearts.duplicate(),
		"day": day,
		"minutes": minutes,
		"visited": visited.duplicate(),
		"wanderer_place": wanderer_place,
		"wanderer_seen": wanderer_seen.duplicate(),
		"letters": letters.duplicate(true),
		"letters_sent": letters_sent,
		"letters_skipped": letters_skipped,
		"postcards": postcards.duplicate(true),
		"arrivals": arrivals,
		"departures": departures,
		"reunions": reunions,
		"since_reunion": since_reunion,
		"last_met": last_met,
		"reunion_noticed": reunion_noticed,
		"photos": photos.duplicate(true),
		"exit_scene": exit_scene,
		"exit_tile": [exit_tile.x, exit_tile.y],
		"quest_flags": quest_flags.duplicate(),
		"quest_days": quest_days.duplicate(),
	}


## 쿼- 이름을 원래 낱말로 되돌렸다 (쿼이스크림 -> 아이스크림).
## 이미 배달된 편지와 엽서에는 옛 이름이 **글자 그대로** 박혀 저장돼
## 있어서, 지난 세이브를 그대로 두면 한 배낭 안에서 이름이 두 가지가
## 된다. 불러올 때 조용히 갈아 끼운다.
const OLD_QUO := {
	"쿼스텔": "호스텔", "쿼빵집": "빵집", "쿼면집": "국수집",
	"쿼귤": "귤", "쿼빵": "빵", "쿼이스크림": "아이스크림",
	"쿼메라": "카메라", "쿼장": "시장", "쿼차방": "찻집",
}

## 마을 이야기(마음매듭)로 갈아엎기 전의 세이브를 이어 붙인다.
##
## **이미 한 일을 다시 시키지 않는다.** 옛 판에는 "등대곶에 가서 사진
## 찍기" 에 시간대 조건이 없었다. 새 판은 저녁을 요구하므로, 옛 표시가
## 있으면 저녁에 본 것으로 쳐 준다. 부두 끝도 마찬가지다.
##
## 그리고 **이미 윤슬을 떠난 사람**은 매듭을 통째로 마친 것으로 둔다 —
## 안 그러면 다음 마을이 도로 잠긴다.
func _migrate_knots() -> void:
	if quest_done("윤슬:등대") and not quest_done("윤슬:등대@저녁"):
		for ph in photos:
			if String(ph.get("place", "")) == "윤슬":
				mark_quest("윤슬:등대@저녁")
				break
	if quest_done("윤슬:부두끝"):
		mark_quest("윤슬:부두끝@아침")
		mark_quest("윤슬:부두끝@저녁")
	var moved_on := false
	for v in ["볕뉘", "가풀재", "하늬섬", "굽이나루", "방울못",
			"갈밭머리", "솔은재", "꽃눈벌"]:
		if visited.has(v):
			moved_on = true
	if moved_on:
		# **배낭은 건드리지 않는다.** 불러올 때 물건이 늘면 "저장하고
		# 불러와도 그대로" 가 깨진다. 대신 매듭 첫 단계를 지났다는
		# 표시만 남긴다.
		mark_quest("윤슬:매듭:1")
		mark_quest("윤슬:등대@저녁")
		mark_quest("윤슬:부두끝@아침")
		mark_quest("윤슬:부두끝@저녁")
		mark_quest("윤슬:매듭:3")
		mark_quest("윤슬:샛길:고르기")


func _rename_old_quo() -> void:
	for l in letters:
		for k in ["who", "text"]:
			var v := String(l.get(k, ""))
			for a in OLD_QUO:
				v = v.replace(String(a), String(OLD_QUO[a]))
			l[k] = v
	for k2 in postcards.keys():
		var pv: Variant = postcards[k2]
		if pv is String:
			var t := String(pv)
			for a2 in OLD_QUO:
				t = t.replace(String(a2), String(OLD_QUO[a2]))
			postcards[k2] = t


func from_dict(d: Dictionary) -> void:
	bag = d.get("bag", {}).duplicate() if d.get("bag") is Dictionary else {}
	taken = d.get("taken", {}).duplicate() if d.get("taken") is Dictionary else {}
	gather_day = d.get("gather_day", {}).duplicate() \
		if d.get("gather_day") is Dictionary else {}
	here = String(d.get("here", ""))
	hearts = d.get("hearts", {}).duplicate() if d.get("hearts") is Dictionary else {}
	day = maxi(1, int(d.get("day", 1)))
	minutes = clampf(float(d.get("minutes", DAY_START)), DAY_START, DAY_END)
	visited = d.get("visited", {}).duplicate() if d.get("visited") is Dictionary else {}
	wanderer_place = String(d.get("wanderer_place", "윤슬"))
	wanderer_seen = d.get("wanderer_seen", {}).duplicate() \
		if d.get("wanderer_seen") is Dictionary else {}
	letters = d.get("letters", []).duplicate(true) if d.get("letters") is Array else []
	letters_sent = int(d.get("letters_sent", 0))
	letters_skipped = d.get("letters_skipped", [])
	postcards = d.get("postcards", {}).duplicate(true) \
		if d.get("postcards") is Dictionary else {}
	arrivals = maxi(0, int(d.get("arrivals", 0)))
	departures = maxi(0, int(d.get("departures", 0)))
	reunions = maxi(0, int(d.get("reunions", 0)))
	since_reunion = maxi(0, int(d.get("since_reunion", 0)))
	last_met = String(d.get("last_met", ""))
	reunion_noticed = String(d.get("reunion_noticed", ""))
	photos = d.get("photos", []).duplicate(true) if d.get("photos") is Array else []
	_rename_old_quo()
	exit_scene = String(d.get("exit_scene", ""))
	var et: Array = d.get("exit_tile", [-1, -1])
	exit_tile = Vector2i(int(et[0]), int(et[1])) if et.size() == 2 else Vector2i(-1, -1)
	quest_flags = d.get("quest_flags", {}).duplicate() \
		if d.get("quest_flags") is Dictionary else {}
	quest_days = d.get("quest_days", {}).duplicate() \
		if d.get("quest_days") is Dictionary else {}
	_migrate_knots()
	# **이 갱신 전에 만든 세이브는 지도·카메라 개념이 없었다** — 그때는
	# 둘 다 처음부터 켜져 있었으니까. `quest_flags` 자체가 없다는 건 이
	# 세이브가 그 시절 것이라는 뜻이다. 이미 여행 중이던 사람에게서
	# 갑자기 미니맵·사진 버튼을 뺏으면 그건 새 기능이 아니라 퇴보로
	# 느껴진다 — 자동으로 쥐여 준다.
	if not d.has("quest_flags"):
		if count("map") <= 0:
			pick("map")
		if count("camera") <= 0:
			pick("camera")


func reset() -> void:
	bag = {}
	taken = {}
	gather_day = {}
	here = ""
	hearts = {}
	day = 1
	minutes = DAY_START
	visited = {}
	wanderer_place = "윤슬"
	wanderer_seen = {}
	letters = []
	letters_sent = 0
	letters_skipped = []
	postcards = {}
	photos = []
	arrivals = 0
	departures = 0
	reunions = 0
	since_reunion = 0
	last_met = ""
	reunion_noticed = ""
	exit_scene = ""
	exit_tile = Vector2i(-1, -1)
	pending_spawn = Vector2i(-1, -1)
	quest_days = {}
	# 이게 빠져 있었다. 기록을 지워도 "가게에 들어가 봤다"·"능을 걸었다"
	# 같은 표시가 그대로 남아, 새로 시작해도 그 퀘스트가 이미 done 이었다.
	quest_flags = {}
	announced = {}
	announce_ready = false
