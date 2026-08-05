extends Node
## 화면이 실제로 살아 움직이는가.
##
## 스크린샷으로는 "움직임"을 확인할 수 없다. 정지 화면은 멈춘 씬과 구별이 안 된다.
## 그래서 값이 시간에 따라 실제로 변하는지 직접 잰다.

var pass_n := 0
var fail_n := 0
func ck(n: String, c: bool, e := "") -> void:
	if c: pass_n += 1; print("  ✔ ", n, ("  " + e) if e else "")
	else: fail_n += 1; print("  ✘ ", n, "  ", e)


func _ready() -> void:
	print("=== 살아있는 화면 테스트 ===")
	var map = load("res://scenes/maps/CompanyFront3D.tscn").instantiate()
	add_child(map)
	for i in 30:
		await get_tree().process_frame

	var ls = get_tree().get_first_node_in_group("living_scene")
	var ds = get_tree().get_first_node_in_group("depth_shading")
	ck("LivingScene 이 붙어 있다", ls != null)
	ck("DepthShading 이 붙어 있다", ds != null)
	if ls == null:
		_done()
		return

	print("\n[1] 명암 — 재질이 셰이더로 바뀌었나")
	var shaded := _count_shaded(map)
	ck("셰이더 재질로 교체됨", shaded > 50, "%d 개" % shaded)

	print("\n[2] 흔들리는 잎")
	var swaying := _count_swaying(map)
	ck("잎사귀에 흔들림이 켜졌다", swaying > 0, "%d 개" % swaying)
	# 나무마다 위상이 다르다는 건 셰이더가 월드 좌표로 만든다. 여기선 켜졌는지만 본다.

	print("\n[3] 숨 쉬는 불빛")
	ck("불빛을 찾았다", ls._lights.size() > 0, "%d 개" % ls._lights.size())
	var before: Array[float] = []
	for l in ls._lights:
		before.append(l["node"].light_energy)
	for i in 45:
		await get_tree().process_frame
	var moved := 0
	for i in ls._lights.size():
		if absf(ls._lights[i]["node"].light_energy - before[i]) > 0.0001:
			moved += 1
	ck("시간이 지나면 밝기가 변한다", moved > 0, "%d/%d 개" % [moved, ls._lights.size()])
	# 밝기가 0 이 되거나 두 배가 되면 깜빡이는 티가 난다
	var sane := true
	for l in ls._lights:
		var r: float = l["node"].light_energy / maxf(l["base"], 0.0001)
		if r < 0.8 or r > 1.2:
			sane = false
	ck("밝기 변화가 과하지 않다 (±20% 이내)", sane)

	print("\n[4] 카메라 호흡")
	var cam: Camera3D = ls._cam
	ck("카메라를 찾았다", cam != null)
	if cam != null:
		var h0 := cam.h_offset
		for i in 40:
			await get_tree().process_frame
		ck("오프셋이 움직인다", absf(cam.h_offset - h0) > 0.0001,
			"%.5f → %.5f" % [h0, cam.h_offset])
		ck("흔들림이 미세하다 (0.05 이내)", absf(cam.h_offset) < 0.05 and absf(cam.v_offset) < 0.05,
			"h %.4f v %.4f" % [cam.h_offset, cam.v_offset])

	print("\n[5] 떠다니는 먼지")
	ck("먼지가 생성됐다", ls._dust != null)
	if ls._dust != null:
		ck("먼지가 뿜어지고 있다", ls._dust.emitting)
		# 처음에 화면을 덮는 흰 사각형이 됐던 적이 있다. 크기를 못 박아 둔다.
		var sz: Vector2 = ls._dust.mesh.size
		ck("먼지가 작다", sz.x < 0.1 and sz.y < 0.1, "%.3f x %.3f" % [sz.x, sz.y])
		if cam != null:
			var d0: Vector3 = ls._dust.global_position
			var moved_cam := cam.global_position
			for i in 20:
				await get_tree().process_frame
			ck("먼지가 카메라를 따라온다",
				ls._dust.global_position.distance_to(cam.global_position) < 12.0,
				"%.1f m" % ls._dust.global_position.distance_to(cam.global_position))
	_done()


func _done() -> void:
	print("\n=== 결과: %d 통과 / %d 실패 ===" % [pass_n, fail_n])
	get_tree().quit(0 if fail_n == 0 else 1)


func _count_shaded(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D:
		for m in _materials_of(n):
			if m is ShaderMaterial:
				c += 1
	for k in n.get_children():
		c += _count_shaded(k)
	return c


func _count_swaying(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D:
		for m in _materials_of(n):
			if not (m is ShaderMaterial):
				continue
			# 값을 설정한 적이 없으면 null 이 온다. float(null) 은 에러다.
			var v = m.get_shader_parameter("sway_amount")
			if typeof(v) == TYPE_FLOAT and v > 0.0:
				c += 1
	for k in n.get_children():
		c += _count_swaying(k)
	return c


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
