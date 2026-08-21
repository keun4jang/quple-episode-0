extends Node
## 처음 시작할 때 나오는 짧은 인트로. **왜 떠나는지**만 보여 준다.
##
## 메인화면에서 "새 여행" 을 고르면 프롤로그(잿마루) 앞에 잠깐 들른다.
## 이어하기·프롤로그 건너뛰기로 들어오면 안 나온다 — 한 번 본 이야기를
## 두 번 보여 주지 않는다.
##
## ## 그림을 새로 안 그렸다
##
## 새 삽화를 그릴 형편이 아니라, **이미 있는 소품 그림 몇 개를 모아**
## 작은 정물을 만든다 — 사무실 창, 책상, 의자, 그리고 주인공. 픽셀
## 게임이라 이 정도로도 장면이 된다. 나중에 진짜 삽화가 생기면
## `SLIDES` 의 `art` 를 그림 한 장으로 바꾸면 된다.
##
## ## 제목을 여기서 쓰지 않는다
##
## "진짜 행복" 은 게임 전체에서 딱 두 번만 나온다(`CLAUDE.md`) — 마지막
## 재회와 평상. 인트로에서 쓰면 세 번째가 된다. 그래서 **말하지 않고
## 질문만 남긴다** — "웃는 얼굴이라고들 했다. 정말 그런지는 나도 몰랐다."

const NEXT := "res://scenes/journey/Jaenmaru.tscn"
const FADE := 0.45

## [글, [정물 조각들]]. 조각은 [그림이름, 가로칸, 세로칸, 배율] —
## 가운데를 기준으로 그 자리에 놓는다.
const SLIDES := [
	["밤 열한 시.\n사무실에 남은 건 나뿐이었다.",
		[["office-window", -180, -60, 4], ["office-window", 0, -60, 4],
		["office-window", 180, -60, 4],
		["desk", -70, 90, 4], ["office-chair", -70, 150, 4],
		["cabinet", 150, 100, 4]]],
	["창밖으로 비행기 한 대가 내려앉았다.\n…어디로 가는 걸까.",
		[["office-window", 0, 0, 9]]],
	["웃는 얼굴이라고들 했다.\n정말 그런지는 나도 몰랐다.",
		[["hero", 0, 0, 9]]],
	["그래서, 떠나기로 했다.",
		[["hero", -110, 20, 6], ["signpost", 120, 10, 6]]],
]

var _at := 0
var _text: Label
var _art: Control
var _tw: Tween
var _going := false


func _ready() -> void:
	# 뒤로가기로 건너뛴다. 화면을 덮는 것은 다 이 그룹에 넣는다
	# (`CLAUDE.md` — 안 넣으면 뒤로가기가 앱을 끈다).
	add_to_group("overlay")
	_build()
	_show_slide()


## 뒤로가기가 부른다. 인트로는 닫는 게 아니라 **건너뛰는** 것이다.
func close() -> void:
	_go_on()


func _build() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	# 정물이 놓이는 자리. 가운데보다 조금 위.
	_art = Control.new()
	_art.set_anchors_preset(Control.PRESET_CENTER)
	# 글과 너무 멀면 두 덩이가 따로 논다. 조금 내려 붙인다.
	_art.position = Vector2(0, 30)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(_art)

	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.add_theme_font_size_override("font_size", 30)
	_text.add_theme_color_override("font_color", Color("#FFF2C8"))
	_text.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_text.offset_left = -420
	_text.offset_right = 420
	_text.offset_top = -230
	_text.offset_bottom = -110
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(_text)

	# 아무 데나 눌러 넘긴다. 폰에는 Esc 가 없다.
	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap.pressed.connect(_next)
	bg.add_child(tap)

	var more := Label.new()
	more.text = "화면을 누르면 넘어가요"
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	more.add_theme_font_size_override("font_size", 20)
	more.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 0.45))
	more.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	more.grow_horizontal = Control.GROW_DIRECTION_BOTH
	more.offset_left = -300
	more.offset_right = 300
	more.offset_top = -70
	more.offset_bottom = -34
	more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(more)

	var skip := Button.new()
	skip.text = "건너뛰기"
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_size_override("font_size", 22)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -160
	skip.offset_top = 28
	skip.offset_right = -32
	skip.offset_bottom = 84
	skip.pressed.connect(_go_on)
	bg.add_child(skip)


## 정물 한 장을 다시 그린다.
func _show_slide() -> void:
	for c in _art.get_children():
		c.queue_free()
	var slide: Array = SLIDES[_at]
	for piece in slide[1]:
		var t := _piece_texture(String(piece[0]))
		if t == null:
			continue
		var r := TextureRect.new()
		r.texture = t
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var k: float = float(piece[3])
		var sz: Vector2 = t.get_size() * k
		r.size = sz
		# 밑동이 그 자리에 닿게. 탑다운 소품은 다 발밑 기준이다.
		r.position = Vector2(float(piece[1]) - sz.x * 0.5, float(piece[2]) - sz.y)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art.add_child(r)

	# 한글은 음절 사이가 다 줄바꿈 자리라 낱말이 갈린다 (`Wrap` 주석).
	Wrap.put(_text, String(slide[0]))
	_art.modulate.a = 0.0
	_text.modulate.a = 0.0
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(_art, "modulate:a", 1.0, FADE)
	_tw.tween_property(_text, "modulate:a", 1.0, FADE)


## 주인공은 걷기 시트라 한 칸만 오려 쓴다 (4프레임 x 3방향의 첫 칸).
func _piece_texture(name: String) -> Texture2D:
	if name == "hero":
		var sheet := load("res://assets/sprites/hero-walk.png") as Texture2D
		if sheet == null:
			return null
		var a := AtlasTexture.new()
		a.atlas = sheet
		a.region = Rect2(0, 0, sheet.get_width() / 4.0, sheet.get_height() / 3.0)
		return a
	return load("res://assets/sprites/%s.png" % name) as Texture2D


func _next() -> void:
	if _going:
		return
	AudioManager.page_turn()
	_at += 1
	if _at >= SLIDES.size():
		_go_on()
		return
	_show_slide()


func _go_on() -> void:
	if _going:
		return
	_going = true
	SaveManager.autosave(NEXT)
	SceneTransition.go_to(NEXT)
