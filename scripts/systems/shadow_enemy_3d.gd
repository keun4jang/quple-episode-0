class_name ShadowEnemy3D
extends Area3D
## 맵을 떠다니는 "그림자 감정". 플레이어가 가까이 오면 쫓아오고, 닿으면 전투가 시작된다.
## 메시는 전부 코드로 만든다(SphereMesh + StandardMaterial3D).

const AGGRO_RANGE := 7.0
## 나타난 직후 잠깐은 쫓지 않는다. 맵을 옮기자마자 전투로 끌려가지 않게 하는 유예.
const SPAWN_GRACE := 2.5
const TOUCH_RANGE := 1.15
const CHASE_SPEED := 1.9
const WANDER_SPEED := 0.7

var enemy_id: String = "anxiety"
var home_pos: Vector3 = Vector3.ZERO

var _time: float = 0.0
var _wander_angle: float = 0.0
var _cooldown: float = 0.0
var _grace: float = SPAWN_GRACE
var _player = null
var _body_mesh: MeshInstance3D
var _glow: OmniLight3D

func setup(id: String, pos: Vector3) -> void:
    enemy_id = id
    home_pos = pos
    position = pos

func _ready() -> void:
    _wander_angle = randf() * TAU
    _time = randf() * 10.0
    monitoring = true
    _build_visual()
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.8
    shape.shape = sphere
    add_child(shape)

func _build_visual() -> void:
    var def: Dictionary = BattleSystem.enemy_def(enemy_id)
    if def.is_empty():
        return
    var main := Color(def.colors.get("X", "#6C7BC4"))
    var accent := Color(def.colors.get("A", "#FFFFFF"))
    var is_boss: bool = def.get("is_boss", false)
    var scale_mul: float = 1.5 if is_boss else 1.0

    # 본체 — 흐물흐물한 어두운 덩어리
    _body_mesh = MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.45 * scale_mul
    sm.height = 0.95 * scale_mul
    _body_mesh.mesh = sm
    var mat := StandardMaterial3D.new()
    mat.albedo_color = main
    mat.emission_enabled = true
    mat.emission = main
    mat.emission_energy_multiplier = 1.4
    mat.roughness = 0.6
    _body_mesh.material_override = mat
    _body_mesh.position = Vector3(0, 0.9, 0)
    add_child(_body_mesh)

    # 아래로 흘러내리는 그림자 꼬리
    var tail := MeshInstance3D.new()
    var tm := SphereMesh.new()
    tm.radius = 0.3 * scale_mul
    tm.height = 0.9 * scale_mul
    tail.mesh = tm
    var tmat := StandardMaterial3D.new()
    tmat.albedo_color = Color(main.r * 0.5, main.g * 0.5, main.b * 0.5, 0.75)
    tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    tail.material_override = tmat
    tail.position = Vector3(0, 0.35, 0)
    tail.scale = Vector3(0.8, 1.1, 0.8)
    add_child(tail)

    # 눈 — 텅 빈 흰 점
    for side in [-1.0, 1.0]:
        var eye := MeshInstance3D.new()
        var em := SphereMesh.new()
        em.radius = 0.09 * scale_mul
        em.height = 0.18 * scale_mul
        eye.mesh = em
        var emat := StandardMaterial3D.new()
        emat.albedo_color = accent
        emat.emission_enabled = true
        emat.emission = accent
        emat.emission_energy_multiplier = 2.5
        emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        eye.material_override = emat
        eye.position = Vector3(0.17 * side * scale_mul, 1.0 * scale_mul, 0.34 * scale_mul)
        add_child(eye)

    # 주변을 물들이는 빛
    _glow = OmniLight3D.new()
    _glow.light_color = main
    _glow.light_energy = 1.1
    _glow.omni_range = 3.2 * scale_mul
    _glow.position = Vector3(0, 1.0, 0)
    add_child(_glow)

    # 이름표
    var label := Label3D.new()
    label.text = def.name
    label.font_size = 96
    label.pixel_size = 0.0032
    label.modulate = accent
    label.outline_size = 24
    label.outline_modulate = Color(0.1, 0.08, 0.12)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.position = Vector3(0, 1.75 * scale_mul, 0)
    add_child(label)

func _physics_process(delta: float) -> void:
    _time += delta
    if _cooldown > 0.0:
        _cooldown -= delta
    if _grace > 0.0:
        _grace -= delta

    if _body_mesh:
        _body_mesh.position.y = 0.9 + sin(_time * 2.2) * 0.12
        _body_mesh.scale = Vector3(
            1.0 + sin(_time * 3.1) * 0.06,
            1.0 - sin(_time * 3.1) * 0.05,
            1.0 + sin(_time * 2.7) * 0.06)
    if _glow:
        _glow.light_energy = 1.0 + sin(_time * 4.0) * 0.3

    if BattleSystem.in_battle:
        return
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player")
        if _player == null:
            return

    var to_player: Vector3 = _player.global_position - global_position
    to_player.y = 0.0
    var dist := to_player.length()

    if _cooldown > 0.0:
        # 방금 전투가 끝났다면 잠시 물러난다
        if dist < 4.0 and dist > 0.01:
            global_position -= to_player.normalized() * CHASE_SPEED * delta
        return

    if _grace > 0.0:
        # 아직 유예 중 — 제자리에서 어슬렁거리기만 한다
        _wander(delta)
        return

    if dist <= TOUCH_RANGE:
        _engage()
        return

    if dist <= AGGRO_RANGE and dist > 0.01:
        global_position += to_player.normalized() * CHASE_SPEED * delta
    else:
        _wander(delta)

## 제자리 근처를 어슬렁거린다
func _wander(delta: float) -> void:
    _wander_angle += delta * 0.6
    var target := home_pos + Vector3(cos(_wander_angle) * 1.6, 0, sin(_wander_angle) * 1.6)
    var dir := target - global_position
    dir.y = 0
    if dir.length() > 0.05:
        global_position += dir.normalized() * WANDER_SPEED * delta

func _engage() -> void:
    if BattleSystem.in_battle or _cooldown > 0.0:
        return
    if BattleSystem.start_battle(enemy_id, self):
        _cooldown = 4.0
