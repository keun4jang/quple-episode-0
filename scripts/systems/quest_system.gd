extends Node
## QuestSystem — 퀘스트(의뢰) 진행 관리.
## 독립 메뉴에서 보여준다. 조건을 채우면 즉시 보상이 지급된다.
##
## kind:
##   "kill"  — 특정 그림자 감정을 target_count마리 물리치기
##   "level" — 마음 레벨 도달
##   "story" — Episode0State 진행 단계 도달
##   "coins" — 반짝 조각 모으기
##
## 설계 규칙 (지킬 것):
##   - **시간대·실시간 대기를 요구하는 퀘스트는 만들지 않는다.** "저녁까지 기다리기" 같은
##     조건은 힐링 게임이라도 그냥 지루함만 준다. 플레이어가 지금 당장 할 수 있어야 한다.
##   - 순수 파밍(같은 행동 반복 수집)도 넣지 않는다. 스토리를 따라가다 보면 자연스럽게
##     채워지는 수준으로만 조건을 잡는다.

signal quest_progress(quest_id: String)
signal quest_completed(quest_id: String, reward_text: String)

const QUESTS := {
    "q_first_shadow": {
        "name": "첫 번째 그림자",
        "desc": "그림자 감정을 1마리 물리치기",
        "kind": "kill", "target": "", "count": 1,
        "reward": {"coins": 30, "exp": 10, "items": {"cocoa": 1}},
    },
    "q_anxiety": {
        "name": "잠들 수 있게",
        "desc": "불안을 2마리 걷어내기",
        "kind": "kill", "target": "anxiety", "count": 2,
        "reward": {"coins": 60, "exp": 25, "items": {"cookie": 2}},
    },
    "q_greed": {
        "name": "그만하면 충분해",
        "desc": "욕심을 2마리 물리치기",
        "kind": "kill", "target": "greed", "count": 2,
        "reward": {"coins": 80, "exp": 30, "items": {"clover": 1}},
    },
    "q_level3": {
        "name": "단단해진 마음",
        "desc": "마음 레벨 3 달성",
        "kind": "level", "count": 3,
        "reward": {"coins": 120, "exp": 0, "items": {"star_candy": 1}},
    },
    "q_travel_items": {
        "name": "떠날 준비",
        "desc": "여행 물품 3개 챙기기",
        "kind": "story", "count": 8,  # Episode0State.State.RETURN_BADGE (const라 숫자로 고정)
        "reward": {"coins": 70, "exp": 20, "items": {"energy_drink": 1}},
    },
    "q_overtime": {
        "name": "퇴근합니다",
        "desc": "야근 귀신 물리치기",
        "kind": "kill", "target": "overtime", "count": 1,
        "reward": {"coins": 200, "exp": 80, "items": {"star_candy": 2}},
    },
}

## { quest_id: 진행도 }
var progress: Dictionary = {}
## 완료 후 보상까지 지급된 퀘스트 id
var claimed: Array = []

func _ready() -> void:
    PlayerStats.leveled_up.connect(func(_lv): _check_kind("level"))
    PlayerStats.coins_changed.connect(func(_c): _check_kind("coins"))
    Episode0State.state_changed.connect(func(_s): _check_kind("story"))

func is_claimed(id: String) -> bool:
    return id in claimed

func current_value(id: String) -> int:
    var q: Dictionary = QUESTS[id]
    match q.kind:
        "level":
            return PlayerStats.level
        "coins":
            return PlayerStats.coins
        "story":
            return int(Episode0State.current_state)
        _:
            return progress.get(id, 0)

func is_complete(id: String) -> bool:
    return current_value(id) >= QUESTS[id].count

## 화면에 보여줄 퀘스트 목록 — 진행 중인 것 먼저, 완료한 것은 뒤로
func listed_quests() -> Array:
    var active: Array = []
    var done: Array = []
    for id in QUESTS:
        if is_claimed(id):
            done.append(id)
        else:
            active.append(id)
    return active + done

func on_enemy_defeated(id: String) -> void:
    for qid in QUESTS:
        var q: Dictionary = QUESTS[qid]
        if q.kind != "kill" or is_claimed(qid):
            continue
        if q.target == "" or q.target == id:
            progress[qid] = progress.get(qid, 0) + 1
            quest_progress.emit(qid)
    _check_kind("kill")

func _check_kind(kind: String) -> void:
    for qid in QUESTS:
        if is_claimed(qid) or QUESTS[qid].kind != kind:
            continue
        if is_complete(qid):
            _grant(qid)

func _grant(qid: String) -> void:
    if is_claimed(qid):
        return
    claimed.append(qid)
    var r: Dictionary = QUESTS[qid].reward
    var parts: Array = []
    if r.get("coins", 0) > 0:
        PlayerStats.add_coins(r.coins)
        parts.append("반짝 조각 +%d" % r.coins)
    if r.get("exp", 0) > 0:
        PlayerStats.add_exp(r.exp)
        parts.append("경험치 +%d" % r.exp)
    for item_id in r.get("items", {}):
        PlayerStats.add_item(item_id, r.items[item_id])
        parts.append("%s ×%d" % [ItemDB.item_name(item_id), r.items[item_id]])
    quest_completed.emit(qid, ", ".join(parts))

func to_dict() -> Dictionary:
    return {"progress": progress, "claimed": claimed}

func from_dict(d: Dictionary) -> void:
    progress = d.get("progress", {})
    claimed = d.get("claimed", [])

func reset_new_game() -> void:
    progress = {}
    claimed = []
