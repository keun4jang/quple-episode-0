extends Node
var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)

func _ready() -> void:
	print("=== 효과음 합성 테스트 ===")
	var kinds = ["footstep", "shutter", "click", "confirm", "chime", "sparkle",
		"door_open", "door_close", "pickup", "sit_rustle", "wind_gust",
		"page_turn", "water_drop", "water_ripple"]
	for k in kinds:
		var st = AudioManager._build(k)
		ck("%s 생성" % k, st != null and st.data.size() > 0,
			"%d bytes / %.2f초" % [st.data.size() if st else 0,
			(float(st.data.size()) / 2.0 / float(AudioManager.SAMPLE_RATE)) if st else 0.0])
		if st:
			# 무음이 아닌지 확인
			# 앞부분만 보면 안 된다 — 바람처럼 서서히 부푸는 소리는 첫 0.1초가 거의 무음이다
			var peak := 0
			for i in range(0, st.data.size(), 2):
				var v: int = st.data[i] | (st.data[i+1] << 8)
				if v > 32767: v -= 65536
				peak = maxi(peak, absi(v))
			ck("  %s 소리 있음" % k, peak > 1000, "peak=%d" % peak)
	# 파형 품질 — 클리핑 / 시작·끝 툭 소리 / 길이
	# 최댓값이 32000(=0.977) 에 닿으면 클램프에 걸려 찌그러진 것이다.
	for k in kinds:
		var st = AudioManager._build(k)
		if st == null:
			continue
		var d: PackedByteArray = st.data
		var n: int = d.size() / 2
		var peak := 0
		var head := 0
		var tail := 0
		for i in range(n):
			var v: int = d[i * 2] | (d[i * 2 + 1] << 8)
			if v > 32767: v -= 65536
			var a := absi(v)
			peak = maxi(peak, a)
			if i < 8: head = maxi(head, a)
			if i >= n - 8: tail = maxi(tail, a)
		ck("  %s 클리핑 없음" % k, peak < 31800, "peak=%d" % peak)
		# 앞뒤 64샘플 페이드가 걸려 있으므로 양끝은 거의 0 이어야 한다
		ck("  %s 시작 무음" % k, head < 3000, "head=%d" % head)
		ck("  %s 끝 무음" % k, tail < 3000, "tail=%d" % tail)
		var sec := float(n) / float(AudioManager.SAMPLE_RATE)
		ck("  %s 길이 적정" % k, sec > 0.03 and sec < 2.5, "%.2f초" % sec)

	# 실제 재생이 에러 없이 되는지
	AudioManager.footstep()
	AudioManager.shutter()
	AudioManager.ui_click()
	AudioManager.message_arrive()
	AudioManager.door_open()
	AudioManager.door_close()
	AudioManager.pickup()
	AudioManager.sit_rustle()
	AudioManager.wind_gust()
	AudioManager.page_turn()
	AudioManager.water_drop()
	AudioManager.water_ripple()
	ck("재생 호출 정상", true)
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(0 if fail_n == 0 else 1)
