extends Node
## 배운 단어를 모아 두는 곳 (오토로드 `WordDex`).
##
## 외운 단어가 아니라 **써 본 단어**를 모은다. 그래서 등록은 마법이 실제로
## 발동했을 때만 일어난다. 어디서 썼는지도 함께 남겨 둔다 — 나중에 도감에서
## 그 장면을 다시 보여 주려면 문맥이 있어야 한다.

signal word_learned(entry: Dictionary)
signal tier_changed(tier: int)

## 배운 단어. word(소문자) → {ko, pron, emoji, note, at, count}
var learned: Dictionary = {}

## 지금 난이도 (WordData.Tier). 기본은 나무 — 이야기 톤을 초등 5~6학년에 맞췄다.
var tier: int = WordData.Tier.TREE

## 끝낸 장면 id
var cleared_scenes: Array[String] = []


func learn(word: String, info: Dictionary, note: String = "") -> void:
	var key := word.to_lower()
	if learned.has(key):
		learned[key]["count"] = int(learned[key].get("count", 1)) + 1
		return
	learned[key] = {
		"ko": info.get("ko", ""),
		"pron": info.get("pron", ""),
		"emoji": info.get("emoji", ""),
		"note": note,
		"at": int(Time.get_unix_time_from_system()),
		"count": 1,
	}
	word_learned.emit(learned[key])


func knows(word: String) -> bool:
	return learned.has(word.to_lower())


func count() -> int:
	return learned.size()


func set_tier(t: int) -> void:
	t = clampi(t, 0, WordData.TIER_NAMES.size() - 1)
	if t == tier:
		return
	tier = t
	tier_changed.emit(t)


func mark_cleared(scene_id: String) -> void:
	if scene_id != "" and not cleared_scenes.has(scene_id):
		cleared_scenes.append(scene_id)


func is_cleared(scene_id: String) -> bool:
	return cleared_scenes.has(scene_id)


# ── 저장 ──────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"learned": learned.duplicate(true),
		"tier": tier,
		"cleared": cleared_scenes.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	learned = d.get("learned", {}).duplicate(true) if d.get("learned") is Dictionary else {}
	tier = clampi(int(d.get("tier", WordData.Tier.TREE)), 0, WordData.TIER_NAMES.size() - 1)
	cleared_scenes = []
	for s in d.get("cleared", []):
		cleared_scenes.append(String(s))


func reset() -> void:
	learned = {}
	cleared_scenes = []
	tier = WordData.Tier.TREE
