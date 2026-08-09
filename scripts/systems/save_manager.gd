extends Node
## user://save.cfg 로 진행 상황을 저장/복원한다.
## 여행은 실제 시각 기준이라, 앱을 껐다 켜도 그동안 흐른 시간이 그대로 반영된다.

const SAVE_PATH := "user://save.cfg"
const TEMP_PATH := "user://save.cfg.tmp"      # 먼저 여기에 쓴다
const BACKUP_PATH := "user://save.bak"        # 직전 저장본
const SAVE_VERSION := 2

var _restoring := false

signal game_saved

## 지금 자리를 적어 둔다.
func autosave(current_scene: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("game", "version", 1)
	cfg.set_value("game", "saved_at", int(Time.get_unix_time_from_system()))
	cfg.set_value("game", "current_scene", current_scene)
	cfg.set_value("journey", "data", JourneyState.to_dict())
	if cfg.save(TEMP_PATH) == OK and _is_valid(TEMP_PATH):
		var da := DirAccess.open("user://")
		if da:
			if FileAccess.file_exists(SAVE_PATH) and not _restoring and _is_valid(SAVE_PATH):
				da.remove(BACKUP_PATH.get_file())
				da.copy(SAVE_PATH, BACKUP_PATH)
			da.remove(SAVE_PATH.get_file())
			da.rename(TEMP_PATH.get_file(), SAVE_PATH.get_file())
	game_saved.emit()

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
		cfg.set_value("game", "current_scene", HUB)
	cfg.set_value("journey", "data", JourneyState.to_dict())

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

## 지금 화면을 그대로 저장한다. 어디서 불러도 안전하다.
func save_now() -> void:
	var scene := get_tree().current_scene if get_tree() != null else null
	if scene == null or not is_instance_valid(scene):
		return
	var here := scene.scene_file_path
	if here == "":
		return
	save_game(here)


## 앱이 물러나거나 꺼질 때 저장한다.
##
## 지금까지 저장은 "무슨 일이 일어났을 때"만 됐다 — 여행 출발, 사진 받기,
## 맵 이동. 그래서 도감을 열어 보다가 홈 버튼을 누르면 그 사이에 한 일이
## 사라졌다. 폰에서 앱이 죽는 건 거의 다 이 순간이다.
##
## 안드로이드는 백그라운드로 갈 때 APPLICATION_PAUSED 를 준다. 그 뒤에
## 시스템이 언제 앱을 죽일지는 알 수 없으므로, 여기서 반드시 써 둔다.
##
## 창을 왔다 갔다 하면 FOCUS_OUT 이 연달아 오므로 잠깐 사이에 두 번은 안 쓴다.
var _last_auto := 0.0

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, \
		NOTIFICATION_APPLICATION_FOCUS_OUT, \
		NOTIFICATION_WM_CLOSE_REQUEST, \
		NOTIFICATION_WM_GO_BACK_REQUEST:
			var now := Time.get_unix_time_from_system()
			if now - _last_auto < 2.0:
				return
			_last_auto = now
			save_now()


## 저장 파일이 온전한가
func _is_valid(path: String) -> bool:
	var c := ConfigFile.new()
	if c.load(path) != OK:
		return false
	if not c.has_section_key("game", "version"):
		return false
	# 예전엔 episode0·travel 칸을 봤다. 그 시절 게임은 지웠고, 지금 저장본의
	# 알맹이는 journey 하나다. 예전 저장본은 이 칸이 없으니 자연히 걸러져
	# 새로 시작하게 된다 — 옛 진행을 옮겨 올 방법이 없으니 그게 맞다.
	if not c.has_section_key("journey", "data"):
		return false
	var jd = c.get_value("journey", "data", null)
	return jd is Dictionary

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
	JourneyState.from_dict(cfg.get_value("journey", "data", {}))
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

## 이어하기의 기본 자리. **이제 여행 쪽이다.**
##
## 예전 저장본은 0편 맵을 가리킬 수 있다. 그 맵들은 이제 게임의 일부가
## 아니므로, 가리키고 있으면 무시하고 여행으로 보낸다 — 안 그러면
## 할 일이 하나도 없는 옛 맵에 갇힌다.
const HUB := "res://scenes/journey/Gwaeul.tscn"

func get_current_scene(fallback: String = HUB) -> String:
	var raw := _raw_current_scene(fallback)
	# 옛 맵을 가리키는 저장은 무시한다. 그 시절은 끝났다.
	if raw.contains("/side/") or raw.contains("/maps/") or raw.contains("/travel/"):
		return HUB
	return raw


## 저장 파일에 적힌 그대로. 이어하기 **정책**이 아니라 저장이 제대로
## 오갔는지를 볼 때 쓴다.
func get_saved_scene(fallback: String = HUB) -> String:
	return _raw_current_scene(fallback)


func _raw_current_scene(fallback: String) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return fallback
	return cfg.get_value("game", "current_scene", fallback)

func clear_save() -> void:
	for f in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	JourneyState.reset()
