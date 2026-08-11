class_name QuoWalker
extends CharacterBody2D
## 걸어 다니는 쿼카. 주인공도 인연도 이걸 쓴다.
##
## 탑다운이라 중력도 점프도 없다. 남는 건 **멈추고 서는 느낌**뿐이라
## 거기에만 공을 들인다 — 미끄러지면 물 위를 걷는 것 같고, 딱 서면
## 로봇 같다. 그 사이를 짧은 가속·감속으로 잡는다.

signal bumped(what: Node)

## 16px 타일 기준. 한 칸을 0.25초에 지난다 — 급하지 않고 답답하지도 않다.
@export var speed := 64.0
@export var accel_time := 0.08
@export var brake_time := 0.06
@export var sheet := "res://assets/sprites/hero-walk.png"

var sprite: QuoSprite
var _input := Vector2.ZERO
var _shape: CollisionShape2D
var _shadow: Node2D
var _outline_node: Node2D
## 실제로 걷고 있나 (벽에 막혀 제자리면 false). 발소리가 이걸 본다.
var _moving := false


func is_moving() -> bool:
	return _moving


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	y_sort_enabled = true

	# 발밑 그림자를 **먼저** 깐다. 이게 없으면 캐릭터가 바닥에 얹혀 있지
	# 않고 공중에 붙어 있는 것처럼 보인다.
	_shadow = Node2D.new()
	_shadow.name = "Shadow"
	_shadow.z_index = -1
	_shadow.draw.connect(func() -> void:
		# 발끝이 원점이다. 그림자는 발 바로 밑에 얕게 눌려 앉는다.
		_shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.36))
		_shadow.draw_circle(Vector2(0, -3.0), 7.0, Color(0.12, 0.09, 0.14, 0.28)))
	add_child(_shadow)

	sprite = QuoSprite.new()
	sprite.name = "Sprite"
	add_child(sprite)
	sprite.load_sheet(sheet)
	_build_outline()

	# 발 근처만 막는다. 몸통 전체로 막으면 나무 뒤로 못 지나가고,
	# 탑다운에서 위쪽은 "머리 위 공간"이라 부딪히면 안 된다.
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	var w: float = maxf(8.0, sprite.size().x * 0.55)
	r.size = Vector2(w, 6.0)
	_shape.shape = r
	_shape.position = Vector2(0, -3.0)
	add_child(_shape)


## 바깥에서 방향을 넣어 준다 (-1..1). 길이가 1을 넘으면 잘라 쓴다.
func set_input(dir: Vector2) -> void:
	_input = dir if dir.length_squared() <= 1.0 else dir.normalized()


func _physics_process(delta: float) -> void:
	var want := _input * speed
	var t := accel_time if want.length_squared() > 0.001 else brake_time
	velocity = velocity.move_toward(want, speed / maxf(t, 0.001) * delta)
	move_and_slide()

	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c != null and c.get_collider() != null:
			bumped.emit(c.get_collider())

	# 그림은 **실제로 움직인 만큼**만 본다.
	#
	# 예전엔 velocity 를 넘겼는데, `MOTION_MODE_FLOATING` 의
	# `move_and_slide()` 는 벽에 정면으로 막혀도 velocity 를 0 으로
	# 만들지 않는다. 그래서 벽에 대고 밀면 3초 동안 0px 을 가면서
	# 걷는 시늉을 하고 발소리도 일곱 번 났다.
	var moved := get_position_delta()
	var real := (moved / maxf(delta, 0.0001)) / maxf(speed, 1.0)
	if real.length() < 0.08:
		real = Vector2.ZERO
	else:
		real = real.limit_length(1.0)
		# 방향은 가려던 쪽을 쓴다 — 미끄러질 때 그림이 옆으로 홱 돌지 않게.
		if velocity.length_squared() > 0.001:
			real = velocity.normalized() * real.length()
	sprite.drive(real, delta)
	_moving = real.length() > 0.0
	_sync_outline()


func face(dir: Vector2) -> void:
	sprite.face(dir)
	_sync_outline()


func stop() -> void:
	_input = Vector2.ZERO
	velocity = Vector2.ZERO
	sprite.drive(Vector2.ZERO, 0.0)


# ── 테두리 ────────────────────────────────────────────────────────────
#
# 밝은 캐릭터가 밝은 바닥 위에 서면 통째로 묻힌다. 갈매기 몸빛
# (206,153,107)은 갑판·나무바닥과 명도차가 **1.02:1** 이었다 — 1.0 이
# "완전히 같은 밝기"이니 사실상 안 보인다는 뜻이다.
#
# 그림을 다시 칠하지 않고 **어두운 복사본 네 장을 1px 씩 밀어** 뒤에
# 깐다. 픽셀 그림에서 흔히 쓰는 방법이고 셰이더가 없어 저사양에서도 싸다.
#
# 노드를 네 개 두지 않고 한 노드가 네 번 그린다. 부모가 Y 정렬이라
# 자식은 z_index 가 아니라 **y 값과 트리 순서**로 겹치는데, 노드를 여러
# 개 두면 그중 일부가 본체 앞으로 올라와 캐릭터를 까맣게 덮는다.
# 스프라이트보다 **먼저** 놓인 노드 하나면 언제나 뒤에 깔린다.
## 어두운 테두리는 밝은 바닥에서만 통한다. 현무암이나 밭고랑처럼 어두운
## 바닥 위에서는 1.6:1 까지 떨어져 사실상 사라진다 — 그럴 땐 뒤집는다.
const OUTLINE_DARK := Color(0.16, 0.13, 0.18, 0.85)
const OUTLINE_LIGHT := Color(0.98, 0.95, 0.88, 0.75)
## 말을 걸 수 있다는 표시. 점을 띄우는 대신 테두리 색 자체를 바꾼다 —
## `Folk._ready()` 와 `Place._outline_sprite()` 가 같이 쓴다.
const OUTLINE_TALK := Color(1.0, 0.82, 0.40, 0.9)
var outline_color := OUTLINE_DARK
const OUTLINE_STEPS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]

func _build_outline() -> void:
	_outline_node = Node2D.new()
	_outline_node.name = "Outline"
	_outline_node.draw.connect(_draw_outline)
	add_child(_outline_node)
	# 스프라이트보다 앞자리에 둔다 — 먼저 그려야 뒤에 깔린다.
	move_child(_outline_node, sprite.get_index())


func _draw_outline() -> void:
	# 몸을 숨긴 걷는이(자리 표시용 Folk)는 테두리도 안 그린다.
	# 안 그러면 평상·창밖 같은 자리마다 **검은 유령**이 서 있게 된다 —
	# 스프라이트만 숨고 테두리·그림자가 남아서 실루엣이 그대로 보였다.
	if sprite == null or sprite.texture == null or not sprite.visible:
		return
	var r := sprite.region_rect
	if sprite.flip_h:
		r = Rect2(r.position.x + r.size.x, r.position.y, -r.size.x, r.size.y)
	for d in OUTLINE_STEPS:
		_outline_node.draw_texture_rect_region(sprite.texture,
			Rect2(sprite.offset + d, sprite.region_rect.size), r, outline_color)


## 밟고 선 바닥이 어두우면 테두리를 밝은 쪽으로 바꾼다.
func set_on_dark_ground(dark: bool) -> void:
	var want := OUTLINE_LIGHT if dark else OUTLINE_DARK
	if want == outline_color:
		return
	outline_color = want
	_sync_outline()


## 자리 표시용으로 쓸 때 몸을 통째로 숨긴다 (그림자·테두리까지).
func hide_body() -> void:
	if sprite != null:
		sprite.visible = false
	if _shadow != null:
		_shadow.visible = false
	if _outline_node != null:
		_outline_node.visible = false


## 걸으면 칸이 바뀐다. 테두리도 같이 다시 그린다.
func _sync_outline() -> void:
	if _outline_node != null:
		_outline_node.queue_redraw()
