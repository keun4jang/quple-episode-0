extends Node2D

const NEXT_SCENE_PATH: String = "res://scenes/maps/TestLobby.tscn"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file(NEXT_SCENE_PATH)
