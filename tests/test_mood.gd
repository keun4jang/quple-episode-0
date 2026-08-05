extends Node
## 시간대 무드 팔레트 — 순수 로직 테스트.
##
## 씬을 띄우지 않는다. 색은 눈으로 보면 "예쁘다/아니다" 밖에 안 나오니까,
## 규칙으로 못 박을 수 있는 것만 잰다. 키가 빠졌는가, 경계에서 색이 튀는가,
## 스카프색을 배경에 깔았는가, 순검정으로 내려앉았는가.

const Mood := preload("res://scripts/systems/mood_palette.gd")

## 0.25시간(15분) 간격으로 하루를 훑는다
const STEP := 0.25
const SAMPLES := 96

## 15분 사이에 색 채널이 이만큼 넘게 움직이면 "뚝 끊긴다" 로 본다.
## 실제 최대치는 0.10 근처다. 여유를 두되 두 배는 주지 않는다.
const MAX_JUMP := 0.15

var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)


func _ready() -> void:
	print("=== 시간대 무드 팔레트 테스트 ===")

	var keys: Array = Mood.mood_keys()
	print("\n[1] 하루를 훑어도 키가 빠지지 않는가 (%d개 키 × %d회)" % [keys.size(), SAMPLES])
	var missing := ""
	var wrong_type := ""
	var out_of_range := ""
	for i in SAMPLES:
		var h := float(i) * STEP
		var m: Dictionary = Mood.at(h)
		for k in keys:
			if not m.has(k):
				missing = "%.2f시 %s" % [h, k]
				continue
			var v = m[k]
			if k in Mood.COLOR_KEYS:
				if typeof(v) != TYPE_COLOR:
					wrong_type = "%.2f시 %s 는 Color 가 아니다" % [h, k]
				elif not _in_range(v):
					out_of_range = "%.2f시 %s %s" % [h, k, str(v)]
			else:
				if typeof(v) != TYPE_FLOAT:
					wrong_type = "%.2f시 %s 는 float 가 아니다" % [h, k]
				elif not is_finite(v):
					out_of_range = "%.2f시 %s = %s" % [h, k, str(v)]
	ck("모든 시각에 모든 키가 있다", missing == "", missing)
	ck("타입이 맞다 (색은 Color, 나머지는 float)", wrong_type == "", wrong_type)
	ck("색 채널이 0~1 안에 있다", out_of_range == "", out_of_range)

	print("\n[2] 구간 경계에서 색이 튀지 않는가")
	var worst := 0.0
	var worst_at := ""
	for i in SAMPLES:
		var h0 := float(i) * STEP
		var a: Dictionary = Mood.at(h0)
		var b: Dictionary = Mood.at(h0 + STEP)
		for k in Mood.COLOR_KEYS:
			var d := _max_channel_diff(a[k], b[k])
			if d > worst:
				worst = d
				worst_at = "%.2f→%.2f시 %s" % [h0, h0 + STEP, k]
	ck("15분 사이 색 변화가 %.2f 이하" % MAX_JUMP, worst <= MAX_JUMP,
		"최대 %.3f (%s)" % [worst, worst_at])

	# 새벽 구간 한가운데. 여기서 튀면 구간을 잘못 나눈 것이다.
	var edge := _max_diff_of(Mood.at(5.9), Mood.at(6.1))
	ck("5.9시와 6.1시가 이어져 있다", edge < 0.06, "최대 %.3f" % edge)

	# 모든 구간 경계를 앞뒤로 찔러 본다
	var rough := ""
	for h in [4.0, 7.0, 10.5, 14.0, 17.5, 20.5]:
		var d := _max_diff_of(Mood.at(h - 0.1), Mood.at(h + 0.1))
		if d > 0.10:
			rough += "%.1f시(%.3f) " % [h, d]
	ck("경계 ±6분 사이가 매끄럽다", rough == "", rough)

	# 자정을 넘어도 이어져야 한다. 23.9시와 0.1시는 같은 밤이다.
	var midnight := _max_diff_of(Mood.at(23.9), Mood.at(0.1))
	ck("자정을 넘어도 이어진다", midnight < 0.02, "최대 %.3f" % midnight)

	print("\n[3] 스카프색이 배경에 없는가 (산호~주황 고채도)")
	var scarf := ""
	for i in SAMPLES:
		var h := float(i) * STEP
		var m: Dictionary = Mood.at(h)
		for k in Mood.BACKGROUND_KEYS:
			if _is_scarf_zone(m[k]):
				scarf = "%.2f시 %s hue %.3f sat %.2f" % [h, k, m[k].h, m[k].s]
	ck("시간대 무드 배경에 스카프색이 없다", scarf == "", scarf)
	var scarf_fixed := ""
	for fname in Mood.fixed_names():
		var m: Dictionary = Mood.fixed(fname)
		for k in Mood.BACKGROUND_KEYS:
			if _is_scarf_zone(m[k]):
				scarf_fixed = "%s %s hue %.3f sat %.2f" % [fname, k, m[k].h, m[k].s]
	ck("고정 무드 배경에도 없다", scarf_fixed == "", scarf_fixed)
	# 금지 규칙 자체가 살아 있는지 (검사기가 통과만 시키면 의미가 없다)
	ck("검사기가 스카프색을 잡아낸다", _is_scarf_zone(Mood.SCARF_CORAL))

	print("\n[4] 순검정 / 순백이 없는가")
	var black := ""
	var white := ""
	for i in SAMPLES:
		var h := float(i) * STEP
		var m: Dictionary = Mood.at(h)
		for k in Mood.COLOR_KEYS:
			var c: Color = m[k]
			if c.v < 0.05:
				black = "%.2f시 %s %s" % [h, k, str(c)]
			if c.r > 0.98 and c.g > 0.98 and c.b > 0.98:
				white = "%.2f시 %s %s" % [h, k, str(c)]
	ck("순검정으로 내려앉지 않는다", black == "", black)
	ck("순백으로 날아가지 않는다", white == "", white)

	print("\n[5] 고정 무드 — 에피소드 0 의 늦은 밤")
	ck("night_office 가 있다", Mood.has_fixed("night_office"))
	var no: Dictionary = Mood.fixed("night_office")
	var no_missing := ""
	for k in keys:
		if not no.has(k):
			no_missing = k
	ck("키가 다 있다", no_missing == "", no_missing)
	ck("하늘이 어둡다", no["sky_top"].v < 0.5, "v %.2f" % no["sky_top"].v)
	ck("햇빛이 약하다", no["sun_energy"] < 0.7, "%.2f" % no["sun_energy"])
	ck("페이드가 어둡다", no["fade_color"].v < 0.3, "v %.2f" % no["fade_color"].v)
	ck("그래도 순검정은 아니다", no["fade_color"].v > 0.05)
	# 지금 CompanyFront3D 에 들어 있는 값이다. 톤이 바뀌면 화면이 달라진다.
	ck("현재 씬의 하늘색을 지킨다",
		no["sky_top"].is_equal_approx(Color(0.231373, 0.290196, 0.419608)),
		str(no["sky_top"]))
	ck("현재 씬의 환경광을 지킨다",
		no["ambient_color"].is_equal_approx(Color(0.725490, 0.654902, 0.909804)),
		str(no["ambient_color"]))
	# 이름을 틀려도 죽지 않는다 (밤 무드로 떨어진다)
	var fallback: Dictionary = Mood.fixed("없는무드")
	ck("모르는 이름이면 밤으로 떨어진다", fallback.size() == keys.size())

	print("\n[6] blend — 두 무드 사이 보간")
	var a: Dictionary = Mood.at(12.0)
	var b: Dictionary = Mood.at(0.0)
	ck("blend(a, b, 0) == a", _same(Mood.blend(a, b, 0.0), a))
	ck("blend(a, b, 1) == b", _same(Mood.blend(a, b, 1.0), b))
	var half: Dictionary = Mood.blend(a, b, 0.5)
	ck("blend(a, b, 0.5) 는 가운데",
		half["sky_top"].is_equal_approx(a["sky_top"].lerp(b["sky_top"], 0.5)))
	ck("blend 가 숫자도 섞는다",
		absf(half["fog_density"] - (a["fog_density"] + b["fog_density"]) * 0.5) < 0.0001)
	ck("blend 결과에도 키가 다 있다", half.size() == keys.size())
	ck("t 가 범위를 벗어나도 안전하다", _same(Mood.blend(a, b, -3.0), a) and _same(Mood.blend(a, b, 9.0), b))

	print("\n[7] 구간 이름")
	var names: Array = Mood.band_names()
	ck("구간이 6개 이상", names.size() >= 6, str(names))
	for want in ["dawn", "morning", "noon", "afternoon", "dusk", "night"]:
		ck("  %s 가 있다" % want, names.has(want))
	ck("새벽 5시는 dawn", Mood.name_at(5.0) == "dawn", Mood.name_at(5.0))
	ck("정오는 noon", Mood.name_at(12.0) == "noon", Mood.name_at(12.0))
	ck("밤 23시는 night", Mood.name_at(23.0) == "night", Mood.name_at(23.0))
	ck("새벽 2시도 night", Mood.name_at(2.0) == "night", Mood.name_at(2.0))
	ck("한국어 이름이 나온다", Mood.label_at(12.0) == "한낮", Mood.label_at(12.0))
	# 하루를 훑으면 여섯 구간이 전부 나와야 한다. 하나라도 안 나오면 구간이 죽어 있다.
	var seen := {}
	for i in SAMPLES:
		seen[Mood.name_at(float(i) * STEP)] = true
	ck("하루 안에 모든 구간이 나온다", seen.size() == names.size(), str(seen.keys()))
	# 25.5시 → 1.5시. 시각이 24를 넘어와도 죽지 않는다.
	ck("24를 넘는 시각을 접는다", Mood.name_at(25.5) == Mood.name_at(1.5))
	ck("음수 시각도 접는다", Mood.name_at(-2.0) == Mood.name_at(22.0))

	print("\n[8] 17시 30분은 오후와 노을 사이")
	var m1730: Dictionary = Mood.at(17.5)
	var aft: Dictionary = Mood.at(15.5)
	var dsk: Dictionary = Mood.at(19.0)
	var to_aft := _max_diff_of(m1730, aft)
	var to_dsk := _max_diff_of(m1730, dsk)
	ck("오후 그대로가 아니다", to_aft > 0.02, "차이 %.3f" % to_aft)
	ck("노을 그대로도 아니다", to_dsk > 0.02, "차이 %.3f" % to_dsk)

	print("\n[9] 상수 오염 방지")
	var m1: Dictionary = Mood.at(12.0)
	m1["sky_top"] = Color(1, 0, 1)
	var m2: Dictionary = Mood.at(12.0)
	ck("돌려받은 무드를 고쳐도 원본이 안 변한다", not m2["sky_top"].is_equal_approx(Color(1, 0, 1)))

	print("\n[10] now_hours")
	var nh: float = Mood.now_hours()
	ck("현재 시각이 0~24 안", nh >= 0.0 and nh < 24.0, "%.2f시" % nh)
	ck("지금 무드에도 키가 다 있다", Mood.now().size() == keys.size())

	_done()


func _done() -> void:
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(0 if fail_n == 0 else 1)


func _in_range(c: Color) -> bool:
	for v in [c.r, c.g, c.b]:
		if v < 0.0 or v > 1.0:
			return false
	return true


func _max_channel_diff(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _max_diff_of(a: Dictionary, b: Dictionary) -> float:
	var d := 0.0
	for k in Mood.COLOR_KEYS:
		d = maxf(d, _max_channel_diff(a[k], b[k]))
	return d


## 쿼카 스카프(산호 #FF6F61) 근처인가. 배경에 이 색이 있으면 캐릭터가 묻힌다.
func _is_scarf_zone(c: Color) -> bool:
	if c.s < 0.5:
		return false
	return c.h >= 0.99 or c.h <= 0.06


func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k):
			return false
		if typeof(a[k]) == TYPE_COLOR:
			if not (a[k] as Color).is_equal_approx(b[k]):
				return false
		elif absf(float(a[k]) - float(b[k])) > 0.000001:
			return false
	return true
