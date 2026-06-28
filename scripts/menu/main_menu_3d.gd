extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var quokka_pivot: Node3D = $QuokkaPivot
var _t := 0.0
var _globe: Node3D = null
var _floaters: Array = []   # [ {node, radius, speed, phase, y} ]

const GLOBE_CENTER := Vector3(0, -1.4, 0)
const GLOBE_R := 2.0

func _ready() -> void:
    _build_scene()
    var cont = $UILayer/Control/VBox/ContinueBtn
    cont.disabled = not FileAccess.file_exists("user://save.cfg")
    $UILayer/Control/VBox/StartBtn.pressed.connect(_on_start)
    cont.pressed.connect(_on_continue)
    $UILayer/Control/VBox/QuitBtn.pressed.connect(_on_quit)
    $UILayer/Control/VBox/SettingsBtn.pressed.connect(func(): var s = get_tree().get_first_node_in_group("settings_ui"); if s: s.open())
    if AudioManager:
        AudioManager.play_bgm("menu")

func _process(delta: float) -> void:
    _t += delta
    # 지구본 천천히 자전
    if _globe:
        _globe.rotate_y(delta * 0.25)
    # 커플은 지구본 위에서 살짝 둥실
    quokka_pivot.position.y = (GLOBE_CENTER.y + GLOBE_R + 0.05) + sin(_t * 1.4) * 0.06
    # 떠다니는 행성/로켓 공전
    for f in _floaters:
        var a = f.phase + _t * f.speed
        f.node.position = Vector3(cos(a) * f.radius, f.y + sin(a * 0.7) * 0.3, -3.0 + sin(a) * f.radius * 0.4)
        f.node.rotate_y(delta * 0.4)

# ─────────────────────────────────────────────
func _on_start() -> void:
    Episode0State.current_state = Episode0State.State.START
    Episode0State.has_camera = false
    Episode0State.has_notebook = false
    Episode0State.has_travel_bag = false
    Episode0State.badge_returned = false
    Episode0State.partner_joined = false
    Episode0State.first_photo_taken = false
    Episode0State.album_created = false
    Episode0State.episode0_cleared = false
    Episode0State.memos_found = []
    SceneTransition.go_to("res://scenes/maps/CompanyFront3D.tscn", "hopeful")

func _on_continue() -> void:
    SaveManager.load_game()
    var cfg = ConfigFile.new()
    cfg.load("user://save.cfg")
    var scene = cfg.get_value("game", "current_scene", "res://scenes/maps/CompanyFront3D.tscn")
    SceneTransition.go_to(scene, "normal")

func _on_quit() -> void:
    get_tree().quit()

# ─────────────────────────────────────────────
func _build_scene() -> void:
    _globe = Node3D.new()
    _globe.position = GLOBE_CENTER
    add_child(_globe)

    # 바다 (지구 본체)
    var ocean = MeshInstance3D.new()
    var om = SphereMesh.new(); om.radius = GLOBE_R; om.height = GLOBE_R * 2
    ocean.mesh = om
    ocean.material_override = _mat("#7FD0EE", 0.55)
    _globe.add_child(ocean)

    # 대륙 (납작한 초록 덩어리들)
    var land_spots := [
        Vector3(0.2, 0.95, 0.15), Vector3(-0.7, 0.5, 0.5),
        Vector3(0.7, 0.4, 0.5), Vector3(0.0, 0.2, -0.95),
        Vector3(-0.5, -0.3, 0.7), Vector3(0.5, -0.5, 0.6),
    ]
    for s in land_spots:
        var land = MeshInstance3D.new()
        var lm = SphereMesh.new(); lm.radius = 0.7; lm.height = 0.5
        land.mesh = lm
        land.material_override = _mat("#8BD17C", 0.9)
        land.position = s.normalized() * (GLOBE_R - 0.05)
        land.look_at_from_position(land.position, Vector3.ZERO, Vector3.UP)
        land.scale = Vector3(1.0, 0.35, 1.0)
        _globe.add_child(land)

    # 랜드마크들 (지구본 윗면 둘레에 배치) — 자전과 함께 돈다
    _eiffel(_surf(Vector3(-0.9, 0.8, 0.2)))
    _tower(_surf(Vector3(0.95, 0.7, 0.1)))      # 남산타워 느낌
    _hanok(_surf(Vector3(0.4, 0.7, -0.7)))
    _pyramid(_surf(Vector3(-0.6, 0.55, -0.7)))
    _pisa(_surf(Vector3(-0.2, 0.6, 0.95)))
    _statue(_surf(Vector3(0.7, 0.55, 0.6)))

    # 토성 고리 등 떠다니는 행성들
    _add_floater(_planet("#E8A766", true), 5.5, 0.18, 0.0, 2.5)    # 토성
    _add_floater(_planet("#B59CE0", false), 6.5, 0.13, 2.2, -1.5)  # 보라 행성
    _add_floater(_planet("#9FC6E8", false), 6.0, 0.16, 4.0, 1.0)   # 파랑 행성
    _add_floater(_rocket(), 4.8, 0.30, 1.0, 3.0)                   # 로켓

    # 달 (쿼카가 앉은 작은 달)
    var moon = _planet("#D8D8E2", false)
    moon.position = Vector3(3.6, 3.2, -4.0)
    moon.scale = Vector3(0.7, 0.7, 0.7)
    add_child(moon)

    # 파스텔 반짝임 별
    for i in range(50):
        var star = MeshInstance3D.new()
        var sm = SphereMesh.new(); sm.radius = 0.05; sm.height = 0.1; star.mesh = sm
        star.material_override = _emit_mat("#FFFFFF", 3.0)
        var ang = float(i) * 0.7
        star.position = Vector3(cos(ang) * (5 + (i % 6)), -1 + (i % 9), -7 - (i % 4))
        add_child(star)

# 지구본 표면 위 위치(자전 노드 기준 로컬좌표) 반환
func _surf(dir: Vector3) -> Vector3:
    return dir.normalized() * (GLOBE_R - 0.02)

# ── 랜드마크 빌더 (지구본 자식 → 함께 회전) ──
func _place(node: Node3D, local_pos: Vector3) -> void:
    node.position = local_pos
    # 표면 바깥 방향으로 세우기
    var up = local_pos.normalized()
    var basis = Basis()
    var fwd = up.cross(Vector3.RIGHT)
    if fwd.length() < 0.01:
        fwd = up.cross(Vector3.FORWARD)
    fwd = fwd.normalized()
    var right = up.cross(fwd).normalized()
    node.basis = Basis(right, up, fwd)
    _globe.add_child(node)

func _eiffel(pos: Vector3) -> void:
    var n = Node3D.new()
    _cone_to(n, Vector3(0, 0.15, 0), 0.18, 0.05, 0.5, "#C8A06A")
    _cone_to(n, Vector3(0, 0.5, 0), 0.06, 0.02, 0.35, "#C8A06A")
    _place(n, pos)

func _tower(pos: Vector3) -> void:
    var n = Node3D.new()
    _cyl(n, Vector3(0, 0.25, 0), 0.04, 0.5, "#DCdce4")
    _ball(n, Vector3(0, 0.5, 0), 0.12, "#9FE0E0")
    _cyl(n, Vector3(0, 0.68, 0), 0.015, 0.25, "#DCDCE4")
    _place(n, pos)

func _hanok(pos: Vector3) -> void:
    var n = Node3D.new()
    _boxn(n, Vector3(0, 0.12, 0), Vector3(0.5, 0.24, 0.35), "#E6D2B5")
    _cone4(n, Vector3(0, 0.33, 0), 0.45, 0.0, 0.22, "#3A4654")  # 기와지붕
    _place(n, pos)

func _pyramid(pos: Vector3) -> void:
    var n = Node3D.new()
    _cone4(n, Vector3(0, 0.22, 0), 0.4, 0.0, 0.45, "#E0C27A")
    _place(n, pos)

func _pisa(pos: Vector3) -> void:
    var n = Node3D.new()
    _cyl(n, Vector3(0, 0.28, 0), 0.1, 0.55, "#F0EAD8")
    n.rotation_degrees.z = 12
    _place(n, pos)

func _statue(pos: Vector3) -> void:
    var n = Node3D.new()
    _cyl(n, Vector3(0, 0.12, 0), 0.08, 0.24, "#7FB89E")  # 받침/몸
    _ball(n, Vector3(0, 0.3, 0), 0.07, "#7FB89E")        # 머리
    _cone(n, Vector3(0, 0.42, 0), 0.1, 0.0, 0.14, "#7FB89E")  # 왕관 스파이크
    _place(n, pos)

# ── 떠다니는 오브젝트 ──
func _add_floater(node: Node3D, radius: float, speed: float, phase: float, y: float) -> void:
    add_child(node)
    _floaters.append({"node": node, "radius": radius, "speed": speed, "phase": phase, "y": y})

func _planet(hex: String, ring: bool) -> Node3D:
    var n = Node3D.new()
    _ball(n, Vector3.ZERO, 0.6, hex)
    if ring:
        var r = MeshInstance3D.new()
        var tm = TorusMesh.new(); tm.inner_radius = 0.8; tm.outer_radius = 1.1
        r.mesh = tm
        r.material_override = _mat("#F0D8A8", 0.7)
        r.rotation_degrees = Vector3(80, 0, 18)
        n.add_child(r)
    return n

func _rocket() -> Node3D:
    var n = Node3D.new()
    _cyl(n, Vector3.ZERO, 0.12, 0.5, "#F4F4F8")
    _cone(n, Vector3(0, 0.32, 0), 0.12, 0.0, 0.22, "#FF8A7A")
    _cone(n, Vector3(0, -0.3, 0), 0.16, 0.05, 0.18, "#FFC36A")  # 화염
    n.rotation_degrees.z = 90
    return n

# ── 메시 헬퍼 ──
func _mat(hex: String, rough: float) -> StandardMaterial3D:
    var m = StandardMaterial3D.new(); m.albedo_color = Color(hex); m.roughness = rough
    return m

func _emit_mat(hex: String, energy: float) -> StandardMaterial3D:
    var m = StandardMaterial3D.new(); m.albedo_color = Color(hex)
    m.emission_enabled = true; m.emission = Color(hex); m.emission_energy_multiplier = energy
    return m

func _ball(parent: Node3D, pos: Vector3, r: float, hex: String) -> void:
    var mi = MeshInstance3D.new()
    var sm = SphereMesh.new(); sm.radius = r; sm.height = r * 2; mi.mesh = sm
    mi.material_override = _mat(hex, 0.8); mi.position = pos; parent.add_child(mi)

func _cyl(parent: Node3D, pos: Vector3, r: float, h: float, hex: String) -> void:
    var mi = MeshInstance3D.new()
    var cm = CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h; mi.mesh = cm
    mi.material_override = _mat(hex, 0.85); mi.position = pos; parent.add_child(mi)

func _cone(parent: Node3D, pos: Vector3, br: float, tr: float, h: float, hex: String) -> void:
    var mi = MeshInstance3D.new()
    var cm = CylinderMesh.new(); cm.top_radius = tr; cm.bottom_radius = br; cm.height = h; mi.mesh = cm
    mi.material_override = _mat(hex, 0.85); mi.position = pos; parent.add_child(mi)

func _cone4(parent: Node3D, pos: Vector3, br: float, tr: float, h: float, hex: String) -> void:
    var mi = MeshInstance3D.new()
    var cm = CylinderMesh.new(); cm.top_radius = tr; cm.bottom_radius = br; cm.height = h
    cm.radial_segments = 4; mi.mesh = cm
    mi.material_override = _mat(hex, 0.85); mi.position = pos; parent.add_child(mi)

func _cone_to(parent: Node3D, pos: Vector3, br: float, tr: float, h: float, hex: String) -> void:
    _cone(parent, pos, br, tr, h, hex)

func _boxn(parent: Node3D, pos: Vector3, size: Vector3, hex: String) -> void:
    var mi = MeshInstance3D.new()
    var bm = BoxMesh.new(); bm.size = size; mi.mesh = bm
    mi.material_override = _mat(hex, 0.85); mi.position = pos; parent.add_child(mi)
