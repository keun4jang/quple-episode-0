extends Node
## user://save.cfg 로 진행 상황을 저장/복원한다.
## 여행은 실제 시각 기준이라, 앱을 껐다 켜도 그동안 흐른 시간이 그대로 반영된다.

const SAVE_PATH := "user://save.cfg"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(current_scene: String = "") -> void:
	var cfg := ConfigFile.new()
	# 기존 값 보존 후 덮어쓰기
	cfg.load(SAVE_PATH)
	cfg.set_value("game", "version", 1)
	cfg.set_value("game", "saved_at", int(Time.get_unix_time_from_system()))
	if current_scene != "":
		cfg.set_value("game", "current_scene", current_scene)
	elif not cfg.has_section_key("game", "current_scene"):
		cfg.set_value("game", "current_scene", "res://scenes/travel/TravelHub.tscn")
	cfg.set_value("episode0", "data", Episode0State.to_dict())
	cfg.set_value("travel", "data", TravelState.to_dict())
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("save_game 실패: %d" % err)

func load_game() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	Episode0State.from_dict(cfg.get_value("episode0", "data", {}))
	TravelState.from_dict(cfg.get_value("travel", "data", {}))
	return true

func get_current_scene(fallback: String = "res://scenes/travel/TravelHub.tscn") -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return fallback
	return cfg.get_value("game", "current_scene", fallback)

func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	Episode0State.reset()
	TravelState.reset()
