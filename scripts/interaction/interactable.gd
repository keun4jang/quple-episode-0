extends Area2D

@export var interact_text: String = ""
@export var target_scene_path: String = ""

func _ready() -> void:
	add_to_group("interactable")

func interact() -> void:
	if target_scene_path != "":
		get_tree().change_scene_to_file(target_scene_path)
	elif interact_text != "":
		var dialogue_box: CanvasLayer = get_tree().get_first_node_in_group("dialogue_box")
		if dialogue_box != null:
			dialogue_box.show_text(interact_text)
