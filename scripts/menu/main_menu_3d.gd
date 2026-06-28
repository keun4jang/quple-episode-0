extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var quokka_pivot: Node3D = $QuokkaPivot
var _t := 0.0

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
    quokka_pivot.rotate_y(delta * 0.6)
    quokka_pivot.position.y = 0.15 + sin(_t * 1.5) * 0.08

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
    SceneTransition.go_to("res://scenes/maps/CompanyFront3D.tscn", "hopeful")

func _on_continue() -> void:
    SaveManager.load_game()
    var cfg = ConfigFile.new()
    cfg.load("user://save.cfg")
    var scene = cfg.get_value("game", "current_scene", "res://scenes/maps/CompanyFront3D.tscn")
    SceneTransition.go_to(scene, "normal")

func _on_quit() -> void:
    get_tree().quit()

func _build_scene() -> void:
    # 바닥 원형 무대
    var floor = MeshInstance3D.new()
    var cyl = CylinderMesh.new(); cyl.top_radius = 2.5; cyl.bottom_radius = 2.5; cyl.height = 0.2
    floor.mesh = cyl
    var fm = StandardMaterial3D.new(); fm.albedo_color = Color("#2A3650"); fm.roughness = 0.8
    floor.material_override = fm; floor.position = Vector3(0, -0.6, 0)
    add_child(floor)
    # 별 배경 (작은 발광 구 여러개)
    for i in range(40):
        var star = MeshInstance3D.new()
        var sm = SphereMesh.new(); sm.radius = 0.06; sm.height = 0.12; star.mesh = sm
        var stm = StandardMaterial3D.new(); stm.albedo_color = Color("#FFF6D0")
        stm.emission_enabled = true; stm.emission = Color("#FFF6D0"); stm.emission_energy_multiplier = 2.0
        star.material_override = stm
        var ang = float(i) * 0.61
        star.position = Vector3(cos(ang) * (5 + (i % 5)), 2 + (i % 7), -6 - (i % 4))
        add_child(star)

func _box(parent, pos, size, hex):
    var mi = MeshInstance3D.new()
    var m = BoxMesh.new(); m.size = size; mi.mesh = m
    var mat = StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.85
    mi.material_override = mat; mi.position = pos; parent.add_child(mi)
