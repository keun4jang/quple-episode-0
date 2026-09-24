class_name Shade
extends Folk
## 마을에 서 있는 그늘. **공격 버튼으로 직접 때려 걷어낸다** (`Field`).
##
## **`Folk` 를 그대로 물려받는다.** 탭 판정(`Place._folk_at`)·이름표·
## 테두리를 새로 쓸 까닭이 없다. 누르면 그 앞까지 걸어가 겨눈다.
##
## **먼저 덤비지 않는다.** 걷다가 저절로 붙으면 쉬러 온 사람이 방해받는다
## - 이건 여행 게임이고, 싸울지 말지는 매번 사람이 고른다. 한 대 맞으면
## 그때부터 쫓아와 덤비고, 멀리 달아나면 제자리로 돌아간다(`LEASH`).
## 쫓는 걸음(`CHASE`)은 쿼카보다 느리다 - 언제든 빠져나갈 수 있다.

## 어느 그늘인가 (`Battle.ENEMIES` 의 열쇠).
var shade_kind := ""
## 몸 상태 (`Field.new_foe`).
var foe: Dictionary = {}
## 처음 선 자리. 싸움을 놓으면 여기로 돌아간다.
var home := Vector2.ZERO
## idle 서 있음 · chase 쫓음 · windup 덤비기 직전 · back 돌아감 · gone 걷힘
var state := "idle"

const CHASE := 38.0
## 이만큼 붙으면 덤빈다(px).
const HIT := 20.0
## 제자리나 쿼카에게서 이만큼 멀어지면 놓는다.
const LEASH := 170.0
## 덤비기 전에 머리 위에 예고를 띄우고 멈칫하는 시간 - 보고 피할 틈.
const WINDUP := 0.6
## 덤비는 박자. 우두머리는 느리지만 무겁다.
const EVERY := 1.8
const EVERY_BOSS := 2.3

## 인연의 금색과 갈라야 한다. 멀리서 봤을 때 "말 걸 사람" 과
## "때려 볼 그늘" 이 같은 색으로 깜빡이면 고르고 말고가 없다.
const SHADE_TALK := Color(0.88, 0.44, 0.50, 0.92)

var _t := 0.0
var _bar: Node2D
var _intent: Label
var _flash_tw: Tween


## **몸으로 길을 막지 않는다.** 그늘이 여섯 배(`Battle.SPAWN_MULT`)가
## 되면서 좁은 다리·부두 위에 하나만 서도 지나갈 길이 끊길 수 있었다.
## 다른 것이 부딪히는 층(`collision_layer`)만 비운다 - 제 몸은 여전히
## 벽에 걸리므로(`collision_mask`) 쫓아오다 집을 뚫고 지나가지는 않는다.
func _ready() -> void:
	super._ready()
	collision_layer = 0
	speed = CHASE
	home = position
	if foe.is_empty():
		foe = Field.new_foe(shade_kind)
	_build_bar()


func _build_bar() -> void:
	var tall: float = sprite.size().y if sprite != null else 24.0
	_bar = Node2D.new()
	_bar.name = "HpBar"
	_bar.z_index = 41
	_bar.position = Vector2(0, -tall - 5.0)
	_bar.visible = false
	_bar.draw.connect(func() -> void:
		var w := 22.0
		var k := clampf(float(foe.get("hp", 0)) / maxf(1.0, float(foe.get("hp_max", 1))), 0.0, 1.0)
		_bar.draw_rect(Rect2(-w * 0.5 - 1, -1, w + 2, 5), Color(0.12, 0.09, 0.14, 0.9))
		_bar.draw_rect(Rect2(-w * 0.5, 0, w * k, 3),
			Color("#FF6B6B") if k < 0.35 else Color("#F2A0A0"))
		# 걸려 있는 것: 누그러짐 노랑 · 흔들림 하늘 · 사그라듦 보라
		var x := -w * 0.5
		for id in ["soften", "shake", "fade"]:
			if Field.foe_has(foe, id):
				var c: Color = {"soften": Color("#FFE066"), "shake": Color("#7FDBFF"),
					"fade": Color("#B28DFF")}[id]
				_bar.draw_rect(Rect2(x, 5, 3, 3), c)
				x += 4.0)
	add_child(_bar)
	_intent = Label.new()
	_intent.name = "Intent"
	_intent.add_theme_font_size_override("font_size", 11)
	_intent.add_theme_color_override("font_color", Color("#FFB3B3"))
	_intent.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.14))
	_intent.add_theme_constant_override("outline_size", 4)
	_intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent.z_index = 42
	add_child(_intent)
	_intent.size = Vector2(100, 14)
	_intent.position = Vector2(-50, -tall - 22.0)
	_intent.visible = false


func _physics_process(delta: float) -> void:
	if state == "gone":
		return
	var p = get_parent()
	var paused: bool = p == null or not p.has_method("combat_paused") \
		or p.combat_paused() or p.walker == null
	if paused:
		set_input(Vector2.ZERO)
		super._physics_process(delta)
		return
	var lost := Field.foe_tick(foe, delta)
	if lost > 0:
		FieldFx.number(p, global_position + Vector2(0, -20), "%d" % lost, Color("#B28DFF"), 12)
		_bar.queue_redraw()
		if int(foe["hp"]) <= 0:
			p.on_shade_down(self)
			return
	var me: Vector2 = p.walker.global_position
	var to := me - global_position
	match state:
		"idle":
			set_input(Vector2.ZERO)
		"chase":
			_t -= delta
			if global_position.distance_to(home) > LEASH or to.length() > LEASH:
				_give_up()
			elif to.length() > HIT:
				set_input(to.normalized())
			else:
				set_input(Vector2.ZERO)
				face(to)
				if _t <= 0.0:
					_wind_up()
		"windup":
			set_input(Vector2.ZERO)
			_t -= delta
			if _t <= 0.0:
				_strike_now(p, to.length())
		"back":
			var h := home - global_position
			if h.length() < 3.0:
				set_input(Vector2.ZERO)
				state = "idle"
				speed = CHASE
			else:
				set_input(h.normalized())
	super._physics_process(delta)


func _wind_up() -> void:
	state = "windup"
	_t = WINDUP
	_intent.text = Field.foe_intent(foe)
	_intent.visible = true
	# 몸이 붉게 부풀었다 가라앉는다 - "온다" 를 글자 말고 몸으로도.
	if sprite != null:
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color(1.6, 0.7, 0.7), WINDUP * 0.6)
		tw.tween_property(sprite, "modulate", Color.WHITE, WINDUP * 0.4)


## 예고한 대로 덤빈다. 예고하는 사이 빠져나갔으면 헛방이다 - 보고 피한 것.
func _strike_now(p: Node, gap: float) -> void:
	_intent.visible = false
	state = "chase"
	_t = EVERY_BOSS if bool(foe["boss"]) else EVERY
	if gap <= HIT * 1.6:
		p.on_shade_attack(self, Field.foe_attack(foe))
	else:
		foe["turn"] = int(foe["turn"]) + 1
		foe["dealt"] = 0
		FieldFx.number(p, global_position + Vector2(0, -20), "헛손질", Color("#DDDDDD"), 11)


## 싸움을 놓는다. 제자리로 돌아간다 - 맞은 만큼은 그대로 둔다.
func _give_up() -> void:
	state = "back"
	_intent.visible = false
	speed = CHASE * 1.3


## 쿼카가 쓰러졌다. 다들 물러난다.
func calm() -> void:
	if state != "gone":
		_give_up()


func is_fighting() -> bool:
	return state == "chase" or state == "windup"


## 맞았다. `res` 는 `Field.strike` 의 결과.
func take_hit(res: Dictionary, from: Vector2) -> void:
	if state == "gone":
		return
	_bar.visible = true
	_bar.queue_redraw()
	# 맞으면 그때부터 덤빈다. 첫 덤빔까지는 조금 틈을 준다.
	if state == "idle" or state == "back":
		state = "chase"
		speed = CHASE
		_t = 0.7
	var st := float(res.get("stagger", 0.0))
	if st > 0.0:
		# 약점을 처음 찔렸다 - 덤비려던 것도 거둔다.
		if state == "windup":
			state = "chase"
			_intent.visible = false
		_t = maxf(_t, st)
	# 뒤로 살짝 밀린다. 몸으로 밀어서 벽은 못 넘는다.
	var push := (global_position - from).normalized() \
		* (5.0 if bool(res.get("weak", false)) else 3.0)
	move_and_collide(push)
	if sprite != null:
		if _flash_tw != null and _flash_tw.is_valid():
			_flash_tw.kill()
		sprite.modulate = Color(3, 3, 3)
		_flash_tw = create_tween()
		_flash_tw.tween_property(sprite, "modulate", Color.WHITE, 0.14)


func pulse_color() -> Color:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var k: float = 0.5 + 0.5 * sin(t * TAU / QuoWalker.TALK_PULSE_SECS)
	return QuoWalker.OUTLINE_DARK.lerp(SHADE_TALK, k)


func near_color() -> Color:
	return SHADE_TALK


## 걷어냈다. 스르르 옅어지며 사라진다 — 터지거나 쓰러지지 않는다.
func dissolve() -> void:
	state = "gone"
	set_process(false)
	set_physics_process(false)
	if _bar != null:
		_bar.visible = false
	if _intent != null:
		_intent.visible = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(self, "scale", Vector2(1.15, 0.85), 0.5)
	tw.tween_callback(queue_free)
