extends "res://scripts/ui/menu_panel.gd"
## ShopUI — 회사 자판기. 반짝 조각(✦)으로 아이템을 산다.

func panel_title() -> String:
    return "자판기"

func _refresh_content() -> void:
    clear_content()
    set_subtitle("가진 반짝 조각   ✦ %d" % PlayerStats.coins)
    content.add_child(make_label("그림자를 걷어내면 반짝 조각이 남는다. 그걸로 뭐라도 사 먹자.", 24, Color("#6A5A4A")))
    for item_id in ItemDB.shop_list():
        content.add_child(_shop_card(item_id))

func _shop_card(item_id: String) -> PanelContainer:
    var item: Dictionary = ItemDB.get_item(item_id)
    var card := make_card()
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
    col.add_child(make_label("%s   (보유 %d)" % [item.name, PlayerStats.item_count(item_id)], 30, COL_INK))
    col.add_child(make_label(item.desc, 23, Color("#6A5A4A")))
    col.add_child(make_label("✦ %d" % item.price, 26, Color("#8A6A3A")))

    row.add_child(make_small_button("구매", func(): _buy(item_id), PlayerStats.coins >= item.price))
    return card

func _buy(item_id: String) -> void:
    var item: Dictionary = ItemDB.get_item(item_id)
    if not PlayerStats.spend_coins(item.price):
        GameUI.toast("반짝 조각이 부족해요.")
        return
    PlayerStats.add_item(item_id, 1)
    GameUI.toast("%s 을(를) 샀어요!" % item.name, Color("#7FBF6A"))
    _refresh_content()
