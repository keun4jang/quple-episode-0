extends SceneTree

# 각 맵 씬을 로드해서 세로 스크린샷을 찍는 도구
# 사용: xvfb-run godot --rendering-driver opengl3 -s tools/screenshot.gd

var _scenes := [
	"res://scenes/maps/CompanyFront3D.tscn",
	"res://scenes/maps/CompanyLobby3D.tscn",
	"res://scenes/maps/Office3D.tscn",
	"res://scenes/maps/BossDoorHallway3D.tscn",
]
var _index := 0
var _frames := 0
var _current = null
var _out_dir := "user://shots/"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	get_root().size = Vector2i(1080, 1920)
	_load_next()

func _find_camera(node) -> Camera3D:
	if node is Camera3D:
		return node
	for c in node.get_children():
		var found = _find_camera(c)
		if found:
			return found
	return null

func _load_next() -> void:
	if _index >= _scenes.size():
		print("ALL_DONE")
		quit()
		return
	var path = _scenes[_index]
	print("LOADING: ", path)
	var packed = load(path)
	if packed == null:
		print("FAIL_LOAD: ", path)
		_index += 1
		_load_next()
		return
	_current = packed.instantiate()
	get_root().add_child(_current)
	var cam = _find_camera(_current)
	if cam:
		cam.make_current()
		print("CAM_FOUND")
	_frames = 0

func _process(_delta: float) -> bool:
	if _current == null:
		return false
	_frames += 1
	if _frames >= 60:
		var img = get_root().get_viewport().get_texture().get_image()
		var fname = _scenes[_index].get_file().get_basename()
		var save_path = _out_dir + fname + ".png"
		img.save_png(save_path)
		print("SAVED: ", ProjectSettings.globalize_path(save_path))
		_current.queue_free()
		_current = null
		_index += 1
		_load_next()
	return false
