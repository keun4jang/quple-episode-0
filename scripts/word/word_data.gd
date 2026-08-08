class_name WordData
extends RefCounted
## 마법영자문의 단어와 장면 데이터.
##
## 단어를 나열하는 건 쉽다. 어려운 건 **그 단어를 써야만 풀리는 장면**이다.
## 그래서 여기서는 단어와 장면을 떼어 놓지 않는다. 한 항목이 곧 한 사건이다.
##
## 지금은 장면 하나뿐이다. 손맛을 먼저 보고 나머지를 붙인다.


## 난이도. 이야기는 넷 다 같고, 마법을 거는 방법만 다르다.
enum Tier {
	SEED,      # 씨앗 — 초1~2. 그림 셋 중 고르기
	SPROUT,    # 새싹 — 초3~4. 빈칸 채우기
	TREE,      # 나무 — 초5~6. 철자 전부 놓기
	MOUNTAIN,  # 산   — 중1~3. 뜻만 보고 전부 놓기
}

const TIER_NAMES := ["씨앗", "새싹", "나무", "산"]
const TIER_HINTS := [
	"초등 1~2학년",
	"초등 3~4학년",
	"초등 5~6학년",
	"중학생",
]


## 장면 하나 = 단어 하나.
##
## before/after 는 [누구, 표정, 대사] 다. 누구는 "leader" 또는 "partner",
## 표정은 face_cut.gd 의 12종 중 하나.
const SCENES: Array[Dictionary] = [
	{
		"id": "ice_wall",
		"word": "fire",
		"ko": "불",
		"pron": "파이어",
		"emoji": "🔥",
		"bg": "ice",
		"before": [
			["partner", "cold", "으… 차가워!"],
			["leader", "think", "얼음이 길을 막았어."],
			["leader", "idea", "이럴 땐…!"],
		],
		"prompt": "얼음을 녹이려면?",
		# 씨앗 단계에서 보여 줄 그림 셋. 첫 번째가 정답이 아니어도 된다 — 섞는다.
		"choices": [
			{"word": "fire", "ko": "불", "emoji": "🔥"},
			{"word": "water", "ko": "물", "emoji": "💧"},
			{"word": "grow", "ko": "자라다", "emoji": "🌱"},
		],
		# 철자 놓기에 섞어 둘 방해 철자
		"extra": ["A", "O", "S"],
		"after": [
			["partner", "joy", "따뜻해!"],
			["leader", "proud", "길이 열렸어."],
		],
		"dex_note": "얼음 벽을 녹였어요",
	},
]


static func scene_by_id(id: String) -> Dictionary:
	for s in SCENES:
		if s["id"] == id:
			return s
	return {}


## 이 단계에서 빈칸으로 둘 자리. 나머지는 미리 채워 준다.
##
## 새싹은 앞 절반을 보여 주고 뒤를 묻는다 — 첫 글자를 아는 것과
## 끝을 아는 것은 다른 일이고, 끝이 더 어렵다.
static func blank_slots(word: String, tier: int) -> Array[int]:
	var n := word.length()
	var out: Array[int] = []
	match tier:
		Tier.SPROUT:
			var start := int(ceil(n / 2.0))
			for i in range(start, n):
				out.append(i)
		_:
			for i in range(n):
				out.append(i)
	return out


## 고를 수 있는 철자. 정답 철자 + 방해 철자를 섞어 돌려준다.
##
## 섞는 데 난수를 쓰면 테스트가 흔들리고, 아이가 다시 풀 때마다 자리가
## 바뀌어 헷갈린다. 단어를 씨앗으로 쓴 고정 순서를 만든다.
static func letter_pool(word: String, tier: int, extra: Array) -> Array[String]:
	var need: Array[String] = []
	for i in blank_slots(word, tier):
		need.append(word[i].to_upper())

	var pool: Array[String] = need.duplicate()
	# 산 단계는 방해 철자를 다 넣고, 나무는 절반만, 아래는 안 넣는다.
	var take := 0
	if tier == Tier.MOUNTAIN:
		take = extra.size()
	elif tier == Tier.TREE:
		take = int(extra.size() / 2.0)
	for i in range(take):
		pool.append(String(extra[i]).to_upper())

	return _stable_shuffle(pool, word)


## 단어 글자값으로 자리를 정하는 뒤섞기. 같은 단어면 늘 같은 순서가 나온다.
static func _stable_shuffle(items: Array[String], seed_word: String) -> Array[String]:
	var out: Array[String] = items.duplicate()
	var h := 7
	for c in seed_word:
		h = (h * 31 + c.unicode_at(0)) % 100003
	for i in range(out.size() - 1, 0, -1):
		h = (h * 1103515245 + 12345) % 2147483647
		var j := h % (i + 1)
		var t := out[i]
		out[i] = out[j]
		out[j] = t
	return out
