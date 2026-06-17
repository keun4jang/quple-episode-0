extends CanvasLayer

@onready var content_label: Label = $Panel/MarginContainer/VBoxContainer/ContentLabel
@onready var hint_label: Label = $Panel/MarginContainer/VBoxContainer/HintLabel

func _ready() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("key_album"):
		if visible:
			visible = false
		else:
			refresh()
			visible = true

func refresh() -> void:
	if Episode0State.album_created:
		content_label.text = "[ 첫 번째 기록 ]\n\n오늘은 퇴근이 아니라\n출발이었다."
		hint_label.text = "쿼카전자 앞 | 저녁"
	else:
		content_label.text = "아직 비어 있어요."
		hint_label.text = "첫 사진을 찍으면 기록됩니다."
