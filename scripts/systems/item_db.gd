extends Node
## ItemDB — 아이템 정의 모음. 외부 이미지 없이 8×8 픽셀 아트 문자열로 아이콘을 만든다.
##
## kind:
##   "consumable" — 인벤토리에서 사용/전투 중 사용 가능, 상점에서 구매 가능. 쓰면 1개 소모된다.
##   "equipment"  — 슬롯(slot)에 상시 착용하는 장비. 소모되지 않고, 장착 중에는 effect가
##                  PlayerStats 스탯에 영구 반영된다(해제하면 그만큼 다시 빠진다).
##   "story"      — 스토리 진행용(카메라·수첩 등). 사용 불가, 인벤토리에 전시만 된다.
##
## effect: { "hp": n, "mp": n, "atk_buff": n, "def_buff": n, "revive": true }
##   (equipment 아이템의 effect는 "defense"/"attack"/"max_hp"/"max_mp" 중 하나 — 착용 시 그만큼 영구 증가)
## wear: { "color": 본체색, "accent": 포인트색, "style": 모양 }
##   장비를 3D 캐릭터에 그릴 때 쓴다. slot이 붙는 자리와 모양 종류를 정하고
##   (scarf=목에 두르는 링, hat=머리, gloves=양손, shoes=양발),
##   style이 세부를 정한다(plain/star, beanie/cap, mitten/glove, slipper/sneaker).

## 장비 세트 — 같은 계열을 여러 개 착용하면 보너스가 붙는다.
## bonuses의 키는 "몇 개 이상 착용"이고, 조건을 만족하는 단계는 **전부 누적**된다
## (4개 착용 = 2단계 + 4단계 둘 다). perk는 4개 다 모았을 때의 특전 설명이다.
const SETS := {
    "cozy": {
        "name": "포근 세트",
        "items": ["hat", "scarf", "mittens", "slippers"],
        "bonuses": {2: {"max_hp": 10}, 4: {"max_hp": 25, "defense": 3}},
        "perk": "전투를 '온기' 상태로 시작한다",
    },
    "travel": {
        "name": "여행 세트",
        "items": ["travel_cap", "star_scarf", "travel_gloves", "travel_shoes"],
        "bonuses": {2: {"attack": 3}, 4: {"attack": 6, "max_mp": 8}},
        "perk": "'거리두기'에 반드시 성공한다",
    },
    # ── 두 개짜리 교차 세트 ──
    # 포근(기본)·여행(상위) 등급을 하나씩 섞어야 완성된다. 한 등급을 다 모으는
    # 길만 있으면 장비를 하나씩 갈아입는 중간 과정이 전부 손해로 느껴지기 때문에,
    # 섞어 입는 쪽에도 갈 곳을 만들어뒀다. 세트끼리 아이템이 겹쳐도 상관없다 —
    # 조건을 만족하는 세트는 전부 따로 계산된다.
    "nightwalk": {
        "name": "밤마실 세트",
        "items": ["hat", "star_scarf"],
        "bonuses": {2: {"defense": 3, "max_mp": 5}},
        "perk": "전투를 시작할 때 적의 약점이 이미 보인다",
    },
    "firststep": {
        "name": "첫걸음 세트",
        "items": ["mittens", "travel_shoes"],
        "bonuses": {2: {"attack": 2, "max_hp": 8}},
        "perk": "전투를 시작할 때 마음력이 6 돌아온다",
    },
}

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
    "herb_tea": {
        "name": "캐모마일 차",
        "desc": "한 김 식히면 마음이 가라앉는다. 나쁜 상태를 모두 없앤다. (전투 중에만)",
        "kind": "consumable",
        "price": 45,
        "effect": {"cure": true},
        "art": [
            "........",
            "..w.....",
            ".kkkkk..",
            ".kgggk.k",
            ".kgggk.k",
            ".kkkkkk.",
            "..kkk...",
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
        "wear": {"color": "#E0645A", "accent": "#FFF6E4", "style": "plain"},
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
    "star_scarf": {
        "name": "별무늬 목도리",
        "desc": "밤하늘을 두른 것 같다. 방어 +7 (상시 착용).",
        "kind": "equipment",
        "slot": "scarf",
        "price": 150,
        "effect": {"defense": 7},
        "wear": {"color": "#3E5AA8", "accent": "#F5D563", "style": "star"},
        "art": [
            "........",
            ".bbbbbb.",
            "bybybybb",
            ".bbbbbb.",
            "...bb...",
            "...byb..",
            "...bb...",
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
        "wear": {"color": "#E8A24A", "accent": "#FFF6E4", "style": "beanie"},
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
    "travel_cap": {
        "name": "여행 모자",
        "desc": "챙이 있어 먼 곳을 보기 좋다. 마음력 최대치 +6, 마음의 힘 +2 (상시 착용).",
        "kind": "equipment",
        "slot": "hat",
        "price": 140,
        "effect": {"max_mp": 6, "attack": 2},
        "wear": {"color": "#7A8B4F", "accent": "#5A4636", "style": "cap"},
        "art": [
            "..gggg..",
            ".gggggg.",
            "gggggggg",
            "gggggggg",
            "kkkkkkkk",
            ".dddddd.",
            "........",
            "........",
        ],
    },
    "mittens": {
        "name": "벙어리장갑",
        "desc": "손이 따뜻하면 마음에도 힘이 들어간다. 마음의 힘 +3 (상시 착용).",
        "kind": "equipment",
        "slot": "gloves",
        "price": 80,
        "effect": {"attack": 3},
        "wear": {"color": "#E08CA0", "accent": "#FFF6E4", "style": "mitten"},
        "art": [
            "........",
            "..pppp..",
            ".pppppp.",
            "ppppppp.",
            "ppppppp.",
            ".wwwwww.",
            "..wwww..",
            "........",
        ],
    },
    "travel_gloves": {
        "name": "여행 장갑",
        "desc": "손끝까지 야무지게 감싼다. 마음의 힘 +5, 방어 +1 (상시 착용).",
        "kind": "equipment",
        "slot": "gloves",
        "price": 160,
        "effect": {"attack": 5, "defense": 1},
        "wear": {"color": "#8A5A3A", "accent": "#5A4636", "style": "glove"},
        "art": [
            "........",
            ".n.nn.n.",
            "nnnnnnnn",
            "nnnnnnnn",
            "nnnnnnnn",
            ".dddddd.",
            "..dddd..",
            "........",
        ],
    },
    "slippers": {
        "name": "푹신한 실내화",
        "desc": "발이 편하면 덜 지친다. 체력 최대치 +12 (상시 착용).",
        "kind": "equipment",
        "slot": "shoes",
        "price": 75,
        "effect": {"max_hp": 12},
        "wear": {"color": "#8FD8E0", "accent": "#FFF6E4", "style": "slipper"},
        "art": [
            "........",
            "..cccc..",
            ".cccccc.",
            "cccccccc",
            "cwwwwwwc",
            "kkkkkkkk",
            "........",
            "........",
        ],
    },
    "travel_shoes": {
        "name": "여행 운동화",
        "desc": "어디든 걸어갈 수 있을 것 같다. 체력 최대치 +20, 마음의 힘 +1 (상시 착용).",
        "kind": "equipment",
        "slot": "shoes",
        "price": 170,
        "effect": {"max_hp": 20, "attack": 1},
        "wear": {"color": "#7FBF6A", "accent": "#FFF6E4", "style": "sneaker"},
        "art": [
            "........",
            "...gg...",
            "..gggg..",
            ".gggggg.",
            "gwgwgwgg",
            "gggggggg",
            "kkkkkkkk",
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
    # ── 스토리 아이템 (사용 불가, 인벤토리에 전시) ──
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
    # 상태 해제 아이템 — 전투 중에, 실제로 나쁜 상태가 있을 때만 쓸 수 있다
    if eff.has("cure"):
        if not in_battle:
            return ""
        var cured := BattleSystem.clear_bad_statuses()
        if cured <= 0:
            return ""
        PlayerStats.remove_item(id, 1)
        return "%s 사용! 마음이 가라앉았다 (나쁜 상태 %d개 해제)" % [item.name, cured]
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
