class_name FaceCut
extends Control
## 말풍선 옆에 붙는 표정 컷.
##
## 쿼카는 입꼬리가 올라간 얼굴이라 원래 표정 변화가 적다. 그게 특징이니
## 얼굴을 새로 그리지 않는다 — **있는 얼굴을 잘라 쓰고**, 눈·눈썹과
## 기울기·흔들림으로 감정을 낸다. 표정 그림 24장은 나중 일이다.
##
## 그때까지도 못 읽는 아이가 상황을 알 수 있어야 하므로, 이모지 배지를
## 얼굴 위에 겹쳐 둔다. 표정과 이모지 두 겹으로 보여 준다.

const SHEET := {
	"leader": "res://assets/mascots/sheet/leader-front.png",
	"partner": "res://assets/mascots/sheet/partner-front.png",
}
## 얼굴만 잘라내는 자리. 전신 그림의 머리 부분이다.
const HEAD := {
	"leader": Rect2(36, 8, 282, 282),
	"partner": Rect2(66, 8, 292, 292),
}

## 감정 12종. [이모지, 기울기(도), 위아래 흔들림]
const MOODS := {
	"joy":    ["😊",  0.0, 0.0],
	"fun":    ["😆", -4.0, 6.0],
	"wow":    ["😲",  0.0, -6.0],
	"think":  ["🤔",  6.0, 0.0],
	"calm":   ["😌",  0.0, 0.0],
	"proud":  ["😤", -3.0, -4.0],
	"thanks": ["🥹",  3.0, 0.0],
	"bored":  ["😑",  0.0, 4.0],
	"sad2":   ["🥺",  8.0, 4.0],
	"cold":   ["😨", -2.0, 3.0],
	"sad":    ["😢",  10.0, 5.0],
	"angry":  ["😠", -6.0, -3.0],
	# 자주 쓰는 별칭
	"idea":   ["💡", -5.0, -6.0],
}

var _who := "leader"
var _mood := "joy"
var _face: TextureRect
var _badge: Label
var _t := 0.0


func _init(who: String = "leader", mood: String = "joy") -> void:
	_who = who if SHEET.has(who) else "leader"
	_mood = mood if MOODS.has(mood) else "joy"


func _ready() -> void:
	custom_minimum_size = Vector2(150, 150)
	clip_contents = false

	_face = TextureRect.new()
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)

	_badge = Label.new()
	_badge.add_theme_font_size_override("font_size", 52)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)

	set_mood(_mood)


func set_who(who: String) -> void:
	_who = who if SHEET.has(who) else "leader"
	_refresh_face()


func set_mood(mood: String) -> void:
	_mood = mood if MOODS.has(mood) else "joy"
	_refresh_face()
	if _badge != null:
		_badge.text = String(MOODS[_mood][0])


func _refresh_face() -> void:
	if _face == null:
		return
	var tex := load(SHEET[_who]) as Texture2D
	if tex == null:
		return
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = HEAD[_who]
	_face.texture = at
	_face.rotation_degrees = float(MOODS[_mood][1])
	_face.pivot_offset = size / 2.0


func _process(delta: float) -> void:
	# 감정마다 다르게 아주 조금 움직인다. 정지 그림이면 표정이 안 읽힌다.
	_t += delta
	if _face == null:
		return
	var amp := float(MOODS[_mood][2])
	_face.position.y = sin(_t * 3.4) * amp * 0.5
	if _badge != null:
		_badge.position = Vector2(size.x - 46, -10 + sin(_t * 2.6) * 3.0)
