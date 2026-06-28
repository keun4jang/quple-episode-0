extends Area3D

@export var interact_text: String = ""
@export var target_scene_path: String = ""
@export var item_id: String = ""

signal interacted

var hint_mesh: MeshInstance3D = null      # 떠다니는 아이콘
var ring_mesh: MeshInstance3D = null      # 바닥 링
var beam_mesh: MeshInstance3D = null      # 포탈 빛기둥
var _kind: String = "npc"                 # portal / item / npc
var _t: float = 0.0
var _label: Label3D = null

func _ready() -> void:
    add_to_group("interactable")
    _resolve_kind()
    _build_marker()

func _resolve_kind() -> void:
    if item_id != "":
        _kind = "item"
    elif target_scene_path != "":
        _kind = "portal"
    else:
        _kind = "npc"

func _kind_color() -> Color:
    match _kind:
        "portal": return Color("#4FC3F7")  # 하늘색 (장소 이동)
        "item":   return Color("#FFD76D")  # 금색 (아이템)
        _:        return Color("#FF9EC4")  # 분홍 (NPC 대화)

func _build_marker() -> void:
    var col = _kind_color()
    # 트리거가 공중에 있어도 링은 항상 바닥(y≈0)에 놓이도록 보정
    var floor_y = 0.04 - global_position.y

    # 1) 바닥 링 (TorusMesh) - 확실하게 위치 표시
    ring_mesh = MeshInstance3D.new()
    var torus = TorusMesh.new()
    torus.inner_radius = 0.55
    torus.outer_radius = 0.72
    ring_mesh.mesh = torus
    var ring_mat = StandardMaterial3D.new()
    ring_mat.albedo_color = col
    ring_mat.emission_enabled = true
    ring_mat.emission = col
    ring_mat.emission_energy_multiplier = 2.5
    ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring_mat.albedo_color.a = 0.9
    ring_mesh.material_override = ring_mat
    ring_mesh.position = Vector3(0, floor_y, 0)  # 항상 바닥 높이
    add_child(ring_mesh)

    # 2) 바닥 채움 디스크 (은은한 빛)
    var disc = MeshInstance3D.new()
    var cyl = CylinderMesh.new()
    cyl.top_radius = 0.55
    cyl.bottom_radius = 0.55
    cyl.height = 0.02
    disc.mesh = cyl
    var disc_mat = StandardMaterial3D.new()
    disc_mat.albedo_color = col
    disc_mat.emission_enabled = true
    disc_mat.emission = col
    disc_mat.emission_energy_multiplier = 0.8
    disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    disc_mat.albedo_color.a = 0.25
    disc.material_override = disc_mat
    disc.position = Vector3(0, floor_y - 0.01, 0)
    add_child(disc)

    # 3) 포탈이면 위로 솟는 빛기둥
    if _kind == "portal":
        beam_mesh = MeshInstance3D.new()
        var beam = CylinderMesh.new()
        beam.top_radius = 0.5
        beam.bottom_radius = 0.55
        beam.height = 3.0
        beam_mesh.mesh = beam
        var beam_mat = StandardMaterial3D.new()
        beam_mat.albedo_color = col
        beam_mat.emission_enabled = true
        beam_mat.emission = col
        beam_mat.emission_energy_multiplier = 1.2
        beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        beam_mat.albedo_color.a = 0.12
        beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        beam_mesh.material_override = beam_mat
        beam_mesh.position = Vector3(0, floor_y + 1.5, 0)
        add_child(beam_mesh)

    # 4) 떠다니는 아이콘 (포탈=화살표 느낌 위로, 그 외=구슬)
    hint_mesh = MeshInstance3D.new()
    if _kind == "portal":
        var cone = CylinderMesh.new()
        cone.top_radius = 0.0
        cone.bottom_radius = 0.16
        cone.height = 0.26
        hint_mesh.mesh = cone
    else:
        var sm = SphereMesh.new()
        sm.radius = 0.1
        sm.height = 0.2
        hint_mesh.mesh = sm
    var hmat = StandardMaterial3D.new()
    hmat.albedo_color = col
    hmat.emission_enabled = true
    hmat.emission = col
    hmat.emission_energy_multiplier = 2.0
    hint_mesh.material_override = hmat
    hint_mesh.position = Vector3(0, 0.7, 0)
    add_child(hint_mesh)

    # 떠다니는 글자 라벨 (무엇을 하는 곳인지 표시)
    var label = Label3D.new()
    var txt = interact_text
    if txt == "":
        match _kind:
            "portal": txt = "이동하기"
            "item": txt = "줍기"
            _: txt = "대화하기"
    label.text = txt
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.fixed_size = true
    label.pixel_size = 0.0012
    label.modulate = col
    label.outline_modulate = Color(0, 0, 0, 0.9)
    label.outline_size = 12
    label.font_size = 48
    label.position = Vector3(0, floor_y + 1.6, 0)
    add_child(label)
    _label = label

func _process(delta: float) -> void:
    _t += delta
    # 플레이어가 가까울 때만 글자 라벨/아이콘 표시 (화면 깔끔하게)
    var near = false
    var p = get_tree().get_first_node_in_group("player")
    if p:
        near = global_position.distance_to(p.global_position) < 2.6
    if _label:
        _label.visible = near
    if hint_mesh:
        hint_mesh.visible = near
    if ring_mesh:
        # 링 회전 + 맥동 스케일
        ring_mesh.rotate_y(delta * 0.8)
        var s = 1.0 + sin(_t * 2.5) * 0.08
        ring_mesh.scale = Vector3(s, 1.0, s)
    if hint_mesh:
        hint_mesh.position.y = 0.7 + sin(_t * 2.0) * 0.1
        if _kind == "portal":
            hint_mesh.position.y += 0.1
            # 화살표는 아래위로 까딱
        else:
            hint_mesh.rotate_y(delta * 1.2)
    if beam_mesh:
        var bm = beam_mesh.material_override as StandardMaterial3D
        if bm:
            bm.albedo_color.a = 0.10 + sin(_t * 2.0) * 0.05
    if _label:
        _label.position.y = (0.04 - global_position.y) + 1.6 + sin(_t * 2.0) * 0.08

func interact() -> void:
    if AudioManager: AudioManager.ui_select()
    interacted.emit()
    if item_id != "":
        _collect_item()
    elif target_scene_path != "":
        var style = "normal"
        if "Front" in target_scene_path:
            style = "hopeful"
        elif "Boss" in target_scene_path:
            style = "tense"
        SceneTransition.go_to(target_scene_path, style)
    elif interact_text != "":
        var db = get_tree().get_first_node_in_group("dialogue_box")
        if db:
            db.show_text(interact_text)

func _collect_item() -> void:
    match item_id:
        "camera":
            Episode0State.has_camera = true
            _show_and_remove("오래된 카메라를 챙겼다.")
        "notebook":
            Episode0State.has_notebook = true
            _show_and_remove("비어 있는 여행 수첩을 챙겼다.")
        "travel_bag":
            Episode0State.has_travel_bag = true
            _show_and_remove("작은 여행 가방을 챙겼다.")
        "badge":
            Episode0State.badge_returned = true
            _show_and_remove("사원증을 반납했다.")
    if Episode0State.all_items_collected() and Episode0State.current_state == Episode0State.State.COLLECT_TRAVEL_ITEMS:
        Episode0State.advance_to(Episode0State.State.RETURN_BADGE)

func _show_and_remove(text: String) -> void:
    var db = get_tree().get_first_node_in_group("dialogue_box")
    if db:
        db.show_text(text)
    if hint_mesh: hint_mesh.visible = false
    if ring_mesh: ring_mesh.visible = false
    if _label: _label.visible = false
    set_deferred("monitoring", false)
