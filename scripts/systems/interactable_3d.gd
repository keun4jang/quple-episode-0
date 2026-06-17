extends Area3D

@export var interact_text: String = ""
@export var target_scene_path: String = ""
@export var item_id: String = ""

signal interacted

var hint_mesh: MeshInstance3D = null

func _ready() -> void:
    add_to_group("interactable")
    _build_hint()

func _build_hint() -> void:
    hint_mesh = MeshInstance3D.new()
    var sm = SphereMesh.new()
    sm.radius = 0.08
    sm.height = 0.16
    hint_mesh.mesh = sm
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color("#FFD76D")
    mat.emission_enabled = true
    mat.emission = Color("#FFD76D")
    mat.emission_energy_multiplier = 1.5
    hint_mesh.material_override = mat
    hint_mesh.position = Vector3(0, 0.55, 0)
    add_child(hint_mesh)

func _process(delta: float) -> void:
    if hint_mesh:
        hint_mesh.position.y = 0.55 + sin(Time.get_ticks_msec() * 0.002) * 0.075
        hint_mesh.rotate_y(delta * 1.2)

func interact() -> void:
    interacted.emit()
    if item_id != "":
        _collect_item()
    elif target_scene_path != "":
        SceneTransition.go_to(target_scene_path)
    elif interact_text != "":
        var db = get_tree().get_first_node_in_group("dialogue_box")
        if db:
            db.show_text(interact_text)

func _collect_item() -> void:
    match item_id:
        "camera":
            Episode0State.has_camera = true
            _show_and_remove("오래된 카메라를 챙겼다.")
        "notebook":
            Episode0State.has_notebook = true
            _show_and_remove("비어 있는 여행 수첩을 챙겼다.")
        "travel_bag":
            Episode0State.has_travel_bag = true
            _show_and_remove("작은 여행 가방을 챙겼다.")
        "badge":
            Episode0State.badge_returned = true
            _show_and_remove("사원증을 반납했다.")
    if Episode0State.all_items_collected() and Episode0State.current_state == Episode0State.State.COLLECT_TRAVEL_ITEMS:
        Episode0State.advance_to(Episode0State.State.RETURN_BADGE)

func _show_and_remove(text: String) -> void:
    var db = get_tree().get_first_node_in_group("dialogue_box")
    if db:
        db.show_text(text)
    hint_mesh.visible = false
    set_deferred("monitoring", false)
