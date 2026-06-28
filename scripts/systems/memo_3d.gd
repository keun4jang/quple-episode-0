extends Area3D

@export var memo_id: String = ""
@export var memo_text: String = "오래된 메모를 발견했다."

var _ring: MeshInstance3D
var _icon: MeshInstance3D
var _t := 0.0
var _label: Label3D

func _ready() -> void:
    add_to_group("interactable")
    if memo_id in Episode0State.memos_found:
        queue_free()
        return
    _build()

func _build() -> void:
    var col = Color("#B98CFF")  # 보라 = 숨겨진 메모
    var floor_y = 0.04 - global_position.y
    _ring = MeshInstance3D.new()
    var t = TorusMesh.new(); t.inner_radius = 0.4; t.outer_radius = 0.55; _ring.mesh = t
    var m = StandardMaterial3D.new(); m.albedo_color = col; m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = 2.5
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color.a = 0.9
    _ring.material_override = m; _ring.position = Vector3(0, floor_y, 0); add_child(_ring)
    _icon = MeshInstance3D.new()
    var bm = BoxMesh.new(); bm.size = Vector3(0.18, 0.22, 0.02); _icon.mesh = bm
    var im = StandardMaterial3D.new(); im.albedo_color = Color("#F5EFD0"); im.emission_enabled = true; im.emission = col; im.emission_energy_multiplier = 1.0
    _icon.material_override = im; _icon.position = Vector3(0, 0.6, 0); add_child(_icon)
    _label = Label3D.new()
    _label.text = "메모 보기"; _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.no_depth_test = true; _label.fixed_size = true; _label.pixel_size = 0.0012
    _label.modulate = col; _label.outline_modulate = Color(0,0,0,0.9); _label.outline_size = 12; _label.font_size = 48
    _label.position = Vector3(0, floor_y + 1.4, 0); add_child(_label); _label.visible = false

func _process(delta: float) -> void:
    _t += delta
    var near = false
    var p = get_tree().get_first_node_in_group("player")
    if p: near = global_position.distance_to(p.global_position) < 2.6
    if _label: _label.visible = near
    if _icon:
        _icon.visible = near
        _icon.position.y = 0.6 + sin(_t * 2.0) * 0.1
        _icon.rotate_y(delta * 1.5)
    if _ring:
        _ring.rotate_y(delta * 0.8)

func interact() -> void:
    if AudioManager: AudioManager.ui_select()
    if Episode0State.collect_memo(memo_id):
        var db = get_tree().get_first_node_in_group("dialogue_box")
        if db: db.show_text(memo_text)
    if _ring: _ring.visible = false
    if _icon: _icon.visible = false
    if _label: _label.visible = false
    set_deferred("monitoring", false)
