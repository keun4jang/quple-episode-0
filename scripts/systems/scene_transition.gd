extends CanvasLayer

var is_transitioning: bool = false

@onready var overlay: ColorRect = $Overlay

func _ready() -> void:
	overlay.color = Color(0, 0, 0, 0)
	layer = 10

func go_to(path: String, style: String = "normal") -> void:
	if is_transitioning:
		return
	is_transitioning = true
	var fade_color: Color
	var duration: float
	match style:
		"hopeful":
			fade_color = Color(1.0, 0.97, 0.9, 1.0)
			duration = 0.4
		"tense":
			fade_color = Color(0.08, 0.0, 0.0, 1.0)
			duration = 0.55
		"dawn":
			fade_color = Color(1.0, 0.9, 0.75, 1.0)
			duration = 0.6
		_:
			fade_color = Color(0, 0, 0, 1)
			duration = 0.35
	var tween = create_tween()
	tween.tween_property(overlay, "color", fade_color, duration)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(path)
	)
	tween.tween_property(overlay, "color", Color(fade_color.r, fade_color.g, fade_color.b, 0.0), duration)
	tween.tween_callback(func(): is_transitioning = false)

# 방향 슬라이드 전환: direction은 "left"/"right"/"up"/"down"
func slide_to(scene_path: String, direction: String = "left") -> void:
	if is_transitioning:
		return
	is_transitioning = true

	# 화면 크기 가져오기
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_w = viewport_size.x
	var screen_h = viewport_size.y

	# 슬라이드 ColorRect 생성 (어두운 오버레이)
	var slide_rect = ColorRect.new()
	slide_rect.color = Color(0.05, 0.05, 0.05, 1.0)
	slide_rect.size = viewport_size
	add_child(slide_rect)

	# 방향에 따라 시작 위치 설정 (화면 밖에서 시작)
	var start_pos: Vector2
	var cover_pos: Vector2 = Vector2.ZERO
	var exit_pos: Vector2
	match direction:
		"left":
			start_pos = Vector2(-screen_w, 0)
			exit_pos = Vector2(screen_w, 0)
		"right":
			start_pos = Vector2(screen_w, 0)
			exit_pos = Vector2(-screen_w, 0)
		"up":
			start_pos = Vector2(0, -screen_h)
			exit_pos = Vector2(0, screen_h)
		"down":
			start_pos = Vector2(0, screen_h)
			exit_pos = Vector2(0, -screen_h)
		_:
			start_pos = Vector2(-screen_w, 0)
			exit_pos = Vector2(screen_w, 0)

	slide_rect.position = start_pos

	var half_dur = 0.2  # 총 0.4초 (0.2 진입 + 씬 전환 + 0.2 퇴장)

	var tween = create_tween()
	# 슬라이드 진입: 화면 덮기
	tween.tween_property(slide_rect, "position", cover_pos, half_dur).set_ease(Tween.EASE_IN_OUT)
	# 씬 전환
	tween.tween_callback(func():
		get_tree().change_scene_to_file(scene_path)
	)
	# 슬라이드 퇴장: 화면 벗어나기
	tween.tween_property(slide_rect, "position", exit_pos, half_dur).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		slide_rect.queue_free()
		is_transitioning = false
	)
