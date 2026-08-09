extends Node
## 재설치 없이 게임 내용을 갱신한다 (OTA).
##
## 안드로이드는 앱이 자기 APK 를 몰래 갈아치우는 걸 막는다. 설치는 언제나
## 사용자 확인이 필요하다. 그래서 APK 를 바꾸는 대신 **내용물**을 바꾼다.
## 스크립트·씬·UI·대사·밸런스는 전부 리소스 팩(.pck) 안에 있고,
## Godot 은 실행 중에 팩을 얹어 기존 파일을 덮어쓸 수 있다.
##
## 못 바꾸는 것: 엔진 자체, 안드로이드 권한, 앱 아이콘·이름, 네이티브 라이브러리.
## 그건 APK 를 새로 깔아야 한다.
##
## 흐름
##   1. 부팅 때 이미 받아둔 팩이 있으면 얹는다 (main scene 보다 먼저)
##   2. 그 다음 백그라운드로 서버의 manifest 를 확인한다
##   3. 새 버전이 있으면 받아서 검증만 해 두고, **다음 실행 때** 적용한다
##
## 받자마자 갈아끼우지 않는 이유: 이미 메모리에 올라간 씬과 새로 얹은 스크립트가
## 섞이면 재현도 안 되는 이상한 버그가 난다. 다음 부팅에 적용하는 편이 안전하다.

signal update_ready(version: String)      ## 새 버전을 받아 다음 실행에 적용될 때
signal update_failed(reason: String)
## 아래 둘은 **사람이 직접 확인 버튼을 눌렀을 때**를 위한 것이다.
## 부팅 때 자동으로 도는 확인은 조용해야 하지만, 손으로 누른 확인은
## 반드시 답을 돌려줘야 한다 — 아무 반응이 없으면 눌린 건지 알 수 없다.
signal check_started()
signal up_to_date(version: String)

## 지금 확인이 돌고 있는가. 버튼을 두 번 누르는 것을 막는다.
var checking := false

## 사용자 저장소만 바라본다. 임의의 주소에서 코드를 받아 실행하면 안 된다.
const MANIFEST_URL := "https://raw.githubusercontent.com/keun4jang/quple-episode-0/claude/dreamy-heisenberg-gkeg9a/update/manifest.json"

const PCK_PATH := "user://patch.pck"
const PCK_TMP := "user://patch.pck.tmp"
const STATE_PATH := "user://update_state.json"
const MAX_PCK_BYTES := 64 * 1024 * 1024

var _state: Dictionary = {}
var _http: HTTPRequest

## 테스트에서 가짜 서버를 물릴 때만 쓴다. 비어 있으면 위의 고정 주소를 본다.
var MANIFEST_URL_OVERRIDE := ""


## 지금 돌고 있는 내용물의 버전. 팩이 얹혔으면 팩의 버전이다.
var current_version: String:
	get:
		var v: String = _state.get("pck_version", "")
		return v if v != "" else baked_version

## APK 에 원래 들어 있던 버전
var baked_version: String:
	get:
		return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func _init() -> void:
	# main scene 보다 먼저 돌아야 한다. 그래야 이번 실행부터 새 내용이 쓰인다.
	_state = _read_state()
	_apply_pending_pack()


func _ready() -> void:
	_show_version_badge()
	_check_for_update()
	_arm_boot_watchdog()


## "이번 부팅은 성공했다" 를 언제 인정할 것인가.
##
## 처음엔 이 _ready 안에서 바로 지웠다. 그건 틀렸다.
## 오토로드의 _ready 는 **메인 씬이 뜨기도 전에** 돈다. 그래서 팩이 씬을 죽여도
## 이미 "성공" 으로 기록된 뒤라 롤백이 영영 걸리지 않는다.
## 잘못된 팩 하나로 앱이 켜지지 않는 상태가 되고, 켤 때마다 같은 팩을 다시 얹는다.
##
## 그래서 화면이 실제로 몇 초 버틴 뒤에 지운다. 그 전에 죽으면 표시가 남고,
## 다음 실행에서 팩을 버리고 APK 원래 내용으로 돌아간다.
## 8초였는데, 껐다 켜기를 빠르게 반복하는 사용자는 매번 이 시간을 못
## 채워서 팩이 계속 되돌려졌다. 씬이 떠 있는 것만 확인하면 되니 짧게 잡는다.
const BOOT_OK_SECONDS := 3.0

func _arm_boot_watchdog() -> void:
	if not _state.get("boot_pending", false):
		return
	await get_tree().create_timer(BOOT_OK_SECONDS).timeout
	# 여기까지 왔으면 씬이 뜨고 몇 초를 버텼다는 뜻이다.
	if get_tree().current_scene == null:
		return          # 아직 씬이 없다 = 아직 성공이라고 못 한다
	_state["boot_pending"] = false
	_state.erase("boot_fail_count")
	_write_state()
	print("[AutoUpdate] 부팅 확인 - 이 팩을 유지한다")
	update_ready.connect(_show_update_toast)


## 부팅할 때 구석에 지금 버전을 잠깐 띄운다.
## 갱신이 실제로 폰까지 닿았는지 눈으로 확인할 방법이 이것뿐이다.
func _show_version_badge() -> void:
	_toast("진짜 행복 v" + current_version, 2.2, Color(1, 1, 1, 0.5))


func _show_update_toast(v: String) -> void:
	_toast("새 이야기를 받았어요 (v%s)\n앱을 다시 켜면 적용돼요" % v, 4.5, Color(1, 0.88, 0.62))


func _toast(text: String, secs: float, col: Color) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# **왼쪽 위, 시각 바로 아래.** 갈 데를 하나씩 지우고 남은 자리다 —
	#   오른쪽 위: 여행 화면의 설정 버튼과 겹친다
	#   아래 가운데: 대화창이 화면 아래를 통째로 쓴다
	#   아래 양 끝: 사진·배낭 버튼이 있다
	#   위 가운데: 메인화면의 제목이 있다
	# 왼쪽 위에는 여행 화면의 시각뿐이고, 그 한 줄 아래는 어디서나 빈다.
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.anchor_left = 0.0; l.anchor_right = 0.0
	l.anchor_top = 0.0;  l.anchor_bottom = 0.0
	l.offset_left = 28.0; l.offset_right = 620.0
	l.offset_top = 68.0; l.offset_bottom = 120.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(l)
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(cl.queue_free)


# ── 부팅 시 적용 ────────────────────────────────────────────────────────

func _apply_pending_pack() -> void:
	if not FileAccess.file_exists(PCK_PATH):
		return

	# APK 를 새로 깔았는데 옛 팩이 남아 있는 경우. 팩이 APK 보다 낡았으면
	# 얹는 순간 게임이 과거로 돌아간다 — 업데이트 문제로 재설치한 사람이
	# 재설치 직후 다시 옛 화면을 보는 것보다 나쁜 첫인상은 없다.
	var pv := str(_state.get("pck_version", ""))
	if pv != "" and not is_newer(pv, baked_version):
		print("[AutoUpdate] 팩(%s)이 APK(%s)보다 낡았다. 버린다." % [pv, baked_version])
		_rollback()
		return

	# 지난 부팅이 확인을 못 받았다. 두 가지 경우가 있다.
	#
	# 팩이 정말 앱을 죽였을 수도 있지만, **사용자가 그냥 빨리 껐을** 수도
	# 있다. "껐다 켜면 적용된다" 는 안내대로 껐다 켜기를 빠르게 반복하면
	# 확인 시간을 매번 못 채워서, 받는다→얹는다→되돌린다→다시 받는다 의
	# 고리에 갇힌다 — 실제로 폰이 며칠 전 내용에 묶여 있었다.
	#
	# 그래서 한 번 실패로는 안 버린다. **연달아 세 번** 확인을 못 받았을
	# 때만 팩이 범인이라 보고 되돌린다. 진짜로 죽는 팩이면 세 번 연속
	# 못 버틸 것이고, 그동안 앱은 어차피 안 켜지는 상태라 잃는 것이 없다.
	if _state.get("boot_pending", false):
		var fails := int(_state.get("boot_fail_count", 0)) + 1
		if fails >= 3:
			push_warning("[AutoUpdate] 팩 적용 후 %d번 연속 확인 실패. 되돌린다." % fails)
			_rollback()
			return
		_state["boot_fail_count"] = fails
		push_warning("[AutoUpdate] 지난 부팅이 확인을 못 받았다 (%d/3). 팩은 유지한다." % fails)

	# 개발 중에는 얹지 않는다. 받아둔 팩이 방금 고친 파일을 덮어써서
	# "코드를 고쳤는데 화면이 안 바뀐다" 는 상황이 벌어진다.
	if OS.has_feature("editor") and OS.get_environment("QUPLE_UPDATE") == "":
		return

	_state["boot_pending"] = true
	_write_state()

	if ProjectSettings.load_resource_pack(PCK_PATH):
		print("[AutoUpdate] 내용 버전 ", _state.get("pck_version", "?"), " 적용됨")
	else:
		push_warning("[AutoUpdate] 팩을 얹지 못했다. 되돌린다.")
		_rollback()


func _rollback() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PCK_PATH))
	if FileAccess.file_exists(PCK_PATH):
		DirAccess.open("user://").remove("patch.pck")
	_state.erase("pck_version")
	_state.erase("boot_fail_count")
	_state["boot_pending"] = false
	_write_state()


# ── 갱신 확인 ──────────────────────────────────────────────────────────

## 사람이 설정에서 "업데이트 확인" 을 눌렀을 때.
##
## 부팅 확인과 다른 점이 둘 있다. 에디터에서도 돌고(개발 중에 눌러서
## 확인할 수 있어야 한다), 최신이면 최신이라고 **말해 준다.** 자동
## 확인은 최신일 때 아무 말도 하지 않는다 — 그게 맞지만, 버튼을 눌렀는데
## 아무 일도 없으면 고장으로 보인다.
func check_now() -> bool:
	if checking:
		return false
	checking = true
	check_started.emit()
	_manual = true
	_check_for_update(true)
	return true

## 이번 확인이 손으로 누른 것인가.
var _manual := false


func _check_for_update(force := false) -> void:
	var url := MANIFEST_URL_OVERRIDE if MANIFEST_URL_OVERRIDE != "" else MANIFEST_URL
	if not force and MANIFEST_URL_OVERRIDE == "" and OS.has_feature("editor") \
			and OS.get_environment("QUPLE_UPDATE") == "":
		return          # 개발 중에는 조용히 있는다
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_manifest, CONNECT_ONE_SHOT)
	if _http.request(url) != OK:
		checking = false
		update_failed.emit("manifest 요청 실패")


func _on_manifest(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		checking = false
		update_failed.emit("연결에 실패했어요 (HTTP %d)" % code)
		return
	var m = JSON.parse_string(body.get_string_from_utf8())
	if typeof(m) != TYPE_DICTIONARY or not m.has("version") or not m.has("url"):
		checking = false
		update_failed.emit("서버 응답을 읽을 수 없어요")
		return
	if not is_newer(str(m["version"]), current_version):
		checking = false
		up_to_date.emit(current_version)
		return
	latest_version = str(m["version"])
	_download(m)


## 서버에 있는 가장 새 버전. 확인하기 전에는 비어 있다.
var latest_version := ""


## "0.2.0" 이 "0.1.9" 보다 새로운가. 자리수가 달라도 맞게 비교한다.
static func is_newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false


func _download(m: Dictionary) -> void:
	var http := HTTPRequest.new()
	http.timeout = 120.0
	http.download_file = PCK_TMP
	add_child(http)
	http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, _b: PackedByteArray):
		http.queue_free()
		_on_downloaded(code, m))
	if http.request(str(m["url"])) != OK:
		checking = false
		update_failed.emit("내려받기를 시작하지 못했어요")


func _on_downloaded(code: int, m: Dictionary) -> void:
	if code != 200:
		_discard_tmp()
		checking = false
		update_failed.emit("내려받기에 실패했어요 (HTTP %d)" % code)
		return

	var f := FileAccess.open(PCK_TMP, FileAccess.READ)
	if f == null:
		checking = false
		update_failed.emit("받은 파일을 열 수 없어요")
		return
	var size := f.get_length()
	f.close()

	if size == 0 or size > MAX_PCK_BYTES:
		_discard_tmp()
		checking = false
		update_failed.emit("받은 파일이 이상해요 (%d 바이트)" % size)
		return

	# 받은 내용이 서버가 말한 것과 같은지 확인한다.
	# 중간에 끊겼거나 바꿔치기된 파일을 코드로 실행하면 안 된다.
	if m.has("sha256"):
		var got := FileAccess.get_sha256(PCK_TMP)
		if got != str(m["sha256"]):
			_discard_tmp()
			checking = false
			update_failed.emit("받은 파일이 손상됐어요")
			return

	var d := DirAccess.open("user://")
	if FileAccess.file_exists(PCK_PATH):
		d.remove("patch.pck")
	if d.rename("patch.pck.tmp", "patch.pck") != OK:
		_discard_tmp()
		checking = false
		update_failed.emit("파일을 바꿔 놓지 못했어요")
		return

	_state["pck_version"] = str(m["version"])
	_state["boot_pending"] = false
	_write_state()
	checking = false
	print("[AutoUpdate] 새 내용 ", m["version"], " 준비됨. 다음 실행에 적용된다.")
	update_ready.emit(str(m["version"]))


func _discard_tmp() -> void:
	if FileAccess.file_exists(PCK_TMP):
		DirAccess.open("user://").remove("patch.pck.tmp")


# ── 상태 저장 ──────────────────────────────────────────────────────────

func _read_state() -> Dictionary:
	if not FileAccess.file_exists(STATE_PATH):
		return {}
	var f := FileAccess.open(STATE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}


func _write_state() -> void:
	var f := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_state))
