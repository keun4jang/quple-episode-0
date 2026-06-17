extends "res://scripts/interaction/interactable.gd"

func interact() -> void:
	var choice_box = get_tree().get_first_node_in_group("choice_box")
	if choice_box == null:
		return

	choice_box.show_choices(
		"애인 쿼카가 지친 얼굴로 모니터를 보고 있다.\n\"...괜찮아? 우리 그냥 나갈까?\"",
		["지금 같이 나가자", "조금 더 기다릴게"],
		_on_choice_made
	)

func _on_choice_made(index: int) -> void:
	var dialogue_box = get_tree().get_first_node_in_group("dialogue_box")
	if dialogue_box == null:
		return

	if index == 0:
		dialogue_box.show_text("애인 쿼카가 손을 잡았다. \"...그래, 가자.\"")
	else:
		dialogue_box.show_text("애인 쿼카가 고개를 저었다. \"조금만 더 버텨볼게... 먼저 둘러보고 있어.\"")
