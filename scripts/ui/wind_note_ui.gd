extends CanvasLayer

@onready var goal_label: Label = $Panel/MarginContainer/VBoxContainer/GoalLabel

const GOALS: Dictionary = {
	0: "불 켜진 사무실로 가기",
	1: "회사 안으로 들어가기",
	2: "사무실로 가기",
	3: "애인과 이야기하기",
	4: "조금 더 둘러보기",
	5: "대표실 근처로 가보기",
	6: "애인에게 돌아가기",
	7: "여행 물품 3개 챙기기",
	8: "사원증 반납하기",
	9: "회사 밖으로 나가기",
	10: "첫 사진 찍기",
	11: "여행 앨범 확인하기",
	12: "여행 시작!"
}

func _ready() -> void:
	visible = false
	Episode0State.state_changed.connect(_on_state_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("key_wind_note"):
		visible = !visible

func _on_state_changed(new_state: int) -> void:
	if GOALS.has(new_state):
		goal_label.text = GOALS[new_state]
