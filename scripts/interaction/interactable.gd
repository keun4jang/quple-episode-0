extends Area2D

@export var interact_text: String = ""

func _ready() -> void:
	add_to_group("interactable")
