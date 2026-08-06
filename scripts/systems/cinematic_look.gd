extends CanvasLayer
class_name CinematicLook
## 모든 3D 씬의 화면 마감을 한 곳에서 책임진다.
##
## 렌더러가 gl_compatibility 라서 SSAO·피사계심도 같은 엔진 후처리를 쓸 수 없다.
## (모바일 호환성을 위해 일부러 이 렌더러를 쓴다. Vulkan 을 요구하면 구형 기기가 떨어진다.)
## 그래서 화면 톤은 두 갈래로 만든다.
##
##   1. Environment — compatibility 에서도 도는 것만: 글로우, 안개, 톤매핑, 색보정
##   2. 화면 위에 겹치는 레이어 — 비네트 / 따뜻한 색조 / 아주 옅은 필름 그레인
##
## 씬마다 값을 따로 만지지 않는다. 톤이 씬마다 흔들리면 그게 제일 싸구려로 보인다.
## 그래서 "무슨 색으로 칠할지"는 MoodPalette 한 곳에서 정하고, 여기서는 그 값을
## 화면에 바르기만 한다.
##
## [무드]
##   mood 가 비어 있으면 실제 시각을 따라간다. 이 게임의 코어 루프가 unix time
##   기준이라, 켠 시각이 화면 색에 나오는 게 맞다 (기념품 방 같은 여행 쪽 화면).
##   mood 에 이름이 있으면 그 고정 무드를 쓴다. 에피소드 0 의 네 씬은 "늦은 밤
##   야근" 으로 각본이 짜여 있어서 아침이 되면 이야기가 깨진다.
##
##   고정 무드는 씬 스크립트가 _enter_tree 에서 지정한다. _ready 는 늦다 —
##   자식인 이 노드의 _ready 가 씬 루트의 _ready 보다 먼저 돌기 때문이다.
##   (그래도 늦게 넣는 실수까지 덮으려고 setter 에서 다시 바르게 해 뒀다.)
##
## [바르는 범위]
##   하늘이 보이는 씬(background_mode = BG_SKY) — 바깥 빛이 그림의 전부다.
##     하늘·해·환경광·안개를 전부 무드가 정한다.
##   하늘이 없는 실내 씬 — 배경색과 환경광은 그 방의 조명 설계다. 해는 아예
##     건드리지 않고, 실시간 무드일 때만 배경색·환경광에 바깥 시간을 조금 섞는다.
##     고정 무드 실내 씬(로비·사무실·복도)은 이미 그 밤에 맞춰 손으로 칠해져
##     있으므로 그대로 둔다. 사무실의 차가운 파랑, 복도의 긴장감은 연출이다.

const MoodPalette := preload("res://scripts/systems/mood_palette.gd")

## 화면 네 귀퉁이를 눌러 시선을 가운데로 모은다
const VIGNETTE := """
shader_type canvas_item;
render_mode blend_mul, unshaded;
uniform float strength : hint_range(0.0, 1.0) = 0.42;
uniform float radius   : hint_range(0.2, 1.5) = 0.82;
uniform float softness : hint_range(0.05, 1.0) = 0.55;
uniform vec3  tint = vec3(0.72, 0.66, 0.82);
void fragment() {
	vec2 p = SCREEN_UV - vec2(0.5);
	p.x *= 1.35;                                  // 가로로 긴 화면이라 원이 아니라 타원으로
	float d = length(p) * 2.0;
	float v = 1.0 - smoothstep(radius, radius + softness, d) * strength;
	COLOR = vec4(mix(tint, vec3(1.0), v), 1.0);
}
"""

## 비네트는 그 시각의 공기색(안개색)을 쓰되 채도를 눌러서 쓴다.
## 귀퉁이가 색으로 물들면 화면이 촌스러워진다.
## 밤 사무실 무드에 넣으면 지금 하드코딩돼 있던 (0.72, 0.66, 0.82) 과 거의 같은 값이 나온다.
const VIGNETTE_DESATURATE := 0.35

## 실내에 바깥 시간이 스며드는 정도. 방의 조명 설계를 지우지 않을 만큼만 섞는다.
## 창도 없는 방이 한낮에 새파래지면 그건 시간 표현이 아니라 사고다.
const INDOOR_SKY_MIX := 0.35        # 배경색에 바깥 하늘이 섞이는 정도
const INDOOR_AMBIENT_MIX := 0.50    # 환경광 색·밝기에 바깥 빛이 섞이는 정도
## 실내 씬들이 전제하고 있는 바깥 밝기 (= night_office 의 ambient_energy).
## 실내 밝기는 무드 값으로 갈아치우지 않고 이 값 대비 비율로만 흔든다.
## 한낮 무드의 ambient_energy 를 그대로 넣으면 방이 하얗게 뜬다.
const INDOOR_AMBIENT_REF := 0.85
## 실내 배경색이 이보다 밝아지지 않게 한다. 벽 위로 보이는 "바깥" 이
## 방 안보다 밝으면 시선이 그리로 끌린다.
const INDOOR_BG_MAX_LUM := 0.30
## 실내 씬이 하늘 배경을 쓸 때 하늘을 이만큼으로 눌러 둔다.
const INDOOR_SKY_DIM := 0.24

## 씬이 원래 갖고 있던 값을 적어 두는 메타 키.
## Environment 는 .tscn 의 sub_resource 라 씬을 다시 들어와도 같은 객체가 재활용된다.
## 원본을 안 적어 두면 방문할 때마다 lerp 이 누적돼서 방이 점점 밝아진다.
const META_BG := "quple_mood_base_bg"
const META_AMBIENT := "quple_mood_base_ambient"
const META_AMBIENT_ENERGY := "quple_mood_base_ambient_energy"

var _applied := false               # mood setter 가 이걸 보고 다시 바를지 정한다

@export var vignette_strength := 0.42

## 고정 무드 이름. 비워 두면 실제 시각을 따라간다.
## 아는 이름은 MoodPalette.fixed_names() — 지금은 "night_office" / "night_office_indoor".
@export var mood: String = "": set = set_mood

## 배경이 하늘(BG_SKY)이어도 실내로 다룬다.
##
## 기념품 방이 하늘 배경을 쓰고 있어서 실외로 판정됐다. 방에는 천장이 없어
## 벽 위로 그 하늘이 그대로 보이는데, 한낮이면 화면 위 1/5 이 순백이 된다.
## 실내 장면에서 제일 밝은 것이 "아무것도 없는 하늘" 이 되는 건 잘못이다.
@export var indoor := false: set = set_indoor

var current_mood: Dictionary = {}   # 지금 화면에 발려 있는 무드
var current_mood_name := ""         # 고정 무드 이름이거나, 실시간이면 "dawn"/"night" 같은 구간 이름

var _vignette_mat: ShaderMaterial = null


func _ready() -> void:
	add_to_group("cinematic_look")
	layer = 5                       # 3D 위, UI(8) 아래
	_add_overlay(VIGNETTE, {"strength": vignette_strength})
	apply_mood(resolve_mood())


## mood 를 늦게(씬 루트의 _ready 등) 넣어도 화면에 반영되게 한다.
func set_mood(value: String) -> void:
	mood = value
	if _applied:
		apply_mood(resolve_mood())


## 씬 루트의 _ready 에서 늦게 켜도 화면에 반영되게 한다.
## 이미 한 번 바른 뒤에 값만 바꾸면 아무 일도 일어나지 않는다.
func set_indoor(value: bool) -> void:
	indoor = value
	if _applied:
		apply_mood(resolve_mood())


## 지금 써야 할 무드를 고른다. 이름이 있으면 고정, 없으면 실제 시각.
func resolve_mood() -> Dictionary:
	if mood.is_empty():
		var h := MoodPalette.now_hours()
		current_mood_name = MoodPalette.name_at(h)
		return MoodPalette.at(h)
	current_mood_name = mood
	return MoodPalette.fixed(mood)     # 모르는 이름이면 경고 후 night_office 로 떨어진다


## 무드를 화면에 바른다. 밖에서 다시 불러도 안전하다.
func apply_mood(m: Dictionary) -> void:
	if m.is_empty():
		return
	current_mood = m
	var outdoor := _apply_environment(m)
	if outdoor:
		_apply_sun(m)
	_apply_vignette(m)
	_push_to_depth_shading(m)
	_applied = true


## 지금 무드의 복사본. DepthShading·SceneTransition 처럼 같은 색을 써야 하는 쪽이 가져간다.
## 복사본을 주는 이유는 mood_palette.gd 와 같다 — 받은 쪽이 고쳐도 여기가 오염되면 안 된다.
func mood_data() -> Dictionary:
	return current_mood.duplicate()


## compatibility 렌더러에서 실제로 동작하는 항목만 손댄다.
## 돌려주는 값은 "하늘이 보이는 씬인가" — 해를 움직일지 여기서 갈린다.
func _apply_environment(m: Dictionary) -> bool:
	var we := _find_world_environment(get_tree().current_scene)
	if we == null or we.environment == null:
		return false
	var e: Environment = we.environment
	var outdoor := e.background_mode == Environment.BG_SKY and not indoor

	# 톤매핑 — 하이라이트가 하얗게 타지 않고 부드럽게 말린다
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_white = 4.0
	e.tonemap_exposure = float(m["exposure"])

	# 글로우 — 창문 불빛과 가로등이 번지면서 밤 공기가 생긴다
	e.glow_enabled = true
	# 실내는 광원이 가깝고 많아 같은 값이면 훨씬 심하게 탄다.
	# 기념품 방에서 창·사진·램프가 전부 흰 덩어리가 됐다.
	var indoor := not outdoor
	e.glow_intensity = 0.55 if indoor else 0.95
	e.glow_strength = 1.15
	e.glow_bloom = 0.16 if indoor else 0.28
	e.glow_hdr_threshold = 1.05 if indoor else 0.82
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# 색보정 — 파스텔이 흐리멍덩해지지 않게 대비와 채도를 올린다
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.02
	e.adjustment_contrast = float(m["contrast"])
	e.adjustment_saturation = float(m["saturation"])

	# 안개 — 뒤로 갈수록 옅어지면서 깊이가 생긴다. 디오라마 느낌의 핵심.
	# 색까지 무드에서 가져와야 새벽 안개와 밤 안개가 달라진다.
	e.fog_enabled = true
	# 안개는 배경(무한 깊이)까지 덮는다. fog_sky_affect = 0 은 하늘 배경만 막을 뿐,
	# 단색 배경 씬에서는 화면이 통째로 안개색이 된다.
	# 기념품 방이 그랬다 — 배경색은 짙은 남색인데 벽 위쪽이 한낮 안개색으로 하얗게 떴다.
	# 실내에서는 안개색 밝기를 눌러 방보다 밝아지지 않게 한다.
	var fog: Color = m["fog_color"]
	if not outdoor:
		var fl := fog.get_luminance()
		if fl > INDOOR_BG_MAX_LUM:
			fog = fog * (INDOOR_BG_MAX_LUM / maxf(fl, 0.001))
			fog.a = 1.0
	e.fog_light_color = fog
	e.fog_density = float(m["fog_density"])
	e.fog_sky_affect = 0.0

	if outdoor:
		_paint_sky(e, m)
		e.ambient_light_color = m["ambient_color"]
		e.ambient_light_energy = float(m["ambient_energy"])
	else:
		_paint_indoor(e, m)
	return outdoor


## 하늘. ProceduralSkyMaterial 의 색 네 개만 갈아끼운다.
## sky_curve / sun_angle_max / sun_curve 는 그 씬의 하늘 모양이라 그대로 둔다.
func _paint_sky(e: Environment, m: Dictionary) -> void:
	if e.sky == null:
		return
	var sm := e.sky.sky_material as ProceduralSkyMaterial
	if sm == null:
		return
	sm.sky_top_color = m["sky_top"]
	sm.sky_horizon_color = m["sky_horizon"]
	sm.ground_horizon_color = m["ground_horizon"]
	sm.ground_bottom_color = m["ground_bottom"]


## 실내. 하늘이 안 보이니 배경색과 환경광에만 바깥 시간을 섞는다.
##
## 고정 무드(에피소드 0 의 실내 세 씬)도 **무드 값을 쓴다.**
## 예전에는 "씬이 손으로 맞춰 둔 값이 있으니 그대로 두자" 며 여기서 그냥 돌아갔는데,
## 그 바람에 `night_office_indoor` 의 환경광이 아무 데도 안 쓰이는 죽은 값이 됐다.
## 실내를 등불색으로 바꾼 변경이 통째로 화면에 닿지 않았고, 로비·사무실·복도는
## .tscn 에 적힌 밤하늘 라벤더 그대로 남아 "수영장 색" 이었다.
##
## 고정 무드는 "시간에 따라 변하지 않는다" 는 뜻이지 "무드를 무시한다" 가 아니다.
func _paint_indoor(e: Environment, m: Dictionary) -> void:
	var base_bg: Color = _base_color(e, META_BG, e.background_color)

	# 하늘 배경을 쓰는 실내 씬(기념품 방)은 하늘을 어둡게 눌러 둔다.
	# 시간대 색은 남기되 밝기는 방보다 아래로 내린다.
	if e.background_mode == Environment.BG_SKY:
		var dim := m.duplicate()
		for k in ["sky_top", "sky_horizon", "ground_horizon", "ground_bottom"]:
			var c: Color = m[k]
			dim[k] = Color(c.r * INDOOR_SKY_DIM, c.g * INDOOR_SKY_DIM, c.b * INDOOR_SKY_DIM)
		_paint_sky(e, dim)

	if not mood.is_empty():
		# 고정 무드 — 시간과 무관하게 이 무드의 값을 그대로 바른다.
		e.background_color = m.get("fog_color", base_bg)
		e.ambient_light_color = m["ambient_color"]
		e.ambient_light_energy = m["ambient_energy"]
		return

	var base_amb: Color = _base_color(e, META_AMBIENT, e.ambient_light_color)
	var base_energy := _base_float(e, META_AMBIENT_ENERGY, e.ambient_light_energy)

	# 방에는 천장이 없어서 벽 위로 이 배경색이 그대로 보인다.
	# 한낮 하늘색을 그대로 섞었더니 화면 위쪽 1/5 이 순백이 되어,
	# 실내 장면에서 제일 밝은 것이 "아무것도 없는 하늘" 이 됐다.
	# 시간대는 색으로만 느끼게 하고 밝기는 방 쪽에 묶어 둔다.
	var bg := base_bg.lerp(m["sky_top"], INDOOR_SKY_MIX)
	var lum := bg.get_luminance()
	if lum > INDOOR_BG_MAX_LUM:
		bg = bg * (INDOOR_BG_MAX_LUM / maxf(lum, 0.001))
		bg.a = 1.0
	e.background_color = bg
	e.ambient_light_color = base_amb.lerp(m["ambient_color"], INDOOR_AMBIENT_MIX)
	var ratio := float(m["ambient_energy"]) / INDOOR_AMBIENT_REF
	e.ambient_light_energy = base_energy * lerpf(1.0, ratio, INDOOR_AMBIENT_MIX)


## 해(또는 달). 실외에서만 부른다 — 창도 없는 방에서 해가 밝아지면 이상하다.
func _apply_sun(m: Dictionary) -> void:
	var sun := _find_sun(get_tree().current_scene)
	if sun == null:
		return
	sun.light_color = m["sun_color"]
	sun.light_energy = float(m["sun_energy"])
	# 고도(pitch)만 바꾼다. 방위(yaw)는 그 씬이 정한 그림자 방향이라 그대로 둔다.
	# 회전 전체를 다시 만들면 그림자가 엉뚱한 쪽으로 눕는다.
	sun.rotation.x = deg_to_rad(float(m["sun_angle_deg"]))


func _apply_vignette(m: Dictionary) -> void:
	if _vignette_mat == null:
		return
	_vignette_mat.set_shader_parameter("strength", vignette_strength)
	_vignette_mat.set_shader_parameter("tint", _to_vec3(_vignette_tint(m)))


func _vignette_tint(m: Dictionary) -> Color:
	var c: Color = m["fog_color"]
	var l := c.get_luminance()
	return c.lerp(Color(l, l, l), VIGNETTE_DESATURATE)


## 반구조명 색을 DepthShading 에 넘긴다.
## 다만 평소 경로는 이쪽이 아니다. DepthShading 은 _ready 에서 한 프레임 기다렸다가
## 재질을 통째로 갈아끼우기 때문에, 그 전에 발라 두면 새 재질이 덮어써 버린다.
## 그래서 DepthShading 이 교체를 끝낸 뒤에 스스로 여기서 가져간다(mood_data).
## 이 push 는 무드를 나중에 다시 바를 때(예: setter)를 위한 것이다.
func _push_to_depth_shading(m: Dictionary) -> void:
	var ds := get_tree().get_first_node_in_group("depth_shading")
	if ds != null and ds.has_method("apply_hemi_tints"):
		ds.apply_hemi_tints(m["hemi_sky_tint"], m["hemi_ground_tint"])


## 씬이 원래 갖고 있던 색. 처음 한 번만 적어 두고 그 뒤로는 적어 둔 값을 쓴다.
func _base_color(e: Environment, key: String, current: Color) -> Color:
	if not e.has_meta(key):
		e.set_meta(key, current)
	var v: Color = e.get_meta(key)
	return v


func _base_float(e: Environment, key: String, current: float) -> float:
	if not e.has_meta(key):
		e.set_meta(key, current)
	return float(e.get_meta(key))


## source_color 힌트가 없는 vec3 uniform 에는 Vector3 로 넣는다.
## Color 로 넣으면 엔진이 sRGB→선형 변환을 걸어서 셰이더에 적힌 기본값과 다른 색이 된다.
func _to_vec3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func _find_world_environment(n: Node) -> WorldEnvironment:
	if n == null:
		return null
	if n is WorldEnvironment:
		return n
	for c in n.get_children():
		var r := _find_world_environment(c)
		if r != null:
			return r
	return null


## 씬의 주광. 그림자를 지는 첫 DirectionalLight3D 를 해로 본다.
## CompanyFront3D 처럼 보조광(FillLight)이 같이 있는 씬에서 엉뚱한 쪽을 잡지 않으려는 것.
func _find_sun(n: Node) -> DirectionalLight3D:
	var shadowed := _find_directional(n, true)
	if shadowed != null:
		return shadowed
	return _find_directional(n, false)


func _find_directional(n: Node, need_shadow: bool) -> DirectionalLight3D:
	if n == null:
		return null
	var d := n as DirectionalLight3D
	if d != null and (not need_shadow or d.shadow_enabled):
		return d
	for c in n.get_children():
		var r := _find_directional(c, need_shadow)
		if r != null:
			return r
	return null


func _add_overlay(code: String, params: Dictionary) -> void:
	var sh := Shader.new()
	sh.code = code
	var mat := ShaderMaterial.new()
	mat.shader = sh
	for k in params:
		mat.set_shader_parameter(k, params[k])
	var r := ColorRect.new()
	r.material = mat
	r.color = Color(1, 1, 1, 1)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	_vignette_mat = mat
