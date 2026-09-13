extends "res://scripts/ui/menu_panel.gd"
## QuestUI — 퀘스트 목록. 독립 메뉴다.

func panel_title() -> String:
    return "퀘스트"

func _refresh_content() -> void:
    clear_content()
    var done := 0
    for id in QuestSystem.QUESTS:
        if QuestSystem.is_claimed(id):
            done += 1
    set_subtitle("완료 %d / %d" % [done, QuestSystem.QUESTS.size()])

    for qid in QuestSystem.listed_quests():
        content.add_child(_quest_card(qid))

func _quest_card(qid: String) -> PanelContainer:
    var q: Dictionary = QuestSystem.QUESTS[qid]
    var claimed: bool = QuestSystem.is_claimed(qid)
    var card := make_card(Color("#7FBF6A") if claimed else COL_INK)
    var margin := MarginContainer.new()
    set_margins(margin, 18)
    card.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    margin.add_child(box)

    var head := HBoxContainer.new()
    box.add_child(head)

    var title := make_label(q.name, 32, COL_INK)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(title)

    var cur: int = min(QuestSystem.current_value(qid), q.count)
    var status := make_label("완료!" if claimed else "%d / %d" % [cur, q.count], 28,
        Color("#4A8F3A") if claimed else Color("#6A5A4A"))
    head.add_child(status)

    box.add_child(make_label(q.desc, 25, Color("#6A5A4A")))

    # 진행 바
    var bar_wrap := Control.new()
    bar_wrap.custom_minimum_size = Vector2(0, 18)
    bar_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var bg := ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.2, 0.17, 0.15, 0.35)
    bar_wrap.add_child(bg)
    var fill := ColorRect.new()
    fill.set_anchors_preset(Control.PRESET_FULL_RECT)
    fill.color = Color("#7FBF6A") if claimed else Color("#F5D563")
    fill.anchor_right = clamp(float(cur) / float(max(1, q.count)), 0.0, 1.0)
    bar_wrap.add_child(fill)
    box.add_child(bar_wrap)

    box.add_child(make_label("보상 — " + _reward_text(q.reward), 23, Color("#8A6A3A")))
    return card

func _reward_text(r: Dictionary) -> String:
    var parts: Array = []
    if r.get("coins", 0) > 0:
        parts.append("✦%d" % r.coins)
    if r.get("exp", 0) > 0:
        parts.append("경험치 %d" % r.exp)
    for item_id in r.get("items", {}):
        parts.append("%s ×%d" % [ItemDB.item_name(item_id), r.items[item_id]])
    return ", ".join(parts)
