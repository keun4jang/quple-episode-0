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

@export var vignette_strength := 0.42

func _ready() -> void:
	add_to_group("cinematic_look")
	layer = 5                       # 3D 위, UI(8) 아래
	_tune_environment()
	_add_overlay(VIGNETTE, {"strength": vignette_strength})


## compatibility 렌더러에서 실제로 동작하는 항목만 손댄다.
func _tune_environment() -> void:
	var we := _find_world_environment(get_tree().current_scene)
	if we == null or we.environment == null:
		return
	var e: Environment = we.environment

	# 톤매핑 — 하이라이트가 하얗게 타지 않고 부드럽게 말린다
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_white = 4.0
	e.tonemap_exposure = 1.05

	# 글로우 — 창문 불빛과 가로등이 번지면서 밤 공기가 생긴다
	e.glow_enabled = true
	e.glow_intensity = 0.95
	e.glow_strength = 1.15
	e.glow_bloom = 0.28
	e.glow_hdr_threshold = 0.82
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# 색보정 — 파스텔이 흐리멍덩해지지 않게 대비와 채도를 올린다
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.02
	e.adjustment_contrast = 1.14
	e.adjustment_saturation = 1.24

	# 안개 — 뒤로 갈수록 옅어지면서 깊이가 생긴다. 디오라마 느낌의 핵심.
	e.fog_enabled = true
	e.fog_density = 0.0055
	e.fog_sky_affect = 0.0


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
