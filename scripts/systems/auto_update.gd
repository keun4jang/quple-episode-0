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
	# 여기까지 왔으면 이번 부팅은 성공이다. 롤백 표시를 지운다.
	if _state.get("boot_pending", false):
		_state["boot_pending"] = false
		_write_state()
	_show_version_badge()
	_check_for_update()
	update_ready.connect(_show_update_toast)


## 부팅할 때 구석에 지금 버전을 잠깐 띄운다.
## 갱신이 실제로 폰까지 닿았는지 눈으로 확인할 방법이 이것뿐이다.
func _show_version_badge() -> void:
	_toast("쿼플 v" + current_version, 2.2, Color(1, 1, 1, 0.5))


func _show_update_toast(v: String) -> void:
	_toast("새 이야기 v%s 를 받았어요\n앱을 다시 켜면 적용돼요" % v, 4.5, Color(1, 0.88, 0.62))


func _toast(text: String, secs: float, col: Color) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.position = Vector2(-28, 22)
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

	# 지난 부팅이 끝까지 못 갔다 = 이 팩이 앱을 죽였다. 되돌린다.
	# 이게 없으면 잘못된 패치 하나로 앱이 영영 안 켜지고 손쓸 방법이 없다.
	if _state.get("boot_pending", false):
		push_warning("[AutoUpdate] 지난 실행이 팩 적용 중 죽었다. 되돌린다.")
		_rollback()
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
	_state["boot_pending"] = false
	_write_state()


# ── 갱신 확인 ──────────────────────────────────────────────────────────

func _check_for_update() -> void:
	var url := MANIFEST_URL_OVERRIDE if MANIFEST_URL_OVERRIDE != "" else MANIFEST_URL
	if MANIFEST_URL_OVERRIDE == "" and OS.has_feature("editor") \
			and OS.get_environment("QUPLE_UPDATE") == "":
		return          # 개발 중에는 조용히 있는다
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_manifest, CONNECT_ONE_SHOT)
	if _http.request(url) != OK:
		update_failed.emit("manifest 요청 실패")


func _on_manifest(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		update_failed.emit("manifest HTTP %d" % code)
		return
	var m = JSON.parse_string(body.get_string_from_utf8())
	if typeof(m) != TYPE_DICTIONARY or not m.has("version") or not m.has("url"):
		update_failed.emit("manifest 형식 오류")
		return
	if not is_newer(str(m["version"]), current_version):
		return
	_download(m)


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
		update_failed.emit("내려받기 요청 실패")


func _on_downloaded(code: int, m: Dictionary) -> void:
	if code != 200:
		_discard_tmp()
		update_failed.emit("내려받기 HTTP %d" % code)
		return

	var f := FileAccess.open(PCK_TMP, FileAccess.READ)
	if f == null:
		update_failed.emit("받은 파일을 열 수 없다")
		return
	var size := f.get_length()
	f.close()

	if size == 0 or size > MAX_PCK_BYTES:
		_discard_tmp()
		update_failed.emit("파일 크기가 이상하다 (%d 바이트)" % size)
		return

	# 받은 내용이 서버가 말한 것과 같은지 확인한다.
	# 중간에 끊겼거나 바꿔치기된 파일을 코드로 실행하면 안 된다.
	if m.has("sha256"):
		var got := FileAccess.get_sha256(PCK_TMP)
		if got != str(m["sha256"]):
			_discard_tmp()
			update_failed.emit("해시 불일치")
			return

	var d := DirAccess.open("user://")
	if FileAccess.file_exists(PCK_PATH):
		d.remove("patch.pck")
	if d.rename("patch.pck.tmp", "patch.pck") != OK:
		_discard_tmp()
		update_failed.emit("파일 교체 실패")
		return

	_state["pck_version"] = str(m["version"])
	_state["boot_pending"] = false
	_write_state()
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
