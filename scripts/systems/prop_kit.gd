extends RefCounted
## 5개 3D 씬이 함께 쓰는 프롭 라이브러리.
##
## 지금 건물은 창문만 붙은 직육면체다. 하늘을 배경으로 한 윤곽선에 정보가 없으면
## 아무리 잘 칠해도 싸구려로 보인다. 그래서 실루엣을 깨는 것들 — 옥상 기계실,
## 물탱크, 안테나, 외벽 배관, 세로 간판 — 을 한곳에 모아 둔다.
##
## 쓰는 법. 쓰는 쪽 파일 맨 위에 preload 상수를 하나 두고 부른다.
## 전부 static 이라 인스턴스는 만들지 않는다.
##
##   const PropKit := preload("res://scripts/systems/prop_kit.gd")
##
##   PropKit.parapet(self, Vector3(0, 18, -6), Vector2(10, 2))
##   PropKit.water_tank(self, Vector3(2.4, 18.2, -6))
##   PropKit.tree_tall(self, Vector3(-8, 0, 0))
##
## class_name 을 일부러 쓰지 않는다.
## class_name 으로 만든 전역 이름은 .godot/global_script_class_cache.cfg 에 등록돼야
## 파서가 찾는데, 그 파일은 에디터가 스캔할 때만 갱신된다. .godot 은 gitignore 대상이라
## 새로 클론했거나 캐시가 이 파일보다 오래된 환경(CI, 다른 에이전트 샌드박스)에서는
## 5개 맵 스크립트가 전부 'Identifier "PropKit" not declared' 로 죽는다.
## preload 는 경로로 바로 찾으므로 캐시 상태와 상관없이 항상 뜬다.
##
## 함수마다 (parent, pos, ...) 를 받아 Node3D 뿌리를 만들어 붙이고 그걸 돌려준다.
## 돌려받은 뿌리를 더 회전시키거나 숨기는 건 부르는 쪽 마음이다.
##
## 세 가지 규칙을 지킨다.
##
##   1. 잎사귀·수풀 노드 이름은 "Canopy"/"Leaf"/"Bush"/"Plant" 로 시작한다.
##      LivingScene 이 이름만 보고 바람에 흔들어 준다. 이름을 바꾸면 멈춘다.
##   2. 변형은 pos 를 시드로 한 결정적 해시로 준다. randf() 는 쓰지 않는다.
##      실행할 때마다 모양이 달라지면 테스트가 흔들린다.
##   3. 빛나야 하는 것은 emission_enabled = true 로 만든다.
##      DepthShading 이 발광 재질만 원본 그대로 남겨 두기 때문이다.
##
## 함수 하나가 메시 20개를 넘지 않는다. 모바일이다.


# ── 결정적 난수 ─────────────────────────────────────────────────────────
#
# 같은 함수를 여러 번 불렀는데 전부 똑같이 생기면 복붙 티가 난다.
# 그렇다고 randf() 를 쓰면 실행할 때마다 씬이 달라져서 테스트가 못 믿을 게 된다.
# 그래서 pos 를 정수로 굳혀 해시를 돌린다. 같은 자리 = 언제나 같은 모양.

const _SEED_BASE := 0x2F6E2B1
const _MASK := 0x7FFFFFFF

## 정수 한 번 섞기. 매 단계 31비트로 잘라서 64비트 넘침이 안 나게 한다.
static func _mix(h: int, v: int) -> int:
	var x := (h ^ v) & _MASK
	x = (x * 1103515245 + 12345) & _MASK
	x = (x ^ (x >> 13)) & _MASK
	return x

## pos + salt → 0~1. salt 만 바꿔 가며 한 프롭에서 여러 값을 뽑는다.
static func _rnd(pos: Vector3, salt: int) -> float:
	# 1mm 단위로 굳힌다. float 오차 때문에 값이 튀지 않게.
	var h := _mix(_SEED_BASE, salt)
	h = _mix(h, int(round(pos.x * 1000.0)))
	h = _mix(h, int(round(pos.y * 1000.0)))
	h = _mix(h, int(round(pos.z * 1000.0)))
	return float(h % 100003) / 100003.0

## lo~hi 사이의 결정적 값
static func _rr(pos: Vector3, salt: int, lo: float, hi: float) -> float:
	return lo + (hi - lo) * _rnd(pos, salt)

## 색조와 밝기만 아주 조금 흔든다. 채도는 건드리지 않는다 — 파스텔 톤이 깨진다.
static func _tint(hex: String, pos: Vector3, salt: int, amount := 0.07) -> Color:
	var c := Color(hex)
	var h := fposmod(c.h + (_rnd(pos, salt) - 0.5) * 0.03, 1.0)
	var v := clampf(c.v + (_rnd(pos, salt + 977) - 0.5) * 2.0 * amount, 0.10, 0.97)
	return Color.from_hsv(h, c.s, v)


# ── 메시 헬퍼 ───────────────────────────────────────────────────────────
#
# 분할 수를 기본값보다 낮춘다. SphereMesh 기본이 64x32 라서, 그대로 두면
# 나무 한 그루에 수천 폴리곤이 들어간다. 이 크기에서는 차이가 안 보인다.

const SPHERE_SEG := 16
const SPHERE_RING := 8
const CYL_SEG := 12

static func _mat(col: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m

## 발광 재질. DepthShading 이 이건 건드리지 않고 원본을 남긴다.
static func _glow_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.roughness = 0.5
	return m

## 프롭 하나를 담는 뿌리. 벽에 붙는 것들은 yaw_deg 로 돌려서 쓴다.
static func _root(parent: Node3D, pos: Vector3, label: String, yaw_deg := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = label
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	parent.add_child(n)
	return n

static func _box(parent: Node3D, pos: Vector3, size: Vector3, col: Color, label := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if label != "": mi.name = label
	var m := BoxMesh.new(); m.size = size
	mi.mesh = m; mi.position = pos
	mi.material_override = _mat(col)
	parent.add_child(mi)
	return mi

static func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float, col: Color, label := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if label != "": mi.name = label
	var m := CylinderMesh.new()
	m.top_radius = radius; m.bottom_radius = radius; m.height = height
	m.radial_segments = CYL_SEG; m.rings = 0
	mi.mesh = m; mi.position = pos
	mi.material_override = _mat(col)
	parent.add_child(mi)
	return mi

## 원뿔. 침엽수와 물탱크 지붕에 쓴다. 꼭짓점을 완전히 0 으로 두면 정점이 뭉쳐서
## 셰이딩이 지저분해지므로 아주 얇게 남긴다.
static func _cone(parent: Node3D, pos: Vector3, radius: float, height: float, col: Color, label := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if label != "": mi.name = label
	var m := CylinderMesh.new()
	m.top_radius = radius * 0.04; m.bottom_radius = radius; m.height = height
	m.radial_segments = CYL_SEG; m.rings = 0
	mi.mesh = m; mi.position = pos
	mi.material_override = _mat(col)
	parent.add_child(mi)
	return mi

static func _sphere(parent: Node3D, pos: Vector3, radius: float, col: Color, label := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if label != "": mi.name = label
	var m := SphereMesh.new()
	m.radius = radius; m.height = radius * 2.0
	m.radial_segments = SPHERE_SEG; m.rings = SPHERE_RING
	mi.mesh = m; mi.position = pos
	mi.material_override = _mat(col)
	parent.add_child(mi)
	return mi

## 삼각 단면 기둥. 박공지붕처럼 위가 뾰족한 실루엣에 쓴다.
## 단면은 XY 평면, 두께는 Z 방향이다.
static func _prism(parent: Node3D, pos: Vector3, size: Vector3, col: Color, label := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if label != "": mi.name = label
	var m := PrismMesh.new()
	m.size = size
	m.subdivide_width = 0; m.subdivide_height = 0; m.subdivide_depth = 0
	mi.mesh = m; mi.position = pos
	mi.material_override = _mat(col)
	parent.add_child(mi)
	return mi


# ── 옥상 / 건물 실루엣 ──────────────────────────────────────────────────

## 옥상 기계실. 크기가 매번 조금씩 달라야 옥상이 여러 채처럼 보인다.
## 메시 8개.
static func rooftop_unit(parent: Node3D, pos: Vector3, hex := "#5A6476", scale_hint := 1.0, yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, pos, "RooftopUnit", yaw_deg + _rr(pos, 9, -8.0, 8.0))
	var w := _rr(pos, 1, 1.1, 1.9) * scale_hint
	var d := _rr(pos, 2, 0.9, 1.5) * scale_hint
	var h := _rr(pos, 3, 0.7, 1.35) * scale_hint
	var col := _tint(hex, pos, 4)
	var dark := _tint(hex, pos, 5, 0.04).darkened(0.22)

	_box(root, Vector3(0, h * 0.5, 0), Vector3(w, h, d), col, "UnitBody")
	# 처마가 조금 튀어나와야 옆에서 봐도 상자가 아니라 건물로 읽힌다
	_box(root, Vector3(0, h + 0.05, 0), Vector3(w + 0.16, 0.1, d + 0.16), dark, "UnitCap")
	# 지붕은 살짝 박공. 옥상 실루엣에 사선이 하나 들어가면 인상이 확 달라진다.
	_prism(root, Vector3(0, h + 0.24, 0), Vector3(w + 0.16, 0.3, d + 0.16), _tint(hex, pos, 6, 0.10), "UnitRoof")
	# 환기구 2개
	for i in range(2):
		var vx := (float(i) - 0.5) * w * 0.44
		var vh := _rr(pos, 10 + i, 0.18, 0.34)
		_cyl(root, Vector3(vx, h + 0.28 + vh * 0.5, d * 0.18), _rr(pos, 20 + i, 0.09, 0.15), vh, dark, "UnitVent%d" % i)
	# 팬 그릴 — 옆면에 원이 하나 있으면 면이 비어 보이지 않는다
	var fan := _cyl(root, Vector3(0, h * 0.55, d * 0.5 + 0.03), h * 0.24, 0.05, dark, "UnitFan")
	fan.rotation_degrees.x = 90.0
	# 점검문
	_box(root, Vector3(-w * 0.26, h * 0.4, d * 0.5 + 0.02), Vector3(w * 0.3, h * 0.66, 0.03), dark, "UnitDoor")
	# 바닥 받침
	_box(root, Vector3(0, 0.05, 0), Vector3(w + 0.1, 0.1, d + 0.1), dark, "UnitBase")
	return root


## 원통 물탱크 + 다리 4개. 옥상에 하나만 얹어도 윤곽이 확 살아난다.
## 메시 13개.
static func water_tank(parent: Node3D, pos: Vector3, hex := "#9AA6B4", scale_hint := 1.0) -> Node3D:
	var root := _root(parent, pos, "WaterTank", _rr(pos, 0, 0.0, 90.0))
	var r := _rr(pos, 1, 0.55, 0.85) * scale_hint
	var leg_h := _rr(pos, 2, 0.9, 1.5) * scale_hint
	var body_h := _rr(pos, 3, 1.1, 1.7) * scale_hint
	var col := _tint(hex, pos, 4)
	var steel := _tint("#77808E", pos, 5, 0.05)

	# 다리 4개. 아래가 비어 있어야 하늘이 비쳐서 실루엣이 재미있어진다.
	for i in range(4):
		var a := TAU * float(i) / 4.0 + PI * 0.25
		_box(root, Vector3(cos(a) * r * 0.72, leg_h * 0.5, sin(a) * r * 0.72),
			Vector3(0.09, leg_h, 0.09), steel, "TankLeg%d" % i)
	_cyl(root, Vector3(0, leg_h + 0.04, 0), r * 1.02, 0.08, steel, "TankBase")
	_cyl(root, Vector3(0, leg_h + body_h * 0.5 + 0.08, 0), r, body_h, col, "TankBody")
	# 허리띠 2줄. 원통 하나만 두면 크기가 안 읽힌다.
	for i in range(2):
		var by := leg_h + 0.08 + body_h * (0.32 + float(i) * 0.38)
		_cyl(root, Vector3(0, by, 0), r * 1.03, 0.06, steel, "TankBand%d" % i)
	_cone(root, Vector3(0, leg_h + body_h + 0.08 + r * 0.28, 0), r * 1.05, r * 0.56,
		_tint(hex, pos, 6, 0.12).darkened(0.12), "TankRoof")
	# 사다리. 가는 선이 하나 붙으면 스케일이 단숨에 읽힌다.
	for i in range(2):
		var lx := (float(i) - 0.5) * 0.22
		_box(root, Vector3(lx, (leg_h + body_h) * 0.5 + 0.1, r + 0.06),
			Vector3(0.035, leg_h + body_h, 0.035), steel, "TankLadder%d" % i)
	for i in range(3):
		var ry := leg_h * 0.4 + float(i) * (leg_h + body_h) * 0.28
		_box(root, Vector3(0, ry, r + 0.06), Vector3(0.24, 0.03, 0.03), steel, "TankRung%d" % i)
	return root


## 가느다란 안테나 + 빨간 항공장애등. 하늘에 선 하나가 그어지면 건물 키가 살아난다.
## 등은 발광이라 CinematicLook 의 글로우가 번지게 잡아 준다. 메시 9개.
static func antenna(parent: Node3D, pos: Vector3, height := 3.2, hex := "#A6AEBC") -> Node3D:
	var root := _root(parent, pos, "Antenna", _rr(pos, 0, 0.0, 180.0))
	var h := height * _rr(pos, 1, 0.8, 1.25)
	var col := _tint(hex, pos, 2, 0.06)

	_box(root, Vector3(0, 0.06, 0), Vector3(0.34, 0.12, 0.34), _tint("#5E6774", pos, 3), "AntBase")
	_cyl(root, Vector3(0, h * 0.5, 0), 0.045, h, col, "AntMast")
	# 버팀줄 3가닥. 마스트만 있으면 종이에 그은 선처럼 보인다.
	for i in range(3):
		var a := TAU * float(i) / 3.0
		var reach := h * 0.34
		var guy := _box(root, Vector3(cos(a) * reach * 0.5, h * 0.34, sin(a) * reach * 0.5),
			Vector3(0.025, h * 0.72, 0.025), _tint("#6B7482", pos, 10 + i), "AntGuy%d" % i)
		guy.rotation_degrees.y = rad_to_deg(-a)
		guy.rotation_degrees.z = rad_to_deg(atan2(reach * 0.5, h * 0.34))
	# 가로대 2단
	for i in range(2):
		var cy := h * (0.58 + float(i) * 0.2)
		_box(root, Vector3(0, cy, 0), Vector3(_rr(pos, 20 + i, 0.4, 0.7), 0.035, 0.035), col, "AntCross%d" % i)
	# 접시 안테나 — 납작한 원기둥이면 충분하다
	var dish := _cyl(root, Vector3(0.16, h * 0.46, 0), 0.16, 0.05, _tint("#D6DAE2", pos, 30), "AntDish")
	dish.rotation_degrees = Vector3(72.0, 0.0, 0.0)
	# 항공장애등. 채도 높은 원색은 안 쓴다. 부드러운 코랄로.
	var beacon := _sphere(root, Vector3(0, h + 0.09, 0), 0.075, Color("#F2726F"), "AntBeacon")
	beacon.material_override = _glow_mat(Color("#F2726F"), 2.6)
	return root


## 벽에 붙는 에어컨 실외기. 격자로 잡되 칸 안에서 흩뿌린다.
## 줄을 딱 맞추면 전광판처럼 보이고, 완전히 흩으면 지저분해진다.
## count 는 1~6 으로 자른다 (유닛당 메시 3개, 최대 18개).
static func ac_units(parent: Node3D, pos: Vector3, count := 4, area := Vector2(3.0, 2.0), hex := "#C2C9D4", yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, pos, "AcUnits", yaw_deg)
	var n := clampi(count, 1, 6)
	var cols := mini(n, 3)
	var rows := int(ceil(float(n) / float(cols)))
	for i in range(n):
		var cx := i % cols
		var cy := floori(float(i) / float(cols))
		var gx := (float(cx) + 0.5) / float(cols) - 0.5
		var gy := (float(cy) + 0.5) / float(rows) - 0.5
		var p := Vector3(gx * area.x + _rr(pos, 100 + i, -0.16, 0.16),
			gy * area.y + _rr(pos, 200 + i, -0.12, 0.12), 0.0)
		var w := _rr(pos, 300 + i, 0.52, 0.74)
		var uh := _rr(pos, 400 + i, 0.36, 0.54)
		var col := _tint(hex, pos, 500 + i, 0.06)
		_box(root, p + Vector3(0, 0, 0.18), Vector3(w, uh, 0.34), col, "AcBody%d" % i)
		# 앞면 팬 그릴
		var fan := _cyl(root, p + Vector3(0, 0, 0.36), uh * 0.33, 0.04, _tint("#8A929E", pos, 600 + i), "AcFan%d" % i)
		fan.rotation_degrees.x = 90.0
		# 벽 브래킷 — 실외기가 공중에 떠 있는 이유가 보여야 한다
		_box(root, p + Vector3(0, -uh * 0.5 - 0.04, 0.15), Vector3(w * 0.88, 0.06, 0.3),
			Color("#6E7684"), "AcBracket%d" % i)
	return root


## 옥상 난간. 건물 꼭대기가 칼로 자른 듯 평평하면 종이 같다.
## 얇은 테두리 하나로 위쪽 실루엣에 선이 두 겹 생긴다. 메시 8개.
static func parapet(parent: Node3D, pos: Vector3, size := Vector2(10.0, 4.0), height := 0.55, hex := "#46536A", yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, pos, "Parapet", yaw_deg)
	var t := 0.16
	var col := _tint(hex, pos, 1, 0.05)
	var cap := _tint(hex, pos, 2, 0.05).lightened(0.14)
	var hw := size.x * 0.5
	var hd := size.y * 0.5
	var sides := [
		[Vector3(0, height * 0.5, -hd + t * 0.5), Vector3(size.x, height, t)],
		[Vector3(0, height * 0.5, hd - t * 0.5), Vector3(size.x, height, t)],
		[Vector3(-hw + t * 0.5, height * 0.5, 0), Vector3(t, height, maxf(size.y - t * 2.0, t))],
		[Vector3(hw - t * 0.5, height * 0.5, 0), Vector3(t, height, maxf(size.y - t * 2.0, t))],
	]
	for i in range(sides.size()):
		var sp: Vector3 = sides[i][0]
		var ss: Vector3 = sides[i][1]
		_box(root, sp, ss, col, "ParapetWall%d" % i)
		# 갓돌. 조금 더 넓게 얹어야 그늘이 생겨서 두께가 읽힌다.
		_box(root, Vector3(sp.x, height + 0.045, sp.z), Vector3(ss.x + 0.1, 0.09, ss.z + 0.1), cap, "ParapetCap%d" % i)
	return root


## 세로 간판. 벽에서 팔로 뻗어 나와야 실루엣이 생긴다.
## 판은 은은하게, 글자칸만 밝게. 간판 전체가 새하얗게 타면 파스텔이 깨진다. 메시 8개.
static func vertical_sign(parent: Node3D, pos: Vector3, height := 3.2, hex := "#FFD76D", yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, pos, "VerticalSign", yaw_deg)
	var w := _rr(pos, 1, 0.5, 0.72)
	var h := height * _rr(pos, 2, 0.9, 1.1)
	var col := _tint(hex, pos, 3, 0.05)

	# 벽에서 뻗는 팔 2개
	for i in range(2):
		var ay := -0.28 - float(i) * maxf(h - 0.72, 0.2)
		_box(root, Vector3(0, ay, 0.14), Vector3(0.07, 0.07, 0.3), Color("#5A6270"), "SignArm%d" % i)
	# 뒤판(테두리) + 앞면(발광)
	_box(root, Vector3(0, -h * 0.5, 0.27), Vector3(w + 0.08, h + 0.08, 0.1), Color("#3C4554"), "SignFrame")
	var face := _box(root, Vector3(0, -h * 0.5, 0.33), Vector3(w, h, 0.04), col, "SignFace")
	face.material_override = _glow_mat(col, 0.9)
	# 글자칸. 세로 간판은 글자가 한 칸씩 쌓여야 세로로 읽힌다.
	var slots := 4
	var step := h / float(slots + 1)
	for i in range(slots):
		var sy := -h * 0.5 + (float(slots - 1) * 0.5 - float(i)) * step
		var g := _box(root, Vector3(0, sy, 0.36), Vector3(w * 0.5, step * 0.5, 0.02), Color("#FFF6DC"), "SignGlyph%d" % i)
		g.material_override = _glow_mat(Color("#FFF6DC"), 2.0)
	return root


## 1층 차양. 기울어진 판이라 건물 아랫부분에 그늘과 두께가 생긴다.
## 수평으로 두면 차양이 아니라 선반으로 보인다. 메시 8개.
static func awning(parent: Node3D, pos: Vector3, width := 3.0, depth := 1.2, hex := "#C98BA0", yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, pos, "Awning", yaw_deg)
	var w := width * _rr(pos, 1, 0.94, 1.06)
	var d := depth * _rr(pos, 2, 0.92, 1.1)
	var tilt := _rr(pos, 3, 16.0, 26.0)
	var col := _tint(hex, pos, 4, 0.06)

	var tilt_node := Node3D.new()
	tilt_node.name = "AwningTilt"
	tilt_node.rotation_degrees.x = -tilt
	root.add_child(tilt_node)

	_box(tilt_node, Vector3(0, 0, d * 0.5), Vector3(w, 0.06, d), col, "AwningPanel")
	# 줄무늬 4줄. 단색 판보다 훨씬 싸구려 티가 덜 난다.
	var stripe := _tint("#F6EFE4", pos, 5, 0.04)
	for i in range(4):
		var sx := (float(i) - 1.5) * (w / 4.4)
		_box(tilt_node, Vector3(sx, 0.04, d * 0.5), Vector3(w / 11.0, 0.012, d), stripe, "AwningStripe%d" % i)
	# 앞단 물받이 — 끝이 두꺼워야 천이 늘어진 느낌이 난다
	_box(tilt_node, Vector3(0, -0.03, d), Vector3(w + 0.06, 0.14, 0.07),
		_tint(hex, pos, 6, 0.05).darkened(0.18), "AwningTrim")
	# 비스듬한 버팀대 2개
	for i in range(2):
		var bx := (float(i) * 2.0 - 1.0) * (w * 0.5 - 0.16)
		var brace := _box(root, Vector3(bx, -d * 0.3, d * 0.45), Vector3(0.05, d * 1.05, 0.05),
			Color("#6E7684"), "AwningBrace%d" % i)
		brace.rotation_degrees.x = 46.0
	return root


## 외벽 배관. 세로 원통 2줄 + 클램프. 밋밋한 벽면을 세로로 나눠 준다.
## 메시 10개.
static func pipe_run(parent: Node3D, pos: Vector3, height := 6.0, hex := "#8A94A4", yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, pos, "PipeRun", yaw_deg)
	var h := height * _rr(pos, 1, 0.9, 1.08)
	var gap := _rr(pos, 2, 0.16, 0.26)
	var r0 := _rr(pos, 3, 0.055, 0.085)
	var col := _tint(hex, pos, 4, 0.06)

	for i in range(2):
		var x := (float(i) - 0.5) * gap * 2.0
		var r := (r0 if i == 0 else r0 * 0.72)
		_cyl(root, Vector3(x, h * 0.5, 0.09), r, h, col, "PipeVert%d" % i)
		# 위쪽에서 벽 안으로 꺾여 들어간다
		_sphere(root, Vector3(x, h, 0.09), r * 1.3, col, "PipeElbow%d" % i)
		var arm := _cyl(root, Vector3(x, h, 0.02), r, 0.16, col, "PipeArm%d" % i)
		arm.rotation_degrees.x = 90.0
	# 벽 고정 클램프. 일정 간격으로 붙어야 배관으로 읽힌다.
	var clamps := 4
	for i in range(clamps):
		var cy := h * (float(i) + 0.6) / (float(clamps) + 0.6)
		_box(root, Vector3(0, cy, 0.05), Vector3(gap * 2.0 + r0 * 3.0, 0.07, 0.06),
			Color("#5E6774"), "PipeClamp%d" % i)
	return root


# ── 가로 / 자연 ────────────────────────────────────────────────────────
#
# 잎사귀 노드 이름은 전부 Canopy/Leaf/Bush 로 시작한다. 그래야 LivingScene 이
# 이름만 보고 바람에 흔들어 준다.

## 둥근 활엽수. 구를 두 덩이 겹쳐서 실루엣이 완전한 원이 되지 않게 한다.
## 메시 4개.
static func tree_round(parent: Node3D, pos: Vector3, hex := "#72B48D", trunk_hex := "#6B4A34", scale_hint := 1.0) -> Node3D:
	var root := _root(parent, pos, "TreeRound", _rr(pos, 0, 0.0, 360.0))
	var th := _rr(pos, 1, 1.0, 1.5) * scale_hint
	var r := _rr(pos, 2, 0.6, 0.85) * scale_hint
	var trunk := _box(root, Vector3(0, th * 0.5, 0), Vector3(0.2, th, 0.2), _tint(trunk_hex, pos, 3, 0.05), "Trunk")
	trunk.rotation_degrees.z = _rr(pos, 4, -4.0, 4.0)
	_sphere(root, Vector3(0, th + r * 0.7, 0), r, _tint(hex, pos, 5), "Canopy")
	_sphere(root, Vector3(r * 0.5, th + r * 0.35, r * 0.28), r * 0.6, _tint(hex, pos, 6, 0.1), "CanopyLow")
	_sphere(root, Vector3(-r * 0.42, th + r * 1.1, -r * 0.2), r * 0.5, _tint(hex, pos, 7, 0.1), "CanopyTop")
	return root


## 길쭉한 원뿔형 침엽수. 가로수 사이에 하나 섞으면 스카이라인 높이가 다양해진다.
## 메시 4개.
static func tree_tall(parent: Node3D, pos: Vector3, hex := "#5F9E86", trunk_hex := "#6B4A34", scale_hint := 1.0) -> Node3D:
	var root := _root(parent, pos, "TreeTall", _rr(pos, 0, 0.0, 360.0))
	var th := _rr(pos, 1, 0.55, 0.9) * scale_hint
	var r := _rr(pos, 2, 0.58, 0.82) * scale_hint
	var tiers := _rr(pos, 3, 1.05, 1.45) * scale_hint
	_cyl(root, Vector3(0, th * 0.5, 0), 0.11 * scale_hint, th, _tint(trunk_hex, pos, 4, 0.05), "Trunk")
	# 3단으로 겹친다. 원뿔 하나만 두면 크리스마스 장식처럼 보인다.
	for i in range(3):
		var f := 1.0 - float(i) * 0.3
		var y := th + tiers * (0.32 + float(i) * 0.62)
		_cone(root, Vector3(0, y, 0), r * f, tiers * (1.15 - float(i) * 0.12),
			_tint(hex, pos, 10 + i, 0.06), "CanopyTier%d" % i)
	return root


## 옆으로 퍼진 나무. 구 3개를 낮고 넓게 겹친다. 벤치 위나 담장 너머에 어울린다.
## 메시 5개.
static func tree_wide(parent: Node3D, pos: Vector3, hex := "#7FBF97", trunk_hex := "#6B4A34", scale_hint := 1.0) -> Node3D:
	var root := _root(parent, pos, "TreeWide", _rr(pos, 0, 0.0, 360.0))
	var th := _rr(pos, 1, 0.9, 1.3) * scale_hint
	var r := _rr(pos, 2, 0.55, 0.75) * scale_hint
	var trunk := _box(root, Vector3(0, th * 0.5, 0), Vector3(0.22, th, 0.22), _tint(trunk_hex, pos, 3, 0.05), "Trunk")
	trunk.rotation_degrees.z = _rr(pos, 4, -7.0, 7.0)
	# 굵은 가지 하나. 잎덩이가 왜 옆으로 뻗었는지 이유가 보인다.
	var branch := _box(root, Vector3(r * 0.4, th * 0.9, 0), Vector3(0.7 * scale_hint, 0.11, 0.11),
		_tint(trunk_hex, pos, 5, 0.05), "Branch")
	branch.rotation_degrees.z = -22.0
	_sphere(root, Vector3(0, th + r * 0.5, 0), r, _tint(hex, pos, 6), "Canopy")
	_sphere(root, Vector3(r * 1.05, th + r * 0.72, r * 0.15), r * 0.78, _tint(hex, pos, 7, 0.1), "CanopyRight")
	_sphere(root, Vector3(-r * 0.95, th + r * 0.3, -r * 0.2), r * 0.66, _tint(hex, pos, 8, 0.1), "CanopyLeft")
	return root


## 낮은 수풀. 구 3개면 충분하다. 바닥과 벽이 만나는 선을 덮어 준다.
## 메시 3개.
static func bush(parent: Node3D, pos: Vector3, hex := "#6FA98A", scale_hint := 1.0) -> Node3D:
	var root := _root(parent, pos, "BushGroup", _rr(pos, 0, 0.0, 360.0))
	var r := _rr(pos, 1, 0.3, 0.46) * scale_hint
	var offs: Array[Vector3] = [Vector3(0, 0, 0), Vector3(r * 0.85, -r * 0.16, r * 0.3), Vector3(-r * 0.7, -r * 0.2, -r * 0.35)]
	for i in range(offs.size()):
		var o: Vector3 = offs[i]
		var br := r * _rr(pos, 10 + i, 0.66, 1.0)
		var mi := _sphere(root, o + Vector3(0, br * 0.72, 0), br, _tint(hex, pos, 20 + i, 0.08), "Bush%d" % i)
		# 완전한 구는 인공적이다. 살짝 눌러서 땅에 얹힌 모양으로.
		mi.scale = Vector3(1.15, 0.72, 1.05)
	return root


## 전신주 + 전선. 하늘을 가로지르는 선이 몇 개 있으면 거리 사진처럼 보인다.
## wire_span 을 0 으로 주면 전선을 뺀다. 메시 최대 12개.
static func street_pole(parent: Node3D, pos: Vector3, height := 6.5, hex := "#7A8290", wire_span := 6.0) -> Node3D:
	var root := _root(parent, pos, "StreetPole", _rr(pos, 0, -6.0, 6.0))
	var h := height * _rr(pos, 1, 0.92, 1.1)
	var col := _tint(hex, pos, 2, 0.05)
	_cyl(root, Vector3(0, h * 0.5, 0), 0.11, h, col, "PoleShaft")
	# 가로대 2단 + 애자 4개
	for i in range(2):
		var cy := h - 0.35 - float(i) * 0.35
		_box(root, Vector3(0, cy, 0), Vector3(0.9, 0.07, 0.07), _tint("#6B7482", pos, 10 + i), "PoleCross%d" % i)
		for s in range(2):
			var ix := (float(s) * 2.0 - 1.0) * 0.36
			_cyl(root, Vector3(ix, cy + 0.09, 0), 0.045, 0.12, Color("#CBD3DE"), "PoleInsulator%d_%d" % [i, s])
	# 변압기. 기둥에 덩어리가 하나 붙으면 실루엣이 안 심심하다.
	_cyl(root, Vector3(0.19, h * 0.72, 0), 0.15, 0.42, _tint("#68717F", pos, 20), "PoleTransformer")
	# 전선. 가운데가 처져야 늘어진 느낌이 난다. 2줄을 V 두 토막으로 만든다.
	if wire_span > 0.1:
		var wire_col := Color("#4E5666")
		var half := wire_span * 0.5
		var sag := wire_span * 0.045
		var seg_len := sqrt(half * half + sag * sag)
		var ang := rad_to_deg(atan2(-sag, half))
		for w in range(2):
			var wy := h - 0.35 - float(w) * 0.35 + 0.14
			var a := _box(root, Vector3(half * 0.5, wy - sag * 0.5, 0), Vector3(seg_len, 0.03, 0.03), wire_col, "PoleWire%dA" % w)
			a.rotation_degrees.z = ang
			var b := _box(root, Vector3(half * 1.5, wy - sag * 0.5, 0), Vector3(seg_len, 0.03, 0.03), wire_col, "PoleWire%dB" % w)
			b.rotation_degrees.z = -ang
	return root


## 길가 쓰레기통. 위가 살짝 넓은 통이라야 플라스틱 통처럼 보인다. 메시 4개.
static func trash_bin(parent: Node3D, pos: Vector3, hex := "#5E6A78") -> Node3D:
	var root := _root(parent, pos, "TrashBin", _rr(pos, 0, 0.0, 360.0))
	var r := _rr(pos, 1, 0.17, 0.23)
	var h := _rr(pos, 2, 0.5, 0.66)
	var col := _tint(hex, pos, 3)
	var body := _cyl(root, Vector3(0, h * 0.5, 0), r, h, col, "BinBody")
	(body.mesh as CylinderMesh).bottom_radius = r * 0.86
	_cyl(root, Vector3(0, h * 0.82, 0), r * 1.04, 0.05, _tint(hex, pos, 4, 0.05).darkened(0.2), "BinRing")
	var lid := _sphere(root, Vector3(0, h + 0.02, 0), r * 1.02, _tint(hex, pos, 5, 0.05).lightened(0.1), "BinLid")
	lid.scale = Vector3(1.0, 0.4, 1.0)
	_box(root, Vector3(0, h + 0.02, r * 0.55), Vector3(r * 0.9, 0.1, 0.05), Color("#3E4652"), "BinSlot")
	return root


## 자전거 거치대. U 자 아치를 나란히. count 는 1~6 으로 자른다 (아치당 메시 3개).
static func bicycle_rack(parent: Node3D, pos: Vector3, count := 3, hex := "#96A0AC", yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, pos, "BicycleRack", yaw_deg)
	var n := clampi(count, 1, 6)
	var h := _rr(pos, 1, 0.62, 0.78)
	var w := _rr(pos, 2, 0.5, 0.66)
	var step := _rr(pos, 3, 0.62, 0.82)
	var col := _tint(hex, pos, 4, 0.05)
	for i in range(n):
		var x := (float(i) - float(n - 1) * 0.5) * step
		for s in range(2):
			var lx := x + (float(s) * 2.0 - 1.0) * w * 0.5
			_cyl(root, Vector3(lx, h * 0.5, 0), 0.035, h, col, "RackLeg%d_%d" % [i, s])
		_box(root, Vector3(x, h, 0), Vector3(w + 0.07, 0.07, 0.07), col, "RackTop%d" % i)
	_box(root, Vector3(0, 0.03, 0), Vector3(step * float(n), 0.06, 0.1), _tint(hex, pos, 5, 0.05).darkened(0.15), "RackRail")
	return root


## 자판기. 유리창이 은은하게 빛나서 밤거리에 앉을 자리를 만든다. 메시 13개.
static func vending_machine(parent: Node3D, pos: Vector3, hex := "#C98BA0", yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, pos, "VendingMachine", yaw_deg)
	var w := _rr(pos, 1, 0.82, 1.0)
	var h := _rr(pos, 2, 1.7, 1.95)
	var d := _rr(pos, 3, 0.6, 0.74)
	var col := _tint(hex, pos, 4, 0.06)

	_box(root, Vector3(0, h * 0.5, 0), Vector3(w, h, d), col, "VendBody")
	# 유리창 (약하게 발광). 세게 주면 밤에 화면이 타 버린다.
	var glass := _box(root, Vector3(-w * 0.14, h * 0.62, d * 0.5 + 0.01), Vector3(w * 0.58, h * 0.56, 0.03),
		Color("#DCEEF6"), "VendGlass")
	glass.material_override = _glow_mat(Color("#DCEEF6"), 0.85)
	# 진열된 음료 6개. 파스텔 색만 쓴다.
	var drinks: Array[String] = ["#F2A6A0", "#A8D5C2", "#F4D79A", "#B3C7EF", "#D8B3E0", "#F0C2A8"]
	for i in range(6):
		var dx := -w * 0.32 + float(i % 3) * (w * 0.18)
		var dy := h * 0.78 - floorf(float(i) / 3.0) * (h * 0.2)
		_cyl(root, Vector3(dx, dy, d * 0.5 + 0.03), w * 0.055, h * 0.1, Color(drinks[i]), "VendDrink%d" % i)
	# 버튼 패널 + 배출구
	_box(root, Vector3(w * 0.32, h * 0.62, d * 0.5 + 0.02), Vector3(w * 0.2, h * 0.5, 0.03),
		_tint(hex, pos, 5, 0.05).darkened(0.24), "VendPanel")
	_box(root, Vector3(0, h * 0.16, d * 0.5 + 0.01), Vector3(w * 0.6, h * 0.12, 0.04), Color("#3E4652"), "VendSlot")
	# 상단 띠. 간판 노릇을 한다.
	var top := _box(root, Vector3(0, h * 0.94, d * 0.5 + 0.02), Vector3(w * 0.94, h * 0.08, 0.03),
		Color("#FFE7A8"), "VendHeader")
	top.material_override = _glow_mat(Color("#FFE7A8"), 1.4)
	for i in range(2):
		_box(root, Vector3((float(i) * 2.0 - 1.0) * w * 0.38, 0.03, 0), Vector3(w * 0.16, 0.06, d * 0.8),
			Color("#4A5260"), "VendFoot%d" % i)
	return root


## 버스 정류장 표지판. 메시 7개.
static func bus_sign(parent: Node3D, pos: Vector3, hex := "#8FA9C9", yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, pos, "BusSign", yaw_deg)
	var h := _rr(pos, 1, 1.9, 2.3)
	var col := _tint(hex, pos, 2, 0.05)
	_cyl(root, Vector3(0, 0.025, 0), 0.16, 0.05, Color("#6E7684"), "BusBase")
	_cyl(root, Vector3(0, h * 0.5, 0), 0.045, h, Color("#B7BEC8"), "BusPole")
	_box(root, Vector3(0, h - 0.28, 0.03), Vector3(0.52, 0.68, 0.05), col, "BusBoard")
	# 머리띠만 살짝 빛난다. 판 전체가 빛나면 표지판이 아니라 전광판이다.
	var head := _box(root, Vector3(0, h - 0.02, 0.05), Vector3(0.52, 0.16, 0.04), Color("#FFE7A8"), "BusHeader")
	head.material_override = _glow_mat(Color("#FFE7A8"), 1.2)
	for i in range(3):
		_box(root, Vector3(0, h - 0.34 - float(i) * 0.13, 0.06), Vector3(0.36 - float(i) * 0.06, 0.045, 0.02),
			Color("#F2EEE2"), "BusLine%d" % i)
	return root


# ── 실내 ───────────────────────────────────────────────────────────────

## 천장 조명. 확산판은 발광, 실제 빛은 OmniLight3D 가 낸다.
## LivingScene 이 이 라이트를 잡아서 저절로 숨 쉬게 만든다. 메시 4개.
static func ceiling_light(parent: Node3D, pos: Vector3, hex := "#FFF3D8", energy := 0.7) -> Node3D:
	var root := _root(parent, pos, "CeilingLight")
	var w := _rr(pos, 1, 0.9, 1.3)
	var d := _rr(pos, 2, 0.24, 0.34)
	_box(root, Vector3(0, 0.06, 0), Vector3(w + 0.06, 0.08, d + 0.06), Color("#8A9099"), "LightMount")
	var panel := _box(root, Vector3(0, 0, 0), Vector3(w, 0.05, d), Color(hex), "LightPanel")
	panel.material_override = _glow_mat(Color(hex), 1.5)
	for i in range(2):
		_box(root, Vector3((float(i) * 2.0 - 1.0) * (w * 0.5 + 0.02), 0.01, 0), Vector3(0.05, 0.09, d + 0.04),
			Color("#7E858F"), "LightEndCap%d" % i)
	var omni := OmniLight3D.new()
	omni.name = "LightOmni"
	omni.light_color = Color(hex)
	omni.light_energy = energy
	omni.omni_range = _rr(pos, 3, 3.0, 4.2)
	omni.position = Vector3(0, -0.15, 0)
	root.add_child(omni)
	return root


## 실내 기둥. 위아래 몰딩이 있어야 그냥 원기둥이 아니라 건축물로 보인다. 메시 5개.
static func pillar(parent: Node3D, pos: Vector3, height := 5.0, hex := "#8E94A2", radius := 0.28) -> Node3D:
	var root := _root(parent, pos, "Pillar", _rr(pos, 0, 0.0, 90.0))
	var col := _tint(hex, pos, 1, 0.05)
	var trim := _tint(hex, pos, 2, 0.05).darkened(0.18)
	_cyl(root, Vector3(0, height * 0.5, 0), radius, height, col, "PillarShaft")
	_box(root, Vector3(0, 0.09, 0), Vector3(radius * 2.5, 0.18, radius * 2.5), trim, "PillarFoot")
	_box(root, Vector3(0, height - 0.09, 0), Vector3(radius * 2.5, 0.18, radius * 2.5), trim, "PillarCap")
	_cyl(root, Vector3(0, 0.3, 0), radius * 1.12, 0.07, trim, "PillarMoldLow")
	_cyl(root, Vector3(0, height - 0.3, 0), radius * 1.12, 0.07, trim, "PillarMoldHigh")
	return root


## 선반장. 위에 얹힌 소품까지 같이 만든다. 빈 선반은 오히려 더 허전해 보인다.
## 메시 11개.
static func shelf_unit(parent: Node3D, pos: Vector3, hex := "#9A7B5A", yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, pos, "ShelfUnit", yaw_deg)
	var w := _rr(pos, 1, 1.3, 1.8)
	var h := _rr(pos, 2, 1.5, 2.0)
	var d := _rr(pos, 3, 0.34, 0.44)
	var col := _tint(hex, pos, 4, 0.06)
	var dark := _tint(hex, pos, 5, 0.05).darkened(0.2)

	for i in range(2):
		_box(root, Vector3((float(i) * 2.0 - 1.0) * w * 0.5, h * 0.5, 0), Vector3(0.07, h, d), dark, "ShelfSide%d" % i)
	_box(root, Vector3(0, h * 0.5, -d * 0.5), Vector3(w, h, 0.04), _tint(hex, pos, 6, 0.05).darkened(0.3), "ShelfBack")
	var boards := 4
	for i in range(boards):
		var by := h * (float(i) + 0.35) / float(boards)
		_box(root, Vector3(0, by, 0), Vector3(w - 0.07, 0.05, d - 0.03), col, "ShelfBoard%d" % i)
	# 얹힌 소품 — 책 두 권, 상자 하나, 작은 화분 하나
	var by0 := h * 0.35 / float(boards)
	var by1 := h * 1.35 / float(boards)
	_box(root, Vector3(-w * 0.28, by1 + 0.14, 0), Vector3(0.1, 0.24, d * 0.6), Color("#C08A8A"), "ShelfBook0")
	_box(root, Vector3(-w * 0.18, by1 + 0.12, 0), Vector3(0.08, 0.2, d * 0.6), Color("#8FA9C9"), "ShelfBook1")
	_box(root, Vector3(w * 0.24, by0 + 0.11, 0), Vector3(0.3, 0.18, d * 0.6), Color("#C9B08A"), "ShelfBox")
	_sphere(root, Vector3(w * 0.3, by1 + 0.16, 0), 0.13, Color("#6FA98A"), "PlantSmall")
	return root


## 벽 포스터. 실내 벽이 비면 방이 창고처럼 보인다. 색 띠만으로 충분하다.
## 메시 5개.
static func poster_panel(parent: Node3D, pos: Vector3, hex := "#F2EEE2", yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, pos, "PosterPanel", yaw_deg)
	var w := _rr(pos, 1, 0.5, 0.8)
	var h := _rr(pos, 2, 0.7, 1.05)
	root.rotation_degrees.z = _rr(pos, 3, -2.0, 2.0)
	_box(root, Vector3(0, 0, 0), Vector3(w + 0.05, h + 0.05, 0.03), Color("#5E4A38"), "PosterFrame")
	_box(root, Vector3(0, 0, 0.025), Vector3(w, h, 0.01), Color(hex), "PosterPaper")
	# 위쪽에 큰 색면 하나, 아래에 글줄 두 개. 그림 같은 인상만 주면 된다.
	var accents: Array[String] = ["#A8C4F0", "#F2A6A0", "#A8D5C2", "#F4D79A", "#D8B3E0"]
	var acol := Color(accents[int(_rnd(pos, 4) * float(accents.size())) % accents.size()])
	_box(root, Vector3(0, h * 0.16, 0.033), Vector3(w * 0.78, h * 0.44, 0.01), acol, "PosterArt")
	_box(root, Vector3(0, -h * 0.24, 0.033), Vector3(w * 0.62, h * 0.06, 0.01), Color("#6E7684"), "PosterLine0")
	_box(root, Vector3(0, -h * 0.35, 0.033), Vector3(w * 0.42, h * 0.05, 0.01), Color("#8A9099"), "PosterLine1")
	return root
