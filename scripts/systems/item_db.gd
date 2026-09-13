extends Node
## ItemDB — 아이템 정의 모음. 외부 이미지 없이 8×8 픽셀 아트 문자열로 아이콘을 만든다.
##
## kind:
##   "consumable" — 가방에서 사용/전투 중 사용 가능, 상점에서 구매 가능. 쓰면 1개 소모된다.
##   "equipment"  — 슬롯(slot)에 상시 착용하는 장비. 소모되지 않고, 장착 중에는 effect가
##                  PlayerStats 스탯에 영구 반영된다(해제하면 그만큼 다시 빠진다).
##   "story"      — 스토리 진행용(카메라·수첩 등). 사용 불가, 가방에 전시만 된다.
##
## effect: { "hp": n, "mp": n, "atk_buff": n, "def_buff": n, "revive": true }
##   (equipment 아이템의 effect는 "defense"/"attack"/"max_hp"/"max_mp" 중 하나 — 착용 시 그만큼 영구 증가)

const PALETTE := {
    "k": "#2A211C",  # 외곽선(어두운 갈색)
    "w": "#FFF6E4",  # 밝은 크림
    "r": "#E0645A",  # 빨강
    "p": "#F2A6AE",  # 분홍
    "o": "#E8A24A",  # 주황
    "y": "#F5D563",  # 노랑
    "g": "#7FBF6A",  # 초록
    "b": "#6C9BD4",  # 파랑
    "c": "#8FD8E0",  # 하늘
    "m": "#B59CE0",  # 보라
    "n": "#8A5A3A",  # 갈색
    "s": "#C9CEDA",  # 은색
    "d": "#5A4636",  # 진한 갈색
}

const ITEMS := {
    "cocoa": {
        "name": "따뜻한 코코아",
        "desc": "한 모금에 마음이 녹는다. 체력 40 회복.",
        "kind": "consumable",
        "price": 28,
        "effect": {"hp": 40},
        "art": [
            "........",
            ".kkkkk..",
            ".kwwwkk.",
            ".knnnk.k",
            ".knnnk.k",
            ".kwwwkk.",
            "..kkk...",
            "........",
        ],
    },
    "cookie": {
        "name": "버터 쿠키",
        "desc": "바삭한 위로. 마음력 20 회복.",
        "kind": "consumable",
        "price": 22,
        "effect": {"mp": 20},
        "art": [
            "........",
            "..kkkk..",
            ".koyoyk.",
            "koyooyok",
            "koooyook",
            ".kyooyk.",
            "..kkkk..",
            "........",
        ],
    },
    "energy_drink": {
        "name": "야근 탈출 드링크",
        "desc": "체력 25, 마음력 15 회복.",
        "kind": "consumable",
        "price": 48,
        "effect": {"hp": 25, "mp": 15},
        "art": [
            "..kkk...",
            "..kck...",
            ".kkckk..",
            ".kccck..",
            ".kgggk..",
            ".kgggk..",
            ".kkkkk..",
            "........",
        ],
    },
    "clover": {
        "name": "네잎클로버",
        "desc": "다음 공격의 마음의 힘이 크게 오른다.",
        "kind": "consumable",
        "price": 60,
        "effect": {"atk_buff": 12},
        "art": [
            "........",
            "..g.g...",
            ".ggkgg..",
            "..gkg...",
            ".ggkgg..",
            "..g.g...",
            "...g....",
            "...g....",
        ],
    },
    "scarf": {
        "name": "포근한 목도리",
        "desc": "항상 두르고 있으면 마음이 든든해진다. 방어 +4 (상시 착용).",
        "kind": "equipment",
        "slot": "scarf",
        "price": 70,
        "effect": {"defense": 4},
        "art": [
            "........",
            ".rrrrrr.",
            "rwrwrwrr",
            ".rrrrrr.",
            "...rr...",
            "...rwr..",
            "...rr...",
            "........",
        ],
    },
    "hat": {
        "name": "털모자",
        "desc": "포근하게 감싸주면 마음에 여유가 생긴다. 마음력 최대치 +10 (상시 착용).",
        "kind": "equipment",
        "slot": "hat",
        "price": 65,
        "effect": {"max_mp": 10},
        "art": [
            "..oooo..",
            ".oyyyyo.",
            "oyyyyyyo",
            "oyyyyyyo",
            "oyyyyyyo",
            "kkkkkkkk",
            "kwwwwwwk",
            "........",
        ],
    },
    "star_candy": {
        "name": "별사탕",
        "desc": "체력과 마음력을 모두 되돌린다.",
        "kind": "consumable",
        "price": 120,
        "effect": {"hp": 999, "mp": 999},
        "art": [
            "...y....",
            "...y....",
            ".yyyyy..",
            "..yyy...",
            ".yy.yy..",
            ".y...y..",
            "........",
            "........",
        ],
    },
    # ── 스토리 아이템 (사용 불가, 가방에 전시) ──
    "camera": {
        "name": "낡은 카메라",
        "desc": "첫 여행을 기록할 도구.",
        "kind": "story",
        "price": 0,
        "effect": {},
        "art": [
            "........",
            "..kkk...",
            "kkkkkkk.",
            "kdwwwdk.",
            "kdwcwdk.",
            "kdwwwdk.",
            "kkkkkkk.",
            "........",
        ],
    },
    "notebook": {
        "name": "여행 수첩",
        "desc": "가고 싶은 곳을 적어둔 수첩.",
        "kind": "story",
        "price": 0,
        "effect": {},
        "art": [
            "kkkkkkk.",
            "kwwwwwk.",
            "kwbbbwk.",
            "kwwwwwk.",
            "kwbbbwk.",
            "kwwwwwk.",
            "kkkkkkk.",
            "........",
        ],
    },
    "travel_bag": {
        "name": "여행 가방",
        "desc": "둘이 함께 쓸 커다란 가방.",
        "kind": "story",
        "price": 0,
        "effect": {},
        "art": [
            "..kkk...",
            ".k...k..",
            "kkkkkkk.",
            "kbbbbbk.",
            "kbbkbbk.",
            "kbbbbbk.",
            "kkkkkkk.",
            "........",
        ],
    },
    "badge": {
        "name": "사원증",
        "desc": "반납하면 마음이 가벼워질 물건.",
        "kind": "story",
        "price": 0,
        "effect": {},
        "art": [
            "...k....",
            "..kkk...",
            "kkkkkkk.",
            "kwwwwwk.",
            "kwsssws.",
            "kwwwwwk.",
            "kkkkkkk.",
            "........",
        ],
    },
}

func get_item(id: String) -> Dictionary:
    return ITEMS.get(id, {})

func item_name(id: String) -> String:
    return ITEMS.get(id, {}).get("name", id)

func is_consumable(id: String) -> bool:
    return ITEMS.get(id, {}).get("kind", "") == "consumable"

func is_story_item(id: String) -> bool:
    return ITEMS.get(id, {}).get("kind", "") == "story"

func is_equipment(id: String) -> bool:
    return ITEMS.get(id, {}).get("kind", "") == "equipment"

## 상점 판매 목록 (자판기) — 소비 아이템과 장비를 함께 판다
func shop_list() -> Array:
    var out: Array = []
    for id in ITEMS:
        if ITEMS[id].kind == "consumable" or ITEMS[id].kind == "equipment":
            out.append(id)
    out.sort_custom(func(a, b): return ITEMS[a].price < ITEMS[b].price)
    return out

## 아이템 사용 — 성공하면 사용 결과 설명을 반환, 실패하면 빈 문자열
## in_battle=false면 버프류(전투 전용)는 사용할 수 없다.
func use_item(id: String, in_battle: bool = false) -> String:
    var item := get_item(id)
    if item.is_empty() or item.kind != "consumable":
        return ""
    if PlayerStats.item_count(id) <= 0:
        return ""
    var eff: Dictionary = item.effect
    var is_buff_only := (eff.has("atk_buff") or eff.has("def_buff")) and not eff.has("hp") and not eff.has("mp")
    if is_buff_only and not in_battle:
        return ""
    var msgs: Array = []
    if eff.has("hp"):
        var healed := PlayerStats.heal(eff.hp)
        if healed > 0:
            msgs.append("체력 +%d" % healed)
    if eff.has("mp"):
        var restored := PlayerStats.restore_mp(eff.mp)
        if restored > 0:
            msgs.append("마음력 +%d" % restored)
    if in_battle and eff.has("atk_buff"):
        BattleSystem.add_atk_buff(eff.atk_buff)
        msgs.append("마음의 힘 +%d" % eff.atk_buff)
    if in_battle and eff.has("def_buff"):
        BattleSystem.add_def_buff(eff.def_buff)
        msgs.append("방어 +%d" % eff.def_buff)
    if msgs.is_empty():
        return ""
    PlayerStats.remove_item(id, 1)
    return "%s 사용! %s" % [item.name, ", ".join(msgs)]
