extends Node3D

const FOLLOW_SPEED: float = 2.8
const FOLLOW_START_DIST: float = 2.0
const FOLLOW_STOP_DIST: float = 1.2
const TELEPORT_DIST: float = 5.0

var _is_following: bool = false
var _idle_time: float = 0.0
var _walk_time: float = 0.0
var _is_walking: bool = false
var _joined: bool = false
var _holding: bool = false

var _tail_mesh: MeshInstance3D = null
var _left_eye_hl: MeshInstance3D = null
var _right_eye_hl: MeshInstance3D = null
var _emotion: String = "neutral"
var _emotion_time: float = 0.0
var _left_ear: Node3D = null
var _right_ear: Node3D = null

@onready var body_pivot: Node3D = $BodyPivot
@onready var head_pivot: Node3D = $BodyPivot/HeadPivot
@onready var left_arm: Node3D = $BodyPivot/LeftArmPivot
@onready var right_arm: Node3D = $BodyPivot/RightArmPivot
@onready var left_leg: Node3D = $BodyPivot/LeftLegPivot
@onready var right_leg: Node3D = $BodyPivot/RightLegPivot
@onready var left_ear: Node3D = $BodyPivot/HeadPivot/LeftEarPivot
@onready var right_ear: Node3D = $BodyPivot/HeadPivot/RightEarPivot

func _ready() -> void:
    _build_meshes()

    var shadow = MeshInstance3D.new()
    var sc = CylinderMesh.new(); sc.top_radius = 0.3; sc.bottom_radius = 0.3; sc.height = 0.01
    shadow.mesh = sc
    var smat = StandardMaterial3D.new()
    smat.albedo_color = Color(0, 0, 0, 0.32)
    smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    shadow.material_override = smat
    shadow.position = Vector3(0, 0.03, 0)
    add_child(shadow)

func join_player() -> void:
    _joined = true

func set_emotion(emotion: String) -> void:
    _emotion = emotion
    _emotion_time = 0.0

func _physics_process(delta: float) -> void:
    if not _joined:
        _holding = false
        _animate_idle(delta)
        return
    var player = get_tree().get_first_node_in_group("player")
    if player == null:
        _holding = false
        _animate_idle(delta)
        return
    var dist = global_position.distance_to(player.global_position)
    _holding = _joined and dist <= 1.5
    if dist > TELEPORT_DIST:
        global_position = player.global_position + Vector3(0.8, 0, 0.8)
    if dist > FOLLOW_START_DIST:
        var dir = (player.global_position - global_position).normalized()
        dir.y = 0
        global_position += dir * FOLLOW_SPEED * delta
        var target_angle = atan2(dir.x, dir.z)
        rotation.y = lerp_angle(rotation.y, target_angle, 8.0 * delta)
        _is_walking = true
    else:
        _is_walking = false
    if _is_walking:
        _animate_walk(delta)
    else:
        _animate_idle(delta)

func _animate_idle(delta: float) -> void:
    _idle_time += delta
    var intensity = 0.015 if _joined else 0.008
    body_pivot.position.y = sin(_idle_time * (TAU / 1.8)) * intensity
    head_pivot.rotation.z = sin(_idle_time * (TAU / 2.5)) * deg_to_rad(0.8)

    _emotion_time += delta
    if _emotion_time > 4.0:
        _emotion = "neutral"

    match _emotion:
        "happy":
            # faster ear wiggle, tail wag
            if _tail_mesh: _tail_mesh.rotation.z = sin(_idle_time * 4.0) * deg_to_rad(25.0)
            left_ear.rotation.z = sin(_idle_time * 3.0) * deg_to_rad(5.0)
            right_ear.rotation.z = -sin(_idle_time * 3.0) * deg_to_rad(5.0)
        "nervous":
            # droopy ears, slight body tremble
            left_ear.rotation.z = lerp(left_ear.rotation.z, deg_to_rad(-8.0), delta * 3.0)
            right_ear.rotation.z = lerp(right_ear.rotation.z, deg_to_rad(8.0), delta * 3.0)
            body_pivot.rotation.z = sin(_idle_time * 8.0) * deg_to_rad(1.5)
        "excited":
            # arms slightly raised
            left_arm.rotation.x = lerp(left_arm.rotation.x, deg_to_rad(-30.0), delta * 3.0)
            right_arm.rotation.x = lerp(right_arm.rotation.x, deg_to_rad(-30.0), delta * 3.0)
            if _tail_mesh: _tail_mesh.rotation.z = sin(_idle_time * 6.0) * deg_to_rad(30.0)
        _:
            if _tail_mesh: _tail_mesh.rotation.z = sin(_idle_time * 1.5) * deg_to_rad(8.0)

    if _holding:
        left_arm.rotation.x = lerp(left_arm.rotation.x, deg_to_rad(-25.0), delta * 6.0)
        left_arm.rotation.z = lerp(left_arm.rotation.z, deg_to_rad(-30.0), delta * 6.0)

func _animate_walk(delta: float) -> void:
    _walk_time += delta * FOLLOW_SPEED * 2.5
    body_pivot.position.y = sin(_walk_time * 3.0) * 0.06
    left_arm.rotation.x = sin(_walk_time * 3.0) * deg_to_rad(10.0)
    right_arm.rotation.x = -sin(_walk_time * 3.0) * deg_to_rad(10.0)
    left_leg.rotation.x = -sin(_walk_time * 3.0) * deg_to_rad(7.0)
    right_leg.rotation.x = sin(_walk_time * 3.0) * deg_to_rad(7.0)

    _emotion_time += delta
    if _emotion_time > 4.0:
        _emotion = "neutral"

    match _emotion:
        "happy":
            # faster ear wiggle, tail wag
            if _tail_mesh: _tail_mesh.rotation.z = sin(_idle_time * 4.0) * deg_to_rad(25.0)
            left_ear.rotation.z = sin(_idle_time * 3.0) * deg_to_rad(5.0)
            right_ear.rotation.z = -sin(_idle_time * 3.0) * deg_to_rad(5.0)
        "nervous":
            # droopy ears, slight body tremble
            left_ear.rotation.z = lerp(left_ear.rotation.z, deg_to_rad(-8.0), delta * 3.0)
            right_ear.rotation.z = lerp(right_ear.rotation.z, deg_to_rad(8.0), delta * 3.0)
            body_pivot.rotation.z = sin(_idle_time * 8.0) * deg_to_rad(1.5)
        "excited":
            # arms slightly raised
            left_arm.rotation.x = lerp(left_arm.rotation.x, deg_to_rad(-30.0), delta * 3.0)
            right_arm.rotation.x = lerp(right_arm.rotation.x, deg_to_rad(-30.0), delta * 3.0)
            if _tail_mesh: _tail_mesh.rotation.z = sin(_idle_time * 6.0) * deg_to_rad(30.0)
        _:
            if _tail_mesh: _tail_mesh.rotation.z = sin(_idle_time * 1.5) * deg_to_rad(8.0)

    if _holding:
        left_arm.rotation.x = lerp(left_arm.rotation.x, deg_to_rad(-25.0), delta * 6.0)
        left_arm.rotation.z = lerp(left_arm.rotation.z, deg_to_rad(-30.0), delta * 6.0)

func _build_meshes() -> void:
    var fur = "#C98B61"
    var body_col = "#F2B9A0"   # 코랄 스웨터
    # ── 몸통(스웨터) ──
    _set_sphere($BodyPivot/BodyMesh, 0.31, 0.50, body_col)
    $BodyPivot/BodyMesh.position = Vector3(0, -0.02, 0)
    $BodyPivot/BodyMesh.scale = Vector3(1.0, 1.0, 0.95)
    var collar = MeshInstance3D.new()
    _set_sphere_mi(collar, 0.21, 0.15, _shade(body_col, -0.08))
    collar.position = Vector3(0, 0.2, 0.02); collar.scale = Vector3(1.0, 0.5, 1.0)
    $BodyPivot.add_child(collar)
    _set_sphere($BodyPivot/BellyMesh, 0.18, 0.18, _shade(body_col, 0.05))
    $BodyPivot/BellyMesh.position = Vector3(0, 0.02, 0.16); $BodyPivot/BellyMesh.scale = Vector3(0.85, 0.95, 0.5)

    # ── 머리 ──
    $BodyPivot/HeadPivot.position = Vector3(0, 0.4, 0)
    _set_sphere($BodyPivot/HeadPivot/HeadMesh, 0.33, 0.34, fur)
    $BodyPivot/HeadPivot/HeadMesh.scale = Vector3(1.05, 0.98, 1.0)

    # ── 귀 + 분홍 안쪽 ──
    $BodyPivot/HeadPivot/LeftEarPivot.position = Vector3(-0.18, 0.21, 0.05)
    $BodyPivot/HeadPivot/RightEarPivot.position = Vector3(0.18, 0.21, 0.05)
    _set_sphere($BodyPivot/HeadPivot/LeftEarPivot/LeftEarMesh, 0.11, 0.12, fur)
    _set_sphere($BodyPivot/HeadPivot/RightEarPivot/RightEarMesh, 0.11, 0.12, fur)
    $BodyPivot/HeadPivot/LeftEarPivot/LeftEarMesh.scale = Vector3(0.9, 1.0, 0.7)
    $BodyPivot/HeadPivot/RightEarPivot/RightEarMesh.scale = Vector3(0.9, 1.0, 0.7)
    _child_sphere($BodyPivot/HeadPivot/LeftEarPivot, 0.065, 0.07, "#F2A6AE", Vector3(0, 0.01, 0.045), Vector3(0.8, 1.0, 0.6))
    _child_sphere($BodyPivot/HeadPivot/RightEarPivot, 0.065, 0.07, "#F2A6AE", Vector3(0, 0.01, 0.045), Vector3(0.8, 1.0, 0.6))

    # ── 주둥이 ──
    var muzzle = MeshInstance3D.new()
    _set_sphere_mi(muzzle, 0.15, 0.14, _shade(fur, 0.22))
    muzzle.position = Vector3(0, -0.06, 0.25); muzzle.scale = Vector3(1.25, 0.85, 0.8)
    $BodyPivot/HeadPivot.add_child(muzzle)

    # ── 눈 + 하이라이트 ──
    _set_sphere($BodyPivot/HeadPivot/LeftEyeMesh, 0.055, 0.066, "#2A211C")
    _set_sphere($BodyPivot/HeadPivot/RightEyeMesh, 0.055, 0.066, "#2A211C")
    $BodyPivot/HeadPivot/LeftEyeMesh.position = Vector3(-0.13, 0.07, 0.28)
    $BodyPivot/HeadPivot/RightEyeMesh.position = Vector3(0.13, 0.07, 0.28)
    _left_eye_hl = _child_sphere($BodyPivot/HeadPivot, 0.019, 0.023, "#FFFFFF", Vector3(-0.143, 0.092, 0.31), Vector3.ONE)
    _right_eye_hl = _child_sphere($BodyPivot/HeadPivot, 0.019, 0.023, "#FFFFFF", Vector3(0.117, 0.092, 0.31), Vector3.ONE)

    # ── 코 ──
    _set_sphere($BodyPivot/HeadPivot/NoseMesh, 0.032, 0.038, "#3A2418")
    $BodyPivot/HeadPivot/NoseMesh.position = Vector3(0, 0.0, 0.33); $BodyPivot/HeadPivot/NoseMesh.scale = Vector3(1.2, 0.9, 0.9)

    # ── 미소(입) ──
    var mouth = MeshInstance3D.new()
    _set_sphere_mi(mouth, 0.046, 0.046, "#5A3A28")
    mouth.position = Vector3(0, -0.08, 0.32); mouth.scale = Vector3(1.4, 0.45, 0.4)
    $BodyPivot/HeadPivot.add_child(mouth)

    # ── 볼터치 ──
    _set_sphere($BodyPivot/HeadPivot/LeftCheekMesh, 0.058, 0.058, "#FFB0B8")
    _set_sphere($BodyPivot/HeadPivot/RightCheekMesh, 0.058, 0.058, "#FFB0B8")
    $BodyPivot/HeadPivot/LeftCheekMesh.position = Vector3(-0.21, -0.03, 0.22)
    $BodyPivot/HeadPivot/RightCheekMesh.position = Vector3(0.21, -0.03, 0.22)
    $BodyPivot/HeadPivot/LeftCheekMesh.scale = Vector3(1.0, 0.7, 0.5)
    $BodyPivot/HeadPivot/RightCheekMesh.scale = Vector3(1.0, 0.7, 0.5)

    # ── 팔(소매) + 손 ──
    $BodyPivot/LeftArmPivot.position = Vector3(-0.3, 0.08, 0.04)
    $BodyPivot/RightArmPivot.position = Vector3(0.3, 0.08, 0.04)
    _set_capsule($BodyPivot/LeftArmPivot/LeftArmMesh, 0.075, 0.24, body_col)
    _set_capsule($BodyPivot/RightArmPivot/RightArmMesh, 0.075, 0.24, body_col)
    $BodyPivot/LeftArmPivot/LeftArmMesh.position = Vector3(0, -0.1, 0)
    $BodyPivot/RightArmPivot/RightArmMesh.position = Vector3(0, -0.1, 0)
    $BodyPivot/LeftArmPivot.rotation_degrees = Vector3(0, 0, 12)
    $BodyPivot/RightArmPivot.rotation_degrees = Vector3(0, 0, -12)
    _child_sphere($BodyPivot/LeftArmPivot, 0.07, 0.075, fur, Vector3(0, -0.22, 0.01), Vector3.ONE)
    _child_sphere($BodyPivot/RightArmPivot, 0.07, 0.075, fur, Vector3(0, -0.22, 0.01), Vector3.ONE)

    # ── 다리 + 발 ──
    $BodyPivot/LeftLegPivot.position = Vector3(-0.13, -0.24, 0.03)
    $BodyPivot/RightLegPivot.position = Vector3(0.13, -0.24, 0.03)
    _set_capsule($BodyPivot/LeftLegPivot/LeftLegMesh, 0.08, 0.16, fur)
    _set_capsule($BodyPivot/RightLegPivot/RightLegMesh, 0.08, 0.16, fur)
    $BodyPivot/LeftLegPivot/LeftLegMesh.position = Vector3(0, -0.05, 0)
    $BodyPivot/RightLegPivot/RightLegMesh.position = Vector3(0, -0.05, 0)
    _child_sphere($BodyPivot/LeftLegPivot, 0.085, 0.065, _shade(fur, -0.1), Vector3(0, -0.14, 0.05), Vector3(1.0, 0.7, 1.3))
    _child_sphere($BodyPivot/RightLegPivot, 0.085, 0.065, _shade(fur, -0.1), Vector3(0, -0.14, 0.05), Vector3(1.0, 0.7, 1.3))

    # ── 사원증(가슴) ──
    _set_box($BodyPivot/BadgeMesh, Vector3(0.09, 0.11, 0.02), "#EDEDED")
    $BodyPivot/BadgeMesh.position = Vector3(0.1, 0.04, 0.27)

    # ── 꼬리 ──
    var tail = _child_sphere($BodyPivot, 0.09, 0.11, _shade(fur, 0.18), Vector3(0, -0.05, -0.3), Vector3(0.8, 0.8, 1.0))
    _tail_mesh = tail

    # ── 배낭 + 매트(등 뒤) ──
    var pack = MeshInstance3D.new()
    _set_sphere_mi(pack, 0.17, 0.34, "#C97A5A")
    pack.position = Vector3(0, 0.05, -0.3); pack.scale = Vector3(1.0, 1.0, 0.6)
    $BodyPivot.add_child(pack)
    var matroll = MeshInstance3D.new()
    var rm = CapsuleMesh.new(); rm.radius = 0.065; rm.height = 0.32; matroll.mesh = rm
    var rmat = StandardMaterial3D.new(); rmat.albedo_color = Color("#F2A0B0"); rmat.roughness = 0.9
    matroll.material_override = rmat
    matroll.position = Vector3(0, 0.24, -0.3); matroll.rotation_degrees = Vector3(0, 0, 90)
    $BodyPivot.add_child(matroll)

func _shade(hex: String, amt: float) -> Color:
    var c = Color(hex)
    return c.lightened(amt) if amt >= 0.0 else c.darkened(-amt)

func _to_col(c) -> Color:
    return c if c is Color else Color(c)

func _child_sphere(parent: Node3D, radius: float, height: float, col, pos: Vector3, scl: Vector3) -> MeshInstance3D:
    var mi = MeshInstance3D.new()
    var m = SphereMesh.new(); m.radius = radius; m.height = height; mi.mesh = m
    var mat = StandardMaterial3D.new(); mat.albedo_color = _to_col(col); mat.roughness = 0.85
    mi.material_override = mat
    mi.position = pos; mi.scale = scl
    parent.add_child(mi)
    return mi

func _set_sphere(mi: MeshInstance3D, radius: float, height: float, hex) -> void:
    var m = SphereMesh.new(); m.radius = radius; m.height = height; mi.mesh = m
    var mat = StandardMaterial3D.new(); mat.albedo_color = _to_col(hex); mat.roughness = 0.85
    mi.material_override = mat

func _set_sphere_mi(mi: MeshInstance3D, radius: float, height: float, hex) -> void:
    var m = SphereMesh.new(); m.radius = radius; m.height = height; mi.mesh = m
    var mat = StandardMaterial3D.new(); mat.albedo_color = _to_col(hex); mat.roughness = 0.85
    mi.material_override = mat

func _set_capsule(mi: MeshInstance3D, radius: float, height: float, hex) -> void:
    var m = CapsuleMesh.new(); m.radius = radius; m.height = height; mi.mesh = m
    var mat = StandardMaterial3D.new(); mat.albedo_color = _to_col(hex); mat.roughness = 0.85
    mi.material_override = mat

func _set_box(mi: MeshInstance3D, size: Vector3, hex) -> void:
    var m = BoxMesh.new(); m.size = size; mi.mesh = m
    var mat = StandardMaterial3D.new(); mat.albedo_color = _to_col(hex); mat.roughness = 0.85
    mi.material_override = mat
