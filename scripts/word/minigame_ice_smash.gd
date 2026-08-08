extends Control
## 미니게임 — 얼음 깨기.
##
## **새 단어를 묻지 않는다.** 이미 배운 `fire` 를 쓰는 자리다.
## 묻는 화면과 쓰는 화면이 번갈아 나와야 공부로 안 느껴진다.
##
## 규칙:
##   - 실패가 없다. 놓친 얼음은 쿼카가 대신 막아 준다
##   - 점수를 안 쓴다. 몇 개 녹였는지만 그림으로 남는다
##   - 탭만 쓴다. 드래그·연타·정확한 타이밍 없음
##   - 26초. 길면 그것대로 지루하다

signal minigame_done(melted: int)

@export var minigame_id := "ice_smash"
@export var instant := false

const GROUND := 596.0
const VP := Vector2(1280, 720)
const SPAWN_EVERY := 1.05
const CHUNK := 118.0        # 톡 누르기 좋은 크기

var data: Dictionary = {}
var melted := 0
var missed := 0

var _left := 26.0
var _spawn := 0.6
var _running := false
var _chunks: Array[Control] = []
var _tally: HBoxContainer
var _clock: ColorRect
var _clock_bar: ColorRect
var _leader: TextureRect
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	data = WordData.minigame_by_id(minigame_id)
	if data.is_empty():
		data = WordData.MINIGAMES[0]
	_left = float(data.get("seconds", 26.0))

	_build()
	if instant:
		return
	_intro()


func _build() -> void:
	var sky := ColorRect.new()
	sky.color = Color("#7FA8CC")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	var snow := ColorRect.new()
	snow.color = Color("#E4EEF4")
	snow.position = Vector2(0, GROUND)
	snow.size = Vector2(VP.x, VP.y - GROUND)
	snow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(snow)

	# 쿼카는 왼쪽 끝에 서 있다. 얼음은 오른쪽에서 굴러온다.
	_leader = TextureRect.new()
	_leader.texture = load("res://assets/mascots/sheet/leader-front.png")
	_leader.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_leader.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_leader.size = Vector2(170, 238)
	_leader.position = Vector2(56, GROUND - 224)
	_leader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_leader)

	# 남은 시간은 숫자가 아니라 줄어드는 막대로 보여 준다. 초읽기는 안 쓴다.
	_clock = ColorRect.new()
	_clock.color = Color(1, 1, 1, 0.30)
	_clock.position = Vector2(240, 40)
	_clock.size = Vector2(800, 22)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clock)
	_clock_bar = ColorRect.new()
	_clock_bar.color = Color("#FFD98A")
	_clock_bar.size = Vector2(800, 22)
	_clock_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock.add_child(_clock_bar)

	# 녹인 만큼 물방울이 늘어난다. 숫자를 안 쓴다.
	_tally = HBoxContainer.new()
	_tally.position = Vector2(240, 78)
	_tally.add_theme_constant_override("separation", 4)
	add_child(_tally)


func _intro() -> void:
	var t := Label.new()
	t.text = "%s  %s" % [String(data.get("emoji", "🔥")), String(data.get("title", ""))]
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 78)
	t.add_theme_color_override("font_color", Color("#FFFDF6"))
	t.add_theme_color_override("font_outline_color", Color("#3A2C2C"))
	t.add_theme_constant_override("outline_size", 14)
	t.position = Vector2(0, 240)
	t.size = Vector2(VP.x, 100)
	add_child(t)

	var tip := Label.new()
	tip.text = String(data.get("tip", ""))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 40)
	tip.add_theme_color_override("font_color", Color("#FFFDF6"))
	tip.position = Vector2(0, 340)
	tip.size = Vector2(VP.x, 60)
	add_child(tip)

	await get_tree().create_timer(1.6).timeout
	var tw := create_tween()
	tw.tween_property(t, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(tip, "modulate:a", 0.0, 0.3)
	await tw.finished
	t.queue_free()
	tip.queue_free()
	_running = true


func _process(delta: float) -> void:
	_t += delta
	if not _running:
		return

	_left -= delta
	if _clock_bar != null:
		_clock_bar.size.x = 800.0 * clampf(_left / float(data.get("seconds", 26.0)),
			0.0, 1.0)
	if _left <= 0.0:
		_finish()
		return

	_spawn -= delta
	if _spawn <= 0.0:
		_spawn = SPAWN_EVERY
		_add_chunk()

	# 굴러온다. 왼쪽 끝까지 가면 쿼카가 대신 막아 준다 — 실패가 아니다.
	for c in _chunks.duplicate():
		if not is_instance_valid(c):
			_chunks.erase(c)
			continue
		c.position.x -= 210.0 * delta
		c.rotation += delta * 1.4
		if c.position.x < 190.0:
			_blocked(c)


func _add_chunk() -> void:
	var n := _chunks.size()
	var b := Button.new()
	b.custom_minimum_size = Vector2(CHUNK, CHUNK)
	b.size = Vector2(CHUNK, CHUNK)
	b.focus_mode = Control.FOCUS_NONE
	b.pivot_offset = Vector2(CHUNK, CHUNK) / 2.0
	b.text = "❄"
	b.add_theme_font_size_override("font_size", 62)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#8FD6EC")
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(6)
	sb.border_color = Color("#4F9DBD")
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color("#FFFDF6"))
	# 높이를 세 줄로 흩어 놓는다. 한 줄이면 손이 안 움직인다.
	var lane := (n + int(_t)) % 3
	b.position = Vector2(VP.x + 40, GROUND - CHUNK - lane * 112.0)
	b.pressed.connect(_on_chunk_tapped.bind(b))
	add_child(b)
	_chunks.append(b)


func _on_chunk_tapped(c: Control) -> void:
	if not is_instance_valid(c) or c.get_meta("gone", false):
		return
	c.set_meta("gone", true)
	melted += 1
	_add_tally()
	_chunks.erase(c)

	# 🔥 가 튀고 얼음이 물이 된다
	var burst := Label.new()
	burst.text = "🔥"
	burst.add_theme_font_size_override("font_size", 70)
	burst.position = c.position
	add_child(burst)
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2(0.2, 0.2), 0.22).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(c, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(burst, "position:y", c.position.y - 60.0, 0.35)
	tw.parallel().tween_property(burst, "modulate:a", 0.0, 0.35)
	await tw.finished
	if is_instance_valid(c):
		c.queue_free()
	burst.queue_free()


## 놓쳤을 때. 쿼카가 대신 막는다. **잃는 것이 없다.**
func _blocked(c: Control) -> void:
	if c.get_meta("gone", false):
		return
	c.set_meta("gone", true)
	missed += 1
	_chunks.erase(c)
	var tw := create_tween()
	tw.tween_property(c, "position:x", 120.0, 0.18)
	tw.parallel().tween_property(c, "modulate:a", 0.0, 0.18)
	# 쿼카가 살짝 밀린다
	if _leader != null:
		var lx := _leader.position.x
		tw.parallel().tween_property(_leader, "position:x", lx - 14.0, 0.09)
		tw.tween_property(_leader, "position:x", lx, 0.14)
	await tw.finished
	if is_instance_valid(c):
		c.queue_free()


func _add_tally() -> void:
	if _tally == null:
		return
	# 열 개마다 줄을 접는다. 100개까지만 보여 준다 — 숫자가 커지면 톤이 깨진다.
	if _tally.get_child_count() >= 20:
		return
	var d := Label.new()
	d.text = "💧"
	d.add_theme_font_size_override("font_size", 34)
	_tally.add_child(d)
	d.scale = Vector2(0.3, 0.3)
	d.pivot_offset = Vector2(17, 17)
	create_tween().tween_property(d, "scale", Vector2.ONE, 0.22) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _finish() -> void:
	if not _running:
		return
	_running = false
	for c in _chunks:
		if is_instance_valid(c):
			c.queue_free()
	_chunks.clear()
	if instant:
		minigame_done.emit(melted)
		return
	_outro()


func _outro() -> void:
	var msg := Label.new()
	# 점수도 등급도 안 준다. 한 일을 말해 줄 뿐이다.
	msg.text = "얼음 %d개를 녹였어요" % melted
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 64)
	msg.add_theme_color_override("font_color", Color("#FFFDF6"))
	msg.add_theme_color_override("font_outline_color", Color("#3A2C2C"))
	msg.add_theme_constant_override("outline_size", 14)
	msg.position = Vector2(0, 250)
	msg.size = Vector2(VP.x, 100)
	msg.modulate.a = 0.0
	add_child(msg)
	var tw := create_tween()
	tw.tween_property(msg, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.5)
	tw.tween_property(msg, "modulate:a", 0.0, 0.3)
	await tw.finished
	minigame_done.emit(melted)


## 테스트에서 시간을 기다리지 않고 돌리려고 쓴다.
func run_instant(taps: int) -> void:
	_running = true
	for i in taps:
		_add_chunk()
		_on_chunk_tapped(_chunks[_chunks.size() - 1])
	_finish()
