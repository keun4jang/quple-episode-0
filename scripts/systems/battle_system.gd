extends Node
## BattleSystem — "그림자 감정"과의 턴제 전투 로직.
##
## 이 게임의 적은 현실에서 눈에 보이지 않는 부정적 감정들이다.
## 불안·욕심·불행·번아웃·비교가 형체를 얻어 나타나고, 쿼카는 마음의 힘으로 걷어낸다.
##
## 로직은 전부 여기에 있고, BattleUI는 여기서 돌려주는 "이벤트 배열"을 순서대로 연출만 한다.
## 이벤트: {"type": ..., ...}
##   text / damage_enemy / damage_player / heal / buff / status / weakness
##   enemy_defeated / victory / defeat / flee_success / flee_fail
##
## 적은 감정마다 다른 행동 패턴을 가진다 — ENEMIES의 "pattern" 필드와 _enemy_plan() 참고.

signal battle_started(enemy: Dictionary)
signal battle_finished(result: String)

## 적 픽셀 아트 문자 → 색 역할
##   X=본체  D=그림자  L=하이라이트  W=눈흰자  K=눈동자  A=강조(포인트)
const ENEMIES := {
    "anxiety": {
        "name": "불안",
        "title": "잠 못 드는 밤의 속삭임",
        "line": "\"내일도 잘할 수 있을까...?\"",
        "pattern": {"kind": "multi", "times": 2, "mult": 0.62, "every": 1},
        "hp": 26, "atk": 8, "def": 2,
        "exp": 18, "coins": 12,
        "weak": "daydream",
        "drop": {"cookie": 0.35},
        "colors": {"X": "#6C7BC4", "D": "#4A57A0", "L": "#9AA6E0", "A": "#C9D2FF"},
        "art": [
            "....XXXX....",
            "..XXXXXXXX..",
            ".XXXXXXXXXX.",
            ".XXWWXXWWXX.",
            ".XXWKXXWKXX.",
            ".XXXXXXXXXX.",
            ".XXXXXXXXXX.",
            ".XXXAAAAXXX.",
            ".XXXXXXXXXX.",
            ".XXXXXXXXXX.",
            ".XX.XX.XX.X.",
            "..X..X..X...",
        ],
    },
    "greed": {
        "name": "욕심",
        "title": "끝없이 더 달라는 목소리",
        "line": "\"더, 더, 더 가져야 해!\"",
        "pattern": {"kind": "drain", "every": 3, "amount": 6},
        "hp": 42, "atk": 11, "def": 4,
        "exp": 30, "coins": 30,
        "weak": "laugh",
        "drop": {"cocoa": 0.3, "clover": 0.1},
        "colors": {"X": "#D9A441", "D": "#A87A26", "L": "#F2CE7A", "A": "#FFF0B8"},
        "art": [
            "...XXXXXX...",
            "..XXXXXXXX..",
            ".XXXXXXXXXX.",
            ".XAAXXXXAAX.",
            ".XAKXXXXAKX.",
            ".XXXXXXXXXX.",
            ".XXXWWWWXXX.",
            ".XXWKKKKWXX.",
            ".XXXWWWWXXX.",
            ".XXXXXXXXXX.",
            "..XXXXXXXX..",
            "...XXXXXX...",
        ],
    },
    "misfortune": {
        "name": "불행",
        "title": "어차피 안 될 거라는 먹구름",
        "line": "\"어차피 안 될 거야.\"",
        "pattern": {"kind": "inflict", "every": 3, "status": "daunted"},
        "hp": 38, "atk": 12, "def": 3,
        "exp": 26, "coins": 22,
        "weak": "hug",
        "drop": {"cocoa": 0.35},
        "colors": {"X": "#4A4458", "D": "#2E2A38", "L": "#6E6682", "A": "#8FD8E0"},
        "art": [
            "....XXXX....",
            "..XXXXXXXX..",
            ".XXXXXXXXXX.",
            "XXXWWXXWWXXX",
            "XXXWKXXWKXXX",
            "XXXXXXXXXXXX",
            "XXXXAAAAXXXX",
            ".XXXXXXXXXX.",
            "..XXXXXXXX..",
            "...A..A..A..",
            "..A..A..A...",
            ".A..A..A....",
        ],
    },
    "comparison": {
        "name": "비교",
        "title": "남의 삶을 비추는 거울",
        "line": "\"쟤는 너보다 잘하잖아.\"",
        "pattern": {"kind": "reflect", "ratio": 0.35},
        "hp": 34, "atk": 10, "def": 3,
        "exp": 22, "coins": 18,
        "weak": "laugh",
        "drop": {"cookie": 0.3},
        "colors": {"X": "#C46C9E", "D": "#934973", "L": "#E4A0C6", "A": "#FFE0F0"},
        "art": [
            "..XXXXXXXX..",
            ".XXXXAXXXXX.",
            "XXWWXAXWWXXX",
            "XXWKXAXWKXXX",
            "XXXXXAXXXXXX",
            "XXXXXAXXXXXX",
            "XXAAXAXAAXXX",
            "XXXXXAXXXXXX",
            ".XXXXAXXXXX.",
            "..XXXAXXXX..",
            "...XXAXXX...",
            "............",
        ],
    },
    "burnout": {
        "name": "번아웃",
        "title": "다 타버린 재의 덩어리",
        "line": "\"...아무것도 하기 싫어.\"",
        "pattern": {"kind": "burst", "every": 3, "mult": 2.0, "inflict": "numb"},
        "hp": 56, "atk": 15, "def": 5,
        "exp": 40, "coins": 38,
        "weak": "hug",
        "drop": {"energy_drink": 0.4, "star_candy": 0.05, "mittens": 0.1},
        "colors": {"X": "#7A7A82", "D": "#4E4E56", "L": "#A6A6B0", "A": "#E86A4A"},
        "art": [
            "..XXXXXXXX..",
            ".XXXXXXXXXX.",
            "XXXXXXXXXXXX",
            "XXWWXXXXWWXX",
            "XXWKXXXXWKXX",
            "XXXXXXXXXXXX",
            "XXXXAAAAXXXX",
            "XXXXXXXXXXXX",
            ".XXXXXXXXXX.",
            "..X.XXXX.X..",
            "..X..XX..X..",
            "............",
        ],
    },
    "loneliness": {
        "name": "외로움",
        "title": "아무도 없는 로비에 남은 메아리",
        "line": "\"다들 집에 갔구나... 나만 아직 여기 남았어.\"",
        "pattern": {"kind": "lonely", "alone_mult": 1.5, "together_mult": 0.5},
        "hp": 36, "atk": 10, "def": 3,
        "exp": 24, "coins": 20,
        "weak": "laugh",
        "drop": {"cocoa": 0.3, "scarf": 0.1, "star_charm": 0.08},
        "colors": {"X": "#4E6478", "D": "#31404F", "L": "#7E96AC", "A": "#FFD9A0"},
        "art": [
            "....XXXX....",
            "...XXXXXX...",
            "..XXXXXXXX..",
            ".XXXXXXXXXX.",
            "XXXDDDDDXXXX",
            "XXDDXXXXDDXX",
            "XXXXXDDXXXXX",
            ".XXXXXXXXXX.",
            "..XXXXXXXX..",
            "...XDDDDX...",
            "....XXXX....",
            "...A....A...",
        ],
    },
    "impatience": {
        "name": "조급함",
        "title": "숨 돌릴 틈도 주지 않는 초침",
        "line": "\"빨리, 빨리… 지금 아니면 늦어버릴 거야.\"",
        "pattern": {"kind": "escalate", "step": 0.18, "max_mult": 2.2},
        "hp": 48, "atk": 13, "def": 3,
        "exp": 34, "coins": 32,
        "weak": "daydream",
        "drop": {"energy_drink": 0.3, "clover": 0.12},
        "colors": {"X": "#E8622E", "D": "#B8451C", "L": "#F5A467", "A": "#FFE066"},
        "art": [
            ".A..XXXX..A.",
            ".XLXXXXXXXX.",
            "XXXXDDDDXXXX",
            "XXWWXXXXWWXX",
            "XWKWXXXXWKWX",
            "XXAXXDDXXAXX",
            "XXXXXDDXXXXX",
            ".XLXXXXXXXX.",
            "AXXXXXXXXXX.",
            "AAXXXXXXXX..",
            "XX......XXX.",
            "A.......XX..",
        ],
    },
    "procrastination": {
        "name": "미루기",
        "title": "내일의 나에게 떠넘기는 손",
        "line": "\"이건 내일의 내가 하면 돼.\"",
        "pattern": {"kind": "lazy", "every": 2},
        "hp": 40, "atk": 7, "def": 4,
        "exp": 26, "coins": 22,
        "weak": "daydream",
        "drop": {"cocoa": 0.3, "cookie": 0.2, "slippers": 0.1},
        "colors": {"X": "#6F8F5C", "D": "#4A6B3C", "L": "#9CBE86", "A": "#F0E3A8"},
        "art": [
            "............",
            "...XXXXXX...",
            "..XXXXXXXX..",
            ".XXXXXXXXXX.",
            ".XDDXXXXDDX.",
            ".XWKXXXXWKX.",
            ".XXXXXXXXXX.",
            "XXXXXAAXXXXX",
            "XXXXXAAXXXXX",
            "XXXXXXXXXXXX",
            ".XXXXXXXXXX.",
            "..X..XX..X..",
        ],
    },
    "obsession": {
        "name": "강박",
        "title": "몇 번을 확인해도 모자란 눈",
        "line": "\"완벽하지 않으면, 아무 소용 없어.\"",
        "pattern": {"kind": "multi", "times": 2, "mult": 0.8, "every": 2, "inflict": "jittery"},
        "hp": 52, "atk": 16, "def": 5,
        "exp": 42, "coins": 36,
        "weak": "hug",
        "drop": {"energy_drink": 0.35, "clover": 0.12, "star_scarf": 0.06},
        "colors": {"X": "#9B3FBF", "D": "#6B2287", "L": "#C97FE8", "A": "#FFF6E4"},
        "art": [
            "..X......X..",
            "..X.XXXX.X..",
            ".XXXXXXXXXX.",
            ".XWWXXXXWWX.",
            ".XWKXXXXWKX.",
            ".XXXXXXXXXX.",
            "XXAXAXAXAXXX",
            "XXAXAXAXAXXX",
            "XXXXXXXXXXXX",
            ".XXXXXXXXXX.",
            ".X.X....X.X.",
            ".X.X....X.X.",
        ],
    },
    "overtime": {
        "name": "야근 귀신",
        "title": "퇴근을 먹고 자라는 것",
        "line": "\"오늘도... 못 가.\"",
        "pattern": {"kind": "heavy", "every": 4, "mult": 1.8},
        "hp": 220, "atk": 18, "def": 6,
        "exp": 140, "coins": 110,
        "drop": {"star_candy": 0.6, "clover": 0.5, "travel_shoes": 0.5},
        "is_boss": true,
        "colors": {"X": "#2E2E3E", "D": "#1A1A26", "L": "#4E4E66", "A": "#FF5A4A"},
        "art": [
            "...A....A...",
            "..AXXXXXXA..",
            ".XXXXXXXXXX.",
            "XXXWWXXWWXXX",
            "XXXWKXXWKXXX",
            "XXXXXXXXXXXX",
            "XXXXAXXXXXXX",
            "XXXXAXXXXXXX",
            "XXXXAAAAXXXX",
            "XXXXXXXXXXXX",
            ".XXXXXXXXXX.",
            "..XXXXXXXX..",
        ],
    },
}

const SKILLS := {
    "laugh": {
        "name": "웃어넘기기",
        "desc": "별거 아니라는 듯 웃는다.",
        "mp": 0, "type": "attack", "power": 1.0,
    },
    "breath": {
        "name": "심호흡",
        "desc": "천천히 숨을 고른다. 체력 회복.",
        "mp": 5, "type": "heal", "heal_base": 26, "grants": "warm",
    },
    "daydream": {
        "name": "여행 상상",
        "desc": "떠날 날을 그린다. 적의 기세를 꺾는다.",
        "mp": 6, "type": "attack", "power": 0.9, "enemy_grants": "soothed",
    },
    "cheer": {
        "name": "응원 한마디",
        "desc": "\"할 수 있어.\" 마음의 힘이 오른다.",
        "mp": 5, "type": "buff", "atk_buff": 8,
    },
    "steel": {
        "name": "마음 단단히",
        "desc": "한 번 숨을 고르고 버틴다. 잠시 덜 아프다.",
        "mp": 6, "type": "buff", "grants": "guarded",
    },
    "hug": {
        "name": "따뜻한 포옹",
        "desc": "둘이 함께라면 더 강하다. 남은 온기가 적을 천천히 녹인다.",
        "mp": 9, "type": "attack", "power": 1.9, "partner_bonus": 1.4,
        "enemy_grants": "fading",
    },
}

const WEAKNESS_MULT := 1.6

## 상태이상 — 전투 중에만 붙고 전투가 끝나면 사라진다.
## 힐링 게임이라 "턴을 통째로 빼앗기는" 상태(기절·속박)는 만들지 않는다.
## 불편하게만 만들고, 플레이어가 대응할 수단(아이템·회복 스킬)을 항상 남겨둔다.
const STATUSES := {
    "daunted": {
        "name": "위축", "good": false, "turns": 3, "color": "#C88FE0",
        "desc": "마음의 힘이 줄어든다.",
        "on_msg": "어깨가 움츠러든다...",
        "off_msg": "다시 어깨를 편다.",
    },
    "jittery": {
        "name": "초조", "good": false, "turns": 3, "color": "#F5A467",
        "desc": "매 턴 마음력이 샌다.",
        "on_msg": "자꾸 시계를 보게 된다...",
        "off_msg": "조바심이 가라앉았다.",
        "mp_per_turn": -3,
    },
    "numb": {
        "name": "먹먹함", "good": false, "turns": 3, "color": "#8A8A96",
        "desc": "회복 스킬의 효과가 절반이 된다. (아이템은 그대로 듣는다)",
        "on_msg": "마음이 먹먹해진다...",
        "off_msg": "다시 감각이 돌아왔다.",
    },
    "guarded": {
        "name": "굳건함", "good": true, "turns": 3, "color": "#6C9BD4",
        "desc": "받는 피해가 30% 줄어든다.",
        "on_msg": "숨을 고르고 자세를 낮췄다.",
        "off_msg": "긴장이 풀렸다.",
    },
    "warm": {
        "name": "온기", "good": true, "turns": 3, "color": "#7FBF6A",
        "desc": "매 턴 체력이 조금씩 돌아온다.",
        "on_msg": "가슴에 온기가 남았다.",
        "off_msg": "온기가 천천히 식었다.",
        "hp_per_turn": 8,
    },
}
const DAUNTED_ATK_MULT := 0.75   # 위축: 주는 피해
const NUMB_HEAL_MULT := 0.5      # 먹먹함: 회복 스킬 효과
const GUARDED_TAKEN_MULT := 0.7  # 굳건함: 받는 피해

## 적에게 거는 상태이상 — 플레이어 쪽(STATUSES)과 표를 따로 둔다.
## 걸리는 방식이 다르기 때문이다: 플레이어 상태는 적이 걸고 아이템으로 풀지만,
## 적 상태는 플레이어 스킬로만 걸리고 시간이 지나야 풀린다.
## 여기서도 "턴을 통째로 빼앗는" 상태는 만들지 않는다 — 적이 아무것도 못 하면
## 행동 예고가 사라지고 전투가 그냥 때리기 싸움이 된다.
## on_msg / off_msg 에는 적 이름이 들어갈 %s 가 하나씩 있다.
const ENEMY_STATUSES := {
    "soothed": {
        "name": "누그러짐", "turns": 3, "color": "#8FD8E0",
        "desc": "적이 주는 피해가 25% 줄어든다.",
        "on_msg": "%s의 기세가 누그러졌다.",
        "off_msg": "%s이(가) 다시 날을 세운다.",
    },
    "shaken": {
        "name": "흔들림", "turns": 3, "color": "#F5D563",
        "desc": "적이 받는 피해가 30% 늘어난다.",
        "on_msg": "%s의 속이 훤히 드러났다!",
        "off_msg": "%s이(가) 다시 마음을 감췄다.",
    },
    "fading": {
        "name": "사그라듦", "turns": 3, "color": "#7FBF6A",
        "desc": "매 턴 조금씩 옅어진다.",
        "on_msg": "%s이(가) 온기에 천천히 녹기 시작한다.",
        "off_msg": "%s이(가) 다시 또렷해졌다.",
        "hp_per_turn": -7,
    },
}
const SOOTHED_ATK_MULT := 0.75   # 누그러짐: 적이 주는 피해
const SHAKEN_TAKEN_MULT := 1.3   # 흔들림: 적이 받는 피해

var in_battle: bool = false
var enemy: Dictionary = {}
var enemy_id: String = ""
var atk_buff: int = 0
var def_buff: int = 0
var turn_count: int = 0
var defeated_counts: Dictionary = {}
var weakness_found: Dictionary = {}
var world_enemy: Node = null
## 직전 플레이어 공격이 준 피해 — "비교"의 되돌리기 패턴이 참고한다.
## 공격이 아닌 행동(회복·버프·아이템·도망)을 하면 0으로 돌아간다.
var _last_player_damage: int = 0

## 지금 걸려 있는 상태이상 { status_id: 남은 턴 }. 전투 밖에서는 항상 비어 있다.
var statuses: Dictionary = {}

## 적에게 걸려 있는 상태이상 { status_id: 남은 턴 }
var enemy_statuses: Dictionary = {}

## 이번 전투에서 약점으로 적 턴을 이미 건너뛰었는지 — 같은 수법은 두 번 통하지 않는다
var _weakness_stunned: bool = false

func start_battle(id: String, source_node: Node = null) -> bool:
    if in_battle or not ENEMIES.has(id):
        return false
    var def: Dictionary = ENEMIES[id]
    enemy_id = id
    world_enemy = source_node
    enemy = {
        "id": id,
        "name": def.name,
        "title": def.title,
        "line": def.line,
        "hp": def.hp,
        "max_hp": def.hp,
        "atk": def.atk,
        "def": def.get("def", 0),
        "is_boss": def.get("is_boss", false),
    }
    atk_buff = 0
    def_buff = 0
    turn_count = 0
    _last_player_damage = 0
    statuses.clear()
    enemy_statuses.clear()
    _weakness_stunned = false
    # 포근 세트 특전 — 온기를 두른 채로 전투를 시작한다
    if PlayerStats.has_full_set("cozy"):
        apply_status("warm")
    # 밤마실 세트 특전 — 약점을 처음부터 알고 들어간다 (보스는 약점이 없다)
    if PlayerStats.has_full_set("nightwalk") and String(def.get("weak", "")) != "":
        weakness_found[id] = true
    # 첫걸음 세트 특전 — 한 발 앞서 나간다
    if PlayerStats.has_full_set("firststep"):
        PlayerStats.restore_mp(6)
    in_battle = true
    battle_started.emit(enemy)
    return true

func enemy_def(id: String) -> Dictionary:
    return ENEMIES.get(id, {})

# ── 상태이상 ──────────────────────────────────────────
func has_status(id: String) -> bool:
    return statuses.get(id, 0) > 0

## 상태를 건다(이미 걸려 있으면 지속 턴을 다시 채운다). UI에 띄울 이벤트를 돌려준다.
func apply_status(id: String) -> Dictionary:
    if not STATUSES.has(id):
        return {"type": "text", "msg": ""}
    var s: Dictionary = STATUSES[id]
    statuses[id] = int(s.turns)
    return {"type": "status", "msg": "%s! %s" % [s.name, s.on_msg], "color": s.color}

## 나쁜 상태를 전부 씻어낸다. 지운 개수를 돌려준다.
func clear_bad_statuses() -> int:
    var removed := 0
    for id in statuses.keys():
        if not STATUSES[id].good:
            statuses.erase(id)
            removed += 1
    return removed

## UI 표시용 — [{name, turns, color, good}, ...]
func status_list() -> Array:
    var out: Array = []
    for id in statuses:
        var s: Dictionary = STATUSES[id]
        out.append({"name": s.name, "turns": statuses[id], "color": s.color, "good": s.good})
    return out

## 턴이 끝날 때 한 번 — 지속 효과를 적용하고 남은 턴을 깎는다
func _tick_statuses() -> Array:
    var events: Array = []
    for id in statuses.keys():
        var s: Dictionary = STATUSES[id]
        if s.has("hp_per_turn"):
            var healed := PlayerStats.heal(int(s.hp_per_turn))
            if healed > 0:
                events.append({"type": "heal", "amount": healed})
        if s.has("mp_per_turn"):
            var drained: int = min(PlayerStats.mp, -int(s.mp_per_turn))
            if drained > 0:
                PlayerStats.spend_mp(drained)
                events.append({"type": "status", "msg": "마음력 -%d" % drained, "color": s.color})
        statuses[id] = int(statuses[id]) - 1
        if statuses[id] <= 0:
            statuses.erase(id)
            events.append({"type": "text", "msg": s.off_msg})
    return events

# ── 적에게 거는 상태이상 ──────────────────────────────
func enemy_has_status(id: String) -> bool:
    return enemy_statuses.get(id, 0) > 0

## 적에게 상태를 건다(이미 걸려 있으면 지속 턴을 다시 채운다)
func apply_enemy_status(id: String) -> Dictionary:
    if not ENEMY_STATUSES.has(id) or enemy.is_empty():
        return {"type": "text", "msg": ""}
    var s: Dictionary = ENEMY_STATUSES[id]
    enemy_statuses[id] = int(s.turns)
    return {"type": "enemy_status", "msg": "%s!" % s.name,
        "detail": String(s.on_msg) % enemy.name, "color": s.color}

## UI 표시용 — [{name, turns, color}, ...]
func enemy_status_list() -> Array:
    var out: Array = []
    for id in enemy_statuses:
        var s: Dictionary = ENEMY_STATUSES[id]
        out.append({"name": s.name, "turns": enemy_statuses[id], "color": s.color})
    return out

## 적 상태의 지속 효과 — 플레이어 상태와 똑같이 적이 움직인 뒤 한 번만 흐른다
func _tick_enemy_statuses() -> Array:
    var events: Array = []
    for id in enemy_statuses.keys():
        var s: Dictionary = ENEMY_STATUSES[id]
        if s.has("hp_per_turn") and enemy.hp > 0:
            var lost: int = min(int(enemy.hp), -int(s.hp_per_turn))
            if lost > 0:
                enemy.hp -= lost
                events.append({"type": "enemy_status", "msg": "-%d" % lost,
                    "detail": "%s이(가) 조금 옅어졌다." % enemy.name, "color": s.color})
        enemy_statuses[id] = int(enemy_statuses[id]) - 1
        if enemy_statuses[id] <= 0:
            enemy_statuses.erase(id)
            events.append({"type": "text", "msg": String(s.off_msg) % enemy.name})
    return events

## 누그러짐이 걸려 있으면 적이 주는 피해가 줄어든다 (예상 피해 계산도 같은 값을 쓴다)
func _enemy_out_mult() -> float:
    return SOOTHED_ATK_MULT if enemy_has_status("soothed") else 1.0

func add_atk_buff(v: int) -> void:
    atk_buff += v

func add_def_buff(v: int) -> void:
    def_buff += v

func available_skills() -> Array:
    var out: Array = []
    for id in PlayerStats.skills:
        if SKILLS.has(id):
            out.append(id)
    return out

func _partner_here() -> bool:
    return Episode0State.partner_joined

# ── 플레이어 턴 ───────────────────────────────────────
func player_use_skill(skill_id: String) -> Array:
    var events: Array = []
    if not in_battle or not SKILLS.has(skill_id):
        return events
    var skill: Dictionary = SKILLS[skill_id]
    if not PlayerStats.spend_mp(skill.mp):
        events.append({"type": "text", "msg": "마음력이 부족해요."})
        return events

    # 약점 판정은 공격형 스킬에만 적용한다 — 회복/버프 스킬은 적에게 피해를 주지 않으므로
    # 여기에 걸리면 "피해 0 + 적 턴 스킵"이 되어 무한 회복 악용이 가능해진다.
    var hit_weakness: bool = skill.type == "attack" and ENEMIES[enemy_id].get("weak", "") == skill_id

    turn_count += 1
    _last_player_damage = 0
    match skill.type:
        "attack":
            var power: float = skill.power
            if hit_weakness:
                power *= WEAKNESS_MULT
            if skill.has("partner_bonus") and _partner_here():
                power *= skill.partner_bonus
                events.append({"type": "text", "msg": "%s! 둘이 함께라 더 단단해요." % skill.name})
            else:
                events.append({"type": "text", "msg": "%s!" % skill.name})
            var dmg := _calc_player_damage(power)
            var crit: bool = dmg.crit
            enemy.hp = max(0, enemy.hp - dmg.amount)
            _last_player_damage = dmg.amount
            events.append({"type": "damage_enemy", "amount": dmg.amount, "crit": crit, "weak": hit_weakness, "skill": skill_id})
        "heal":
            var amount: int = skill.heal_base + PlayerStats.level * 3
            if has_status("numb"):
                amount = int(round(float(amount) * NUMB_HEAL_MULT))
            var healed := PlayerStats.heal(amount)
            events.append({"type": "text", "msg": "%s — 체력 %d 회복." % [skill.name, healed]})
            events.append({"type": "heal", "amount": healed, "skill": skill_id})
        "buff":
            if skill.has("atk_buff"):
                atk_buff += skill.atk_buff
                events.append({"type": "text", "msg": "%s! 마음의 힘 +%d" % [skill.name, skill.atk_buff]})
                events.append({"type": "buff", "amount": skill.atk_buff, "skill": skill_id})
            else:
                events.append({"type": "text", "msg": "%s!" % skill.name})

    # 나에게 상태를 남기는 스킬 (심호흡=온기, 마음 단단히=굳건함)
    if skill.has("grants"):
        events.append(apply_status(String(skill.grants)))
    # 적에게 상태를 거는 스킬 (여행 상상=누그러짐, 따뜻한 포옹=사그라듦)
    if skill.has("enemy_grants") and enemy.hp > 0:
        events.append(apply_enemy_status(String(skill.enemy_grants)))

    if enemy.hp <= 0:
        events.append({"type": "enemy_defeated"})
        events.append(_make_victory_event())
        return events
    if hit_weakness:
        weakness_found[enemy_id] = true
        events.append(apply_enemy_status("shaken"))
        # 허를 찌르면 한 턴을 번다. 다만 이 스킵이 매번 통하면 약점 스킬만 반복해도
        # 적이 영원히 움직이지 못하므로(웃어넘기기는 마음력 0이라 무한히 쓸 수 있다)
        # 턴 스킵은 전투당 한 번으로 제한한다. 피해 배율과 흔들림은 계속 붙는다.
        if not _weakness_stunned:
            _weakness_stunned = true
            events.append({"type": "weakness", "msg": "약점을 찔렀다! %s이(가) 말을 잇지 못한다." % enemy.name})
            return events
        events.append({"type": "weakness", "msg": "약점을 다시 찔렀다! %s이(가) 크게 흔들린다." % enemy.name})
    events.append_array(_enemy_turn())
    return events

## 아이템 사용 턴 (사용에 성공하면 적도 한 번 움직인다)
func player_use_item(item_id: String) -> Array:
    var events: Array = []
    if not in_battle:
        return events
    var msg := ItemDB.use_item(item_id, true)
    if msg == "":
        events.append({"type": "text", "msg": "지금은 쓸 수 없어요."})
        return events
    turn_count += 1
    _last_player_damage = 0
    events.append({"type": "text", "msg": msg})
    events.append({"type": "heal", "amount": 0})
    events.append_array(_enemy_turn())
    return events

## 도망 — 보스에게선 도망갈 수 없다
func player_flee() -> Array:
    var events: Array = []
    if not in_battle:
        return events
    if enemy.get("is_boss", false):
        events.append({"type": "text", "msg": "도망칠 수 없어! 지금 마주해야 해."})
        events.append_array(_enemy_turn())
        return events
    turn_count += 1
    _last_player_damage = 0
    # 여행 세트 특전 — 언제든 떠날 수 있다
    if randf() < 0.62 or PlayerStats.has_full_set("travel"):
        events.append({"type": "text", "msg": "잠시 거리를 두었다. 그것도 방법이야."})
        events.append({"type": "flee_success"})
        return events
    events.append({"type": "text", "msg": "발이 떨어지지 않는다!"})
    events.append_array(_enemy_turn())
    return events

# ── 적 턴 ────────────────────────────────────────────
## 적마다 다른 행동을 한다. ENEMIES의 "pattern"을 보고 이번 턴에 무엇을 할지 정한다.
## 같은 함수를 enemy_intent()도 쓰기 때문에, 예고와 실제 행동이 항상 일치한다.
func _enemy_turn() -> Array:
    var events: Array = []
    if enemy.hp <= 0:
        return events
    events.append_array(_enemy_action())
    # 상태이상은 적이 움직인 뒤에 한 번만 흐른다 (약점으로 적 턴을 건너뛰면 시간도 안 간다)
    if not PlayerStats.is_down():
        events.append_array(_tick_statuses())
        events.append_array(_tick_enemy_statuses())
        if enemy.hp <= 0:
            events.append({"type": "enemy_defeated"})
            events.append(_make_victory_event())
    return events

func _enemy_action() -> Array:
    var events: Array = []
    var plan := _enemy_plan(turn_count)

    match String(plan.act):
        "rest":
            events.append({"type": "text", "msg": "%s%s" % [enemy.name, plan.rest_msg]})
            return events
        "drain":
            var taken: int = min(PlayerStats.mp, int(plan.amount))
            events.append({"type": "text", "msg": "%s가 마음의 여유를 빨아간다..." % enemy.name})
            if taken > 0:
                PlayerStats.spend_mp(taken)
                events.append({"type": "status", "msg": "마음력 -%d" % taken, "color": "#6C9BD4"})
            else:
                events.append({"type": "text", "msg": "하지만 빼앗을 여유가 남아 있지 않았다."})
            return events
        "inflict":
            events.append({"type": "text", "msg": enemy.line})
            events.append(apply_status(String(plan.status)))
            return events
        "reflect":
            var back: int = clamp(int(round(float(_last_player_damage) * float(plan.ratio) * _enemy_out_mult())), 1, enemy.atk * 2)
            events.append({"type": "text", "msg": "%s가 방금 그 마음을 그대로 비춘다..." % enemy.name})
            var mirrored := _hit_player(back)
            events.append({"type": "damage_player", "amount": mirrored, "heavy": false})
            if PlayerStats.is_down():
                events.append({"type": "defeat"})
            return events

    # ── 공격 계열 ──
    var times: int = int(plan.get("times", 1))
    var mult: float = float(plan.get("mult", 1.0))
    var heavy: bool = bool(plan.get("heavy", false))
    if heavy:
        events.append({"type": "text", "msg": "%s가 크게 숨을 몰아쉰다..." % enemy.name})
    else:
        events.append({"type": "text", "msg": enemy.line})
    for i in range(times):
        var base: int = int(round(float(enemy.atk + randi_range(0, 3)) * mult * _enemy_out_mult()))
        var real := _hit_player(base)
        events.append({"type": "damage_player", "amount": real, "heavy": heavy})
        if PlayerStats.is_down():
            events.append({"type": "defeat"})
            return events
    # 공격과 함께 상태를 남기는 적이 있다 (번아웃=먹먹함, 강박=초조)
    if String(plan.get("inflict", "")) != "":
        events.append(apply_status(String(plan.inflict)))
    return events

## 이번(또는 다음) 턴에 적이 할 행동을 정한다 — 무작위 없이 턴 수만으로 결정된다.
## act: attack / rest / drain / inflict / reflect
func _enemy_plan(turn: int) -> Dictionary:
    var p: Dictionary = ENEMIES.get(enemy_id, {}).get("pattern", {})
    match String(p.get("kind", "plain")):
        "multi":
            # 여러 번 연속으로 때린다 (불안=매 턴 재잘거림, 강박=주기적으로 다시 확인)
            if turn % int(p.get("every", 1)) == 0:
                var n: int = int(p.get("times", 2))
                return _with_inflict({"act": "attack", "times": n,
                    "mult": float(p.get("mult", 0.65)), "desc": "%d연속 공격" % n}, p)
        "heavy":
            # 주기적으로 강한 일격 (보스)
            if turn % int(p.get("every", 4)) == 0:
                return {"act": "attack", "times": 1, "mult": float(p.get("mult", 1.8)),
                    "heavy": true, "desc": "강한 일격"}
        "burst":
            # 타올랐다 꺼진다 — 쉬다가 주기마다 크게 터진다 (번아웃)
            if turn % int(p.get("every", 3)) == 0:
                return _with_inflict({"act": "attack", "times": 1, "mult": float(p.get("mult", 2.0)),
                    "heavy": true, "desc": "다 태우는 일격"}, p)
            return {"act": "rest", "rest_msg": "은(는) 잿더미처럼 늘어져 있다.", "desc": "타오를 준비"}
        "lazy":
            # 대부분의 턴을 미룬다 (미루기)
            if turn % int(p.get("every", 2)) != 0:
                return {"act": "rest", "rest_msg": "은(는) \"조금 이따 할게...\" 하며 늘어진다.", "desc": "미루는 중"}
        "drain":
            if turn % int(p.get("every", 3)) == 0:
                return {"act": "drain", "amount": int(p.get("amount", 6)), "desc": "마음력 흡수"}
        "inflict":
            if turn % int(p.get("every", 3)) == 0:
                var sid: String = String(p.get("status", "daunted"))
                return {"act": "inflict", "status": sid,
                    "desc": "%s 걸기" % STATUSES.get(sid, {}).get("name", "상태이상")}
        "reflect":
            # 직전에 받은 만큼 되돌려준다. 맞은 게 없으면 그냥 때린다 (비교)
            if _last_player_damage > 0:
                return {"act": "reflect", "ratio": float(p.get("ratio", 0.35)), "desc": "되돌리기"}
        "escalate":
            # 턴이 갈수록 조급해져 빨라진다 (조급함)
            var grown: float = 1.0 + float(p.get("step", 0.18)) * float(max(0, turn - 1))
            return {"act": "attack", "times": 1,
                "mult": min(grown, float(p.get("max_mult", 2.2))), "desc": "점점 빨라지는 공격"}
        "lonely":
            # 곁에 누가 있으면 힘을 잃는다 (외로움)
            var m: float = float(p.get("together_mult", 0.5)) if _partner_here() else float(p.get("alone_mult", 1.5))
            return {"act": "attack", "times": 1, "mult": m, "desc": "공격"}
    return {"act": "attack", "times": 1, "mult": 1.0, "desc": "공격"}

## 패턴에 inflict가 있으면 계획에 실어준다
func _with_inflict(plan: Dictionary, p: Dictionary) -> Dictionary:
    if String(p.get("inflict", "")) != "":
        plan["inflict"] = String(p.inflict)
    return plan

# ── 계산 ─────────────────────────────────────────────
func _mitigation(def_value: int) -> float:
    return 100.0 / (100.0 + float(def_value) * 8.0)

func _calc_player_damage(power: float) -> Dictionary:
    var base: float = float(PlayerStats.attack + atk_buff) * power * _mitigation(enemy.get("def", 0))
    if has_status("daunted"):
        base *= DAUNTED_ATK_MULT
    if enemy_has_status("shaken"):
        base *= SHAKEN_TAKEN_MULT
    base *= randf_range(0.9, 1.1)
    var crit := randf() < 0.15
    if crit:
        base *= 1.75
    var amount := max(1, int(round(base)))
    return {"amount": amount, "crit": crit}

## 다음 적 행동 예고 — _enemy_plan()과 같은 계산을 쓰므로 예고와 실제가 어긋나지 않는다
func enemy_intent() -> String:
    var plan := _enemy_plan(turn_count + 1)
    match String(plan.act):
        "rest":
            return "다음 — %s" % plan.desc
        "drain":
            return "다음 — 마음력을 빨아간다 (약 %d)" % int(plan.amount)
        "inflict":
            return "다음 — %s 상태로 만든다" % STATUSES.get(String(plan.status), {}).get("name", "이상")
        "reflect":
            return "다음 — 방금 준 피해를 되돌린다"
    var per: int = expected_enemy_damage(float(plan.get("mult", 1.0)))
    var times: int = int(plan.get("times", 1))
    var tail: String = ""
    if String(plan.get("inflict", "")) != "":
        tail = " + %s" % STATUSES.get(String(plan.inflict), {}).get("name", "이상")
    if times > 1:
        return "다음 — %d연속 공격 (각 약 %d)%s" % [times, per, tail]
    if plan.get("heavy", false):
        return "다음 — %s! (약 %d)%s" % [plan.desc, per, tail]
    return "다음 — 공격 (약 %d)%s" % [per, tail]

func expected_enemy_damage(mult: float = 1.0) -> int:
    var raw: int = int(round(float(enemy.get("atk", 0) + 1) * mult * _enemy_out_mult()))
    var base: float = float(max(1, raw - def_buff))
    if has_status("guarded"):
        base *= GUARDED_TAKEN_MULT
    return max(1, int(round(base * _mitigation(PlayerStats.defense))))

## 플레이어가 실제로 맞는 자리 — 방어 버프와 굳건함을 여기서 한 번에 반영한다
func _hit_player(base: int) -> int:
    var amount: float = float(max(1, base - def_buff))
    if has_status("guarded"):
        amount *= GUARDED_TAKEN_MULT
    return PlayerStats.take_damage(max(1, int(round(amount))))

## 이 전투 중 밝혀진 적의 약점 (없으면 "")
func known_weakness() -> String:
    if weakness_found.get(enemy_id, false):
        return ENEMIES.get(enemy_id, {}).get("weak", "")
    return ""

func _make_victory_event() -> Dictionary:
    var def: Dictionary = ENEMIES[enemy_id]
    var exp_gain: int = def.exp
    var coin_gain: int = def.coins
    # 별밤 세트 특전 — 걷어낸 자리에서 조각을 더 찾아낸다
    if PlayerStats.has_full_set("starlit"):
        coin_gain = int(round(float(coin_gain) * 1.25))
    var drops: Array = []
    for item_id in def.get("drop", {}):
        if randf() < def.drop[item_id]:
            drops.append(item_id)
    return {
        "type": "victory",
        "exp": exp_gain,
        "coins": coin_gain,
        "drops": drops,
    }

## 승리 보상을 실제로 지급한다 (UI가 연출을 마친 뒤 호출)
func apply_victory(ev: Dictionary) -> Dictionary:
    var levels: Array = PlayerStats.add_exp(ev.exp)
    PlayerStats.add_coins(ev.coins)
    for item_id in ev.drops:
        PlayerStats.add_item(item_id, 1)
    defeated_counts[enemy_id] = defeated_counts.get(enemy_id, 0) + 1
    QuestSystem.on_enemy_defeated(enemy_id)
    return {"levels": levels}

func end_battle(result: String) -> void:
    if not in_battle:
        return
    in_battle = false
    statuses.clear()
    enemy_statuses.clear()
    if result == "victory" and is_instance_valid(world_enemy):
        world_enemy.queue_free()
    world_enemy = null
    atk_buff = 0
    def_buff = 0
    if result == "defeat":
        PlayerStats.revive_soft()
    battle_finished.emit(result)

func to_dict() -> Dictionary:
    return {"defeated_counts": defeated_counts, "weakness_found": weakness_found}

func from_dict(d: Dictionary) -> void:
    defeated_counts = d.get("defeated_counts", {})
    weakness_found = d.get("weakness_found", {})
