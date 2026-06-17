extends Node

const SAVE_PATH = "user://save.cfg"

func save_game(scene_path: String, player_pos: Vector3) -> void:
    var cfg = ConfigFile.new()
    cfg.set_value("game", "current_scene", scene_path)
    cfg.set_value("game", "player_x", player_pos.x)
    cfg.set_value("game", "player_y", player_pos.y)
    cfg.set_value("game", "player_z", player_pos.z)
    cfg.set_value("game", "episode0_state", Episode0State.current_state)
    cfg.set_value("game", "has_camera", Episode0State.has_camera)
    cfg.set_value("game", "has_notebook", Episode0State.has_notebook)
    cfg.set_value("game", "has_travel_bag", Episode0State.has_travel_bag)
    cfg.set_value("game", "badge_returned", Episode0State.badge_returned)
    cfg.set_value("game", "partner_joined", Episode0State.partner_joined)
    cfg.set_value("game", "first_photo_taken", Episode0State.first_photo_taken)
    cfg.set_value("game", "album_created", Episode0State.album_created)
    cfg.set_value("game", "episode0_cleared", Episode0State.episode0_cleared)
    cfg.save(SAVE_PATH)

func load_game() -> void:
    var cfg = ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    Episode0State.current_state = cfg.get_value("game", "episode0_state", 0)
    Episode0State.has_camera = cfg.get_value("game", "has_camera", false)
    Episode0State.has_notebook = cfg.get_value("game", "has_notebook", false)
    Episode0State.has_travel_bag = cfg.get_value("game", "has_travel_bag", false)
    Episode0State.badge_returned = cfg.get_value("game", "badge_returned", false)
    Episode0State.partner_joined = cfg.get_value("game", "partner_joined", false)
    Episode0State.first_photo_taken = cfg.get_value("game", "first_photo_taken", false)
    Episode0State.album_created = cfg.get_value("game", "album_created", false)
    Episode0State.episode0_cleared = cfg.get_value("game", "episode0_cleared", false)
