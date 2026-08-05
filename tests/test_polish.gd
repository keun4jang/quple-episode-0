extends Node
## 힐링 요소: 앰비언트 · 팔레트 · 엽서 · 습관 · 조용한 하루

var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)

func _ready() -> void:
	print("=== 힐링 요소 테스트 ===")

	print("\n[1] 앰비언트 사운드 (코드 합성)")
	for kind in ["wave", "wind", "rain", "space", "room"]:
		var st = AudioManager._build_ambient(kind)
		if st == null:
			ck("%s 생성" % kind, false); continue
		var n: int = st.data.size() / 2
		var peak := 0
		for i in range(0, n, 11):
			var v: int = st.data[i*2] | (st.data[i*2+1] << 8)
			if v > 32767: v -= 65536
			peak = maxi(peak, absi(v))
		ck("%s 소리 있음" % kind, peak > 2000, "peak=%d / %.1f초" % [peak, float(n)/22050.0])
		ck("  %s 루프" % kind, st.loop_mode == AudioStreamWAV.LOOP_FORWARD)

	print("\n[2] 여행지 색조 팔레트")
	var seen := {}
	for id in ["seoul", "france", "kenya", "brazil", "australia", "moon", "rift"]:
		var d := TravelState.get_destination(id)
		if d.is_empty(): continue
		var pal: Dictionary = TravelPalette.for_destination(d)
		ck("%s 팔레트" % id, pal.has("sky_top") and pal.has("accent"))
		seen[str(pal.get("sky_top"))] = true
	ck("여행지마다 색이 다름", seen.size() >= 4, "%d가지 하늘색" % seen.size())
	# 스카프색은 배경에 쓰이지 않아야 한다
	var scarf := Color("#FF6F61")
	var clash := []
	for d in TravelState.DESTINATIONS:
		var pal: Dictionary = TravelPalette.for_destination(d)
		for k in ["sky_top", "sky_bottom", "ground", "accent"]:
			var c: Color = pal.get(k, Color.BLACK)
			if abs(c.r - scarf.r) < 0.06 and abs(c.g - scarf.g) < 0.06 and abs(c.b - scarf.b) < 0.06:
				clash.append("%s.%s" % [d.id, k])
	ck("스카프색이 배경과 안 겹침", clash.is_empty(), "%d건" % clash.size())

	print("\n[3] 엽서 이미지 생성")
	var d2 := TravelState.get_destination("paris")
	var img: Image = PostcardExport.render_souvenir(
		{"dest_id": "paris", "title": "[ 탑 ]", "diary": "좋았다."}, d2)
	ck("엽서 생성", img != null and img.get_width() > 0, "%dx%d" % [img.get_width(), img.get_height()])
	var sm: Image = PostcardExport.render_trip_summary(
		[{"dest_id":"seoul"},{"dest_id":"paris"}], TravelState.CHAPTERS)
	ck("통계 카드 생성", sm != null and sm.get_width() > 0)

	print("\n[4] 함께 배우는 것 (습관)")
	ck("습관 8개", TravelState.TRAVEL_HABITS.size() == 8, "%d개" % TravelState.TRAVEL_HABITS.size())
	SaveManager.clear_save(); TravelState.reset()
	Episode0State.has_camera = true; Episode0State.has_notebook = true; Episode0State.has_travel_bag = true
	ck("처음엔 하나도 안 열림", TravelState.unlocked_habits().is_empty())
	for i in range(4):
		TravelState.start_trip("seoul")
		TravelState.trip["arrive_at"] = int(Time.get_unix_time_from_system()) - 1
		TravelState.collect_arrival()
	ck("4곳 다녀오면 첫 습관", TravelState.unlocked_habits().size() >= 1,
		str(TravelState.unlocked_habits()[0].name) if TravelState.unlocked_habits().size() > 0 else "")
	# 수치 표현이 없는가
	var numeric := []
	for h in TravelState.TRAVEL_HABITS:
		var txt := str(h.name) + str(h.desc) + str(h.effect_hint)
		if txt.contains("%") or txt.contains("+") or txt.contains("증가"):
			numeric.append(h.id)
	ck("수치 표현 없음", numeric.is_empty(), str(numeric))

	print("\n[5] 아무 일 없는 날")
	var quiet_n := 0
	for i in range(200):
		if TravelState._is_quiet_day("seoul", i): quiet_n += 1
	ck("조용한 날 비율 15~30%", quiet_n >= 30 and quiet_n <= 60, "%d/200" % quiet_n)
	var q: Dictionary = TravelState._quiet_souvenir(TravelState.get_destination("seoul"), 0)
	ck("조용한 날 기록", str(q.get("title","")).contains("조용한") and bool(q.get("quiet", false)))

	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	SaveManager.clear_save()
	get_tree().quit(0 if fail_n == 0 else 1)
