extends Node
## user://save.cfg 로 진행 상황을 저장/복원한다.
## 여행은 실제 시각 기준이라, 앱을 껐다 켜도 그동안 흐른 시간이 그대로 반영된다.

const SAVE_PATH := "user://save.cfg"
const TEMP_PATH := "user://save.cfg.tmp"      # 먼저 여기에 쓴다
const BACKUP_PATH := "user://save.bak"        # 직전 저장본
const SAVE_VERSION := 2

var _restoring := false

signal game_saved

const PROFILE_PATH := "user://profile.cfg"

## 0편을 한 번이라도 클리어했는가 (새 게임을 시작해도 유지되는 기록)
func has_cleared_episode0() -> bool:
	var c := ConfigFile.new()
	if c.load(PROFILE_PATH) != OK:
		return false
	return bool(c.get_value("progress", "episode0_cleared", false))

func mark_episode0_cleared() -> void:
	var c := ConfigFile.new()
	c.load(PROFILE_PATH)
	c.set_value("progress", "episode0_cleared", true)
	c.save(PROFILE_PATH)

## 0편 자동 저장. 플레이어 위치까지 함께 남긴다.
func autosave(current_scene: String, player_pos: Vector3 = Vector3.ZERO) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("game", "version", 1)
	cfg.set_value("game", "saved_at", int(Time.get_unix_time_from_system()))
	cfg.set_value("game", "current_scene", current_scene)
	cfg.set_value("game", "player_position", player_pos)
	cfg.set_value("episode0", "data", Episode0State.to_dict())
	cfg.set_value("travel", "data", TravelState.to_dict())
	if cfg.save(TEMP_PATH) == OK and _is_valid(TEMP_PATH):
		var da := DirAccess.open("user://")
		if da:
			if FileAccess.file_exists(SAVE_PATH) and not _restoring and _is_valid(SAVE_PATH):
				da.remove(BACKUP_PATH.get_file())
				da.copy(SAVE_PATH, BACKUP_PATH)
			da.remove(SAVE_PATH.get_file())
			da.rename(TEMP_PATH.get_file(), SAVE_PATH.get_file())
	game_saved.emit()

func get_player_position() -> Vector3:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return Vector3.ZERO
	return cfg.get_value("game", "player_position", Vector3.ZERO)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## 저장. 도중에 앱이 꺼져도 기록이 깨지지 않게 3단계로 쓴다.
##   ① 임시 파일에 쓴다  ② 제대로 써졌는지 읽어서 확인  ③ 기존 것을 백업하고 교체
func save_game(current_scene: String = "") -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)   # 기존 값 보존
	cfg.set_value("game", "version", SAVE_VERSION)
	cfg.set_value("game", "saved_at", int(Time.get_unix_time_from_system()))
	if current_scene != "":
		cfg.set_value("game", "current_scene", current_scene)
	elif not cfg.has_section_key("game", "current_scene"):
		cfg.set_value("game", "current_scene", "res://scenes/travel/TravelHub.tscn")
	cfg.set_value("episode0", "data", Episode0State.to_dict())
	cfg.set_value("travel", "data", TravelState.to_dict())

	# ① 임시 파일에 먼저
	if cfg.save(TEMP_PATH) != OK:
		push_warning("저장 실패: 임시 파일을 쓸 수 없음")
		return
	# ② 읽어서 검증 (반쯤 쓰인 파일을 진짜 저장본으로 만들지 않는다)
	if not _is_valid(TEMP_PATH):
		push_warning("저장 실패: 임시 파일이 온전하지 않음")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
		return
	# ③ 기존 저장본을 백업으로 옮기고 교체
	var da := DirAccess.open("user://")
	if da:
		# 복구 중이거나 기존 저장본이 깨졌으면 백업을 갱신하지 않는다
		if FileAccess.file_exists(SAVE_PATH) and not _restoring and _is_valid(SAVE_PATH):
			da.remove(BACKUP_PATH.get_file())
			da.copy(SAVE_PATH, BACKUP_PATH)
		da.remove(SAVE_PATH.get_file())
		da.rename(TEMP_PATH.get_file(), SAVE_PATH.get_file())
	game_saved.emit()

## 저장 파일이 온전한가
func _is_valid(path: String) -> bool:
	var c := ConfigFile.new()
	if c.load(path) != OK:
		return false
	if not c.has_section_key("game", "version"):
		return false
	if not c.has_section_key("episode0", "data"):
		return false
	if not c.has_section_key("travel", "data"):
		return false
	var td = c.get_value("travel", "data", null)
	return td is Dictionary

## 불러오기. 저장본이 깨졌으면 직전 백업으로 되살린다.
func load_game() -> bool:
	var path := SAVE_PATH
	if not _is_valid(path):
		if _is_valid(BACKUP_PATH):
			push_warning("저장본이 손상되어 백업에서 복구합니다")
			path = BACKUP_PATH
		else:
			return false
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	Episode0State.from_dict(cfg.get_value("episode0", "data", {}))
	TravelState.from_dict(cfg.get_value("travel", "data", {}))
	# 백업에서 살렸으면 정상 저장본으로 다시 써둔다.
	# 이때 백업을 덮으면 안 된다 — 깨진 파일이 백업이 되어버린다.
	if path == BACKUP_PATH:
		_restoring = true
		save_game()
		_restoring = false
	return true

# ── 작은 표시들 ────────────────────────────────────────────────────────
#
# "튜토리얼 봤음" 처럼 게임 진행과 무관한 한 줄짜리 기록. 저장본에 같이 넣는다.
# 세이브 슬롯을 따로 만들 만한 무게가 아니고, 저장본과 생사를 같이 하는 편이 맞다.
# (저장을 지우면 튜토리얼도 다시 나오는 게 자연스럽다.)

func get_flag(key: String, fallback = false):
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return fallback
	return cfg.get_value("flags", key, fallback)


func set_flag(key: String, value) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)              # 없으면 빈 것으로 시작한다
	cfg.set_value("flags", key, value)
	# 표시 하나 때문에 전체 저장 절차(임시→검증→백업→교체)를 돌리진 않는다.
	# 이게 날아가도 튜토리얼이 한 번 더 나올 뿐이다.
	cfg.save(SAVE_PATH)


## 백업이 있는가 (설정 화면에서 안내용)
func has_backup() -> bool:
	return _is_valid(BACKUP_PATH)

func get_current_scene(fallback: String = "res://scenes/travel/TravelHub.tscn") -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return fallback
	return cfg.get_value("game", "current_scene", fallback)

func clear_save() -> void:
	for f in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Episode0State.reset()
	TravelState.reset()
