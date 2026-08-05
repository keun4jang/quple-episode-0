extends Node
var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)

func _s16(d: PackedByteArray, i: int) -> int:
	var v: int = d[i * 2] | (d[i * 2 + 1] << 8)
	return v - 65536 if v > 32767 else v

func _ready() -> void:
	print("=== 배경음악 합성 테스트 ===")
	for track in ["menu", "episode0", "travel", "room"]:
		var t0 := Time.get_ticks_msec()
		var st: AudioStreamWAV = AudioManager._build_bgm(track)
		var ms := Time.get_ticks_msec() - t0
		if st == null:
			ck("%s 생성" % track, false); continue
		var n := st.data.size() / 2
		var dur := float(n) / float(AudioManager.BGM_RATE)
		ck("%s 생성" % track, n > 0, "%.1f초 / %.1fMB / %dms" % [dur, st.data.size() / 1048576.0, ms])
		ck("  루프 설정", st.loop_mode == AudioStreamWAV.LOOP_FORWARD and st.loop_end == n)

		# 소리 크기
		var peak := 0
		var sum_abs := 0
		for i in range(0, n, 7):
			var a: int = absi(_s16(st.data, i))
			peak = maxi(peak, a); sum_abs += a
		var avg := float(sum_abs) / float(n / 7)
		ck("  소리 있음", peak > 3000 and avg > 300, "peak=%d avg=%.0f" % [peak, avg])
		ck("  과포화 아님", peak < 32700, "peak=%d" % peak)

		# 이음매: 끝 샘플과 시작 샘플이 이어지는가 (루프 클릭 방지)
		var head := _s16(st.data, 0)
		var tail := _s16(st.data, n - 1)
		var gap: int = absi(tail - head)
		ck("  루프 이음매 매끄러움", gap < 2500, "|끝-시작| = %d" % gap)

		# 무음 구간이 지나치게 길지 않은가
		var silent_run := 0
		var max_silent := 0
		for i in range(0, n, 40):
			if absi(_s16(st.data, i)) < 150:
				silent_run += 1; max_silent = maxi(max_silent, silent_run)
			else:
				silent_run = 0
		var silent_sec := float(max_silent * 40) / float(AudioManager.BGM_RATE)
		ck("  긴 무음 없음", silent_sec < 1.5, "최장 %.2f초" % silent_sec)

	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(0 if fail_n == 0 else 1)
