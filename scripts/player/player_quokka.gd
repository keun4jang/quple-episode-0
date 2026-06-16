extends CharacterBody2D

const SPEED: float = 140.0

var nearby_interactables: Array[Area2D] = []
var dialogue_box: CanvasLayer = null
var choice_box: CanvasLayer = null

func _ready() -> void:
	$InteractionArea.area_entered.connect(_on_interaction_area_entered)
	$InteractionArea.area_exited.connect(_on_interaction_area_exited)

func _physics_process(_delta: float) -> void:
	if _is_input_locked():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()

	velocity = input_vector * SPEED
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return

	_cache_ui_references()

	if dialogue_box != null and dialogue_box.is_open():
		dialogue_box.hide_box()
		return

	if choice_box != null and choice_box.visible:
		return

	if nearby_interactables.size() == 0:
		return

	nearby_interactables[0].interact()

func _is_input_locked() -> bool:
	_cache_ui_references()
	if dialogue_box != null and dialogue_box.is_open():
		return true
	if choice_box != null and choice_box.visible:
		return true
	return false

func _cache_ui_references() -> void:
	if dialogue_box == null:
		dialogue_box = get_tree().get_first_node_in_group("dialogue_box")
	if choice_box == null:
		choice_box = get_tree().get_first_node_in_group("choice_box")

func _on_interaction_area_entered(area: Area2D) -> void:
	if area.is_in_group("interactable"):
		nearby_interactables.append(area)

func _on_interaction_area_exited(area: Area2D) -> void:
	nearby_interactables.erase(area)
