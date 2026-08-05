class_name TravelPalette
extends RefCounted

# 여행지별 "색조 1개" 팔레트.
# 한 장면에는 지배적인 색조를 하나만 두어야 그림이 정리돼 보이기 때문에,
# 하늘·땅·빛·안개를 한 세트로 묶어서 정의한다. 씬마다 색을 즉흥적으로
# 고르면 색조가 섞여서 탁해진다.
#
# [중요] 쿼카의 스카프색(산호 #FF6F61 계열)은 어떤 팔레트에도 넣지 않는다.
# 배경에 같은 색이 있으면 캐릭터가 배경에 묻힌다. 이 색을 캐릭터에만
# 남겨 둬야 플레이어의 시선이 자동으로 쿼카 커플로 간다.
# 팔레트 색을 추가/수정할 때도 산호~주황 계열(대략 hue 0.99~0.06 &
# 채도 0.5 이상)은 피할 것.

# 스카프 색 (참고용, 배경 금지 표시)
const SCARF_CORAL := Color("#FF6F61")

# 막(chapter) 기본 팔레트. region 정보가 없을 때 쓰인다.
const CHAPTER_PALETTES := {
	"korea": {
		"sky_top": Color(0.44, 0.62, 0.82),
		"sky_bottom": Color(0.80, 0.88, 0.92),
		"ground": Color(0.42, 0.56, 0.40),
		"accent": Color(0.62, 0.76, 0.70),
		"light_color": Color(1.00, 0.96, 0.86),
		"light_angle_deg": -48.0,
		"fog_color": Color(0.74, 0.83, 0.90),
	},
	"world": {
		"sky_top": Color(0.34, 0.52, 0.80),
		"sky_bottom": Color(0.78, 0.85, 0.93),
		"ground": Color(0.48, 0.52, 0.46),
		"accent": Color(0.56, 0.70, 0.82),
		"light_color": Color(1.00, 0.97, 0.90),
		"light_angle_deg": -52.0,
		"fog_color": Color(0.72, 0.80, 0.90),
	},
	"space": {
		"sky_top": Color(0.05, 0.06, 0.16),
		"sky_bottom": Color(0.16, 0.16, 0.32),
		"ground": Color(0.30, 0.28, 0.38),
		"accent": Color(0.52, 0.60, 0.92),
		"light_color": Color(0.82, 0.86, 1.00),
		"light_angle_deg": -35.0,
		"fog_color": Color(0.14, 0.15, 0.28),
	},
	"beyond": {
		"sky_top": Color(0.20, 0.10, 0.30),
		"sky_bottom": Color(0.48, 0.32, 0.62),
		"ground": Color(0.30, 0.24, 0.44),
		"accent": Color(0.66, 0.52, 0.90),
		"light_color": Color(0.90, 0.84, 1.00),
		"light_angle_deg": -40.0,
		"fog_color": Color(0.36, 0.26, 0.52),
	},
}

# 대륙(region) 팔레트. 같은 "world" 막이어도 대륙마다 인상이 달라야
# 여행한 느낌이 나므로 따로 둔다.
const REGION_PALETTES := {
	"asia": {
		"sky_top": Color(0.40, 0.58, 0.80),
		"sky_bottom": Color(0.86, 0.88, 0.84),
		"ground": Color(0.44, 0.55, 0.38),
		"accent": Color(0.70, 0.78, 0.62),
		"light_color": Color(1.00, 0.96, 0.84),
		"light_angle_deg": -50.0,
		"fog_color": Color(0.78, 0.84, 0.86),
	},
	"europe": {
		"sky_top": Color(0.36, 0.48, 0.72),
		"sky_bottom": Color(0.80, 0.84, 0.90),
		"ground": Color(0.40, 0.46, 0.44),
		"accent": Color(0.58, 0.66, 0.80),
		"light_color": Color(0.94, 0.95, 1.00),
		"light_angle_deg": -42.0,
		"fog_color": Color(0.74, 0.79, 0.88),
	},
	"africa": {
		# 사바나의 황토색. 다만 채도를 낮춰 스카프의 산호색과 겹치지 않게 한다.
		"sky_top": Color(0.52, 0.66, 0.82),
		"sky_bottom": Color(0.90, 0.86, 0.70),
		"ground": Color(0.62, 0.54, 0.34),
		"accent": Color(0.78, 0.70, 0.46),
		"light_color": Color(1.00, 0.94, 0.78),
		"light_angle_deg": -58.0,
		"fog_color": Color(0.86, 0.82, 0.68),
	},
	"america": {
		"sky_top": Color(0.30, 0.54, 0.78),
		"sky_bottom": Color(0.82, 0.88, 0.92),
		"ground": Color(0.50, 0.48, 0.40),
		"accent": Color(0.60, 0.74, 0.72),
		"light_color": Color(1.00, 0.97, 0.88),
		"light_angle_deg": -54.0,
		"fog_color": Color(0.76, 0.84, 0.90),
	},
	"oceania": {
		"sky_top": Color(0.26, 0.60, 0.80),
		"sky_bottom": Color(0.78, 0.92, 0.94),
		"ground": Color(0.36, 0.62, 0.58),
		"accent": Color(0.48, 0.80, 0.78),
		"light_color": Color(1.00, 0.98, 0.92),
		"light_angle_deg": -60.0,
		"fog_color": Color(0.72, 0.88, 0.92),
	},
}

# 팔레트가 하나도 안 맞을 때의 기본값 (무채색에 가까운 파랑)
const FALLBACK := {
	"sky_top": Color(0.40, 0.54, 0.76),
	"sky_bottom": Color(0.82, 0.86, 0.90),
	"ground": Color(0.46, 0.50, 0.46),
	"accent": Color(0.62, 0.70, 0.78),
	"light_color": Color(1.00, 0.98, 0.92),
	"light_angle_deg": -50.0,
	"fog_color": Color(0.76, 0.82, 0.88),
}


# 여행지 딕셔너리로 팔레트를 고른다.
# region 이 더 구체적인 정보이므로 우선한다. 없으면 막 단위로 떨어진다.
static func for_destination(d: Dictionary) -> Dictionary:
	var region := str(d.get("region", ""))
	if region != "" and REGION_PALETTES.has(region):
		return (REGION_PALETTES[region] as Dictionary).duplicate(true)
	var chapter := str(d.get("chapter", ""))
	if chapter != "" and CHAPTER_PALETTES.has(chapter):
		return (CHAPTER_PALETTES[chapter] as Dictionary).duplicate(true)
	return FALLBACK.duplicate(true)


static func _col(pal: Dictionary, key: String) -> Color:
	# 팔레트가 부분적으로만 채워져 있어도 죽지 않게 기본값으로 보정한다.
	var v: Variant = pal.get(key, FALLBACK[key])
	return v if v is Color else Color(FALLBACK[key])


# Environment 에 하늘·환경광·안개를 한 번에 입힌다.
# 배경/ambient/fog 가 각각 다른 색이면 색조가 흩어지므로 전부 같은 팔레트에서 뽑는다.
static func apply_to_environment(env: Environment, pal: Dictionary) -> void:
	if env == null:
		return
	var sky_top := _col(pal, "sky_top")
	var sky_bottom := _col(pal, "sky_bottom")
	var fog := _col(pal, "fog_color")

	env.background_mode = Environment.BG_COLOR
	env.background_color = sky_top

	# 환경광은 하늘 위/아래의 중간색. 이러면 그림자 쪽도 같은 색조에 머문다.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = sky_top.lerp(sky_bottom, 0.5)
	env.ambient_light_energy = 1.0

	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_density = 0.012


# 태양광의 색과 각도. 각도는 팔레트마다 달라서 지역의 위도/시간 느낌을 만든다.
static func apply_to_light(light: DirectionalLight3D, pal: Dictionary) -> void:
	if light == null:
		return
	light.light_color = _col(pal, "light_color")
	var deg: float = float(pal.get("light_angle_deg", FALLBACK["light_angle_deg"]))
	# X 회전이 고도(내리쬐는 각도), Y 는 방위. 방위는 살짝 틀어 그림자가 정면으로
	# 떨어지지 않게 한다(정면 그림자는 캐릭터 실루엣을 뭉갠다).
	light.rotation_degrees = Vector3(deg, -35.0, 0.0)


# t: 0.0 새벽 → 0.5 낮 → 1.0 노을.
# 원본 팔레트를 유지한 채 색온도만 옮긴다. 색조는 하나라는 원칙을 지키려고
# 새 색을 넣지 않고 기존 색을 어둡게/따뜻하게 "기울이기"만 한다.
static func time_of_day_shift(pal: Dictionary, t: float) -> Dictionary:
	var k := clampf(t, 0.0, 1.0)
	# 새벽: 푸르고 어둡다 / 노을: 노랗고 어둡다. 산호색은 피해야 하므로
	# 노을 쪽 틴트도 붉은 기 대신 황금빛(노랑)으로 간다.
	var dawn_tint := Color(0.62, 0.70, 0.95)
	var noon_tint := Color(1.0, 1.0, 1.0)
	var dusk_tint := Color(1.00, 0.90, 0.58)

	var tint: Color
	var bright: float
	if k < 0.5:
		var a := k / 0.5
		tint = dawn_tint.lerp(noon_tint, a)
		bright = lerpf(0.72, 1.0, a)
	else:
		var b := (k - 0.5) / 0.5
		tint = noon_tint.lerp(dusk_tint, b)
		bright = lerpf(1.0, 0.78, b)

	var out := pal.duplicate(true)
	for key in ["sky_top", "sky_bottom", "ground", "accent", "light_color", "fog_color"]:
		var c := _col(pal, key)
		out[key] = Color(
			clampf(c.r * tint.r * bright, 0.0, 1.0),
			clampf(c.g * tint.g * bright, 0.0, 1.0),
			clampf(c.b * tint.b * bright, 0.0, 1.0),
			c.a
		)
	# 해가 낮을수록 빛이 옆에서 들어온다.
	var base_deg: float = float(pal.get("light_angle_deg", FALLBACK["light_angle_deg"]))
	var low := absf(k - 0.5) * 2.0   # 0 낮, 1 새벽/노을
	out["light_angle_deg"] = lerpf(base_deg, base_deg * 0.28, low)
	return out
