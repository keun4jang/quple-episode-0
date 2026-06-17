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

@onready var body_pivot: Node3D = $BodyPivot
@onready var head_pivot: Node3D = $BodyPivot/HeadPivot
@onready var left_arm: Node3D = $BodyPivot/LeftArmPivot
@onready var right_arm: Node3D = $BodyPivot/RightArmPivot
@onready var left_leg: Node3D = $BodyPivot/LeftLegPivot
@onready var right_leg: Node3D = $BodyPivot/RightLegPivot

func _ready() -> void:
    _build_meshes()

func join_player() -> void:
    _joined = true

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

func _animate_walk(delta: float) -> void:
    _walk_time += delta * FOLLOW_SPEED * 2.5
    body_pivot.position.y = sin(_walk_time * 3.0) * 0.06
    left_arm.rotation.x = sin(_walk_time * 3.0) * deg_to_rad(10.0)
    right_arm.rotation.x = -sin(_walk_time * 3.0) * deg_to_rad(10.0)
    left_leg.rotation.x = -sin(_walk_time * 3.0) * deg_to_rad(7.0)
    right_leg.rotation.x = sin(_walk_time * 3.0) * deg_to_rad(7.0)

func _build_meshes() -> void:
    _set_sphere($BodyPivot/BodyMesh, 0.3, 0.34, "#C98B61")
    _set_sphere($BodyPivot/BellyMesh, 0.2, 0.24, "#F5D9B5")
    _set_sphere($BodyPivot/HeadPivot/HeadMesh, 0.26, 0.28, "#C98B61")
    _set_sphere($BodyPivot/HeadPivot/LeftEarPivot/LeftEarMesh, 0.08, 0.09, "#C98B61")
    _set_sphere($BodyPivot/HeadPivot/RightEarPivot/RightEarMesh, 0.08, 0.09, "#C98B61")
    _set_sphere($BodyPivot/HeadPivot/LeftEyeMesh, 0.042, 0.048, "#1A1412")
    _set_sphere($BodyPivot/HeadPivot/RightEyeMesh, 0.042, 0.048, "#1A1412")
    _set_sphere($BodyPivot/HeadPivot/NoseMesh, 0.032, 0.038, "#3A2418")
    _set_sphere($BodyPivot/HeadPivot/LeftCheekMesh, 0.05, 0.055, "#EFA3A3")
    _set_sphere($BodyPivot/HeadPivot/RightCheekMesh, 0.05, 0.055, "#EFA3A3")
    _set_capsule($BodyPivot/LeftArmPivot/LeftArmMesh, 0.065, 0.2, "#C98B61")
    _set_capsule($BodyPivot/RightArmPivot/RightArmMesh, 0.065, 0.2, "#C98B61")
    _set_capsule($BodyPivot/LeftLegPivot/LeftLegMesh, 0.065, 0.22, "#C98B61")
    _set_capsule($BodyPivot/RightLegPivot/RightLegMesh, 0.065, 0.22, "#C98B61")
    _set_box($BodyPivot/BadgeMesh, Vector3(0.08, 0.1, 0.02), "#EDEDED")

func _set_sphere(mi: MeshInstance3D, radius: float, height: float, hex: String) -> void:
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
