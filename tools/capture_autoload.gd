extends Node

# 임시 캡처 오토로드: 현재 씬을 일정 프레임 후 스크린샷 찍고 종료
# 환경변수 SHOT_NAME 으로 파일명 지정

var _frames := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1080, 1920))

func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 90:
		var img = get_tree().root.get_viewport().get_texture().get_image()
		var name = OS.get_environment("SHOT_NAME")
		if name == "":
			name = "shot"
		var out_dir = "user://shots/"
		DirAccess.make_dir_recursive_absolute(out_dir)
		var path = out_dir + name + ".png"
		img.save_png(path)
		print("CAPTURE_SAVED: ", ProjectSettings.globalize_path(path))
		get_tree().quit()
