extends Node
## 재설치 없는 내용 갱신(OTA)이 실제로 도는가.
##
## 진짜 HTTP 서버를 띄우고, 진짜 .pck 를 내려받아, 진짜로 얹어서 확인한다.
## 자기 자신을 갈아끼우는 기능이라 "아마 되겠지" 로 두면 안 된다.
## 잘못된 패치 하나가 앱을 영영 못 켜게 만들 수 있다.

const AU := preload("res://scripts/systems/auto_update.gd")

var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)


func _ready() -> void:
	print("=== 자동 갱신 테스트 ===")
	_test_version_compare()
	await _test_download_cycle()
	_test_rollback()
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(0 if fail_n == 0 else 1)


func _test_version_compare() -> void:
	print("\n[1] 버전 비교")
	ck("0.1.2 > 0.1.1", AU.is_newer("0.1.2", "0.1.1"))
	ck("0.2.0 > 0.1.9", AU.is_newer("0.2.0", "0.1.9"))
	ck("1.0.0 > 0.9.9", AU.is_newer("1.0.0", "0.9.9"))
	ck("같으면 아님", not AU.is_newer("0.1.1", "0.1.1"))
	ck("낮으면 아님", not AU.is_newer("0.1.0", "0.1.1"))
	# 문자열 비교로 짰으면 "0.1.10" < "0.1.9" 로 잘못 나온다
	ck("0.1.10 > 0.1.9 (자리수 함정)", AU.is_newer("0.1.10", "0.1.9"))
	ck("자리수 달라도 됨", AU.is_newer("0.2", "0.1.9"))


func _test_download_cycle() -> void:
	print("\n[2] 내려받기 → 검증 → 다음 실행에 적용")
	# 진짜 HTTP 서버를 띄운다. 소켓을 흉내내면 정작 HTTPRequest 경로를 안 보게 된다.
	var dir := OS.get_user_data_dir() + "/testsrv"
	DirAccess.make_dir_recursive_absolute(dir)
	var payload := "QUPLE-TEST-PACK".to_utf8_buffer()
	var f := FileAccess.open(dir + "/quple.pck", FileAccess.WRITE)
	f.store_buffer(payload); f.close()
	var sha := FileAccess.get_sha256(dir + "/quple.pck")

	var port := 38111
	var pid := OS.create_process("python3",
		["-m", "http.server", str(port), "--directory", dir, "--bind", "127.0.0.1"])
	if pid <= 0:
		ck("테스트 서버 시작", false, "python3 http.server 를 못 띄웠다")
		return
	for i in 90:
		await get_tree().process_frame
	ck("테스트 서버 시작", true, "포트 %d" % port)

	var au := AU.new()
	add_child(au)
	_reset(au)
	au.MANIFEST_URL_OVERRIDE = "http://127.0.0.1:%d/manifest.json" % port

	_write_manifest(dir, {"version": "9.9.9",
		"url": "http://127.0.0.1:%d/quple.pck" % port, "sha256": sha})

	var got := await _run_check(au)
	ck("새 버전을 받았다", got == ["9.9.9"], str(got))
	ck("팩 파일이 저장됐다", FileAccess.file_exists(AU.PCK_PATH))
	ck("받은 내용이 그대로다", FileAccess.get_sha256(AU.PCK_PATH) == sha)
	ck("다음 실행에 적용될 버전으로 기록됨", au.current_version == "9.9.9", au.current_version)

	print("\n[3] 내용이 바뀐 파일은 거부한다")
	_reset(au)
	_write_manifest(dir, {"version": "9.9.9",
		"url": "http://127.0.0.1:%d/quple.pck" % port,
		"sha256": "00000000000000000000000000000000000000000000000000000000deadbeef"})
	got = await _run_check(au)
	ck("해시가 다르면 거부", got.size() == 1 and str(got[0]).begins_with("실패: 해시"), str(got))
	ck("거부한 팩은 저장 안 됨", not FileAccess.file_exists(AU.PCK_PATH))

	print("\n[3-2] 이미 최신이면 아무것도 안 한다")
	_reset(au)
	_write_manifest(dir, {"version": "0.0.1",
		"url": "http://127.0.0.1:%d/quple.pck" % port, "sha256": sha})
	got = await _run_check(au)
	ck("옛 버전은 무시", got.is_empty(), str(got))
	ck("팩을 받지 않았다", not FileAccess.file_exists(AU.PCK_PATH))

	au.queue_free()
	OS.kill(pid)


func _write_manifest(dir: String, d: Dictionary) -> void:
	var f := FileAccess.open(dir + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()


## 갱신 확인을 한 번 돌리고 결과(신호)를 모아 돌려준다.
func _run_check(au) -> Array:
	var got := []
	var a := func(v): got.append(v)
	var b := func(r): got.append("실패: " + r)
	au.update_ready.connect(a)
	au.update_failed.connect(b)
	au._check_for_update()
	for i in 300:
		await get_tree().process_frame
		if not got.is_empty():
			break
	au.update_ready.disconnect(a)
	au.update_failed.disconnect(b)
	return got


func _test_rollback() -> void:
	print("\n[4] 앱을 죽이는 패치는 스스로 되돌린다")
	# 지난 실행이 팩을 얹다가 죽은 상태를 만든다
	var f := FileAccess.open(AU.PCK_PATH, FileAccess.WRITE)
	f.store_string("망가진 팩")
	f.close()
	f = FileAccess.open(AU.STATE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"pck_version": "9.9.9", "boot_pending": true}))
	f.close()

	var au := AU.new()          # _init 에서 롤백이 돌아야 한다
	ck("망가진 팩이 지워졌다", not FileAccess.file_exists(AU.PCK_PATH))
	ck("APK 원래 버전으로 돌아왔다", au.current_version == au.baked_version,
		au.current_version)
	au.free()


# ── 도우미 ─────────────────────────────────────────────────────────────

func _reset(au) -> void:
	var d := DirAccess.open("user://")
	for n in ["patch.pck", "patch.pck.tmp", "update_state.json"]:
		if FileAccess.file_exists("user://" + n):
			d.remove(n)
	au._state = {}
