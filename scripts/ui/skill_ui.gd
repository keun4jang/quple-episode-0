extends "res://scripts/ui/menu_panel.gd"
## SkillUI — 스킬 창. 배운 스킬과 아직 못 배운 스킬을 해금 레벨과 함께 보여준다.
## 실제 사용은 전투 화면에서 한다 (여기서는 확인만).

const TYPE_NAMES := {
    "attack": "공격",
    "heal": "회복",
    "buff": "강화",
}

func panel_title() -> String:
    return "스킬"

func _refresh_content() -> void:
    clear_content()
    var learned: int = PlayerStats.skills.size()
    set_subtitle("배운 스킬 %d / %d   ·   마음력 %d / %d" % [
        learned, BattleSystem.SKILLS.size(), PlayerStats.mp, PlayerStats.max_mp])
    content.add_child(make_label(
        "스킬은 전투 중 '싸운다'에서 고른다. 적의 약점을 찌르면 피해가 크게 오른다.",
        24, Color("#6A5A4A")))

    for skill_id in _ordered_skills():
        content.add_child(_skill_card(skill_id))

## 기본 보유 스킬 먼저, 그 다음 해금 레벨 순서
func _ordered_skills() -> Array:
    var out: Array = []
    for id in BattleSystem.SKILLS:
        if _unlock_level(id) <= 1:
            out.append(id)
    var levels: Array = PlayerStats.SKILL_UNLOCKS.keys()
    levels.sort()
    for lv in levels:
        out.append(PlayerStats.SKILL_UNLOCKS[lv])
    return out

func _unlock_level(skill_id: String) -> int:
    for lv in PlayerStats.SKILL_UNLOCKS:
        if PlayerStats.SKILL_UNLOCKS[lv] == skill_id:
            return int(lv)
    return 1

func _skill_card(skill_id: String) -> PanelContainer:
    var s: Dictionary = BattleSystem.SKILLS[skill_id]
    var learned: bool = skill_id in PlayerStats.skills
    var card := make_card(COL_INK if learned else Color("#A89F92"))
    var margin := MarginContainer.new()
    set_margins(margin, 16)
    card.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    margin.add_child(box)

    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 12)
    box.add_child(head)

    var name_label := make_label(s.name, 32, COL_INK if learned else Color("#8A8074"))
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(name_label)

    var cost: String = "마음력 %d" % s.mp if s.mp > 0 else "마음력 0"
    head.add_child(make_label(cost, 26, Color("#4A6A9A")))

    var info: Array = [TYPE_NAMES.get(s.type, s.type)]
    if s.has("power"):
        info.append("위력 ×%.1f" % s.power)
    if s.has("heal_base"):
        info.append("회복 %d + 레벨×3" % s.heal_base)
    if s.has("atk_buff"):
        info.append("마음의 힘 +%d" % s.atk_buff)
    if s.has("enemy_grants"):
        info.append("적을 %s 상태로 만든다" % BattleSystem.ENEMY_STATUSES.get(String(s.enemy_grants), {}).get("name", "특수"))
    if s.has("partner_bonus"):
        info.append("파트너와 함께면 ×%.2f" % s.partner_bonus)
    if s.has("grants"):
        info.append("%s 상태를 남긴다" % BattleSystem.STATUSES.get(String(s.grants), {}).get("name", "특수"))
    box.add_child(make_label("   ".join(info), 24, Color("#4A7A3A") if learned else Color("#8A8074")))

    box.add_child(make_label(s.desc, 24, Color("#6A5A4A") if learned else Color("#9A9084")))

    if not learned:
        box.add_child(make_label("마음 레벨 %d에 배운다 (지금 %d)" % [
            _unlock_level(skill_id), PlayerStats.level], 24, Color("#9A6A4A")))
    return card
