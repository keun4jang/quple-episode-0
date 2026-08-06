extends Node
## 표면 결이 셰이더와 재질에 실제로 물렸는가.
##
## 표면 판정(어떤 이름이 무슨 표면인가)은 tests/test_surface.gd 가 본다.
## 여기는 그 다음 칸 — DepthShading 이 그 답을 받아서 셰이더에 제대로 넣는가,
## 그리고 제일 중요한 것: **결이 없는 물체가 예전과 똑같이 나오는가**.
##
## 헤드리스에서 돈다. 화면이 있어야만 알 수 있는 것(파싱된 uniform 목록 등)은
## 값이 비면 실패가 아니라 건너뛴 것으로 센다.

const DepthShading := preload("res://scripts/systems/depth_shading.gd")
const SurfaceKit := preload("res://scripts/systems/surface_kit.gd")

## assets/textures 전체 용량 한도. APK 가 27MB 라 여기서 더 불리고 싶지 않다.
const TEX_DIR := "res://assets/textures"
const BUDGET_BYTES := 2 * 1024 * 1024

## 결을 받는 이름 하나를 찾을 때 쓴다. 씬에 실제로 있는 이름들이다.
const PROBE_NAMES := ["Floor", "BackWall", "Building", "Desk", "Canopy", "Bollard"]

var pass_n := 0
var fail_n := 0
var skip_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)
func sk(n: String, e := "") -> void:
	skip_n += 1; print("  – ", n, ("  " + e) if e else "")


func _ready() -> void:
	print("=== 표면 결 연결 테스트 ===")
	_test_budget()
	_test_shader()
	await _test_wiring()
	print("\n=== 결과: %d 통과 / %d 실패 / %d 건너뜀 ===" % [pass_n, fail_n, skip_n])
	get_tree().quit(0 if fail_n == 0 else 1)


# ── 1. 용량 ──────────────────────────────────────────────────────────────

func _test_budget() -> void:
	print("\n[1] 용량")
	var d := DirAccess.open(TEX_DIR)
	if d == null:
		ck("텍스처 폴더가 있다", false, TEX_DIR)
		return
	var total := 0
	var n := 0
	for f in d.get_files():
		# 임포트가 돌면 같은 자리에 .import 가 생긴다. 원본만 센다.
		var fname := str(f)
		if not fname.ends_with(".png"):
			continue
		var fa := FileAccess.open("%s/%s" % [TEX_DIR, fname], FileAccess.READ)
		if fa == null:
			continue
		total += fa.get_length()
		fa.close()
		n += 1
	ck("assets/textures 2MB 이하", total <= BUDGET_BYTES,
		"%d장 / %.2fMB" % [n, float(total) / 1048576.0])


# ── 2. 셰이더 ────────────────────────────────────────────────────────────

func _test_shader() -> void:
	print("\n[2] 셰이더")
	var code: String = DepthShading.SHADER

	# 기존 것들이 그대로 살아 있는가. 여기가 깨지면 화면 톤이 통째로 바뀐다.
	var kept := ["sky_tint", "ground_tint", "hemi_amount", "ao_height", "ao_amount",
		"floor_y", "rim_tint", "rim_amount", "rim_power", "sway_amount", "sway_speed"]
	var lost := []
	for k in kept:
		if not code.contains(str(k)):
			lost.append(k)
	ck("기존 uniform 이 그대로 있다", lost.is_empty(), str(lost))

	var added := ["detail_tex", "normal_tex", "uv_scale", "detail_strength",
		"normal_strength", "use_detail", "use_normal"]
	var miss := []
	for k in added:
		if not code.contains(str(k)):
			miss.append(k)
	ck("새 uniform 7개", miss.is_empty(), str(miss))

	ck("world_pos varying", code.contains("varying vec3 world_pos"))
	ck("삼중평면 가중치", code.contains("tri_weights"))
	# 디테일 맵 평균이 0.5 라 2배 보정이 없으면 씬 전체가 절반 어두워진다.
	ck("디테일 2배 보정", code.contains("d * 2.0"))

	# 두 장 다 색이 아니라 데이터다. source_color 가 붙으면 sRGB→선형 변환이 걸려서
	# 디테일 평균 0.5 가 0.21 로 읽히고, 그러면 씬이 통째로 어두워진다.
	var srgb := []
	for line in code.split("\n"):
		if line.contains("uniform sampler2D") and line.contains("source_color"):
			srgb.append(line.strip_edges())
	ck("텍스처 uniform 에 source_color 가 없다", srgb.is_empty(), str(srgb))

	# 렌더러가 살아 있으면 실제로 파싱된 uniform 목록을 볼 수 있다. 더미면 빈 목록.
	var sh := Shader.new()
	sh.code = code
	var names := []
	for u in sh.get_shader_uniform_list():
		names.append(str(u.get("name", "")))
	if names.is_empty():
		sk("셰이더 파싱", "헤드리스 더미 렌더러라 uniform 목록이 비어 있다")
	else:
		var not_found := []
		for k in added:
			if not names.has(k):
				not_found.append(k)
		ck("파싱된 uniform 에 새 항목이 있다", not_found.is_empty(), str(not_found))


# ── 3. DepthShading 이 실제로 물리는가 ───────────────────────────────────

func _test_wiring() -> void:
	print("\n[3] DepthShading 연결")
	var gray := Color(0.72, 0.72, 0.74)
	var plain_name := "__민무늬_zzz__"

	# 결이 붙는 이름 하나를 찾는다. SurfaceKit 의 어휘를 여기서 못 박지 않으려고
	# 목록에서 골라 쓴다 — 규칙표가 바뀌어도 이 테스트는 안 깨진다.
	var probe := ""
	for n in PROBE_NAMES:
		if not SurfaceKit.for_node(str(n), gray).is_empty():
			probe = str(n)
			break
	var surf := probe if probe != "" else plain_name

	var plain := _mesh(plain_name, _mat(gray))
	# 재질 하나를 셋이 나눠 쓴다. 표면이 다르면 갈라지고 같으면 합쳐져야 한다.
	var shared := _mat(gray)
	var sh_a := _mesh(surf, shared)
	var sh_b := _mesh(plain_name, shared)
	var sh_c := _mesh(surf, shared)

	# 이름 없는 메시. PropKit 의 label 인자가 선택이라 실제로 절반쯤이 이렇다.
	# 이때는 프롭 뿌리(부모)의 이름을 대신 봐야 한다.
	var fb_holder := Node3D.new()
	fb_holder.name = surf
	add_child(fb_holder)
	var fb := MeshInstance3D.new()          # 일부러 이름을 안 준다
	fb.mesh = BoxMesh.new()
	fb.material_override = shared
	fb_holder.add_child(fb)

	var ds := Node.new()
	ds.set_script(DepthShading)
	add_child(ds)
	# _ready 가 한 프레임 기다렸다가 훑는다. 넉넉히 세 번 넘긴다.
	for i in 3:
		await get_tree().process_frame

	var pm = plain.material_override
	ck("재질이 셰이더 재질로 바뀐다", pm is ShaderMaterial)
	if pm is ShaderMaterial:
		# 표면이 없으면 결 관련 값을 아예 안 넣는다 = 예전과 완전히 같은 그림.
		var m: ShaderMaterial = pm
		ck("결 없는 재질은 use_detail 을 안 켠다", m.get_shader_parameter("use_detail") != true)
		ck("결 없는 재질은 use_normal 을 안 켠다", m.get_shader_parameter("use_normal") != true)
		var a = m.get_shader_parameter("albedo")
		ck("albedo 는 그대로 넘어간다", a is Color and (a as Color).is_equal_approx(gray))

	# 캐시 키가 재질만이면 같은 회색인 벽과 바닥이 같은 결을 쓰게 된다.
	ck("같은 재질 + 같은 표면 = 재질을 나눠 쓴다",
		sh_a.material_override == sh_c.material_override)
	if probe == "":
		sk("같은 재질 + 다른 표면 = 갈라진다", "SurfaceKit 이 아는 이름을 못 찾았다")
	else:
		ck("같은 재질 + 다른 표면 = 갈라진다",
			sh_a.material_override != sh_b.material_override)
	# 이름 없는 메시가 부모 이름을 따라갔다면 sh_a 와 같은 재질에 묶인다.
	ck("이름 없는 메시는 부모(프롭 뿌리) 이름을 쓴다",
		fb.material_override == sh_a.material_override, "부모=%s" % surf)

	if probe == "":
		sk("결 있는 재질", "SurfaceKit 이 아는 이름을 못 찾았다")
		return
	if not (sh_a.material_override is ShaderMaterial):
		ck("결 있는 재질도 셰이더 재질", false)
		return

	var m2: ShaderMaterial = sh_a.material_override
	if m2.get_shader_parameter("use_detail") != true:
		# 임포트 전이면 텍스처를 못 읽는다. 그때 화면이 까매지지 않고
		# 결만 빠지는 게 설계다.
		sk("결 켜짐 (%s)" % probe, "텍스처를 못 읽어 결 없이 넘어갔다 — 에디터 임포트 필요")
		ck("못 읽어도 albedo 는 살아 있다", m2.get_shader_parameter("albedo") != null)
		return
	ck("use_detail 켜짐 (%s)" % probe, true)
	ck("use_normal 켜짐", m2.get_shader_parameter("use_normal") == true)
	ck("디테일 텍스처가 들어갔다", m2.get_shader_parameter("detail_tex") is Texture2D)
	ck("노멀 텍스처가 들어갔다", m2.get_shader_parameter("normal_tex") is Texture2D)
	var uv = m2.get_shader_parameter("uv_scale")
	ck("uv_scale 이 0 보다 크다", uv != null and float(uv) > 0.0, str(uv))
	var s = m2.get_shader_parameter("detail_strength")
	ck("세기가 0~1", s != null and float(s) >= 0.0 and float(s) <= 1.0, str(s))


func _mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	return mat


## 이름이 겹치면 Godot 이 뒤에 다른 이름을 붙여 버린다. 표면 판정이 이름으로
## 갈리니 하나씩 따로 담아서 이름을 지킨다.
func _mesh(node_name: String, mat: StandardMaterial3D) -> MeshInstance3D:
	var holder := Node3D.new()
	add_child(holder)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = BoxMesh.new()
	mi.material_override = mat
	holder.add_child(mi)
	return mi
