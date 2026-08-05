extends Node3D
## 기념품 방. 여행에서 모아온 사진이 선반에 하나씩 쌓인다.
## 방문할수록 방이 채워지는 게 눈에 보이는 것이 이 화면의 목적이다.

@onready var player = $PlayerQuokka3D
@onready var camera: Camera3D = $Camera3D
@onready var dialogue_box = $DialogueBox

const CAM_OFFSET = Vector3(0, 3.9, 5.4)
const CAM_LOOK_OFFSET = Vector3(0, 1.5, -3.0)
const CAM_LERP = 5.0

## 선반 슬롯 (한 줄에 5개, 최대 3줄 = 15개)
const SLOTS_PER_ROW := 5
const SLOT_X_START := -2.0
const SLOT_X_STEP := 1.0
const SHELF_Y := [1.05, 1.75, 2.45]
const SHELF_Z := -3.35

var _lamp: OmniLight3D = null
var _t: float = 0.0

func _ready() -> void:
	_build_room()
	_build_souvenirs()
	player.add_to_group("player")
	AudioManager.play_bgm("room")
	PartnerSpawner.ensure(self, player, Vector3(1.0, 0, 0.7))
	$ExitInteract.interacted.connect(_go_hub)
	await get_tree().create_timer(0.4).timeout
	var n := TravelState.collection.size()
	if n == 0:
		dialogue_box.show_text("아직 비어 있어요. 여행을 다녀오면 이 방이 채워져요.")
	else:
		dialogue_box.show_text("기념품 %d개를 모았어요. 가까이 가서 Space 로 볼 수 있어요." % n)

func _process(delta: float) -> void:
	var target = player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target, CAM_LERP * delta)
	camera.look_at(player.global_position + CAM_LOOK_OFFSET, Vector3.UP)
	_t += delta
	if _lamp:
		_lamp.light_energy = 1.25 + sin(_t * 1.6) * 0.06

func _go_hub() -> void:
	SceneTransition.go_to("res://scenes/travel/TravelHub.tscn", "hopeful")

# ── 방 ──────────────────────────────────────────────────────────────────
func _build_room() -> void:
	# 바닥 / 러그 / 벽
	_box(self, Vector3(0, -0.05, 0), Vector3(9, 0.1, 9), "#6B5744", "Floor")
	_box(self, Vector3(0, 0.01, 0.6), Vector3(5.2, 0.02, 4.4), "#8A6E58", "Rug")
	_box(self, Vector3(0, 1.9, -4.4), Vector3(9, 4.0, 0.25), "#4A5D74", "BackWall")
	_box(self, Vector3(-4.4, 1.9, 0), Vector3(0.25, 4.0, 9), "#41526A", "LeftWall")
	_box(self, Vector3(4.4, 1.9, 0), Vector3(0.25, 4.0, 9), "#41526A", "RightWall")
	# 걸레받이
	_box(self, Vector3(0, 0.12, -4.25), Vector3(9, 0.24, 0.06), "#3A4A5E", "Baseboard")

	# 선반 3단
	for i in range(SHELF_Y.size()):
		var y: float = SHELF_Y[i] - 0.06
		_box(self, Vector3(0, y, SHELF_Z), Vector3(5.8, 0.09, 0.42), "#9A7B5A", "ShelfBoard%d" % i)
		for sx in [-2.9, 2.9]:
			_box(self, Vector3(sx, y - 0.32, SHELF_Z), Vector3(0.10, 0.62, 0.40), "#7E6248", "ShelfLeg")

	# 창문 (밤하늘) — 유리를 앞에 두고 테두리는 얇은 막대 4개로
	var glass := _box(self, Vector3(2.9, 2.2, -4.26), Vector3(1.7, 1.4, 0.03), "#16243C", "WindowGlass")
	_emissive(glass, "#1E3358", 0.5)
	for i in range(9):
		var a := float(i) * 1.9
		var st := _sphere(self, Vector3(2.9 + cos(a) * 0.62, 2.2 + sin(a * 1.4) * 0.46, -4.245), 0.032, "#FFF3C8", "Star%d" % i)
		_emissive(st, "#FFF3C8", 3.0)
	# 테두리
	for off in [Vector3(0, 0.74, 0), Vector3(0, -0.74, 0)]:
		_box(self, Vector3(2.9, 2.2, -4.235) + off, Vector3(1.84, 0.09, 0.05), "#5E4A38", "WinBar")
	for off in [Vector3(0.88, 0, 0), Vector3(-0.88, 0, 0)]:
		_box(self, Vector3(2.9, 2.2, -4.235) + off, Vector3(0.09, 1.58, 0.05), "#5E4A38", "WinBar")
	# 창살
	_box(self, Vector3(2.9, 2.2, -4.235), Vector3(0.055, 1.4, 0.04), "#5E4A38", "WinCrossV")
	_box(self, Vector3(2.9, 2.2, -4.235), Vector3(1.7, 0.055, 0.04), "#5E4A38", "WinCrossH")
	# 창밖에서 스며드는 달빛
	var moon := OmniLight3D.new()
	moon.light_color = Color("#9FB6E8")
	moon.light_energy = 0.55
	moon.omni_range = 6.0
	moon.position = Vector3(2.9, 2.2, -3.9)
	add_child(moon)

	# 작은 탁자 + 램프
	_box(self, Vector3(-3.0, 0.55, -2.4), Vector3(1.1, 0.1, 0.9), "#8A6A4A", "TableTop")
	for tx in [-3.45, -2.55]:
		for tz in [-2.75, -2.05]:
			_box(self, Vector3(tx, 0.27, tz), Vector3(0.08, 0.55, 0.08), "#6E5238", "TableLeg")
	_cylinder(self, Vector3(-3.0, 0.72, -2.4), 0.05, 0.26, "#8A9099", "LampStem")
	var shade := _cylinder(self, Vector3(-3.0, 0.94, -2.4), 0.22, 0.24, "#FFD76D", "LampShade")
	_emissive(shade, "#FFE7A8", 2.0)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color("#FFD3A0")
	_lamp.light_energy = 1.25
	_lamp.omni_range = 7.5
	_lamp.position = Vector3(-3.0, 1.15, -2.4)
	add_child(_lamp)

	# 화분 / 쿠션
	_cylinder(self, Vector3(3.5, 0.26, -2.2), 0.30, 0.5, "#A9705A", "PotBody")
	_sphere(self, Vector3(3.5, 0.82, -2.2), 0.42, "#6FA98A", "PotLeaf")
	_box(self, Vector3(1.4, 0.16, 1.6), Vector3(0.9, 0.28, 0.9), "#C98BA0", "Cushion")
	_box(self, Vector3(-1.4, 0.16, 1.9), Vector3(0.8, 0.26, 0.8), "#8FA9C9", "Cushion2")

	# 천장 은은한 조명
	var amb := OmniLight3D.new()
	amb.light_color = Color("#B9A7E8")
	amb.light_energy = 0.45
	amb.omni_range = 12.0
	amb.position = Vector3(0, 3.4, 0)
	add_child(amb)

# ── 기념품 배치 ─────────────────────────────────────────────────────────
func _build_souvenirs() -> void:
	var col: Array = TravelState.collection
	for i in range(col.size()):
		if i >= SLOTS_PER_ROW * SHELF_Y.size():
			break
		var s: Dictionary = col[i]
		var row := i / SLOTS_PER_ROW
		var cidx := i % SLOTS_PER_ROW
		var x := SLOT_X_START + float(cidx) * SLOT_X_STEP
		var y: float = SHELF_Y[row]
		_place_souvenir(s, Vector3(x, y, SHELF_Z), i)

	# 빈 슬롯 힌트 (다음 자리 하나만 은은하게)
	var next_i: int = col.size()
	if next_i < SLOTS_PER_ROW * SHELF_Y.size():
		var row := next_i / SLOTS_PER_ROW
		var cidx := next_i % SLOTS_PER_ROW
		var x := SLOT_X_START + float(cidx) * SLOT_X_STEP
		var ghost := _box(self, Vector3(x, SHELF_Y[row] + 0.16, SHELF_Z), Vector3(0.34, 0.30, 0.03), "#FFD76D", "EmptySlot")
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(1, 0.843, 0.427, 0.16)
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost.material_override = gm

## 기념품 하나 = 액자 + 여행지별 작은 소품
func _place_souvenir(s: Dictionary, pos: Vector3, idx: int) -> void:
	var dest_id: String = s.get("dest_id", "")
	var d := TravelState.get_destination(dest_id)
	var tint: Color = d.get("tint", Color(0.8, 0.8, 0.9))

	var root := Node3D.new()
	root.name = "Souvenir%d" % idx
	root.position = pos
	add_child(root)

	# 액자
	_box(root, Vector3(0, 0.18, 0), Vector3(0.36, 0.32, 0.035), "#5E4A38", "Frame")
	var photo := _box(root, Vector3(0, 0.18, 0.028), Vector3(0.30, 0.26, 0.01),
		"#%02X%02X%02X" % [int(tint.r * 255), int(tint.g * 255), int(tint.b * 255)], "Photo")
	_emissive(photo, "#%02X%02X%02X" % [int(tint.r * 255), int(tint.g * 255), int(tint.b * 255)], 0.55)
	# 액자 받침
	_box(root, Vector3(0, 0.015, -0.03), Vector3(0.30, 0.03, 0.14), "#4A3A2C", "FrameStand")

	# 여행지별 소품
	match dest_id:
		"seoul":
			_box(root, Vector3(0.24, 0.09, 0.02), Vector3(0.17, 0.10, 0.12), "#E6D8BE", "MiniHanok")
			_box(root, Vector3(0.24, 0.16, 0.02), Vector3(0.24, 0.045, 0.17), "#C0504A", "MiniRoof")
		"paris":
			_cylinder(root, Vector3(0.24, 0.13, 0.02), 0.035, 0.26, "#C9B08A", "MiniTower")
			_box(root, Vector3(0.24, 0.03, 0.02), Vector3(0.16, 0.035, 0.16), "#C9B08A", "MiniTowerBase")
		"moon":
			var st := _sphere(root, Vector3(0.24, 0.12, 0.02), 0.075, "#FFE7A8", "MiniMoon")
			_emissive(st, "#FFE7A8", 1.8)
		_:
			_sphere(root, Vector3(0.24, 0.09, 0.02), 0.06, "#CFC6E8", "MiniTrinket")

	# 상호작용 (가까이 가서 Space 로 일기 읽기)
	var area := Area3D.new()
	area.name = "Interact%d" % idx
	area.set_script(load("res://scripts/systems/interactable.gd"))
	area.position = Vector3(0, -pos.y + 0.4, 0.9)   # 선반 앞 바닥 높이
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.85
	cs.shape = sh
	area.add_child(cs)
	root.add_child(area)
	area.set("prompt_text", str(s.get("title", "기념품")))
	area.set("indicator_height", 1.2)
	area.interacted.connect(func(): _read_souvenir(s))

func _read_souvenir(s: Dictionary) -> void:
	AudioManager.ui_click()
	var d := TravelState.get_destination(s.get("dest_id", ""))
	dialogue_box.show_text("%s  %s\n%s" % [
		d.get("emoji", "📷"), s.get("title", ""), s.get("diary", "")])

# ── 헬퍼 ────────────────────────────────────────────────────────────────
func _emissive(mi: MeshInstance3D, hex: String, energy: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.emission_enabled = true
	m.emission = Color(hex)
	m.emission_energy_multiplier = energy
	mi.material_override = m

func _box(parent: Node3D, pos: Vector3, size: Vector3, hex: String, label := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new(); m.size = size
	mi.mesh = m; mi.position = pos
	if label != "": mi.name = label
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, hex: String, label := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new(); m.top_radius = radius; m.bottom_radius = radius; m.height = height
	mi.mesh = m; mi.position = pos
	if label != "": mi.name = label
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _sphere(parent: Node3D, pos: Vector3, radius: float, hex: String, label := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new(); m.radius = radius; m.height = radius * 2.0
	mi.mesh = m; mi.position = pos
	if label != "": mi.name = label
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi
