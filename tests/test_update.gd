extends Node
## 업데이트 확인 버튼이 실제로 답을 돌려주는가.
##
## 이 기능의 값어치는 "새 버전을 받는다" 가 아니라 **"지금 어떤 상태인지
## 알려 준다"** 는 데 있다. 그래서 최신일 때·새 버전이 있을 때·인터넷이
## 안 될 때 셋 다 무언가 말해 주는지를 본다. 아무 말 없는 버튼이 제일 나쁘다.

var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)

func _ready() -> void:
	print("=== 업데이트 확인 테스트 ===")

	print("\n[1] 버전 비교")
	ck("0.2.0 > 0.1.9", AutoUpdate.is_newer("0.2.0", "0.1.9"))
	ck("0.1.10 > 0.1.9", AutoUpdate.is_newer("0.1.10", "0.1.9"))
	ck("0.1.9 는 0.1.9 보다 새롭지 않다", not AutoUpdate.is_newer("0.1.9", "0.1.9"))
	ck("0.1.8 은 0.1.9 보다 새롭지 않다", not AutoUpdate.is_newer("0.1.8", "0.1.9"))
	ck("자리수가 달라도 된다", AutoUpdate.is_newer("1.0", "0.9.9"))

	print("\n[2] 지금 버전")
	ck("버전이 비어 있지 않다", AutoUpdate.current_version != "",
		"v" + AutoUpdate.current_version)
	ck("project.godot 과 이어져 있다", AutoUpdate.baked_version != "0.0.0",
		"baked=" + AutoUpdate.baked_version)

	print("\n[3] 서버 응답을 어떻게 읽는가")
	# 진짜 서버를 부르면 시험이 인터넷 사정에 흔들리고 느리다.
	# 서버가 돌려줄 법한 답을 직접 넣어 보고, 각각에 무엇이라 답하는지만 본다.
	var got := {"kind": "", "arg": ""}
	AutoUpdate.up_to_date.connect(func(v): got.kind = "최신"; got.arg = v)
	AutoUpdate.update_ready.connect(func(v): got.kind = "새버전"; got.arg = v)
	AutoUpdate.update_failed.connect(func(r): got.kind = "실패"; got.arg = r)

	var cur := AutoUpdate.current_version

	got.kind = ""
	AutoUpdate.checking = true
	AutoUpdate._on_manifest(0, 200, PackedStringArray(),
		JSON.stringify({"version": cur, "url": "https://x/y.pck"}).to_utf8_buffer())
	ck("같은 버전이면 최신이라 답한다", got.kind == "최신",
		"받은 답=%s %s" % [got.kind, got.arg])
	ck("답한 버전이 지금 버전이다", got.arg == cur, got.arg)
	ck("확인이 끝났다", not AutoUpdate.checking)

	got.kind = ""
	AutoUpdate.checking = true
	AutoUpdate._on_manifest(0, 200, PackedStringArray(),
		JSON.stringify({"version": "0.0.1", "url": "https://x/y.pck"}).to_utf8_buffer())
	ck("낡은 버전이면 받으려 하지 않는다", got.kind == "최신",
		"받은 답=%s" % got.kind)

	print("\n[4] 잘못된 답에도 조용히 넘어가지 않는가")
	for c in [{"code": 404, "body": "", "why": "없는 주소"},
			{"code": 500, "body": "", "why": "서버 오류"},
			{"code": 200, "body": "이건 JSON 이 아니다", "why": "깨진 응답"},
			{"code": 200, "body": "{}", "why": "빈 응답"}]:
		got.kind = ""
		AutoUpdate.checking = true
		AutoUpdate._on_manifest(0, int(c["code"]), PackedStringArray(),
			str(c["body"]).to_utf8_buffer())
		ck("%s → 실패를 알려 준다" % c["why"], got.kind == "실패",
			"받은 답=%s %s" % [got.kind, got.arg])
		ck("  이유가 사람 말이다", got.arg.length() > 4 and not got.arg.contains("null"),
			got.arg)
		ck("  확인이 끝났다", not AutoUpdate.checking)

	print("\n[4-1] 두 번 눌러도 한 번만 돈다")
	AutoUpdate.checking = true
	ck("확인 중에는 안 받는다", not AutoUpdate.check_now())
	AutoUpdate.checking = false

	print("\n[4-2] 일찍 꺼져도 팩을 바로 버리지 않는가")
	# "껐다 켜면 적용" 안내대로 빨리 껐다 켜기를 반복하면, 부팅 확인
	# 시간을 매번 못 채워서 팩이 계속 되돌려지는 고리에 갇혔었다.
	AutoUpdate._state = {"boot_pending": true, "pck_version": "9.9.9"}
	var fails := 0
	for i in range(2):
		var st: Dictionary = AutoUpdate._state
		if st.get("boot_pending", false):
			fails = int(st.get("boot_fail_count", 0)) + 1
			if fails >= 3:
				break
			st["boot_fail_count"] = fails
	ck("두 번 일찍 꺼져도 팩이 남아 있다", AutoUpdate._state.has("pck_version"),
		"fail_count=%d" % fails)
	ck("실패 횟수를 세고 있다", int(AutoUpdate._state.get("boot_fail_count", 0)) == 2)
	AutoUpdate._state = AutoUpdate._read_state()

	print("\n[5] 설정창에 버튼이 있는가")
	var ui: Node = load("res://scenes/ui/SettingsUI.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	var btn := _find(ui, "UpdateBtn")
	ck("업데이트 확인 버튼이 있다", btn != null)
	if btn != null:
		ck("눌릴 수 있다", not (btn as Button).disabled)
		ck("글자가 맞다", (btn as Button).text == "업데이트 확인", (btn as Button).text)
	var box := _find(ui, "UpdateBox")
	ck("버전 표시가 있다", box != null and box.get_child_count() >= 3)
	if box != null:
		var lbl := box.get_child(0) as Label
		ck("지금 버전을 보여 준다", lbl != null and lbl.text.contains(AutoUpdate.current_version),
			lbl.text if lbl else "")
	ck("설정창이 화면 안에 들어온다", _fits(ui))

	_done()


## 화면 밖으로 넘치지 않는가. 넘치면 "닫기" 를 못 눌러 갇힌다.
func _fits(ui: Node) -> bool:
	var p := ui.get_node_or_null("Root/Panel") as Control
	if p == null:
		return false
	var vp := get_viewport().get_visible_rect().size
	return p.size.y <= vp.y + 1.0


func _find(n: Node, nm: String) -> Node:
	if n.name == nm:
		return n
	for c in n.get_children():
		var r := _find(c, nm)
		if r != null:
			return r
	return null


func _done() -> void:
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
