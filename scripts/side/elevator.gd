extends AnimatableBody2D
## 두 층을 오가는 엘리베이터.
##
## 사다리와 다른 점은 **탄 사람이 조작하지 않아도 움직인다**는 것이다.
## 올라타서 위를 누르면 올라가고, 도착하면 선다. 가는 동안 조작은 막지
## 않는다 — 중간에 뛰어내릴 수 있어야 갇힌 느낌이 안 든다.

## 오르내리는 속도(픽셀/초). 너무 빠르면 탄 사람이 발판에서 튕겨 나간다.
@export var lift_speed: float = 300.0
## 도착한 층에서 다시 출발하기 전까지의 뜸(초). 없으면 누르는 순간
## 위아래로 덜덜 떨린다.
@export var settle: float = 0.35

var top_y: float = 0.0
var bottom_y: float = 0.0

var _target: float = 0.0
var _cool := 0.0
var _riding := false

@onready var _rider: Area2D = $Rider


func _ready() -> void:
	_target = position.y
	if _rider != null:
		_rider.body_entered.connect(_on_enter)
		_rider.body_exited.connect(_on_exit)


func _on_enter(b: Node) -> void:
	if b is SideWalker:
		_riding = true


func _on_exit(b: Node) -> void:
	if b is SideWalker:
		_riding = false


func _physics_process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)

	# 탄 사람이 부르면 층을 바꾼다. 서 있을 때만 받는다.
	if _riding and _cool <= 0.0 and is_equal_approx(position.y, _target):
		if Input.is_action_pressed("move_up") and _target > top_y:
			_target = top_y
			_cool = settle
		elif Input.is_action_pressed("move_down") and _target < bottom_y:
			_target = bottom_y
			_cool = settle

	if is_equal_approx(position.y, _target):
		return
	position.y = move_toward(position.y, _target, lift_speed * delta)
	if is_equal_approx(position.y, _target):
		_cool = settle
