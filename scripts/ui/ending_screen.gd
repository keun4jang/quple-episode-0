extends CanvasLayer
## 마지막 엔딩. 다른 차원에 다녀오면 나온다.
## 0편의 "오늘은 퇴근이 아니라 출발이었다" 와 짝을 이룬다.

@onready var root: Control = $Root
@onready var stars: Control = $Root/Stars
@onready var body: VBoxContainer = $Root/Center/Body
@onready var title: Label = $Root/Center/Body/TitleLabel
@onready var quote: Label = $Root/Center/Body/QuoteLabel
@onready var stats: Label = $Root/Center/Body/StatsLabel
@onready var last_line: Label = $Root/Center/Body/LastLabel
@onready var hint: Label = $Root/Center/Body/HintLabel

var _t: float = 0.0
var _star_dots: Array = []
var _done: bool = false

func _ready() -> void:
	add_to_group("ending_screen")
	_build_stars()
	_fill_stats()
	AudioManager.play_bgm("gohyang")
	_play_sequence()

func _process(delta: float) -> void:
	_t += delta
	# 별이 아주 천천히 흐른다
	for i in range(_star_dots.size()):
		var s: ColorRect = _star_dots[i]
		if not is_instance_valid(s):
			continue
		s.position.y += delta * (4.0 + float(i % 5) * 2.0)
		if s.position.y > root.size.y:
			s.position.y = -4.0
		s.modulate.a = 0.35 + sin(_t * 1.2 + float(i)) * 0.3

## 여행 기록을 요약한다
func _fill_stats() -> void:
	var places := {}
	for sv in TravelState.collection:
		places[str(sv.get("dest_id", ""))] = true
	var by_ch := {}
	for pid in places.keys():
		var d := TravelState.get_destination(pid)
		if d.is_empty():
			continue
		var c := str(d.get("chapter", ""))
		by_ch[c] = int(by_ch.get(c, 0)) + 1
	var parts: Array[String] = []
	for ch in TravelState.CHAPTERS:
		var n: int = int(by_ch.get(str(ch.id), 0))
		if n > 0:
			parts.append("%s %d곳" % [ch.name, n])
	stats.text = "다녀온 곳  %d곳\n%s\n\n모은 기록  %d개" % [
		places.size(), "   ·   ".join(parts), TravelState.collection.size()]

func _play_sequence() -> void:
	for n in [title, quote, stats, last_line, hint]:
		n.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(title, "modulate", Color(1, 1, 1, 1), 1.2)
	tw.tween_interval(0.8)
	tw.tween_property(quote, "modulate", Color(1, 1, 1, 1), 1.2)
	tw.tween_interval(1.0)
	tw.tween_property(stats, "modulate", Color(1, 1, 1, 1), 1.0)
	tw.tween_interval(1.2)
	tw.tween_property(last_line, "modulate", Color(1, 1, 1, 1), 1.4)
	tw.tween_interval(1.0)
	tw.tween_property(hint, "modulate", Color(1, 1, 1, 1), 0.8)
	tw.tween_callback(func(): _done = true)

func _unhandled_input(event: InputEvent) -> void:
	if not _done:
		# 연출 중 아무 키나 누르면 건너뛴다
		if event is InputEventKey and event.pressed:
			for n in [title, quote, stats, last_line, hint]:
				n.modulate = Color(1, 1, 1, 1)
			_done = true
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		AudioManager.ui_confirm()
		SceneTransition.go_to("res://scenes/travel/TravelHub.tscn", "hopeful")
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		get_tree().quit()

func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260805
	for i in range(90):
		var s := ColorRect.new()
		var sz: float = rng.randf_range(1.5, 3.5)
		s.size = Vector2(sz, sz)
		s.position = Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720))
		s.color = [Color(1, 1, 1), Color(1, 0.95, 0.82), Color(0.82, 0.88, 1)][i % 3]
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars.add_child(s)
		_star_dots.append(s)
