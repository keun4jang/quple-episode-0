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


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	y_sort_enabled = true

	sprite = QuoSprite.new()
	sprite.name = "Sprite"
	add_child(sprite)
	sprite.load_sheet(sheet)

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

	# 그림은 실제로 가는 쪽을 본다. 넣어 준 방향을 그대로 쓰면 벽에
	# 붙어 있을 때 안 가면서 걷는 시늉을 한다.
	sprite.drive(velocity / maxf(speed, 1.0), delta)


func face(dir: Vector2) -> void:
	sprite.face(dir)


func stop() -> void:
	_input = Vector2.ZERO
	velocity = Vector2.ZERO
	sprite.drive(Vector2.ZERO, 0.0)
