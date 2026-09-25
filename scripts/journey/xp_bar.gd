class_name XpBar
extends Control
## 화면 맨 아래 가로로 긴 **경험 막대** (메이플스토리처럼). 늘 떠 있다.
##
## "내가 언제 레벨업 하는지" 가 보여야 한 마리 더 잡는다. 여태는 싸울 때만
## 뜨는 왼쪽 아래 막대 밑에 얇은 노란 띠로만 있어서, 싸움을 놓으면 사라졌고
## 수도 안 적혀 있었다. 이제 늘 보이고, 수와 **레벨업까지 남은 양**을 적는다.
## 경험이 들어오면 막대가 한 번 반짝인다.

const H := 22.0
const MARGIN := 6.0

var _last_xp := -1
var _last_lv := -1
var _flash := 0.0


func _ready() -> void:
	name = "XpBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 0
	offset_right = 0
	offset_top = -H - MARGIN
	offset_bottom = -MARGIN


func _process(delta: float) -> void:
	if Battle.xp != _last_xp or Battle.level != _last_lv:
		if _last_xp >= 0:
			_flash = 1.0
		_last_xp = Battle.xp
		_last_lv = Battle.level
	_flash = maxf(0.0, _flash - delta * 2.0)
	queue_redraw()


## 막대에 적는 글.
static func text_now() -> String:
	if Battle.level >= Battle.LEVEL_MAX:
		return "LV %d  ·  최고 레벨" % Battle.level
	var need := Battle.xp_need()
	return "LV %d  ·  경험 %d / %d  ·  레벨업까지 %d" % [Battle.level, Battle.xp, need,
		maxi(0, need - Battle.xp)]


func _draw() -> void:
	var w := size.x
	var k := 1.0 if Battle.level >= Battle.LEVEL_MAX \
		else clampf(float(Battle.xp) / maxf(1.0, float(Battle.xp_need())), 0.0, 1.0)
	draw_rect(Rect2(0, 0, w, H), Color(0.12, 0.09, 0.14, 0.82))
	var fill := Color("#FFD43B").lerp(Color("#FFFBE6"), _flash * 0.8)
	draw_rect(Rect2(2, 3, (w - 4) * k, H - 6), fill)
	# 열 칸 눈금 - 얼마나 남았는지 한눈에.
	for i in range(1, 10):
		var x := w * float(i) / 10.0
		draw_line(Vector2(x, 3), Vector2(x, H - 3), Color(0.12, 0.09, 0.14, 0.45), 2.0)
	var font := get_theme_default_font()
	if font == null:
		return
	var t := text_now()
	var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var at := Vector2((w - tw) * 0.5, H - 5)
	draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0.12, 0.09, 0.14))
	draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#FFFDF6"))
