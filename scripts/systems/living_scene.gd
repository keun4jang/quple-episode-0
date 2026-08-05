extends Node
## 화면을 살아있게 만든다.
##
## 지금까지는 움직이는 게 플레이어뿐이었다. 나머지가 전부 멈춰 있으면
## 아무리 잘 칠해도 정지 화면으로 보인다. 마이 오아시스가 중독성 있는 이유는
## 늘 뭔가 흔들리고 반짝이기 때문이다. 네 가지를 넣는다.
##
##   1. 떠다니는 먼지 — 카메라를 따라다니며 공기를 만든다
##   2. 흔들리는 잎 — 나무마다 다른 위상으로. 같이 흔들리면 가짜 티가 난다
##   3. 숨 쉬는 불빛 — 창문·가로등이 아주 느리게 밝아졌다 어두워진다
##   4. 카메라 호흡 — 손으로 든 것처럼 미세하게 흔들린다
##
## 전부 "있는지 모르겠지만 없으면 허전한" 세기로 맞춘다.
## 눈에 띄면 과한 것이다.

## 이름이 이걸로 끝나면 잎사귀로 본다
const FOLIAGE := ["Canopy", "Plant", "PlanterLeaf", "PotLeaf", "Leaf", "Bush"]

@export var dust_amount := 38
@export var sway := 0.035
@export var camera_breath := 0.010
@export var light_breath := 0.12

var _cam: Camera3D
var _dust: CPUParticles3D
var _lights: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	add_to_group("living_scene")
	# DepthShading 이 재질을 갈아끼운 뒤에 잎사귀를 켜야 한다
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		return
	_cam = _find_camera(scene)
	_collect(scene)
	_make_dust()


func _process(delta: float) -> void:
	_t += delta
	_breathe_lights()
	_breathe_camera()
	if _dust != null and _cam != null:
		# 먼지는 카메라를 따라다닌다. 안 그러면 걸어나가는 순간 공기가 사라진다.
		_dust.global_position = _cam.global_position - _cam.global_transform.basis.z * 6.0


# ── 수집 ───────────────────────────────────────────────────────────────

func _find_camera(n: Node) -> Camera3D:
	if n is Camera3D:
		return n
	for c in n.get_children():
		var r := _find_camera(c)
		if r != null:
			return r
	return null


func _collect(n: Node) -> void:
	if n is MeshInstance3D and _is_foliage(n.name):
		_enable_sway(n)
	elif n is OmniLight3D or n is SpotLight3D:
		# 불빛마다 다른 위상과 속도. 같은 박자로 깜빡이면 전광판처럼 보인다.
		_lights.append({
			"node": n,
			"base": n.light_energy,
			"phase": randf() * TAU,
			"speed": randf_range(0.35, 0.75),
		})
	for c in n.get_children():
		_collect(c)


func _is_foliage(name: String) -> bool:
	for f in FOLIAGE:
		if name.begins_with(f):
			return true
	return false


func _enable_sway(mi: MeshInstance3D) -> void:
	for m in _materials_of(mi):
		if m is ShaderMaterial:
			m.set_shader_parameter("sway_amount", sway)


func _materials_of(mi: MeshInstance3D) -> Array:
	var out := []
	if mi.material_override != null:
		out.append(mi.material_override)
	if mi.mesh != null:
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m != null:
				out.append(m)
	return out


# ── 움직임 ─────────────────────────────────────────────────────────────

func _breathe_lights() -> void:
	for l in _lights:
		var n: Light3D = l["node"]
		if not is_instance_valid(n):
			continue
		n.light_energy = l["base"] * (1.0 + sin(_t * l["speed"] + l["phase"]) * light_breath)


## 카메라를 직접 옮기면 맵 스크립트가 매 프레임 덮어쓴다.
## h_offset/v_offset 은 아무도 안 건드리므로 여기에 얹는다.
func _breathe_camera() -> void:
	if _cam == null:
		return
	_cam.h_offset = sin(_t * 0.43) * camera_breath + sin(_t * 0.27) * camera_breath * 0.6
	_cam.v_offset = sin(_t * 0.31 + 1.3) * camera_breath * 0.8


# ── 먼지 ───────────────────────────────────────────────────────────────

func _make_dust() -> void:
	if _cam == null:
		return
	var p := CPUParticles3D.new()
	p.amount = dust_amount
	p.lifetime = 9.0
	p.preprocess = 9.0                     # 처음부터 공중에 떠 있게
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(9, 4, 9)
	p.direction = Vector3(0.2, 1, 0)
	p.spread = 40.0
	p.gravity = Vector3(0, 0.045, 0)       # 아주 천천히 위로
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.16
	# 크기는 메시 자체로 정한다. scale_amount 에 맡겼더니 먹지 않아서
	# 화면을 덮는 흰 사각형이 됐다.
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.035, 0.035)
	p.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(1.0, 0.95, 0.82, 0.30)
	mat.vertex_color_use_as_albedo = true
	mat.disable_receive_shadows = true
	p.material_override = mat

	# 나타났다 사라지게. 갑자기 툭 생기면 눈에 띈다.
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 1))
	g.add_point(0.75, Color(1, 1, 1, 1))
	p.color_ramp = g   # CPUParticles3D 는 텍스처가 아니라 Gradient 를 직접 받는다

	add_child(p)
	p.emitting = true
	_dust = p
