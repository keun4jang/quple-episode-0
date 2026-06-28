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

func join_player() -> void:
    _joined = true

func set_emotion(emotion: String) -> void:
    _emotion = emotion
    _emotion_time = 0.0

func _physics_process(delta: float) -> void:
    if not _joined:
        _animate_idle(delta)
        return
    var player = get_tree().get_first_node_in_group("player")
    if player == null:
        _animate_idle(delta)
        return
    var dist = global_position.distance_to(player.global_position)
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

func _build_meshes() -> void:
    _set_sphere($BodyPivot/BodyMesh, 0.28, 0.32, "#C98B61")
    _set_sphere($BodyPivot/BellyMesh, 0.2, 0.24, "#F5D9B5")
    _set_sphere($BodyPivot/HeadPivot/HeadMesh, 0.31, 0.33, "#C98B61")
    _set_sphere($BodyPivot/HeadPivot/LeftEarPivot/LeftEarMesh, 0.095, 0.11, "#C98B61")
    _set_sphere($BodyPivot/HeadPivot/RightEarPivot/RightEarMesh, 0.095, 0.11, "#C98B61")
    _set_sphere($BodyPivot/HeadPivot/LeftEyeMesh, 0.058, 0.064, "#1A1412")
    _set_sphere($BodyPivot/HeadPivot/RightEyeMesh, 0.058, 0.064, "#1A1412")
    _set_sphere($BodyPivot/HeadPivot/NoseMesh, 0.028, 0.032, "#3A2418")
    _set_sphere($BodyPivot/HeadPivot/LeftCheekMesh, 0.062, 0.07, "#FFB0B8")
    _set_sphere($BodyPivot/HeadPivot/RightCheekMesh, 0.062, 0.07, "#FFB0B8")
    _set_capsule($BodyPivot/LeftArmPivot/LeftArmMesh, 0.065, 0.2, "#C98B61")
    _set_capsule($BodyPivot/RightArmPivot/RightArmMesh, 0.065, 0.2, "#C98B61")
    _set_capsule($BodyPivot/LeftLegPivot/LeftLegMesh, 0.065, 0.22, "#C98B61")
    _set_capsule($BodyPivot/RightLegPivot/RightLegMesh, 0.065, 0.22, "#C98B61")
    _set_box($BodyPivot/BadgeMesh, Vector3(0.08, 0.1, 0.02), "#EDEDED")

    # Reposition face features for bigger chibi head
    $BodyPivot/HeadPivot/LeftEyeMesh.position = Vector3(-0.11, 0.05, 0.25)
    $BodyPivot/HeadPivot/RightEyeMesh.position = Vector3(0.11, 0.05, 0.25)
    $BodyPivot/HeadPivot/NoseMesh.position = Vector3(0, -0.02, 0.3)
    $BodyPivot/HeadPivot/LeftCheekMesh.position = Vector3(-0.16, -0.04, 0.23)
    $BodyPivot/HeadPivot/RightCheekMesh.position = Vector3(0.16, -0.04, 0.23)

    # Get eye positions for sclera and highlight placement
    var left_eye_mi: MeshInstance3D = $BodyPivot/HeadPivot/LeftEyeMesh
    var right_eye_mi: MeshInstance3D = $BodyPivot/HeadPivot/RightEyeMesh

    # White sclera behind each eye
    var left_sclera = MeshInstance3D.new()
    var right_sclera = MeshInstance3D.new()
    $BodyPivot/HeadPivot.add_child(left_sclera)
    $BodyPivot/HeadPivot.add_child(right_sclera)
    left_sclera.position = left_eye_mi.position + Vector3(0, 0, -0.01)
    right_sclera.position = right_eye_mi.position + Vector3(0, 0, -0.01)
    _set_sphere_mi(left_sclera, 0.07, 0.083, "#F5F5F5")
    _set_sphere_mi(right_sclera, 0.07, 0.083, "#F5F5F5")

    # Eye highlights
    var left_hl = MeshInstance3D.new()
    var right_hl = MeshInstance3D.new()
    $BodyPivot/HeadPivot.add_child(left_hl)
    $BodyPivot/HeadPivot.add_child(right_hl)
    left_hl.position = left_eye_mi.position + Vector3(-0.012, 0, 0.03)
    right_hl.position = right_eye_mi.position + Vector3(-0.012, 0, 0.03)
    _set_sphere_mi(left_hl, 0.023, 0.029, "#FFFFFF")
    _set_sphere_mi(right_hl, 0.023, 0.029, "#FFFFFF")
    _left_eye_hl = left_hl
    _right_eye_hl = right_hl

    # Tail
    var tail = MeshInstance3D.new()
    $BodyPivot.add_child(tail)
    tail.position = Vector3(0, 0.08, -0.27)
    _set_sphere_mi(tail, 0.09, 0.11, "#F5D9B5")
    _tail_mesh = tail

func _set_sphere(mi: MeshInstance3D, radius: float, height: float, hex: String) -> void:
    var m = SphereMesh.new(); m.radius = radius; m.height = height; mi.mesh = m
    var mat = StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.85
    mi.material_override = mat

func _set_sphere_mi(mi: MeshInstance3D, radius: float, height: float, hex: String) -> void:
    var m = SphereMesh.new(); m.radius = radius; m.height = height; mi.mesh = m
    var mat = StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.85
    mi.material_override = mat

func _set_capsule(mi: MeshInstance3D, radius: float, height: float, hex: String) -> void:
    var m = CapsuleMesh.new(); m.radius = radius; m.height = height; mi.mesh = m
    var mat = StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.85
    mi.material_override = mat

func _set_box(mi: MeshInstance3D, size: Vector3, hex: String) -> void:
    var m = BoxMesh.new(); m.size = size; mi.mesh = m
    var mat = StandardMaterial3D.new(); mat.albedo_color = Color(hex); mat.roughness = 0.85
    mi.material_override = mat
