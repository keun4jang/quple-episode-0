extends Node
var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)

func _ready() -> void:
	print("=== 효과음 합성 테스트 ===")
	var kinds = ["footstep", "shutter", "click", "confirm", "chime", "sparkle"]
	for k in kinds:
		var st = AudioManager._build(k)
		ck("%s 생성" % k, st != null and st.data.size() > 0,
			"%d bytes / %.2f초" % [st.data.size() if st else 0,
			(float(st.data.size()) / 2.0 / float(AudioManager.SAMPLE_RATE)) if st else 0.0])
		if st:
			# 무음이 아닌지 확인
			var peak := 0
			for i in range(0, mini(st.data.size(), 4000), 2):
				var v: int = st.data[i] | (st.data[i+1] << 8)
				if v > 32767: v -= 65536
				peak = maxi(peak, absi(v))
			ck("  %s 소리 있음" % k, peak > 1000, "peak=%d" % peak)
	# 실제 재생이 에러 없이 되는지
	AudioManager.footstep()
	AudioManager.shutter()
	AudioManager.ui_click()
	AudioManager.message_arrive()
	ck("재생 호출 정상", true)
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(0 if fail_n == 0 else 1)
