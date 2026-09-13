extends Node
## PlayerStats — 쿼카의 "마음" 스탯. 레벨/경험치/체력/마음력/화폐/인벤토리를 관리한다.
## 이 게임의 전투는 눈에 보이지 않는 부정적 감정(불안·욕심·불행 등)을 상대하므로
## 공격력은 "마음의 힘", MP는 "마음력"으로 부른다.

signal stats_changed
signal leveled_up(new_level: int)
signal coins_changed(amount: int)
signal item_changed(item_id: String, count: int)
signal equipment_changed

var level: int = 1
var exp_points: int = 0
var hp: int = 60
var max_hp: int = 60
var mp: int = 24
var max_mp: int = 24
var attack: int = 12
var defense: int = 4
var coins: int = 0

## 배운 스킬 id 목록 (battle_system.gd의 SKILLS 참조)
var skills: Array = ["laugh", "breath"]

## 소비 아이템 보유량 { item_id: 개수 }
var inventory: Dictionary = {}

## 장비 슬롯 { slot: item_id } — 목도리(scarf)/모자(hat) 등 상시 착용 장비
var equipment: Dictionary = {}

## 지금 스탯에 반영돼 있는 세트 보너스 { stat_key: 값 }.
## 장비를 벗을 때 정확히 이만큼만 되돌리려고 들고 있는다.
var _applied_set_bonus: Dictionary = {}

## 레벨업에 필요한 누적 경험치
func exp_to_next() -> int:
    return int(round(24.0 * pow(float(level), 1.25)))

func add_exp(amount: int) -> Array:
    var gained_levels: Array = []
    exp_points += amount
    while exp_points >= exp_to_next():
        exp_points -= exp_to_next()
        _level_up()
        gained_levels.append(level)
    stats_changed.emit()
    return gained_levels

func _level_up() -> void:
    level += 1
    max_hp += 14
    max_mp += 6
    attack += 3
    defense += 1
    hp = max_hp
    mp = max_mp
    _unlock_skills_for_level()
    leveled_up.emit(level)

## 레벨에 따라 새 스킬 해금
const SKILL_UNLOCKS := {
    2: "daydream",
    3: "cheer",
    4: "steel",
    5: "hug",
}

func _unlock_skills_for_level() -> void:
    if SKILL_UNLOCKS.has(level):
        var id: String = SKILL_UNLOCKS[level]
        if not id in skills:
            skills.append(id)

func take_damage(amount: int) -> int:
    var real := max(1, int(round(float(amount) * 100.0 / (100.0 + float(defense) * 8.0))))
    hp = max(0, hp - real)
    stats_changed.emit()
    return real

func heal(amount: int) -> int:
    var before := hp
    hp = min(max_hp, hp + amount)
    stats_changed.emit()
    return hp - before

func restore_mp(amount: int) -> int:
    var before := mp
    mp = min(max_mp, mp + amount)
    stats_changed.emit()
    return mp - before

func spend_mp(amount: int) -> bool:
    if mp < amount:
        return false
    mp -= amount
    stats_changed.emit()
    return true

func is_down() -> bool:
    return hp <= 0

## 쓰러졌을 때 — 힐링 게임이라 죽지 않고 절반 회복으로 다시 일어선다
func revive_soft() -> void:
    hp = max(1, int(max_hp * 0.5))
    mp = max(0, int(max_mp * 0.3))
    stats_changed.emit()

# ── 화폐 ──────────────────────────────────────────────
func add_coins(amount: int) -> void:
    coins = max(0, coins + amount)
    coins_changed.emit(coins)
    stats_changed.emit()

func spend_coins(amount: int) -> bool:
    if coins < amount:
        return false
    coins -= amount
    coins_changed.emit(coins)
    stats_changed.emit()
    return true

# ── 인벤토리 ──────────────────────────────────────────
func add_item(item_id: String, count: int = 1) -> void:
    inventory[item_id] = inventory.get(item_id, 0) + count
    item_changed.emit(item_id, inventory[item_id])
    stats_changed.emit()

func remove_item(item_id: String, count: int = 1) -> bool:
    var have: int = inventory.get(item_id, 0)
    if have < count:
        return false
    have -= count
    if have <= 0:
        inventory.erase(item_id)
    else:
        inventory[item_id] = have
    item_changed.emit(item_id, have)
    stats_changed.emit()
    return true

func item_count(item_id: String) -> int:
    return inventory.get(item_id, 0)

func total_items() -> int:
    var n := 0
    for k in inventory:
        n += inventory[k]
    return n

# ── 장비 (상시 착용) ──────────────────────────────────
## 장비를 착용한다. 같은 슬롯에 이미 다른 장비가 있으면 자동으로 해제 후 갈아입는다.
func equip_item(item_id: String) -> bool:
    var item := ItemDB.get_item(item_id)
    if item.is_empty() or item.kind != "equipment" or item_count(item_id) <= 0:
        return false
    var slot: String = item.slot
    if equipment.get(slot, "") == item_id:
        return false
    if equipment.has(slot):
        _apply_equip_effect(equipment[slot], -1)
    equipment[slot] = item_id
    _apply_equip_effect(item_id, 1)
    _refresh_set_bonus()
    stats_changed.emit()
    equipment_changed.emit()
    return true

func unequip_slot(slot: String) -> bool:
    if not equipment.has(slot):
        return false
    _apply_equip_effect(equipment[slot], -1)
    equipment.erase(slot)
    _refresh_set_bonus()
    stats_changed.emit()
    equipment_changed.emit()
    return true

func _apply_equip_effect(item_id: String, sign: int) -> void:
    var eff: Dictionary = ItemDB.get_item(item_id).get("effect", {})
    if eff.has("defense"):
        defense = max(0, defense + sign * int(eff.defense))
    if eff.has("attack"):
        attack = max(1, attack + sign * int(eff.attack))
    if eff.has("max_hp"):
        var delta: int = sign * int(eff.max_hp)
        max_hp = max(1, max_hp + delta)
        hp = clamp(hp + delta, 0, max_hp)
    if eff.has("max_mp"):
        var delta_mp: int = sign * int(eff.max_mp)
        max_mp = max(0, max_mp + delta_mp)
        mp = clamp(mp + delta_mp, 0, max_mp)

# ── 장비 세트 효과 ────────────────────────────────────
## 세트별로 지금 몇 개를 착용 중인지 { set_id: 개수 }
func set_counts() -> Dictionary:
    var worn: Array = equipment.values()
    var out: Dictionary = {}
    for set_id in ItemDB.SETS:
        var n := 0
        for item_id in ItemDB.SETS[set_id].items:
            if item_id in worn:
                n += 1
        out[set_id] = n
    return out

## 세트를 전부 갖췄는지 (4개 특전 판정용)
func has_full_set(set_id: String) -> bool:
    var s: Dictionary = ItemDB.SETS.get(set_id, {})
    if s.is_empty():
        return false
    return set_counts().get(set_id, 0) >= s.items.size()

## 지금 착용 상태로 받아야 할 세트 보너스 총합
func pending_set_bonus() -> Dictionary:
    var total: Dictionary = {}
    var counts := set_counts()
    for set_id in ItemDB.SETS:
        var have: int = counts.get(set_id, 0)
        for need in ItemDB.SETS[set_id].bonuses:
            if have < int(need):
                continue
            for key in ItemDB.SETS[set_id].bonuses[need]:
                total[key] = int(total.get(key, 0)) + int(ItemDB.SETS[set_id].bonuses[need][key])
    return total

## 장비가 바뀔 때마다 세트 보너스를 다시 계산해 차액만 스탯에 반영한다.
## (이미 적용된 값은 _applied_set_bonus에 남겨두고 저장 데이터에도 넣는다 —
##  나중에 장비를 벗을 때 정확히 그만큼만 되돌려야 하기 때문)
func _refresh_set_bonus() -> void:
    var want := pending_set_bonus()
    var keys: Array = []
    for k in want:
        if not k in keys:
            keys.append(k)
    for k in _applied_set_bonus:
        if not k in keys:
            keys.append(k)
    for key in keys:
        var delta: int = int(want.get(key, 0)) - int(_applied_set_bonus.get(key, 0))
        if delta != 0:
            _apply_stat_delta(String(key), delta)
    _applied_set_bonus = want

func _apply_stat_delta(key: String, delta: int) -> void:
    match key:
        "defense":
            defense = max(0, defense + delta)
        "attack":
            attack = max(1, attack + delta)
        "max_hp":
            max_hp = max(1, max_hp + delta)
            hp = clamp(hp + delta, 0, max_hp)
        "max_mp":
            max_mp = max(0, max_mp + delta)
            mp = clamp(mp + delta, 0, max_mp)

# ── 저장/불러오기용 ───────────────────────────────────
func to_dict() -> Dictionary:
    return {
        "level": level,
        "exp": exp_points,
        "hp": hp,
        "max_hp": max_hp,
        "mp": mp,
        "max_mp": max_mp,
        "attack": attack,
        "defense": defense,
        "coins": coins,
        "skills": skills,
        "inventory": inventory,
        "equipment": equipment,
        "set_bonus": _applied_set_bonus,
    }

func from_dict(d: Dictionary) -> void:
    level = d.get("level", 1)
    exp_points = d.get("exp", 0)
    max_hp = d.get("max_hp", 60)
    max_mp = d.get("max_mp", 24)
    hp = d.get("hp", max_hp)
    mp = d.get("mp", max_mp)
    attack = d.get("attack", 12)
    defense = d.get("defense", 4)
    coins = d.get("coins", 0)
    skills = d.get("skills", ["laugh", "breath"])
    inventory = d.get("inventory", {})
    # attack/defense/max_hp/max_mp는 이미 장비 보너스가 반영된 값으로 저장되어 있으므로
    # equipment는 표시용으로만 복원하고 _apply_equip_effect()를 다시 적용하지 않는다.
    equipment = d.get("equipment", {})
    _applied_set_bonus = d.get("set_bonus", {})
    stats_changed.emit()
    equipment_changed.emit()

func reset_new_game() -> void:
    level = 1
    exp_points = 0
    max_hp = 60
    max_mp = 24
    hp = max_hp
    mp = max_mp
    attack = 12
    defense = 4
    coins = 0
    skills = ["laugh", "breath"]
    inventory = {"cocoa": 2, "cookie": 1}
    equipment = {}
    _applied_set_bonus = {}
    stats_changed.emit()
    equipment_changed.emit()
