extends Node3D

var in_photo_zone: bool = false

func _ready() -> void:
	$PhotoArea.body_entered.connect(func(_b): in_photo_zone = true)
	$PhotoArea.body_exited.connect(func(_b): in_photo_zone = false)
	_build_visual()

func _build_visual() -> void:
	var ring = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.8
	mesh.bottom_radius = 0.8
	mesh.height = 0.02
	ring.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("#FFD76D")
	mat.emission_enabled = true
	mat.emission = Color("#FFD76D")
	mat.emission_energy_multiplier = 0.5
	ring.material_override = mat
	add_child(ring)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("key_photo") and in_photo_zone:
		_take_photo()

func _take_photo() -> void:
	if Episode0State.first_photo_taken:
		return
	Episode0State.first_photo_taken = true
	if AudioManager: AudioManager.photo_shutter()
	Episode0State.album_created = true
	var db = get_tree().get_first_node_in_group("dialogue_box")
	if db:
		db.show_text("찰칵!\n첫 번째 여행 기록이 앨범에 남았다.")
	var save_scene = get_tree().current_scene
	var player = get_tree().get_first_node_in_group("player")
	if player:
		SaveManager.save_game(save_scene.scene_file_path, player.global_position)
	Episode0State.advance_to(Episode0State.State.ALBUM_CREATED)
	await get_tree().create_timer(2.5).timeout
	Episode0State.episode0_cleared = true
	Episode0State.advance_to(Episode0State.State.CLEAR)
	var clear = get_tree().get_first_node_in_group("clear_screen")
	if clear:
		clear.show_clear()
