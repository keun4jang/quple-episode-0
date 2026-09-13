extends CanvasLayer
## TutorialUI — 첫 플레이 때 한 번만 보여주는 단계별 조작 안내.
## 첫 맵(CompanyFront3D)에서 maybe_show()로 띄운다. 한 번 보면 다시 뜨지 않는다.
## 언제든 "건너뛰기"로 끝낼 수 있다 — 붙잡아두지 않는다.

const STEPS := [
	{
		"title": "움직이기",
		"body": "왼쪽 아래 조이스틱을 끌면 쿼카가 걸어가요.\n키보드로는 화살표 키를 씁니다.",
	},
	{
		"title": "말 걸기 · 줍기",
		"body": "바닥에 빛나는 표시가 보이면 가까이 가서\n오른쪽 아래 ✦ 버튼을 누르세요.\n\n파랑 = 이동    분홍 = 대화    금색 = 줍기",
	},
	{
		"title": "메뉴",
		"body": "왼쪽 위 버튼으로 메뉴를 엽니다.\n\n인벤토리 · 장비 · 스킬 · 퀘스트\n상점 · 앨범 · 설정",
	},
	{
		"title": "전투",
		"body": "그림자 감정이 다가오면 전투가 시작돼요.\n\"싸운다\"에서 스킬을 고르세요.\n\n적마다 약점 스킬이 있어요. 약점을 맞히면\n피해가 크게 오르고 적의 턴도 건너뜁니다.",
	},
	{
		"title": "괜찮아요",
		"body": "체력이 0이 돼도 게임이 끝나지 않아요.\n잠시 주저앉았다가 다시 일어섭니다.\n\n이제 불 켜진 사무실로 가볼까요?",
	},
]

const COL_INK := Color("#1B1622")
const COL_PANEL := Color("#F7ECD8")

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/VBox/Label
@onready var ok_btn: Button = $Panel/VBox/OkBtn

var _step: int = 0
var _step_label: Label
var _skip_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_style()
	ok_btn.pressed.connect(_next)

func _style() -> void:
	panel.add_theme_stylebox_override("panel", _pixel_box(COL_PANEL, COL_INK))
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", COL_INK)

	var vbox: VBoxContainer = $Panel/VBox
	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 34)
	_step_label.add_theme_color_override("font_color", Color("#7A5A9A"))
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_step_label)
	vbox.move_child(_step_label, 0)

	_style_button(ok_btn, Color("#4A3D63"), COL_PANEL)

	_skip_btn = Button.new()
	_skip_btn.text = "건너뛰기"
	_skip_btn.custom_minimum_size = Vector2(300, 84)
	_skip_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(_skip_btn, Color("#B4AFA4"), COL_INK)
	_skip_btn.pressed.connect(_close)
	vbox.add_child(_skip_btn)

func _style_button(b: Button, bg: Color, fg: Color) -> void:
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_stylebox_override("normal", _pixel_box(bg, COL_INK))
	b.add_theme_stylebox_override("hover", _pixel_box(bg.lightened(0.12), COL_INK))
	b.add_theme_stylebox_override("pressed", _pixel_box(bg.darkened(0.15), COL_INK))

func _pixel_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(0)
	return sb

func maybe_show() -> void:
	if _seen():
		return
	_step = 0
	_render()
	visible = true
	get_tree().paused = true

func _render() -> void:
	var s: Dictionary = STEPS[_step]
	_step_label.text = "%s   %d / %d" % [s.title, _step + 1, STEPS.size()]
	label.text = s.body
	ok_btn.text = "시작하기" if _step == STEPS.size() - 1 else "다음"
	_skip_btn.visible = _step < STEPS.size() - 1

func _next() -> void:
	if AudioManager:
		AudioManager.ui_select()
	_step += 1
	if _step >= STEPS.size():
		_close()
		return
	_render()

func _close() -> void:
	visible = false
	get_tree().paused = false
	var cfg = ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("tutorial", "seen", true)
	cfg.save("user://settings.cfg")

func _seen() -> bool:
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return false
	return bool(cfg.get_value("tutorial", "seen", false))
