extends CanvasLayer

@onready var _panel: Panel = get_node_or_null("Panel")
@onready var _vbox: VBoxContainer = get_node_or_null("Panel/VBoxContainer")
@onready var _title: Label = get_node_or_null("Panel/VBoxContainer/TitleLabel")
@onready var _sub: Label = get_node_or_null("Panel/VBoxContainer/SubLabel")
@onready var _hint: Label = get_node_or_null("Panel/VBoxContainer/HintLabel")

var _memo: Label
var _started: bool = false

func _ready() -> void:
	add_to_group("clear_screen")
	visible = false

func _prepare_nodes() -> void:
	# Title: 크게, 초기엔 투명 + 살짝 작게
	if _title:
		_title.add_theme_font_size_override("font_size", 64)
		_title.pivot_offset = _title.size * 0.5
		var tc := _title.get_theme_color("font_color")
		tc.a = 0.0
		_title.modulate = Color(1, 1, 1, 0.0)
		_title.scale = Vector2(0.7, 0.7)

	# Subtitle: 처음엔 투명
	if _sub:
		_sub.modulate = Color(1, 1, 1, 0.0)

	# Memo 라벨 동적 생성 (subtitle 뒤에 삽입)
	_memo = Label.new()
	_memo.text = "발견한 메모: 0 / 3"
	_memo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_memo.add_theme_font_size_override("font_size", 24)
	_memo.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0, 1.0))
	_memo.modulate = Color(1, 1, 1, 0.0)
	if _vbox:
		_vbox.add_child(_memo)
		if _hint:
			_vbox.move_child(_memo, _hint.get_index())
	else:
		add_child(_memo)

	# Hint: 처음엔 투명
	if _hint:
		_hint.text = "Space / Esc 로 종료"
		_hint.modulate = Color(1, 1, 1, 0.0)

	# Panel(어두운 오버레이): 처음엔 투명
	if _panel:
		_panel.modulate = Color(1, 1, 1, 0.0)

func _memo_count() -> int:
	var st = get_node_or_null("/root/Episode0State")
	if st and "memos_found" in st and st.memos_found != null:
		return st.memos_found.size()
	return 0

func show_clear() -> void:
	if _started:
		return
	_started = true
	visible = true

	# 오디오
	var am = get_node_or_null("/root/AudioManager")
	if am:
		if am.has_method("stop_bgm"):
			am.stop_bgm()
		if am.has_method("play_sfx"):
			am.play_sfx("ui_select")

	_prepare_nodes()

	var n := _memo_count()
	if _memo:
		_memo.text = "발견한 메모: %d / 3" % n

	# 1) 어두운 오버레이 페이드인
	if _panel:
		var t0 := create_tween()
		t0.tween_property(_panel, "modulate:a", 1.0, 0.8)

	# 2) 타이틀 페이드인 + 부드러운 스케일업 (0.4s 지연)
	if _title:
		var tt := create_tween()
		tt.set_parallel(true)
		tt.tween_property(_title, "modulate:a", 1.0, 0.8).set_delay(0.4)
		tt.tween_property(_title, "scale", Vector2(1.0, 1.0), 0.9) \
			.set_delay(0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 3) 부제 페이드인 (1s 후)
	if _sub:
		var ts := create_tween()
		ts.tween_interval(1.0)
		ts.tween_property(_sub, "modulate:a", 1.0, 0.9)

	# 4) 메모 라인 페이드인 (1.7s 후)
	if _memo:
		var tm := create_tween()
		tm.tween_interval(1.7)
		tm.tween_property(_memo, "modulate:a", 1.0, 0.8)

	# 5) 종료 힌트 페이드인 (2.5s 후)
	if _hint:
		var th := create_tween()
		th.tween_interval(2.5)
		th.tween_property(_hint, "modulate:a", 1.0, 0.8)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_tree().quit()
