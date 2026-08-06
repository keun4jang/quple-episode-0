extends Node
## 평평해 보이는 3D 에 명암과 깊이를 넣는다.
##
## 렌더러가 gl_compatibility 라 SSAO 를 못 쓴다. 그래서 물체가 바닥에 붙어 있는
## 느낌이 안 나고, 전부 종이를 오려 붙인 것처럼 보였다. 없는 기능을 기다리는 대신
## 셰이더로 직접 만든다. 네 가지를 넣는다.
##
##   1. 반구 조명 — 위를 본 면은 하늘색, 아래를 본 면은 땅색을 머금는다.
##      단색 덩어리에 방향이 생겨서 형태가 읽힌다. 효과가 제일 크다.
##   2. 접지 그림자 — 바닥에 가까울수록 어두워진다. SSAO 흉내.
##   3. 림 라이트 — 실루엣 가장자리가 살짝 밝아진다. 배경에서 물체가 떨어져 나온다.
##   4. 표면 결 — 흑백 디테일 맵을 albedo 에 곱하고, 노멀 맵으로 빛이 요철에
##      걸리게 한다. 표면이 무엇인지는 SurfaceKit 이 노드 이름으로 답한다.
##
## 4번을 컬러 텍스처가 아니라 흑백으로 하는 이유: 색은 mood_palette / travel palette
## 에서 이미 다 맞춰 놨다. 컬러 텍스처를 씌우면 그게 통째로 무너진다. 흑백 디테일은
## 밝기 편차만 곱하므로 색은 그대로 두고 결만 얹힌다.
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

// 표면 결. SurfaceKit 이 "이 노드는 콘크리트다" 라고 답하면 DepthShading 이 채운다.
// 아무것도 안 채우면 use_ 두 개가 false 로 남고, 그러면 아래 계산이 통째로 건너뛴다
// = 결이 붙기 전과 픽셀 하나까지 똑같이 나온다.
//
// source_color 를 붙이지 않는 게 중요하다. 두 장 다 색이 아니라 데이터라서
// sRGB→선형 변환이 걸리면 안 된다. 디테일 맵은 평균 0.5 를 그대로 읽어야
// 아래의 2배 보정이 맞고, 노멀 맵은 애초에 색이 아니다.
uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 1.0;                              // 월드 1미터당 반복 횟수
uniform float detail_strength : hint_range(0.0, 1.0) = 0.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.0;
uniform bool  use_detail = false;
uniform bool  use_normal = false;

// 삼중평면 가중치를 얼마나 좁힐지. 1.0 이면 모서리에서 세 방향이 넓게 섞여 뭉개지고,
// 너무 크면 면이 바뀌는 자리에 금이 보인다. 4 는 그 사이.
const float TRI_SHARPNESS = 4.0;

// 바람에 흔들리는 잎. LivingScene 이 나뭇잎 재질에만 켜 준다.
uniform float sway_amount = 0.0;
uniform float sway_speed = 1.1;

varying float world_y;
varying vec3 world_normal;
varying vec3 world_pos;   // 삼중평면이 쓸 월드 좌표. 결을 물체가 아니라 공간에 물린다.

void vertex() {
	if (sway_amount > 0.0) {
		// 나무마다 다른 위상을 줘서 전부 같이 흔들리지 않게 한다
		float ph = MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 2.3;
		VERTEX.x += sin(TIME * sway_speed + ph) * sway_amount;
		VERTEX.z += cos(TIME * sway_speed * 0.77 + ph) * sway_amount * 0.6;
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_y = world_pos.y;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 삼중평면 가중치. 월드 노멀이 향한 축의 평면을 주로 쓰고, 나머지는 조금만 섞는다.
vec3 tri_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(TRI_SHARPNESS));
	return w / max(w.x + w.y + w.z, 0.00001);
}

void fragment() {
	vec3 c = albedo.rgb;

	// 삼중평면 준비. UV 를 안 쓰는 이유는 이 게임이 BoxMesh/CylinderMesh 하나를
	// 크기만 바꿔 돌려쓰기 때문이다. UV 로 깔면 큰 벽에서는 결이 늘어나고 작은
	// 소품에서는 뭉갠다. 월드 좌표에 물리면 크기와 상관없이 결 밀도가 일정하다.
	vec3 tw = vec3(0.0);
	vec3 tp = vec3(0.0);
	if (use_detail || use_normal) {
		tw = tri_weights(normalize(world_normal));
		tp = world_pos * uv_scale;
	}

	// 0. 표면 결(밝기) — 흑백 디테일을 albedo 에 곱한다. 색은 그대로, 결만 생긴다.
	//    디테일 맵의 평균이 0.5 라 2배 해야 평균 1.0(=손대지 않음)이 된다.
	//    그냥 곱하면 물체가 통째로 절반 어두워지면서 파스텔 팔레트가 무너진다.
	if (use_detail) {
		float d = texture(detail_tex, tp.zy).r * tw.x
		        + texture(detail_tex, tp.xz).r * tw.y
		        + texture(detail_tex, tp.xy).r * tw.z;
		c *= mix(1.0, d * 2.0, detail_strength);
	}

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

	// 4. 표면 결(요철) — 빛이 실제로 걸리게 만드는 쪽. 사실 이쪽이 절반 이상을 한다.
	//    맨 마지막에 흔드는 게 중요하다. 위의 반구·접지·림은 전부 흔들리지 않은
	//    기하 노멀 기준으로 맞춰 둔 값이고, 특히 림은 실루엣 효과라 여기에 결이
	//    끼면 가장자리가 지글거린다.
	if (use_normal) {
		vec3 nx = texture(normal_tex, tp.zy).rgb * 2.0 - 1.0;
		vec3 ny = texture(normal_tex, tp.xz).rgb * 2.0 - 1.0;
		vec3 nz = texture(normal_tex, tp.xy).rgb * 2.0 - 1.0;
		// 각 평면의 접선 편차를 그 평면이 걸친 두 월드 축에 그대로 얹는다.
		//   x평면은 uv=(z,y) 니까 편차 x → 월드 z, 편차 y → 월드 y. 나머지도 같은 식.
		// 정석 삼중평면은 뒷면에서 u 를 뒤집지만, 여기 노멀 맵은 방향성 없는 잡음이라
		// 뒤집어도 눈에 안 보인다. 대신 식이 짧아져서 나중에 읽기 쉽다.
		vec3 bump = vec3(0.0, nx.y, nx.x) * tw.x
		          + vec3(ny.x, 0.0, ny.y) * tw.y
		          + vec3(nz.x, nz.y, 0.0) * tw.z;
		vec3 wn = normalize(normalize(world_normal) + bump * normal_strength);
		// NORMAL 은 뷰 공간이다. 월드에서 흔든 뒤 되돌려 넣는다.
		// NORMAL_MAP 을 안 쓰는 이유: 그건 메시의 UV 탄젠트 프레임을 타는데,
		// 삼중평면은 UV 를 안 쓰므로 프레임이 맞지 않는다.
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
}
"""

## 표면 종류를 답해 주는 쪽. class_name 을 안 쓰는 이유는 .godot 이 gitignore 라
## 새로 클론한 곳에서 "Identifier not declared" 로 죽기 때문이다. 실제로 당했다.
const SurfaceKit := preload("res://scripts/systems/surface_kit.gd")

## 씬마다 바닥 높이가 다르다. 잘못 주면 공중에 뜬 물체가 까맣게 된다.
@export var floor_y := 0.0
@export var ao_height := 1.15
@export var ao_amount := 0.30
@export var rim_amount := 0.62

var _shader: Shader
var _cache: Dictionary = {}          # "재질+표면" 키 → 만들어 둔 셰이더 재질
var _tex_cache: Dictionary = {}      # 텍스처 경로 → Texture2D (못 읽었으면 null)
var _surfaced := 0                   # 그중 결이 붙은 재질 수. 로그용.

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
	print("[DepthShading] 재질 %d 개 교체 (결 %d 개 / 텍스처 %d 장)"
		% [n, _surfaced, _tex_cache.size()])


## 반구조명 색을 갈아끼운다. 이미 만들어 둔 재질과 앞으로 만들 재질 모두에 적용된다.
func apply_hemi_tints(sky: Color, ground: Color) -> void:
	_sky_tint = sky
	_ground_tint = ground
	for k in _cache:
		var m: ShaderMaterial = _cache[k]
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
	# 표면 종류는 색이 아니라 노드 이름으로 갈리므로 이름을 같이 넘긴다.
	var sname := _surface_name(mi)
	if mi.material_override is StandardMaterial3D:
		mi.material_override = _shade(mi.material_override, sname)
		return 1
	if mi.mesh == null:
		return 0
	for i in mi.mesh.get_surface_count():
		var src := mi.get_active_material(i)
		if src is StandardMaterial3D:
			mi.set_surface_override_material(i, _shade(src, sname))
			n += 1
	return n


## SurfaceKit 에 물어볼 이름을 고른다.
##
## PropKit 의 _box/_cyl 은 label 인자가 선택이라 절반쯤은 이름 없이 만들어진다.
## 그러면 Godot 이 "MeshInstance3D" / "@MeshInstance3D@31" 을 붙이는데 거기엔
## 정보가 0 이다. 그럴 때는 한 칸 위, 프롭 뿌리의 이름을 쓴다 —
## PropKit._root 가 "BikeRack" 처럼 뜻이 있는 이름을 붙여 두기 때문이다.
## 한 칸만 올라간다. 계속 올라가면 결국 맵 이름("Office3D")까지 닿는다.
func _surface_name(mi: MeshInstance3D) -> String:
	var n := String(mi.name)
	if not _is_auto_name(n):
		return n
	var p := mi.get_parent()
	if p != null:
		var pn := String(p.name)
		if not _is_auto_name(pn):
			return pn
	return n


## Godot 이 알아서 붙인 이름인가. 겹치면 "@클래스명@숫자" 가 된다.
func _is_auto_name(n: String) -> bool:
	return n.is_empty() or n.begins_with("@") or n.begins_with("MeshInstance3D")


## StandardMaterial3D 의 겉모습을 그대로 옮긴 셰이더 재질을 만든다.
func _shade(src: StandardMaterial3D, node_name: String) -> Material:
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

	# 캐시 키가 재질만이면 안 된다. 같은 회색이라도 벽이면 콘크리트, 바닥이면
	# 아스팔트다. 재질로만 묶으면 먼저 만난 쪽의 결이 나머지 전부에 퍼진다.
	# 그렇다고 노드마다 새로 만들면 씬당 200개까지 가니, "재질 + 표면" 으로 묶는다.
	var kit := _kit_for(node_name, src.albedo_color)
	var key := "%d|%s" % [src.get_instance_id(), _kit_key(kit)]
	if _cache.has(key):
		return _cache[key]

	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("albedo", src.albedo_color)
	m.set_shader_parameter("roughness", src.roughness)
	m.set_shader_parameter("floor_y", floor_y)
	m.set_shader_parameter("ao_height", ao_height)
	m.set_shader_parameter("ao_amount", ao_amount)
	m.set_shader_parameter("rim_amount", rim_amount)
	_apply_surface(m, kit)           # roughness 를 덮어쓸 수 있으니 위 줄들보다 뒤에
	_write_hemi(m)                   # 스캔이 끝난 뒤 만들어지는 재질도 같은 무드를 따르게
	_cache[key] = m
	return m


## SurfaceKit 에게 "이 노드는 어떤 표면이냐" 를 묻는다.
## 계약이 어긋나도(Dictionary 가 아닌 걸 돌려줘도) 여기서 막는다. 결이 없는 지금
## 모습으로 나오면 되지, 이것 때문에 씬 전체가 안 서면 안 된다.
func _kit_for(node_name: String, albedo: Color) -> Dictionary:
	var r = SurfaceKit.for_node(node_name, albedo)
	return r if r is Dictionary else {}


## 같은 표면·같은 세기면 재질을 나눠 쓰라고 만드는 키.
func _kit_key(kit: Dictionary) -> String:
	if kit.is_empty():
		return "-"
	return "%s|%s|%.4f|%.4f|%.4f|%.4f" % [
		str(kit.get("detail", "")),
		str(kit.get("normal", "")),
		float(kit.get("uv_scale", 1.0)),
		float(kit.get("strength", 0.0)),
		float(kit.get("normal_strength", 0.0)),
		float(kit.get("roughness", -1.0)),
	]


## SurfaceKit 이 정해 준 결을 재질에 얹는다.
## 텍스처를 못 읽으면 그 장만 조용히 건너뛴다. 결이 없는 건 아쉬운 정도지만
## 화면이 까매지는 건 사고다.
func _apply_surface(m: ShaderMaterial, kit: Dictionary) -> void:
	if kit.is_empty():
		return
	var detail := _texture(str(kit.get("detail", "")))
	var normal := _texture(str(kit.get("normal", "")))
	if detail == null and normal == null:
		return

	m.set_shader_parameter("uv_scale", maxf(float(kit.get("uv_scale", 1.0)), 0.0001))
	if detail != null:
		m.set_shader_parameter("detail_tex", detail)
		m.set_shader_parameter("detail_strength", clampf(float(kit.get("strength", 0.5)), 0.0, 1.0))
		m.set_shader_parameter("use_detail", true)
	if normal != null:
		m.set_shader_parameter("normal_tex", normal)
		m.set_shader_parameter("normal_strength",
			clampf(float(kit.get("normal_strength", 0.6)), 0.0, 2.0))
		m.set_shader_parameter("use_normal", true)
	# 거칠기는 표면마다 다르다(젖은 타일과 마른 콘크리트). 안 주면 원래 값 그대로.
	if kit.has("roughness"):
		m.set_shader_parameter("roughness", clampf(float(kit["roughness"]), 0.0, 1.0))
	_surfaced += 1


## 텍스처는 경로당 한 번만 읽는다. 씬당 재질이 200개인데 그때마다 load 하면
## 같은 파일을 200번 읽는 셈이 된다.
func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	if t == null:
		# 임포트가 아직 안 돌았거나 파일이 없다. 한 번만 알리고 넘어간다.
		push_warning("[DepthShading] 표면 텍스처를 못 읽었다: %s" % path)
	_tex_cache[path] = t             # 실패도 적어 둔다. 같은 실패를 200번 반복하지 않게.
	return t
