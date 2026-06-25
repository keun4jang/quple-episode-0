extends Node

var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _current_bgm: String = ""
var bgm_volume: float = 0.8
var sfx_volume: float = 1.0

func _ready() -> void:
    _bgm_player = AudioStreamPlayer.new()
    _bgm_player.bus = "Master"
    add_child(_bgm_player)
    _sfx_player = AudioStreamPlayer.new()
    _sfx_player.bus = "Master"
    add_child(_sfx_player)

func play_bgm(track_name: String, _fade_in: float = 1.0) -> void:
    if _current_bgm == track_name:
        return
    _current_bgm = track_name
    # TODO: load AudioStream from res://audio/bgm/{track_name}.ogg

func stop_bgm(_fade_out: float = 1.0) -> void:
    _current_bgm = ""

func play_sfx(_sfx_name: String) -> void:
    pass  # TODO: res://audio/sfx/{_sfx_name}.ogg

func footstep() -> void: play_sfx("footstep")
func photo_shutter() -> void: play_sfx("camera_shutter")
func dialogue_tick() -> void: play_sfx("dialogue_tick")
func ui_select() -> void: play_sfx("ui_select")
