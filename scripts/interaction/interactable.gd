extends Area2D

@export var interact_text: String = ""
@export var target_scene_path: String = ""

func _ready() -> void:
	add_to_group("interactable")
