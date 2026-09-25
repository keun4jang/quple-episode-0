class_name TouchScroll
extends RefCounted
## 손가락으로 쓰는 목록 스크롤 - 여행판·배낭·설정·가게 선반이 같이 쓴다.
##
## 두 가지가 모자랐다 (폰으로 해 보고 들은 말):
## - **스크롤 막대가 너무 가늘었다.** 기본 막대는 몇 px 라 손가락으로 못 잡는다.
##   엄지 폭(`BAR_W`)으로 넓히고 손잡이를 밝은 금색으로 칠한다
## - **목록이 안 움직였다.** 엔진의 `ScrollContainer` 는 손가락 끌기로 굴러가지만,
##   끌기가 **버튼 위에서** 시작되면 버튼이 입력을 먹어 버려 목록까지 안 온다
##   (버튼의 기본 `MOUSE_FILTER_STOP`). 목록이 거의 버튼이라 사실상 안 굴렀다.
##   목록 안의 버튼들을 `MOUSE_FILTER_PASS` 로 바꾼다 - 누르기는 그대로 되고,
##   끌면 목록이 받아 굴린다. 끌기가 시작되면 엔진이 그 버튼의 눌림을 풀어 준다
##   (`NOTIFICATION_SCROLL_BEGIN`) - 굴리다 잘못 눌리지 않는다.

const BAR_W := 30.0


static func setup(sc: ScrollContainer) -> void:
	sc.scroll_deadzone = 10
	var vb := sc.get_v_scroll_bar()
	vb.custom_minimum_size.x = BAR_W
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.09, 0.14, 0.28)
	track.set_corner_radius_all(int(BAR_W * 0.5))
	vb.add_theme_stylebox_override("scroll", track)
	vb.add_theme_stylebox_override("scroll_focus", track)
	for key in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var g := StyleBoxFlat.new()
		g.bg_color = Color("#E8C46A") if key == "grabber" else Color("#FFE39A")
		g.set_corner_radius_all(int(BAR_W * 0.5))
		g.border_color = Color(0.16, 0.13, 0.18, 0.8)
		g.set_border_width_all(2)
		# 손잡이가 너무 짧으면 못 잡는다.
		g.content_margin_top = 28
		g.content_margin_bottom = 28
		vb.add_theme_stylebox_override(key, g)
	# 이미 든 것과 나중에 들어오는 것 모두.
	for c in sc.get_children():
		_watch(c)
	sc.child_entered_tree.connect(_watch)


static func _watch(n: Node) -> void:
	if n is ScrollBar:
		return
	if n is BaseButton:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for c in n.get_children():
		_watch(c)
	if not n.child_entered_tree.is_connected(_watch):
		n.child_entered_tree.connect(_watch)
