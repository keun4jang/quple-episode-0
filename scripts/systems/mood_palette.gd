extends RefCounted

# 시간대별 화면 무드(색 세트)를 한 곳에서 정의한다.
#
# 이 게임의 코어 루프는 실제 시각(unix time) 기준이다. 앱을 껐다 켜면 시간이
# 흘러 있고, 쿼카 커플은 그 사이에 여행을 다녀온다. 그렇다면 "지금 몇 시인가"
# 가 화면 색으로 보여야 앞뒤가 맞는다. 아침에 켜면 아침빛, 밤에 켜면 달빛.
#
# 이 파일은 값만 만든다. Environment·DirectionalLight·셰이더에 실제로 바르는 일은
# 쓰는 쪽이 한다. 그래야 씬 없이 순수 로직만 테스트할 수 있다.
#
# [쓰는 법] class_name 을 쓰지 않는다. 전역 클래스 이름은 에디터 스캔에서만
# 갱신되는 캐시에 의존해서, 새로 클론한 환경에서 통째로 죽는다. preload 로 쓴다.
#
#   const MoodPalette := preload("res://scripts/systems/mood_palette.gd")
#   var m := MoodPalette.at(MoodPalette.now_hours())
#
# [중요] 쿼카의 스카프색(산호 #FF6F61 계열)은 어떤 무드에도 넣지 않는다.
# 배경에 같은 색이 있으면 캐릭터가 배경에 묻힌다. scripts/travel/palette.gd 에
# 적힌 금지를 그대로 따른다. 대략 hue 0.99~0.06 & 채도 0.5 이상은 피할 것.
# 그래서 노을도 주황이 아니라 분홍~보라로 간다.
#
# [색 원칙] 한 시간대는 지배 색조 하나로 정리한다. 하늘·안개·환경광·반구조명이
# 제각각 놀면 화면이 탁해진다. 채도 높은 원색과 순검정은 쓰지 않는다.

# 스카프 색 (참고용, 배경 금지 표시)
const SCARF_CORAL := Color("#FF6F61")

# 한 무드가 담는 값. 전부 이 키를 빠짐없이 채운다.
# 비어 있는 키가 있으면 쓰는 쪽에서 "이 씬만 안개가 없네" 같은 사고가 난다.
const COLOR_KEYS := [
	"sky_top", "sky_horizon", "ground_horizon", "ground_bottom",  # 하늘(ProceduralSkyMaterial)
	"sun_color",                                                  # 해/달
	"ambient_color",                                              # 환경광
	"fog_color",                                                  # 안개
	"hemi_sky_tint", "hemi_ground_tint",                          # depth_shading 셰이더의 sky_tint / ground_tint
	"fade_color",                                                 # scene_transition 페이드 색
]

const FLOAT_KEYS := [
	"sun_energy", "sun_angle_deg",
	"ambient_energy",
	"fog_density",
	"exposure", "saturation", "contrast",                         # cinematic_look 의 톤매핑·색보정
]

# 스카프 금지 구역 검사 대상. 배경에 깔리는 색만 본다.
# sun_color 는 빛이지 배경이 아니지만, 여기 정의된 값은 전부 채도를 낮게 잡아 뒀다.
const BACKGROUND_KEYS := [
	"sky_top", "sky_horizon", "ground_horizon", "ground_bottom",
	"ambient_color", "fog_color",
	"hemi_sky_tint", "hemi_ground_tint",
	"fade_color",
]

# 구간 경계에서 색이 뚝 끊기지 않도록 섞는 폭(시간).
# 경계 앞뒤로 이만큼씩, 총 2배 구간에 걸쳐 부드럽게 넘어간다.
# 어떤 구간도 이 값의 2배보다 짧으면 안 된다. 짧으면 양쪽 섞임 구간이 겹친다.
const BLEND_HOURS := 1.25

# 시간 구간. 반드시 시간 순서대로 두고, 마지막(밤)만 자정을 넘어 감긴다.
# end 는 다음 구간의 start 와 같아야 한다. 사이가 비면 그 시각에 무드가 없다.
const BANDS := [
	{"id": "dawn",      "label": "새벽", "start": 4.0,  "end": 7.0},
	{"id": "morning",   "label": "아침", "start": 7.0,  "end": 10.5},
	{"id": "noon",      "label": "한낮", "start": 10.5, "end": 14.0},
	{"id": "afternoon", "label": "오후", "start": 14.0, "end": 17.5},
	{"id": "dusk",      "label": "노을", "start": 17.5, "end": 20.5},
	{"id": "night",     "label": "밤",   "start": 20.5, "end": 4.0},
]

# 시간대 무드. 구간의 "한가운데" 색이고, 경계 근처에서는 이웃과 섞인다.
const MOODS := {
	# 새벽 — 해 뜨기 전 푸르스름한 보라. 아직 잠긴 공기.
	"dawn": {
		"sky_top": Color(0.22, 0.21, 0.40),
		"sky_horizon": Color(0.62, 0.56, 0.76),
		"ground_horizon": Color(0.72, 0.66, 0.80),
		"ground_bottom": Color(0.20, 0.20, 0.32),
		"sun_color": Color(0.86, 0.82, 0.98),
		"sun_energy": 0.45,
		"sun_angle_deg": -12.0,
		"ambient_color": Color(0.56, 0.54, 0.76),
		"ambient_energy": 0.72,
		"fog_color": Color(0.66, 0.62, 0.82),
		"fog_density": 0.0100,
		"hemi_sky_tint": Color(0.60, 0.62, 0.90),
		"hemi_ground_tint": Color(0.46, 0.42, 0.58),
		"exposure": 1.00,
		"saturation": 1.10,
		"contrast": 1.12,
		"fade_color": Color(0.52, 0.48, 0.70),
	},
	# 아침 — 맑은 하늘. 하루가 열리는 파랑.
	"morning": {
		"sky_top": Color(0.40, 0.62, 0.86),
		"sky_horizon": Color(0.80, 0.90, 0.95),
		"ground_horizon": Color(0.84, 0.90, 0.92),
		"ground_bottom": Color(0.46, 0.56, 0.60),
		"sun_color": Color(1.00, 0.97, 0.90),
		"sun_energy": 0.85,
		"sun_angle_deg": -32.0,
		"ambient_color": Color(0.72, 0.82, 0.92),
		"ambient_energy": 0.95,
		"fog_color": Color(0.80, 0.88, 0.94),
		"fog_density": 0.0055,
		"hemi_sky_tint": Color(0.66, 0.80, 0.96),
		"hemi_ground_tint": Color(0.56, 0.56, 0.54),
		"exposure": 1.04,
		"saturation": 1.12,
		"contrast": 1.10,
		"fade_color": Color(0.86, 0.92, 0.96),
	},
	# 한낮 — 밝게, 대신 채도는 낮게. 여기서 색을 세우면 눈이 아프다.
	"noon": {
		"sky_top": Color(0.48, 0.68, 0.88),
		"sky_horizon": Color(0.88, 0.93, 0.96),
		"ground_horizon": Color(0.90, 0.92, 0.90),
		"ground_bottom": Color(0.56, 0.62, 0.62),
		"sun_color": Color(1.00, 0.99, 0.95),
		"sun_energy": 1.05,
		"sun_angle_deg": -58.0,
		"ambient_color": Color(0.84, 0.88, 0.94),
		"ambient_energy": 1.05,
		"fog_color": Color(0.88, 0.92, 0.95),
		"fog_density": 0.0042,
		"hemi_sky_tint": Color(0.76, 0.86, 0.98),
		"hemi_ground_tint": Color(0.62, 0.62, 0.58),
		"exposure": 1.02,
		"saturation": 1.06,
		"contrast": 1.06,
		"fade_color": Color(0.93, 0.95, 0.96),
	},
	# 오후 — 따뜻하게. 다만 주황이 아니라 꿀빛(노랑)으로 기운다. 산호색과 겹치면 안 된다.
	"afternoon": {
		"sky_top": Color(0.44, 0.60, 0.82),
		"sky_horizon": Color(0.92, 0.88, 0.74),
		"ground_horizon": Color(0.90, 0.84, 0.68),
		"ground_bottom": Color(0.52, 0.50, 0.42),
		"sun_color": Color(1.00, 0.94, 0.78),
		"sun_energy": 0.95,
		"sun_angle_deg": -38.0,
		"ambient_color": Color(0.88, 0.84, 0.76),
		"ambient_energy": 0.95,
		"fog_color": Color(0.90, 0.86, 0.76),
		"fog_density": 0.0058,
		"hemi_sky_tint": Color(0.78, 0.82, 0.92),
		"hemi_ground_tint": Color(0.66, 0.58, 0.48),
		"exposure": 1.05,
		"saturation": 1.12,
		"contrast": 1.10,
		"fade_color": Color(0.92, 0.86, 0.74),
	},
	# 노을 — 분홍~보라. 주황을 과하게 쓰면 스카프색과 부딪혀 쿼카가 묻힌다.
	"dusk": {
		"sky_top": Color(0.30, 0.26, 0.52),
		"sky_horizon": Color(0.88, 0.68, 0.78),
		"ground_horizon": Color(0.82, 0.62, 0.74),
		"ground_bottom": Color(0.28, 0.24, 0.40),
		"sun_color": Color(1.00, 0.84, 0.92),
		"sun_energy": 0.60,
		"sun_angle_deg": -10.0,
		"ambient_color": Color(0.74, 0.62, 0.82),
		"ambient_energy": 0.85,
		"fog_color": Color(0.82, 0.68, 0.82),
		"fog_density": 0.0085,
		"hemi_sky_tint": Color(0.72, 0.62, 0.88),
		"hemi_ground_tint": Color(0.58, 0.44, 0.56),
		"exposure": 1.05,
		"saturation": 1.16,
		"contrast": 1.14,
		"fade_color": Color(0.62, 0.44, 0.62),
	},
	# 밤 — 짙은 남색에 달빛. 검정으로 내리지 않는다. 검정은 화면을 죽인다.
	"night": {
		"sky_top": Color(0.10, 0.12, 0.24),
		"sky_horizon": Color(0.26, 0.30, 0.46),
		"ground_horizon": Color(0.24, 0.28, 0.42),
		"ground_bottom": Color(0.08, 0.10, 0.18),
		"sun_color": Color(0.72, 0.78, 1.00),
		"sun_energy": 0.30,
		"sun_angle_deg": -62.0,
		"ambient_color": Color(0.34, 0.38, 0.58),
		"ambient_energy": 0.55,
		"fog_color": Color(0.22, 0.26, 0.42),
		"fog_density": 0.0125,
		"hemi_sky_tint": Color(0.40, 0.48, 0.78),
		"hemi_ground_tint": Color(0.24, 0.24, 0.36),
		"exposure": 1.10,
		"saturation": 1.10,
		"contrast": 1.16,
		"fade_color": Color(0.08, 0.09, 0.16),
	},
}

# 시간과 무관하게 고정으로 쓰는 무드.
#
# 에피소드 0 의 네 씬(CompanyFront3D / CompanyLobby3D / Office3D / BossDoorHallway3D)은
# "늦은 밤 야근" 으로 각본이 짜여 있다. 여기서 아침이 되면 이야기가 깨진다.
# 값은 지금 씬에 들어 있는 것을 그대로 옮겼다. 지금 화면이 예쁘다는 평가를
# 받고 있으니 톤을 바꾸지 않는다.
const FIXED_MOODS := {
	# CompanyFront3D 의 현재 값 (하늘·해·환경광·안개) + cinematic_look 의 색보정
	"night_office": {
		"sky_top": Color(0.231373, 0.290196, 0.419608),
		"sky_horizon": Color(0.725490, 0.709804, 0.552941),
		"ground_horizon": Color(0.964706, 0.709804, 0.552941),
		"ground_bottom": Color(0.176471, 0.223529, 0.313726),
		"sun_color": Color(0.964706, 0.709804, 0.552941),
		"sun_energy": 0.55,
		"sun_angle_deg": -45.0,
		"ambient_color": Color(0.725490, 0.654902, 0.909804),
		"ambient_energy": 0.85,
		"fog_color": Color(0.725490, 0.654902, 0.909804),
		"fog_density": 0.0060,
		"hemi_sky_tint": Color(0.62, 0.70, 0.92),
		"hemi_ground_tint": Color(0.58, 0.48, 0.56),
		"exposure": 1.05,
		"saturation": 1.24,
		"contrast": 1.14,
		"fade_color": Color(0.10, 0.10, 0.18),
	},
	# 같은 밤이지만 실내(로비·사무실·복도). 창밖이 없어 하늘이 배경색으로만 보인다.
	# CompanyLobby3D / Office3D / BossDoorHallway3D 의 배경·환경광 값에서 가져왔다.
	"night_office_indoor": {
		"sky_top": Color(0.058824, 0.074510, 0.113725),
		"sky_horizon": Color(0.098039, 0.113725, 0.160784),
		"ground_horizon": Color(0.082353, 0.094118, 0.129412),
		"ground_bottom": Color(0.054902, 0.062745, 0.090196),
		"sun_color": Color(1.000000, 0.945098, 0.847059),
		"sun_energy": 0.40,
		"sun_angle_deg": -70.0,
		"ambient_color": Color(0.725490, 0.654902, 0.909804),
		"ambient_energy": 0.55,
		"fog_color": Color(0.130000, 0.140000, 0.210000),
		"fog_density": 0.0045,
		"hemi_sky_tint": Color(0.62, 0.70, 0.92),
		"hemi_ground_tint": Color(0.58, 0.48, 0.56),
		"exposure": 1.05,
		"saturation": 1.24,
		"contrast": 1.14,
		"fade_color": Color(0.06, 0.07, 0.11),
	},
}


# ── 공개 API ────────────────────────────────────────────────────────────
# 전부 static 이다. 인스턴스를 만들지 않고 preload 한 상수로 바로 부른다.

## 지금 몇 시인가. 0.0 ~ 24.0 (예: 오후 6시 30분 → 18.5)
## 기기의 로컬 시각을 쓴다. 플레이어가 창밖을 보고 느끼는 시간과 맞아야 하기 때문.
static func now_hours() -> float:
	var d := Time.get_datetime_dict_from_system()
	return wrap_hours(float(d["hour"]) + float(d["minute"]) / 60.0 + float(d["second"]) / 3600.0)


## unix time 을 0~24 시각으로. 저장된 시각(여행 출발/도착)의 무드를 뽑을 때 쓴다.
## 로컬 시간대 보정을 넣는다. 보정 없이 쓰면 한국에서 9시간 어긋난다.
static func hours_from_unix(unix_time: int) -> float:
	var tz := Time.get_time_zone_from_system()
	var bias_min := int(tz.get("bias", 0))          # 분 단위
	var d := Time.get_datetime_dict_from_unix_time(unix_time + bias_min * 60)
	return wrap_hours(float(d["hour"]) + float(d["minute"]) / 60.0 + float(d["second"]) / 3600.0)


## 그 시각의 무드. 구간 경계 근처는 이웃 구간과 섞어서 돌려준다.
## 예: 17.5 시는 오후와 노을의 딱 중간.
static func at(hours: float) -> Dictionary:
	var h := wrap_hours(hours)
	var i := _band_index(h)
	var band: Dictionary = BANDS[i]
	var span := _forward(band["start"], band["end"])   # 구간 길이
	var pos := _forward(band["start"], h)              # 구간 시작부터 흐른 시간
	var here := str(band["id"])

	if pos < BLEND_HOURS:
		# 앞 구간에서 넘어오는 중. 경계에서 정확히 절반이 되도록 0.5 부터 시작한다.
		var prev := str(BANDS[(i - 1 + BANDS.size()) % BANDS.size()]["id"])
		return _mix(MOODS[prev], MOODS[here], _smooth(0.5 + 0.5 * (pos / BLEND_HOURS)))
	if pos > span - BLEND_HOURS:
		# 다음 구간으로 넘어가는 중
		var next := str(BANDS[(i + 1) % BANDS.size()]["id"])
		var t := 0.5 * ((pos - (span - BLEND_HOURS)) / BLEND_HOURS)
		return _mix(MOODS[here], MOODS[next], _smooth(t))
	return _copy(MOODS[here])


## 지금 시각의 무드. at(now_hours()) 와 같다.
static func now() -> Dictionary:
	return at(now_hours())


## 시간과 무관한 고정 무드. 이름이 틀리면 밤 사무실로 떨어진다(에피소드 0 기본값).
static func fixed(name: String) -> Dictionary:
	if FIXED_MOODS.has(name):
		return _copy(FIXED_MOODS[name])
	push_warning("[MoodPalette] 모르는 고정 무드: %s — night_office 로 대체한다" % name)
	return _copy(FIXED_MOODS["night_office"])


static func has_fixed(name: String) -> bool:
	return FIXED_MOODS.has(name)


## 두 무드 사이 보간. 씬 전환에서 이전 무드 → 새 무드로 넘길 때 쓴다.
## t=0 이면 a 그대로, t=1 이면 b 그대로 (부동소수점 오차 없이 원본을 돌려준다).
static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var k := clampf(t, 0.0, 1.0)
	if k <= 0.0:
		return _copy(a)
	if k >= 1.0:
		return _copy(b)
	return _mix(a, b, k)


## 사람이 읽을 구간 이름. 테스트·디버그용.
## 경계에서 섞이는 것과 별개로, 이름은 "지금 어느 구간에 서 있는가" 하나만 답한다.
static func name_at(hours: float) -> String:
	return str(BANDS[_band_index(wrap_hours(hours))]["id"])


## 한국어 이름 ("새벽" / "아침" / …). 화면에 띄울 때 쓴다.
static func label_at(hours: float) -> String:
	return str(BANDS[_band_index(wrap_hours(hours))]["label"])


## 구간 이름 목록 (시간 순)
static func band_names() -> Array:
	var out := []
	for b in BANDS:
		out.append(str(b["id"]))
	return out


## 고정 무드 이름 목록
static func fixed_names() -> Array:
	return FIXED_MOODS.keys()


## 무드가 담아야 할 키 전부 (색 + 숫자)
static func mood_keys() -> Array:
	var out := []
	out.append_array(COLOR_KEYS)
	out.append_array(FLOAT_KEYS)
	return out


## 0 <= h < 24 로 접는다. 25.5 → 1.5, -2.0 → 22.0
static func wrap_hours(h: float) -> float:
	return fposmod(h, 24.0)


# ── 내부 ────────────────────────────────────────────────────────────────

## a 에서 b 까지 시계 방향으로 흐른 시간. 자정을 넘는 구간(밤)을 위해 감아서 잰다.
static func _forward(a: float, b: float) -> float:
	return fposmod(b - a, 24.0)


## h 가 어느 구간에 있는가. 구간 시작은 포함, 끝은 제외.
static func _band_index(h: float) -> int:
	for i in BANDS.size():
		var b: Dictionary = BANDS[i]
		if _forward(b["start"], h) < _forward(b["start"], b["end"]):
			return i
	# 구간 정의가 24시간을 다 덮으므로 여기 오지 않는다. 와도 죽지는 말 것.
	return BANDS.size() - 1


## 경계에서 각지지 않게. 직선 보간이면 경계에서 색이 꺾이는 게 눈에 보인다.
static func _smooth(t: float) -> float:
	var k := clampf(t, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## 실제 섞기. 키가 빠져 있으면 반대쪽 값으로 메운다.
static func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for key in COLOR_KEYS:
		var ca: Color = a.get(key, b.get(key, Color(0.5, 0.5, 0.5)))
		var cb: Color = b.get(key, ca)
		out[key] = ca.lerp(cb, t)
	for key in FLOAT_KEYS:
		var fa := float(a.get(key, b.get(key, 0.0)))
		var fb := float(b.get(key, fa))
		out[key] = lerpf(fa, fb, t)
	return out


## 원본을 그대로 넘기면 쓰는 쪽에서 고쳤을 때 상수가 오염된다. 항상 복사본을 준다.
static func _copy(m: Dictionary) -> Dictionary:
	var out := {}
	for key in COLOR_KEYS:
		var c: Color = m.get(key, Color(0.5, 0.5, 0.5))
		out[key] = c
	for key in FLOAT_KEYS:
		out[key] = float(m.get(key, 0.0))
	return out
