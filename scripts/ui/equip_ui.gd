extends "res://scripts/ui/menu_panel.gd"
## EquipUI — 장비 창. 슬롯별로 가진 장비를 보여주고 장착/해제한다.
## 인벤토리(소모품·중요 물품)와 완전히 분리된 독립 메뉴다.

## 슬롯 순서와 표시 이름 (ItemDB 아이템의 slot 값과 맞춰야 한다)
const SLOTS := [
    {"id": "hat", "name": "머리"},
    {"id": "scarf", "name": "목"},
    {"id": "gloves", "name": "손"},
    {"id": "shoes", "name": "발"},
]

## 장비 effect 키 → 화면에 보여줄 이름
const EFFECT_NAMES := {
    "attack": "마음의 힘",
    "defense": "방어",
    "max_hp": "체력 최대치",
    "max_mp": "마음력 최대치",
}

func panel_title() -> String:
    return "장비"

func _refresh_content() -> void:
    clear_content()
    set_subtitle("마음의 힘 %d   ·   방어 %d   ·   체력 %d   ·   마음력 %d" % [
        PlayerStats.attack, PlayerStats.defense, PlayerStats.max_hp, PlayerStats.max_mp])

    for slot in SLOTS:
        var slot_id: String = slot.id
        var equipped_id: String = String(PlayerStats.equipment.get(slot_id, ""))
        var head: String = "— %s —" % slot.name
        if equipped_id != "":
            head += "   %s 착용 중" % ItemDB.item_name(equipped_id)
        content.add_child(make_label(head, 30, Color("#6A5A4A")))

        var owned := _owned_for_slot(slot_id)
        if owned.is_empty():
            content.add_child(make_label(
                "가진 장비가 없어요. 상점에서 사거나 그림자를 물리치면 얻어요.", 26, Color("#8A7A6A")))
            continue
        for item_id in owned:
            content.add_child(_equip_card(item_id, item_id == equipped_id))

func _owned_for_slot(slot_id: String) -> Array:
    var out: Array = []
    for id in PlayerStats.inventory.keys():
        if not ItemDB.is_equipment(id):
            continue
        if String(ItemDB.get_item(id).get("slot", "")) == slot_id:
            out.append(id)
    return out

func _equip_card(item_id: String, equipped: bool) -> PanelContainer:
    var item: Dictionary = ItemDB.get_item(item_id)
    var card := make_card(Color("#7FBF6A") if equipped else COL_INK)
    var margin := MarginContainer.new()
    set_margins(margin, 16)
    card.add_child(margin)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 18)
    margin.add_child(row)

    var icon_wrap := Control.new()
    icon_wrap.custom_minimum_size = Vector2(80, 80)
    PixelArt.build(item.art, ItemDB.PALETTE, 10.0, icon_wrap)
    row.add_child(icon_wrap)

    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(col)

    var title: String = item.name
    if equipped:
        title += "   (착용 중)"
    col.add_child(make_label(title, 32, COL_INK))
    col.add_child(make_label(_effect_text(item.get("effect", {})), 26, Color("#4A7A3A")))
    col.add_child(make_label(item.desc, 23, Color("#6A5A4A")))

    if equipped:
        row.add_child(make_small_button("해제", func(): _unequip(String(item.slot))))
    else:
        row.add_child(make_small_button("장착", func(): _equip(item_id)))
    return card

func _effect_text(eff: Dictionary) -> String:
    var parts: Array = []
    for key in eff:
        if EFFECT_NAMES.has(key):
            parts.append("%s +%d" % [EFFECT_NAMES[key], int(eff[key])])
    return "   ".join(parts)

func _equip(item_id: String) -> void:
    if PlayerStats.equip_item(item_id):
        GameUI.toast("%s 착용!" % ItemDB.item_name(item_id), Color("#7FBF6A"))
    _refresh_content()

func _unequip(slot: String) -> void:
    PlayerStats.unequip_slot(slot)
    _refresh_content()
