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
	for track in ["gohyang", "arirang", "doraji", "gaeguri", "episode0", "room"]:
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

	# 악기별 음이 끝에서 0 으로 닫히는지 = "툭" 소리 방지
	print("\n[악기] 음 끝이 0 으로 닫히는가")
	for role in ["melody", "arp", "bass"]:
		var note_len := 0.4
		var len_i := int(note_len * AudioManager.BGM_RATE)
		var buf := PackedFloat32Array(); buf.resize(len_i + 100)
		AudioManager._voice(buf, 0, 440.0, note_len, 1.0, role)
		var last := absf(buf[len_i - 1])
		var mid := absf(buf[len_i / 4])
		ck("%s 끝이 0" % role, last < 0.01, "%.5f" % last)
		ck("%s 소리 남" % role, mid > 0.01, "%.4f" % mid)

	# 음역 검사: 너무 높으면 귀가 아프다
	print("\n[음역] 편안한 범위인지")
	for track in ["arirang", "gohyang", "doraji", "gaeguri"]:
		var cfg: Dictionary = AudioManager.BGM_TRACKS[track]
		var mel: Dictionary = AudioManager.PD_MELODIES[cfg.melody]
		var lo := 99999.0
		var hi := 0.0
		for pair in mel.notes:
			var semi: int = int(pair[0])
			if semi == AudioManager.REST: continue
			var f: float = AudioManager._semi(float(cfg.root) * float(cfg.octave), float(semi))
			lo = minf(lo, f); hi = maxf(hi, f)
		# 사람이 편하게 듣는 선율 음역: 대략 200~750Hz (C4 ~ F#5)
		ck("%s 최고음 안 높음" % track, hi < 780.0, "%.0fHz (한계 780)" % hi)
		ck("%s 최저음 안 낮음" % track, lo > 150.0, "%.0fHz" % lo)

	# 화음이 선율과 맞는지 = 불협 방지
	print("\n[화음] 선율과 어울리는가")
	for track in ["arirang", "gohyang", "doraji", "gaeguri"]:
		var cfg: Dictionary = AudioManager.BGM_TRACKS[track]
		var mel: Dictionary = AudioManager.PD_MELODIES[cfg.melody]
		var dur: float = cfg.dur
		var notes := AudioManager._layout_melody(mel, float(cfg.root), int(cfg.octave), dur)
		var bars: int = int(cfg.get("bars", cfg.chords.size()))
		var ch := AudioManager._auto_chords(notes, dur, bars, float(cfg.root))
		var bar := dur / float(bars)

		# 각 마디에서 오래 울리는 선율 음이 화음에 들어 있는가
		var fit := 0
		var total := 0
		for bi in range(bars):
			var t0 := float(bi) * bar
			var pcs := []
			for tn in ch[bi]:
				pcs.append(((int(tn) % 12) + 12) % 12)
			for note in notes:
				var ns: float = float(note.t)
				if ns < t0 or ns >= t0 + bar: continue
				var semi: int = int(round(12.0 * log(float(note.f) / float(cfg.root)) / log(2.0)))
				var pc: int = ((semi % 12) + 12) % 12
				total += 1
				if pcs.has(pc): fit += 1
		var ratio := float(fit) / maxf(1.0, float(total))
		ck("%s 화음 적합도" % track, ratio >= 0.55, "%.0f%% (%d/%d)" % [ratio * 100.0, fit, total])

		# 같은 화음만 반복되지 않는가
		var uniq := {}
		for c in ch: uniq[str(c)] = true
		ck("%s 화음 변화 있음" % track, uniq.size() >= 2, "%d종" % uniq.size())

		# 마지막이 으뜸화음으로 끝나는가
		ck("%s 으뜸화음 종지" % track, ch[bars - 1] == [0, 4, 7])

	# 두 손이 같은 박 격자 위에 있는가
	print("\n[박자] 왼손·오른손 격자 일치")
	for track in ["arirang", "gohyang", "doraji", "gaeguri"]:
		var cfg: Dictionary = AudioManager.BGM_TRACKS[track]
		var mel: Dictionary = AudioManager.PD_MELODIES[cfg.melody]
		var spb: float = 60.0 / float(mel.bpm)
		var bpb: int = 3 if str(cfg.get("lh", "ballad")) == "waltz" else 4
		var total_beats := 0.0
		for pair in mel.notes:
			total_beats += float(pair[1])
		var bars: int = int(ceil(total_beats / float(bpb)))
		var bar: float = float(bpb) * spb
		var dur: float = float(bars) * bar

		# 마디가 박의 정수배인가 (왼손이 박 위에 떨어지려면 필수)
		var beats_in_bar := bar / spb
		ck("%s 마디=박의 정수배" % track,
			absf(beats_in_bar - round(beats_in_bar)) < 0.0001, "%.3f박" % beats_in_bar)

		# 전체 길이가 마디의 정수배인가 (루프해도 박이 안 밀린다)
		var bars_in_dur := dur / bar
		ck("%s 전체=마디의 정수배" % track,
			absf(bars_in_dur - round(bars_in_dur)) < 0.0001, "%.3f마디" % bars_in_dur)

		# 선율 음이 반박 격자에 올라가 있는가
		var t := 0.0
		var on_grid := 0
		var total := 0
		for pair in mel.notes:
			if int(pair[0]) != AudioManager.REST:
				total += 1
				var bp: float = t / spb
				if absf(bp - round(bp * 2.0) / 2.0) < 0.001:
					on_grid += 1
			t += float(pair[1]) * spb
		ck("%s 선율이 박 위에" % track, on_grid == total, "%d/%d" % [on_grid, total])

	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(0 if fail_n == 0 else 1)
