class_name WornGear
extends RefCounted
## 착용 장비를 실제 메시로 그리는 공용 코드.
## 플레이어와 파트너가 같은 모양을 써야 해서 캐릭터 스크립트에서 떼어냈다.
## 전부 Godot 기본 프리미티브(Sphere/Box/Cylinder/Torus)로만 만든다.
##
## build(root, item_id) — root 아래에 그 아이템의 메시를 만든다.
##   ItemDB 아이템의 wear 필드(color/accent/style)와 slot 을 읽는다.

static func build(root: Node3D, item_id: String) -> void:
	if item_id == "":
		return
	var item = ItemDB.get_item(item_id)
	if item.is_empty():
		return
	var wear = item.get("wear", {})
	var col = Color(String(wear.get("color", "#E0645A")))
	var accent = Color(String(wear.get("accent", "#FFF6E4")))
	var style = String(wear.get("style", ""))
	match String(item.get("slot", "")):
		"scarf":
			_scarf(root, col, accent, style)
		"hat":
			_hat(root, col, accent, style)
		"gloves":
			_gloves(root, col, accent, style)
		"shoes":
			_shoes(root, col, accent, style)
		"tail":
			_tail(root, col, accent, style)

static func _scarf(root: Node3D, col: Color, accent: Color, style: String) -> void:
	# 목에 두르는 링
	var ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.14
	tm.outer_radius = 0.23
	ring.mesh = tm
	ring.material_override = _mat(col)
	root.add_child(ring)
	# 앞으로 늘어뜨린 자락
	var tail = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.11, 0.26, 0.06)
	tail.mesh = bm
	tail.material_override = _mat(col)
	tail.position = Vector3(0.07, -0.14, 0.25)
	tail.rotation_degrees = Vector3(10, 0, -6)
	root.add_child(tail)
	if style == "muffler":
		# 양쪽으로 길게 늘어뜨린 자락 (같이 두르는 목도리)
		for i in range(2):
			var side_tail = MeshInstance3D.new()
			var stm = BoxMesh.new()
			stm.size = Vector3(0.10, 0.34, 0.06)
			side_tail.mesh = stm
			side_tail.material_override = _mat(col)
			var sx = 0.16 if i == 0 else -0.16
			side_tail.position = Vector3(sx, -0.18, 0.18)
			side_tail.rotation_degrees = Vector3(8, 0, -6.0 if i == 0 else 6.0)
			root.add_child(side_tail)
			# 자락 끝 술
			var fringe = MeshInstance3D.new()
			var fm = BoxMesh.new()
			fm.size = Vector3(0.11, 0.05, 0.07)
			fringe.mesh = fm
			fringe.material_override = _mat(accent)
			fringe.position = Vector3(sx, -0.34, 0.19)
			root.add_child(fringe)
	elif style == "star":
		# 링 위에 박힌 작은 별빛
		for i in range(4):
			var star = MeshInstance3D.new()
			var sm = SphereMesh.new()
			sm.radius = 0.03
			sm.height = 0.06
			star.mesh = sm
			star.material_override = _mat(accent)
			var a = TAU * float(i) / 4.0 + 0.4
			star.position = Vector3(cos(a) * 0.19, 0.02, sin(a) * 0.19)
			root.add_child(star)
	else:
		# 자락에 들어간 줄무늬
		for i in range(2):
			var stripe = MeshInstance3D.new()
			var sbm = BoxMesh.new()
			sbm.size = Vector3(0.12, 0.04, 0.05)
			stripe.mesh = sbm
			stripe.material_override = _mat(accent)
			stripe.position = Vector3(0.07, -0.09 - float(i) * 0.1, 0.27)
			root.add_child(stripe)

static func _hat(root: Node3D, col: Color, accent: Color, style: String) -> void:
	var crown = MeshInstance3D.new()
	var cm = SphereMesh.new()
	cm.radius = 0.27
	cm.height = 0.26
	crown.mesh = cm
	crown.material_override = _mat(col)
	crown.scale = Vector3(1.0, 0.85, 1.0)
	root.add_child(crown)
	# 아래 테두리
	var band = MeshInstance3D.new()
	var bandm = CylinderMesh.new()
	bandm.top_radius = 0.30
	bandm.bottom_radius = 0.33
	bandm.height = 0.07
	band.mesh = bandm
	band.material_override = _mat(accent)
	band.position = Vector3(0, -0.06, 0)
	root.add_child(band)
	if style == "straw":
		# 사방으로 넓게 퍼진 챙 (밀짚모자)
		var wide = MeshInstance3D.new()
		var wm = CylinderMesh.new()
		wm.top_radius = 0.30
		wm.bottom_radius = 0.40  # 위에서 내려다보는 카메라라 더 넓으면 얼굴을 덮는다
		wm.height = 0.035
		wide.mesh = wm
		wide.material_override = _mat(col)
		wide.position = Vector3(0, -0.07, 0)
		root.add_child(wide)
		# 챙에 두른 띠
		var ribbon = MeshInstance3D.new()
		var rm = TorusMesh.new()
		rm.inner_radius = 0.28
		rm.outer_radius = 0.33
		ribbon.mesh = rm
		ribbon.material_override = _mat(accent)
		ribbon.position = Vector3(0, -0.04, 0)
		root.add_child(ribbon)
	elif style == "cap":
		# 앞으로 뻗은 챙
		var brim = MeshInstance3D.new()
		var brimm = BoxMesh.new()
		brimm.size = Vector3(0.30, 0.03, 0.20)
		brim.mesh = brimm
		brim.material_override = _mat(accent)
		brim.position = Vector3(0, -0.06, 0.30)
		brim.rotation_degrees = Vector3(-6, 0, 0)
		root.add_child(brim)
	else:
		# 방울
		var pom = MeshInstance3D.new()
		var pm = SphereMesh.new()
		pm.radius = 0.07
		pm.height = 0.14
		pom.mesh = pm
		pom.material_override = _mat(accent)
		pom.position = Vector3(0, 0.16, 0)
		root.add_child(pom)

static func _gloves(root: Node3D, col: Color, accent: Color, style: String) -> void:
	# 손을 감싸는 덩어리 (원래 손보다 한 겹 크게)
	var mitt = MeshInstance3D.new()
	var mm = SphereMesh.new()
	mm.radius = 0.092
	mm.height = 0.184
	mitt.mesh = mm
	mitt.material_override = _mat(col)
	if style == "glove" or style == "hold":
		# 장갑은 손 모양이 살아 있게 조금 갸름하게
		mitt.scale = Vector3(0.92, 1.05, 1.0)
	root.add_child(mitt)
	if style == "hold":
		# 손등에 올라간 작은 장식
		var stud = MeshInstance3D.new()
		var stm = SphereMesh.new()
		stm.radius = 0.035
		stm.height = 0.06
		stud.mesh = stm
		stud.material_override = _mat(accent)
		stud.position = Vector3(0, 0.02, 0.075)
		root.add_child(stud)
	# 손목 테두리
	var cuff = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.088
	cm.bottom_radius = 0.098
	cm.height = 0.055
	cuff.mesh = cm
	cuff.material_override = _mat(accent)
	cuff.position = Vector3(0, 0.085, 0)
	root.add_child(cuff)

static func _shoes(root: Node3D, col: Color, accent: Color, style: String) -> void:
	if style == "sandal":
		# 샌들은 발을 덮지 않는다 — 얇은 밑창 + 발등을 가로지르는 끈 두 개
		var plate = MeshInstance3D.new()
		var pm = BoxMesh.new()
		pm.size = Vector3(0.19, 0.03, 0.26)
		plate.mesh = pm
		plate.material_override = _mat(col)
		plate.position = Vector3(0, -0.05, 0.02)
		root.add_child(plate)
		for i in range(2):
			var strap = MeshInstance3D.new()
			var stm = BoxMesh.new()
			stm.size = Vector3(0.2, 0.03, 0.045)
			strap.mesh = stm
			strap.material_override = _mat(accent)
			strap.position = Vector3(0, 0.005 - float(i) * 0.02, -0.02 + float(i) * 0.12)
			strap.rotation_degrees = Vector3(12.0 * float(i), 0, 0)
			root.add_child(strap)
		return
	# 발등 (원래 발보다 한 겹 크게, 앞으로 길게)
	var shoe = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.098
	sm.height = 0.15
	shoe.mesh = sm
	shoe.material_override = _mat(col)
	shoe.scale = Vector3(1.05, 0.8, 1.4)
	root.add_child(shoe)
	# 밑창
	var sole = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.2, 0.035, 0.27)
	sole.mesh = bm
	sole.material_override = _mat(accent if style == "slipper" else Color("#3A3630"))
	sole.position = Vector3(0, -0.055, 0.02)
	root.add_child(sole)
	if style == "sneaker":
		# 발등 끈
		var lace = MeshInstance3D.new()
		var lm = BoxMesh.new()
		lm.size = Vector3(0.13, 0.02, 0.06)
		lace.mesh = lm
		lace.material_override = _mat(accent)
		lace.position = Vector3(0, 0.052, 0.05)
		root.add_child(lace)

static func _tail(root: Node3D, col: Color, accent: Color, style: String) -> void:
	# 꼬리를 감싸는 띠 (토러스 구멍이 꼬리 방향(Z)을 향하도록 눕힌다)
	var band = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.055
	tm.outer_radius = 0.095
	band.mesh = tm
	band.material_override = _mat(col)
	band.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(band)
	if style == "knot":
		# 매듭 — 겹쳐 묶은 두 덩이와 아래로 뻗은 짧은 끈
		for i in range(2):
			var lump = MeshInstance3D.new()
			var km = SphereMesh.new()
			km.radius = 0.05
			km.height = 0.085
			lump.mesh = km
			lump.material_override = _mat(accent)
			var kx = 0.045 if i == 0 else -0.045
			lump.position = Vector3(kx, -0.02, -0.03)
			lump.scale = Vector3(1.0, 1.0, 0.8)
			root.add_child(lump)
		var cord = MeshInstance3D.new()
		var cm2 = BoxMesh.new()
		cm2.size = Vector3(0.03, 0.12, 0.03)
		cord.mesh = cm2
		cord.material_override = _mat(accent)
		cord.position = Vector3(0, -0.1, -0.03)
		root.add_child(cord)
	elif style == "charm":
		# 별 장식 — 작은 구 하나에 십자 막대를 얹어 반짝임을 만든다
		var core = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.09
		core.mesh = sm
		core.material_override = _mat(accent)
		core.position = Vector3(0, -0.12, -0.02)
		root.add_child(core)
		for i in range(2):
			var spike = MeshInstance3D.new()
			var sbm = BoxMesh.new()
			sbm.size = Vector3(0.14, 0.025, 0.025)
			spike.mesh = sbm
			spike.material_override = _mat(accent)
			spike.position = Vector3(0, -0.12, -0.02)
			spike.rotation_degrees = Vector3(0, 0, 45.0 + 90.0 * float(i))
			root.add_child(spike)
	else:
		# 리본 — 양옆으로 뻗은 고리 두 개와 가운데 매듭
		for i in range(2):
			var loop = MeshInstance3D.new()
			var lm = SphereMesh.new()
			lm.radius = 0.055
			lm.height = 0.09
			loop.mesh = lm
			loop.material_override = _mat(accent)
			var side = 0.09 if i == 0 else -0.09
			loop.position = Vector3(side, 0.02, -0.02)
			loop.scale = Vector3(1.3, 0.7, 0.6)
			root.add_child(loop)
		var knot = MeshInstance3D.new()
		var km = SphereMesh.new()
		km.radius = 0.038
		km.height = 0.07
		knot.mesh = km
		knot.material_override = _mat(accent)
		knot.position = Vector3(0, 0.02, -0.02)
		root.add_child(knot)

static func _mat(col: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	return mat
