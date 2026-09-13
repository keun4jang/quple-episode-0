extends Node
## GameUI — 화면 UI(HUD·가방·퀘스트·상점·전투)를 한 곳에서 만들고 관리한다.
## 오토로드라 씬이 바뀌어도 살아남으므로, 맵마다 UI를 넣어줄 필요가 없다.
## 맵에 그림자 감정을 뿌리는 일도 여기서 한다.

const HUD_SCRIPT := preload("res://scripts/ui/hud_ui.gd")
const BAG_SCRIPT := preload("res://scripts/ui/bag_ui.gd")
const QUEST_SCRIPT := preload("res://scripts/ui/quest_ui.gd")
const SHOP_SCRIPT := preload("res://scripts/ui/shop_ui.gd")
const BATTLE_SCRIPT := preload("res://scripts/ui/battle_ui.gd")

## UI를 숨기는 씬 (메뉴·엔딩 화면)
const NO_HUD_SCENES := ["MainMenu3D", "StartScreen", "CharPreview"]

## 맵마다 등장하는 그림자 감정
const SPAWN_TABLE := {
    "CompanyFront3D": ["anxiety", "anxiety", "misfortune"],
    "CompanyLobby3D": ["anxiety", "comparison", "comparison"],
    "Office3D": ["burnout", "burnout", "greed"],
    "BossDoorHallway3D": ["overtime", "greed"],
}

# 런타임에 스크립트를 붙여 만들기 때문에 타입을 지정하지 않는다(메서드가 스크립트 쪽에 있음)
var hud
var bag
var quest
var shop
var battle

var _last_scene: Node = null

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

    # 각 스크립트가 CanvasLayer를 상속하므로 new()로 바로 만든다
    hud = HUD_SCRIPT.new()
    add_child(hud)

    bag = BAG_SCRIPT.new()
    add_child(bag)

    quest = QUEST_SCRIPT.new()
    add_child(quest)

    shop = SHOP_SCRIPT.new()
    add_child(shop)

    battle = BATTLE_SCRIPT.new()
    add_child(battle)

    # 씬 전환 감시 (SceneTransition이 change_scene_to_file로 바꾸므로 폴링이 가장 확실하다)
    var timer := Timer.new()
    timer.wait_time = 0.3
    timer.autostart = true
    timer.process_mode = Node.PROCESS_MODE_ALWAYS
    timer.timeout.connect(_check_scene)
    add_child(timer)

func _check_scene() -> void:
    var scene := get_tree().current_scene
    if scene == null or scene == _last_scene:
        return
    _last_scene = scene
    _on_scene_changed(scene)

func _on_scene_changed(scene: Node) -> void:
    var show_hud := not (String(scene.name) in NO_HUD_SCENES)
    hud.visible = show_hud
    _close_all_panels()
    if show_hud:
        _spawn_enemies(scene)

func _close_all_panels() -> void:
    for p in [bag, quest, shop]:
        p.visible = false

# ── 패널 열기 ────────────────────────────────────────
func open_panel(which: String) -> void:
    if BattleSystem.in_battle:
        return
    _close_all_panels()
    match which:
        "bag":
            bag.open()
        "quest":
            quest.open()
        "shop":
            shop.open()

func open_album() -> void:
    if BattleSystem.in_battle:
        return
    var scene := get_tree().current_scene
    if scene == null:
        return
    var album = scene.get_node_or_null("AlbumUI")
    if album and album.has_method("refresh"):
        album.refresh()
        album.visible = true
    else:
        toast("앨범은 여행이 시작된 뒤에 볼 수 있어요.")

func open_settings() -> void:
    var s = get_tree().get_first_node_in_group("settings_ui")
    if s and s.has_method("open"):
        s.open()
    else:
        toast("설정은 이 화면에서 열 수 없어요.")

func toast(text: String, color: Color = Color("#FFF6E4")) -> void:
    if hud and hud.has_method("toast"):
        hud.toast(text, color)

# ── 단축키 ───────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
    if BattleSystem.in_battle:
        return
    if event.is_action_pressed("key_bag"):
        _toggle(bag, "bag")
    elif event.is_action_pressed("key_quest"):
        _toggle(quest, "quest")

func _toggle(panel, key: String) -> void:
    if panel.visible:
        panel.close()
    else:
        open_panel(key)

# ── 그림자 감정 배치 ─────────────────────────────────
func _spawn_enemies(scene: Node) -> void:
    var scene_name := String(scene.name)
    if not SPAWN_TABLE.has(scene_name):
        return
    await get_tree().create_timer(0.6).timeout
    if get_tree().current_scene != scene:
        return
    var player = get_tree().get_first_node_in_group("player")
    if player == null:
        return
    var origin: Vector3 = player.global_position
    var ids: Array = SPAWN_TABLE[scene_name]
    var index := 0
    for id in ids:
        # 보스는 한 번만 나타난다
        if BattleSystem.enemy_def(id).get("is_boss", false) and BattleSystem.defeated_counts.get(id, 0) > 0:
            continue
        var angle := TAU * (float(index) / float(max(1, ids.size()))) + randf_range(-0.4, 0.4)
        var radius := randf_range(6.5, 10.0)
        var pos := origin + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
        pos.y = origin.y
        var enemy := ShadowEnemy3D.new()
        enemy.setup(id, pos)
        scene.add_child(enemy)
        index += 1
