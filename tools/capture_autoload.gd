extends Node

# 캡처 도구 오토로드 — 씬을 띄운 뒤 원하는 화면을 만들어놓고 스크린샷을 찍는다.
# tools/take_screenshots.sh 가 project.godot 에 임시로 끼웠다가 원복하므로
# 실제 게임 빌드에는 절대 포함되지 않는다.
#
# 환경변수
#   SHOT_NAME  저장 파일 이름 (기본 "shot")
#   SHOT_MODE  무엇을 찍을지
#     map               맵 화면 그대로 (기본)
#     panel:<id>        메뉴 창을 열고 찍는다 — inventory / equip / skill / quest / shop
#     battle:<enemy>    전투를 시작하고 찍는다 — anxiety / burnout / obsession / overtime ...
#     tutorial          튜토리얼 첫 화면
#   SHOT_DEMO  "0"이 아니면 아이템·장비·레벨을 미리 채운다 (기본 채움)

const SETTLE_FRAMES := 70          # 씬·HUD가 자리 잡을 때까지
const AFTER_FRAMES := 50           # 화면을 만든 뒤 기다릴 프레임
const AFTER_FRAMES_BATTLE := 200   # 전투는 등장 연출이 길다

var _frames := 0
var _acted := false
var _after := AFTER_FRAMES

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	if _mode().begins_with("battle:"):
		_after = AFTER_FRAMES_BATTLE

func _process(_delta: float) -> void:
	_frames += 1
	if _frames == SETTLE_FRAMES and not _acted:
		_acted = true
		_setup_shot()
	elif _frames >= SETTLE_FRAMES + _after:
		_save_and_quit()

func _mode() -> String:
	var m := OS.get_environment("SHOT_MODE")
	return m if m != "" else "map"

# ── 찍을 화면 만들기 ──────────────────────────────────
func _setup_shot() -> void:
	if OS.get_environment("SHOT_DEMO") != "0":
		_seed_demo_state()
	var mode := _mode()
	# 튜토리얼 샷이 아니면 튜토리얼 창을 치운다 — 안 그러면 맵·메뉴가 가려진다
	if mode != "tutorial":
		_dismiss_tutorial()
	if mode.begins_with("panel:"):
		GameUI.open_panel(mode.substr(6))
	elif mode.begins_with("battle:"):
		BattleSystem.start_battle(mode.substr(7))
	elif mode == "tutorial":
		_force_tutorial()

## 빈 세이브로는 메뉴가 전부 비어 보여서 확인이 안 된다.
## 아이템·장비·레벨을 적당히 채워 실제 플레이 중간쯤 상태를 만든다.
func _seed_demo_state() -> void:
	PlayerStats.add_exp(200)     # LV4 — '마음 단단히'까지 해금, '따뜻한 포옹'은 아직 잠김
	PlayerStats.add_coins(480)
	for id in ["cocoa", "cookie", "energy_drink", "clover", "herb_tea", "star_candy"]:
		PlayerStats.add_item(id, 3)
	for id in ["hat", "scarf", "mittens", "slippers", "travel_cap", "star_scarf",
			"tail_ribbon", "star_charm"]:
		PlayerStats.add_item(id, 1)
	for id in ["camera", "notebook"]:
		PlayerStats.add_item(id, 1)
	# 포근 세트를 다 갖춰 세트 효과가 보이게 한다
	for id in ["hat", "scarf", "mittens", "slippers", "tail_ribbon"]:
		PlayerStats.equip_item(id)

## 첫 실행이면 튜토리얼이 떠서 화면을 덮는다. 봤다고 표시하고 이미 뜬 창은 닫는다.
func _dismiss_tutorial() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("tutorial", "seen", true)
	cfg.save("user://settings.cfg")
	var scene = get_tree().current_scene
	if scene and scene.has_node("TutorialUI"):
		scene.get_node("TutorialUI").queue_free()

func _force_tutorial() -> void:
	# 이미 봤다고 저장돼 있으면 안 뜨므로 플래그를 지운다
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("tutorial", "seen", false)
	cfg.save("user://settings.cfg")
	var scene = get_tree().current_scene
	if scene and scene.has_node("TutorialUI"):
		scene.get_node("TutorialUI").maybe_show()

# ── 저장 ─────────────────────────────────────────────
func _save_and_quit() -> void:
	var img := get_tree().root.get_viewport().get_texture().get_image()
	var shot_name := OS.get_environment("SHOT_NAME")
	if shot_name == "":
		shot_name = "shot"
	var out_dir := "user://shots/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := out_dir + shot_name + ".png"
	img.save_png(path)
	print("CAPTURE_SAVED: ", ProjectSettings.globalize_path(path))
	get_tree().quit()
