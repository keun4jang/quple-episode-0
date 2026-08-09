extends CanvasLayer

## 씬 전환 페이드.
##
## 예전에는 도착할 씬의 "무드"에서 색을 뽑았다. 3D 시절 이야기고, 그 팔레트는
## 게임과 함께 지웠다. 지금은 짙은 남색 하나로 덮었다 걷는다 —
## 순검정은 안 쓴다. 눈이 놀란다.

## style 별 페이드 시간. 길이는 연출의 일부라 그대로 옮겼다.
const STYLE_DURATION := {
	"normal": 0.35,
	"hopeful": 0.4,
	"tense": 0.55,
	"dawn": 0.6,
}

const FADE_COLOR := Color(0.08, 0.09, 0.16)

var is_transitioning: bool = false

@onready var overlay: ColorRect = $Overlay

func _ready() -> void:
	overlay.color = Color(0, 0, 0, 0)
	layer = 10


func go_to(raw_path: String, style: String = "normal") -> void:
	var path := raw_path
	if is_transitioning:
		return
	is_transitioning = true
	var fade_color := fade_color_for(path, style)
	var duration: float = float(STYLE_DURATION.get(style, STYLE_DURATION["normal"]))
	# 장면이 바뀐다는 건 이 게임에서 대개 문을 지난다는 뜻이다.
	# 소리가 먼저 나고 화면이 넘어가야 "내가 연 것" 으로 느껴진다.
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("door_open"):
		am.door_open()

	var tween = create_tween()
	tween.tween_property(overlay, "color", fade_color, duration)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(path)
	)
	tween.tween_property(overlay, "color", Color(fade_color.r, fade_color.g, fade_color.b, 0.0), duration)
	tween.tween_callback(func(): is_transitioning = false)

## 이 전환에 쓸 페이드 색.
##
## 예전엔 시각과 씬의 "무드"에서 뽑았다. 그 팔레트를 지우면서 한 색으로
## 모았다 — 지금은 여행 화면 자체가 시간에 따라 어두워지므로, 전환까지
## 색을 맞출 이유가 없다.
func fade_color_for(_path: String, style: String = "normal") -> Color:
	var base := FADE_COLOR
	match style:
		"hopeful":
			# 밝게 열리는 느낌은 남기되 순백으로 튀지 않게 한다.
			# 밤에 눈부신 흰 화면이 터지면 힐링이 아니라 놀람이 된다.
			base = base.lerp(Color(1.0, 0.97, 0.90), 0.72)
		"dawn":
			base = base.lerp(Color(1.0, 0.90, 0.75), 0.68)
		"tense":
			base = Color(0.08, 0.0, 0.0)
	return Color(base.r, base.g, base.b, 1.0)


# 방향 슬라이드 전환: direction은 "left"/"right"/"up"/"down"
func slide_to(scene_path: String, direction: String = "left") -> void:
	if is_transitioning:
		return
	is_transitioning = true

	# 화면 크기 가져오기
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_w = viewport_size.x
	var screen_h = viewport_size.y

	# 슬라이드 ColorRect 생성 (도착할 씬의 색을 어둡게 깐 판)
	# 화면을 가리는 판이라 페이드보다 한 단계 어둡게 둔다. 밝은 판이 지나가면 눈이 아프다.
	var slide_rect = ColorRect.new()
	slide_rect.color = fade_color_for(scene_path).darkened(0.35)
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
