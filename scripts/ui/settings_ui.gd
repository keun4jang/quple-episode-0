extends CanvasLayer

signal closed

@onready var bgm_slider: HSlider = $Panel/VBox/BGMRow/BGMSlider
@onready var sfx_slider: HSlider = $Panel/VBox/SFXRow/SFXSlider
@onready var close_btn: Button = $Panel/VBox/CloseBtn

func _ready() -> void:
    add_to_group("settings_ui")
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    if AudioManager:
        bgm_slider.value = AudioManager.bgm_volume
        sfx_slider.value = AudioManager.sfx_volume
    bgm_slider.value_changed.connect(func(v): if AudioManager: AudioManager.set_bgm_volume(v))
    sfx_slider.value_changed.connect(func(v):
        if AudioManager:
            AudioManager.set_sfx_volume(v)
            AudioManager.ui_select())
    close_btn.pressed.connect(_on_close)

func open() -> void:
    visible = true
    if AudioManager:
        bgm_slider.value = AudioManager.bgm_volume
        sfx_slider.value = AudioManager.sfx_volume

func _on_close() -> void:
    visible = false
    closed.emit()
