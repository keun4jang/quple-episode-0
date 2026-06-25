extends CanvasLayer

var is_transitioning: bool = false

@onready var overlay: ColorRect = $Overlay

func _ready() -> void:
    overlay.color = Color(0, 0, 0, 0)
    layer = 10

func go_to(path: String, style: String = "normal") -> void:
    if is_transitioning:
        return
    is_transitioning = true
    var fade_color: Color
    var duration: float
    match style:
        "hopeful":
            fade_color = Color(1.0, 0.97, 0.9, 1.0)
            duration = 0.4
        "tense":
            fade_color = Color(0.08, 0.0, 0.0, 1.0)
            duration = 0.55
        "dawn":
            fade_color = Color(1.0, 0.9, 0.75, 1.0)
            duration = 0.6
        _:
            fade_color = Color(0, 0, 0, 1)
            duration = 0.35
    var tween = create_tween()
    tween.tween_property(overlay, "color", fade_color, duration)
    tween.tween_callback(func():
        get_tree().change_scene_to_file(path)
    )
    tween.tween_property(overlay, "color", Color(fade_color.r, fade_color.g, fade_color.b, 0.0), duration)
    tween.tween_callback(func(): is_transitioning = false)
