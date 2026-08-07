extends CanvasLayer

## 씬 전환 페이드.
##
## 페이드 색은 더 이상 하드코딩이 아니라 "도착할 씬의 무드" 에서 뽑는다.
## 까만 화면으로 뚝 끊기는 것보다 그 세계의 색으로 넘어가는 편이 훨씬 부드럽다.
## 페이드는 다음 씬을 여는 문이라, 문 너머의 색으로 덮었다가 걷어야 눈이 놀라지 않는다.
##
## style 이름(normal / hopeful / tense / dawn)은 그대로 받는다. 호출부가 여럿이고
## 각 이름이 장면의 감정을 뜻하기 때문에, 이름은 두고 색만 세계에 맞춘다.

## class_name 을 쓰지 않는다 — 전역 클래스 캐시는 에디터 스캔에서만 갱신돼서
## 새로 클론한 환경에서 통째로 죽는다. preload 로 잡는다.
const MoodPalette := preload("res://scripts/systems/mood_palette.gd")

## 시계를 따라가면 안 되는 씬.
## 에피소드 0 의 네 씬은 "늦은 밤 야근" 으로 각본이 짜여 있다. 낮에 켰다고
## 화면이 밝아지면 이야기가 깨지므로 여기 적힌 씬은 고정 무드를 쓴다.
const FIXED_SCENE_MOODS := {
	"res://scenes/maps/CompanyFront3D.tscn": "night_office",
	"res://scenes/maps/CompanyLobby3D.tscn": "night_office_indoor",
	"res://scenes/maps/Office3D.tscn": "night_office_indoor",
	"res://scenes/maps/BossDoorHallway3D.tscn": "night_office_indoor",
}

## style 별 페이드 시간. 기존 값을 그대로 옮겼다 — 길이는 연출의 일부다.
const STYLE_DURATION := {
	"normal": 0.35,
	"hopeful": 0.4,
	"tense": 0.55,
	"dawn": 0.6,
}

## 무드를 못 읽었을 때의 마지막 안전망 (짙은 남색. 순검정은 쓰지 않는다)
const FALLBACK_FADE := Color(0.08, 0.09, 0.16)

var is_transitioning: bool = false

## 무드를 강제로 지정하고 싶을 때 쓴다 (MoodPalette 의 고정 무드 이름).
## 빈 값이면 씬 경로를 보고 알아서 고른다. 특별한 장면에서만 잠깐 쓰고 되돌릴 것.
var mood_override: String = ""

@onready var overlay: ColorRect = $Overlay

func _ready() -> void:
	overlay.color = Color(0, 0, 0, 0)
	layer = 10

## 0편 맵을 옆에서 보는 판으로 갈아끼운다.
##
## 맵을 부르는 곳이 열 군데 넘게 흩어져 있다. 전부 고치는 대신 지나가는
## 길목 한 곳에서 바꾼다 — 되돌릴 때도 이 표만 비우면 되고, 3D 씬은
## 지우지 않고 그대로 남아 있다. 저장 파일에 적힌 옛 경로도 여기서
## 자연히 새 맵으로 이어진다.
const SIDE_MAPS := {
	"res://scenes/maps/CompanyFront3D.tscn": "res://scenes/side/Front.tscn",
	"res://scenes/maps/CompanyLobby3D.tscn": "res://scenes/side/Lobby.tscn",
	"res://scenes/maps/Office3D.tscn": "res://scenes/side/Office.tscn",
	"res://scenes/maps/BossDoorHallway3D.tscn": "res://scenes/side/Hallway.tscn",
}
## false 로 두면 예전 3D 맵으로 돌아간다.
const USE_SIDE_MAPS := true


## 이 경로로 실제로 열 씬. 저장·복원하는 쪽에서도 쓴다.
static func route(path: String) -> String:
	if USE_SIDE_MAPS and SIDE_MAPS.has(path):
		return SIDE_MAPS[path]
	return path


func go_to(raw_path: String, style: String = "normal") -> void:
	var path := route(raw_path)
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
## 기본은 도착할 씬의 무드색이다. style 이 붙으면 그 감정 쪽으로 기울이되,
## 출발점은 언제나 세계의 색이라 시간대가 화면에서 사라지지 않는다.
func fade_color_for(path: String, style: String = "normal") -> Color:
	var mood := mood_for_scene(path)
	var base: Color = mood.get("fade_color", FALLBACK_FADE)
	match style:
		"hopeful":
			# 밝게 열리는 느낌은 남기되, 순백으로 튀지 않게 세계의 색을 섞는다.
			# 밤에 눈부신 흰 화면이 터지면 힐링이 아니라 놀람이 된다.
			base = base.lerp(Color(1.0, 0.97, 0.90), 0.72)
		"dawn":
			base = base.lerp(Color(1.0, 0.90, 0.75), 0.68)
		"tense":
			# 긴장은 시각과 무관한 연출이다. 여기만 색을 고정한다.
			# (쓰는 곳이 사장실 복도뿐인데, 그 씬들은 어차피 시계를 보지 않는다.)
			base = Color(0.08, 0.0, 0.0)
	return Color(base.r, base.g, base.b, 1.0)

## 그 씬이 쓸 무드. 고정 씬이면 고정 무드, 아니면 지금 시각의 무드.
func mood_for_scene(path: String) -> Dictionary:
	if mood_override != "" and MoodPalette.has_fixed(mood_override):
		return MoodPalette.fixed(mood_override)
	var fixed_name := str(FIXED_SCENE_MOODS.get(path, ""))
	if fixed_name != "":
		return MoodPalette.fixed(fixed_name)
	return MoodPalette.now()

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
