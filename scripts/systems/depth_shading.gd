extends Node
## 평평해 보이는 3D 에 명암과 깊이를 넣는다.
##
## 렌더러가 gl_compatibility 라 SSAO 를 못 쓴다. 그래서 물체가 바닥에 붙어 있는
## 느낌이 안 나고, 전부 종이를 오려 붙인 것처럼 보였다. 없는 기능을 기다리는 대신
## 셰이더로 직접 만든다. 세 가지를 넣는다.
##
##   1. 반구 조명 — 위를 본 면은 하늘색, 아래를 본 면은 땅색을 머금는다.
##      단색 덩어리에 방향이 생겨서 형태가 읽힌다. 효과가 제일 크다.
##   2. 접지 그림자 — 바닥에 가까울수록 어두워진다. SSAO 흉내.
##   3. 림 라이트 — 실루엣 가장자리가 살짝 밝아진다. 배경에서 물체가 떨어져 나온다.
##
## 씬마다 재질을 손으로 고치지 않는다. 실행할 때 한 번 훑어서 갈아끼운다.
## 그래야 새 오브젝트를 추가해도 저절로 같은 톤을 따른다.

const SHADER := """
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec4  albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

// 반구 조명
uniform vec3  sky_tint : source_color = vec3(0.62, 0.70, 0.92);
uniform vec3  ground_tint : source_color = vec3(0.58, 0.48, 0.56);
uniform float hemi_amount : hint_range(0.0, 1.0) = 0.26;

// 접지 그림자
uniform float ao_height : hint_range(0.05, 6.0) = 1.15;
uniform float ao_amount : hint_range(0.0, 1.0) = 0.30;
uniform float floor_y = 0.0;

// 림 라이트
uniform vec3  rim_tint : source_color = vec3(1.0, 0.86, 0.72);
uniform float rim_amount : hint_range(0.0, 2.0) = 0.62;
uniform float rim_power : hint_range(0.5, 8.0) = 3.2;

// 바람에 흔들리는 잎. LivingScene 이 나뭇잎 재질에만 켜 준다.
uniform float sway_amount = 0.0;
uniform float sway_speed = 1.1;

varying float world_y;
varying vec3 world_normal;

void vertex() {
	if (sway_amount > 0.0) {
		// 나무마다 다른 위상을 줘서 전부 같이 흔들리지 않게 한다
		float ph = MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 2.3;
		VERTEX.x += sin(TIME * sway_speed + ph) * sway_amount;
		VERTEX.z += cos(TIME * sway_speed * 0.77 + ph) * sway_amount * 0.6;
	}
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = albedo.rgb;

	// 1. 위/아래를 보는 정도에 따라 하늘빛과 땅빛을 섞는다
	float up = world_normal.y * 0.5 + 0.5;
	c *= mix(ground_tint, sky_tint, up) * hemi_amount + (1.0 - hemi_amount);

	// 2. 바닥에 가까울수록 어둡게 — 물체가 땅에 얹힌 것처럼 보인다
	float h = clamp((world_y - floor_y) / ao_height, 0.0, 1.0);
	c *= 1.0 - (1.0 - smoothstep(0.0, 1.0, h)) * ao_amount;

	// 명암을 넣으면 전체가 가라앉는다. 파스텔 톤을 지키려고 조금 되올린다.
	ALBEDO = c * 1.10;
	ROUGHNESS = roughness;

	// 3. 가장자리를 살짝 밝혀 배경에서 떼어 놓는다
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	EMISSION = rim_tint * rim * rim_amount;
}
"""

## 씬마다 바닥 높이가 다르다. 잘못 주면 공중에 뜬 물체가 까맣게 된다.
@export var floor_y := 0.0
@export var ao_height := 1.15
@export var ao_amount := 0.30
@export var rim_amount := 0.62

var _shader: Shader
var _cache: Dictionary = {}          # 원본 재질 → 만들어 둔 셰이더 재질

## 반구조명 색. 위 셰이더의 기본값과 같은 값으로 시작한다.
## CinematicLook 이 지금 무드의 hemi_sky_tint / hemi_ground_tint 로 갈아준다.
## 씬의 하늘색과 여기가 따로 놀면 물체만 다른 시간대에 서 있는 것처럼 보인다.
var _sky_tint := Color(0.62, 0.70, 0.92)
var _ground_tint := Color(0.58, 0.48, 0.56)


func _ready() -> void:
	add_to_group("depth_shading")
	_shader = Shader.new()
	_shader.code = SHADER
	# 씬이 다 세워진 뒤에 훑는다. 스크립트가 _ready 에서 만드는 메시도 잡아야 한다.
	await get_tree().process_frame
	var n := _apply_to(get_tree().current_scene)
	# 재질을 다 갈아끼운 "뒤에" 무드 색을 입힌다. 순서가 중요하다 —
	# 교체 전에 발라 봐야 새로 만든 재질이 기본값으로 덮어쓴다.
	# CinematicLook 이 밀어 주는 게 아니라 이쪽에서 가져온다. 위에서 한 프레임을
	# 기다렸으니 씬의 _ready 는 전부 끝나 있고, 그러면 누가 먼저 도는지 따질 필요가 없다.
	_pull_mood()
	print("[DepthShading] 재질 %d 개 교체" % n)


## 반구조명 색을 갈아끼운다. 이미 만들어 둔 재질과 앞으로 만들 재질 모두에 적용된다.
func apply_hemi_tints(sky: Color, ground: Color) -> void:
	_sky_tint = sky
	_ground_tint = ground
	for src in _cache:
		var m: ShaderMaterial = _cache[src]
		_write_hemi(m)


func _pull_mood() -> void:
	var look := get_tree().get_first_node_in_group("cinematic_look")
	if look == null or not look.has_method("mood_data"):
		return
	var m: Dictionary = look.mood_data()
	if m.is_empty():
		return
	apply_hemi_tints(m.get("hemi_sky_tint", _sky_tint), m.get("hemi_ground_tint", _ground_tint))


## source_color 힌트가 붙어 있어도 Vector3 로 넣는다.
## Color 로 넣으면 엔진이 sRGB→선형 변환을 한 번 더 걸어서, 셰이더에 적힌 기본값과
## 다른(훨씬 어둡고 진한) 색이 된다. 지금 화면은 그 기본값 기준으로 맞춰져 있다.
func _write_hemi(m: ShaderMaterial) -> void:
	m.set_shader_parameter("sky_tint", Vector3(_sky_tint.r, _sky_tint.g, _sky_tint.b))
	m.set_shader_parameter("ground_tint", Vector3(_ground_tint.r, _ground_tint.g, _ground_tint.b))


func _apply_to(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		count += _convert(node)
	for c in node.get_children():
		count += _apply_to(c)
	return count


func _convert(mi: MeshInstance3D) -> int:
	var n := 0
	if mi.material_override is StandardMaterial3D:
		mi.material_override = _shade(mi.material_override)
		return 1
	if mi.mesh == null:
		return 0
	for i in mi.mesh.get_surface_count():
		var src := mi.get_active_material(i)
		if src is StandardMaterial3D:
			mi.set_surface_override_material(i, _shade(src))
			n += 1
	return n


## StandardMaterial3D 의 겉모습을 그대로 옮긴 셰이더 재질을 만든다.
func _shade(src: StandardMaterial3D) -> Material:
	# 빛나는 것(창문·간판·눈 하이라이트)과 반투명한 것(그림자 블롭)은 건드리지 않는다.
	# 여기에 명암을 먹이면 오히려 빛이 죽는다.
	if src.emission_enabled:
		return src
	if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return src
	if src.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return src
	if src.albedo_texture != null:
		return src

	if _cache.has(src):
		return _cache[src]

	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("albedo", src.albedo_color)
	m.set_shader_parameter("roughness", src.roughness)
	m.set_shader_parameter("floor_y", floor_y)
	m.set_shader_parameter("ao_height", ao_height)
	m.set_shader_parameter("ao_amount", ao_amount)
	m.set_shader_parameter("rim_amount", rim_amount)
	_write_hemi(m)                   # 스캔이 끝난 뒤 만들어지는 재질도 같은 무드를 따르게
	_cache[src] = m
	return m
