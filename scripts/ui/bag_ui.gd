extends "res://scripts/ui/menu_panel.gd"
## BagUI — 가방. 오직 "아이템"만 들어있다.
## (퀘스트는 별도 메뉴로 분리했다 — 가방에 퀘스트가 있으면 이상하니까.)

func panel_title() -> String:
    return "가방"

func _refresh_content() -> void:
    clear_content()
    set_subtitle("아이템 %d개   ·   ✦ %d" % [PlayerStats.total_items(), PlayerStats.coins])

    var consumables: Array = []
    var story_items: Array = []
    for id in PlayerStats.inventory.keys():
        if ItemDB.is_story_item(id):
            story_items.append(id)
        else:
            consumables.append(id)

    content.add_child(make_label("— 쓸 수 있는 것 —", 30, Color("#6A5A4A")))
    if consumables.is_empty():
        content.add_child(make_label("아직 아무것도 없어요. 상점에서 사거나 그림자를 물리치면 얻어요.", 26, Color("#8A7A6A")))
    for id in consumables:
        content.add_child(_item_card(id, true))

    content.add_child(make_label("— 여행 준비물 —", 30, Color("#6A5A4A")))
    if story_items.is_empty():
        content.add_child(make_label("아직 챙긴 여행 물품이 없어요.", 26, Color("#8A7A6A")))
    for id in story_items:
        content.add_child(_item_card(id, false))

func _item_card(item_id: String, usable: bool) -> PanelContainer:
    var item: Dictionary = ItemDB.get_item(item_id)
    var card := make_card()
    var margin := MarginContainer.new()
    set_margins(margin, 16)
    card.add_child(margin)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 18)
    margin.add_child(row)

    # 픽셀 아이콘
    var icon_wrap := Control.new()
    icon_wrap.custom_minimum_size = Vector2(80, 80)
    PixelArt.build(item.art, ItemDB.PALETTE, 10.0, icon_wrap)
    row.add_child(icon_wrap)

    var text_col := VBoxContainer.new()
    text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(text_col)

    var count: int = PlayerStats.item_count(item_id)
    text_col.add_child(make_label("%s   ×%d" % [item.name, count], 32, COL_INK))
    text_col.add_child(make_label(item.desc, 24, Color("#6A5A4A")))

    if usable:
        var eff: Dictionary = item.effect
        var buff_only: bool = (eff.has("atk_buff") or eff.has("def_buff")) and not eff.has("hp") and not eff.has("mp")
        if buff_only:
            text_col.add_child(make_label("전투 중에만 쓸 수 있어요.", 22, Color("#9A6A4A")))
        else:
            row.add_child(make_small_button("사용", func(): _use(item_id)))
    return card

func _use(item_id: String) -> void:
    var msg := ItemDB.use_item(item_id, false)
    if msg == "":
        GameUI.toast("지금은 쓸 수 없어요.")
    else:
        GameUI.toast(msg, Color("#7FBF6A"))
    _refresh_content()
