extends Node
## BattleSystem — "그림자 감정"과의 턴제 전투 로직.
##
## 이 게임의 적은 현실에서 눈에 보이지 않는 부정적 감정들이다.
## 불안·욕심·불행·번아웃·비교가 형체를 얻어 나타나고, 쿼카는 마음의 힘으로 걷어낸다.
##
## 로직은 전부 여기에 있고, BattleUI는 여기서 돌려주는 "이벤트 배열"을 순서대로 연출만 한다.
## 이벤트: {"type": ..., ...}
##   text / damage_enemy / damage_player / heal / buff / enemy_defeated
##   victory / defeat / flee_success / flee_fail

signal battle_started(enemy: Dictionary)
signal battle_finished(result: String)

## 적 픽셀 아트 문자 → 색 역할
##   X=본체  D=그림자  L=하이라이트  W=눈흰자  K=눈동자  A=강조(포인트)
const ENEMIES := {
    "anxiety": {
        "name": "불안",
        "title": "잠 못 드는 밤의 속삭임",
        "line": "\"내일도 잘할 수 있을까...?\"",
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
        "hp": 56, "atk": 15, "def": 5,
        "exp": 40, "coins": 38,
        "weak": "hug",
        "drop": {"energy_drink": 0.4, "star_candy": 0.05},
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
        "hp": 36, "atk": 10, "def": 3,
        "exp": 24, "coins": 20,
        "weak": "laugh",
        "drop": {"cocoa": 0.3, "scarf": 0.1},
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
        "hp": 40, "atk": 7, "def": 4,
        "exp": 26, "coins": 22,
        "weak": "daydream",
        "drop": {"cocoa": 0.3, "cookie": 0.2},
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
        "hp": 220, "atk": 18, "def": 6,
        "exp": 140, "coins": 110,
        "drop": {"star_candy": 0.6, "clover": 0.5},
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
        "mp": 5, "type": "heal", "heal_base": 26,
    },
    "daydream": {
        "name": "여행 상상",
        "desc": "떠날 날을 그린다. 적의 기세를 꺾는다.",
        "mp": 6, "type": "attack", "power": 0.9, "enemy_atk_down": 3,
    },
    "cheer": {
        "name": "응원 한마디",
        "desc": "\"할 수 있어.\" 마음의 힘이 오른다.",
        "mp": 5, "type": "buff", "atk_buff": 8,
    },
    "hug": {
        "name": "따뜻한 포옹",
        "desc": "둘이 함께라면 더 강하다.",
        "mp": 9, "type": "attack", "power": 1.9, "partner_bonus": 1.4,
    },
}

const WEAKNESS_MULT := 1.6

var in_battle: bool = false
var enemy: Dictionary = {}
var enemy_id: String = ""
var atk_buff: int = 0
var def_buff: int = 0
var turn_count: int = 0
var defeated_counts: Dictionary = {}
var weakness_found: Dictionary = {}
var world_enemy: Node = null

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
    in_battle = true
    battle_started.emit(enemy)
    return true

func enemy_def(id: String) -> Dictionary:
    return ENEMIES.get(id, {})

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
            events.append({"type": "damage_enemy", "amount": dmg.amount, "crit": crit, "weak": hit_weakness, "skill": skill_id})
            if skill.has("enemy_atk_down"):
                enemy.atk = max(1, enemy.atk - skill.enemy_atk_down)
                events.append({"type": "text", "msg": "%s의 기세가 꺾였다! (공격 -%d)" % [enemy.name, skill.enemy_atk_down]})
        "heal":
            var amount: int = skill.heal_base + PlayerStats.level * 3
            var healed := PlayerStats.heal(amount)
            events.append({"type": "text", "msg": "%s — 체력 %d 회복." % [skill.name, healed]})
            events.append({"type": "heal", "amount": healed, "skill": skill_id})
        "buff":
            atk_buff += skill.atk_buff
            events.append({"type": "text", "msg": "%s! 마음의 힘 +%d" % [skill.name, skill.atk_buff]})
            events.append({"type": "buff", "amount": skill.atk_buff, "skill": skill_id})

    if enemy.hp <= 0:
        events.append({"type": "enemy_defeated"})
        events.append(_make_victory_event())
        return events
    if hit_weakness:
        weakness_found[enemy_id] = true
        events.append({"type": "weakness", "msg": "약점을 찔렀다! %s이(가) 말을 잇지 못한다." % enemy.name})
        return events
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
    if randf() < 0.62:
        events.append({"type": "text", "msg": "잠시 거리를 두었다. 그것도 방법이야."})
        events.append({"type": "flee_success"})
        return events
    events.append({"type": "text", "msg": "발이 떨어지지 않는다!"})
    events.append_array(_enemy_turn())
    return events

# ── 적 턴 ────────────────────────────────────────────
func _enemy_turn() -> Array:
    var events: Array = []
    if enemy.hp <= 0:
        return events
    # 보스는 가끔 강한 일격을 날린다
    var heavy: bool = enemy.get("is_boss", false) and turn_count % 4 == 0
    var base: int = enemy.atk + randi_range(0, 3)
    if heavy:
        base = int(base * 1.8)
        events.append({"type": "text", "msg": "%s가 크게 숨을 몰아쉰다..." % enemy.name})
    else:
        events.append({"type": "text", "msg": enemy.line})
    var real := PlayerStats.take_damage(max(1, base - def_buff))
    events.append({"type": "damage_player", "amount": real, "heavy": heavy})
    if PlayerStats.is_down():
        events.append({"type": "defeat"})
    return events

# ── 계산 ─────────────────────────────────────────────
func _mitigation(def_value: int) -> float:
    return 100.0 / (100.0 + float(def_value) * 8.0)

func _calc_player_damage(power: float) -> Dictionary:
    var base: float = float(PlayerStats.attack + atk_buff) * power * _mitigation(enemy.get("def", 0))
    base *= randf_range(0.9, 1.1)
    var crit := randf() < 0.15
    if crit:
        base *= 1.75
    var amount := max(1, int(round(base)))
    return {"amount": amount, "crit": crit}

## 다음 적 행동 예고
func enemy_intent() -> String:
    if enemy.get("is_boss", false) and (turn_count + 1) % 4 == 0:
        return "다음 — 강한 일격을 준비 중!"
    return "다음 — 공격 (약 %d)" % expected_enemy_damage()

func expected_enemy_damage() -> int:
    var base: int = max(1, enemy.get("atk", 0) + 1 - def_buff)
    return max(1, int(round(float(base) * _mitigation(PlayerStats.defense))))

## 이 전투 중 밝혀진 적의 약점 (없으면 "")
func known_weakness() -> String:
    if weakness_found.get(enemy_id, false):
        return ENEMIES.get(enemy_id, {}).get("weak", "")
    return ""

func _make_victory_event() -> Dictionary:
    var def: Dictionary = ENEMIES[enemy_id]
    var exp_gain: int = def.exp
    var coin_gain: int = def.coins
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
