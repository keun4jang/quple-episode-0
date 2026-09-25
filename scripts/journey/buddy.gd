class_name Buddy
extends Folk
## 파티 동료 - 배낭 멘 너구리 (`docs/redesign-dream.md` 2절 "승").
##
## 현실에선 옆 부서 과장, 꿈속에선 먼저 떨어진 베테랑 모험가. **구역마다
## 다시 만나 그 구역 동안 같이 싸운다** - 마을에서 말을 걸면 따라나서고
## (`Place._offer_party`), 그 마을과 딸린 길(우두머리의 길·방, 꿈의 탑)을
## 함께 다닌다. 다음 구역으로 떠나면 제 갈 길로 간다 (`JourneyState.move_wanderer`).
##
## 지키는 선:
## - **먼저 싸움을 걸지 않는다.** 쿼카가 겨눴거나 덤벼 오는 몬스터만 친다.
##   싸울지 말지는 매번 사람이 고른다 (`Shade` 주석과 같은 약속)
## - **몬스터가 너구리를 노리지 않는다.** 동료가 쓰러지는 걸 챙기게 되면
##   거드는 손이 짐이 된다
## - 가끔 **도토리를 나눠 준다** - 체력이 반 밑으로 내려가면

## 쿼카 뒤로 이만큼 떨어져 따라온다(px).
const FOLLOW := 22.0
## 이보다 멀어지면 곁으로 건너온다 - 벽 뒤에 끼어 못 오는 일이 없게.
const TELEPORT := 200.0
## 쿼카에게서 이만큼 안에서 싸우는 몬스터만 친다.
const SEEK := 120.0
## 이만큼 붙으면 친다.
const REACH := 22.0
## 치는 박자(초).
const EVERY := 1.4
## 도토리 나눠 주는 박자(초)와 그 문턱(체력 비율).
const HEAL_EVERY := 14.0
const HEAL_AT := 0.5

const TAG_COL := Color("#9BE7A8")

var _hit_t := 0.8
var _heal_t := 3.0
var _target: Shade = null


func _ready() -> void:
	super._ready()
	# 길을 막지 않는다 - 좁은 다리에서 쿼카를 밀면 성가시다.
	collision_layer = 0
	speed = 74.0
	set_tag_near(true)
	var tag := get_node_or_null("NameTag") as Label
	if tag != null:
		tag.add_theme_color_override("font_color", TAG_COL)


func pulse_color() -> Color:
	return Color(0.42, 0.82, 0.52, 0.85)


func near_color() -> Color:
	return pulse_color()


func _physics_process(delta: float) -> void:
	var p = get_parent()
	if p == null or not p.has_method("combat_paused") or p.walker == null \
			or p.combat_paused():
		set_input(Vector2.ZERO)
		super._physics_process(delta)
		return
	var me: Vector2 = p.walker.global_position
	_hit_t -= delta
	_heal_t -= delta
	if _heal_t <= 0.0:
		_heal_t = 1.0
		if float(Battle.hp) < float(Battle.hp_max()) * HEAL_AT and Battle.hp > 0:
			_heal_t = HEAL_EVERY
			p.buddy_heal(self)
	if global_position.distance_to(me) > TELEPORT:
		global_position = me + Vector2(-14, 2)
		_target = null
	if _target != null and (not is_instance_valid(_target) or _target.state == "gone"
			or _target.global_position.distance_to(me) > SEEK * 1.5):
		_target = null
	if _target == null:
		_target = p.buddy_target()
	if _target != null:
		var to := _target.global_position - global_position
		if to.length() > REACH:
			set_input(to.normalized())
		else:
			set_input(Vector2.ZERO)
			face(to)
			if _hit_t <= 0.0:
				_hit_t = EVERY
				p.buddy_strike(self, _target)
	else:
		var d := me - global_position
		if d.length() > FOLLOW:
			set_input(d.normalized())
		else:
			set_input(Vector2.ZERO)
	super._physics_process(delta)
