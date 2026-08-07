extends SideEpisode
## 대표실 앞 복도. 0편의 전환점.
##
## 여기서는 아무것도 챙기지 않고 아무 데도 가지 않는다. 문 앞까지 걸어가
## 서서 듣는 것이 전부다. 그래서 복도를 **길게** 만든다 — 걸어가는 동안
## 목소리가 조금씩 또렷해지는 그 시간이 이 장면의 전부다.

const DOOR_X := 3000.0

var _listening := false
var _door_glow: ColorRect
var _t := 0.0


func map_title() -> String:
	return "대표실 앞 복도"


func build() -> void:
	set_bounds(3400.0, 300.0)
	# 그려 받은 그림이 있으면 그것을 쓰고, 없으면 코드로 그린다.
	if not use_backdrop("hallway"):
		IndoorParts.skyline(self, 3400.0, FLOOR_Y, 13)
		# 복도는 창이 없다. 벽으로 꽉 막아 답답하게 둔다.
		IndoorParts.room(self, 3400.0, FLOOR_Y, 820.0, 840.0, 600.0)
		IndoorParts.ceiling_lights(self, 3400.0, 120.0, 760.0)
		IndoorParts.floor_pools(self, 3400.0, FLOOR_Y, 760.0)
	IndoorParts.floor_slab(self, -200, FLOOR_Y, 3800)

	# 대표실 문. 문틈으로 새어 나오는 빛이 유일하게 밝은 것이다.
	var n := Node2D.new()
	add_child(n)
	_rect(n, Vector2(DOOR_X - 120, FLOOR_Y - 340), Vector2(240, 340), Color("#1E2738"))
	_rect(n, Vector2(DOOR_X - 100, FLOOR_Y - 318), Vector2(200, 318), Color("#33405A"))
	_door_glow = ColorRect.new()
	_door_glow.color = Color(1, 0.84, 0.42, 0.55)
	_door_glow.size = Vector2(200, 12)
	_door_glow.position = Vector2(DOOR_X - 100, FLOOR_Y - 12)
	_door_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(_door_glow)
	_rect(n, Vector2(DOOR_X - 60, FLOOR_Y - 430), Vector2(120, 46), Color("#46587A"))

	spot(DOOR_X, "문 앞에서 들어보기", _eavesdrop, false, 260.0)
	door(180.0, "사무실로 돌아가기", "res://scenes/maps/Office3D.tscn")


func on_enter() -> void:
	AudioManager.play_ambient("room")
	await get_tree().create_timer(0.5).timeout
	await say("문 너머에서 목소리가 새어 나와요.", 0.0)


func _process(delta: float) -> void:
	super._process(delta)
	# 문틈 빛이 아주 약하게 흔들린다
	_t += delta
	if _door_glow != null:
		_door_glow.color.a = 0.5 + sin(_t * 2.2) * 0.08


## 엿듣기 — 0편의 감정 전환점
func _eavesdrop() -> void:
	if _listening:
		return
	_listening = true
	for line in [
		"대표: \"사람은 도구처럼 쓰면 돼.\"",
		"대표: \"지치면 바꾸면 그만이지.\"",
		"……",
		"이제 정말 나가야 해.",
	]:
		await say(line, 2.2)
	hide_say()
	Episode0State.advance_to(Episode0State.State.RETURN_TO_PARTNER)
	await get_tree().create_timer(0.3).timeout
	SceneTransition.go_to("res://scenes/maps/Office3D.tscn", "tense")


func _rect(p: Node, pos: Vector2, size: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.color = col
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(r)
