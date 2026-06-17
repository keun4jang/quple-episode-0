extends CanvasLayer

var is_transitioning: bool = false

@onready var overlay: ColorRect = $Overlay

func _ready() -> void:
    overlay.color = Color(0, 0, 0, 0)
    layer = 10

func go_to(path: String) -> void:
    if is_transitioning:
        return
    is_transitioning = true
    var tween = create_tween()
    tween.tween_property(overlay, "color", Color(0, 0, 0, 1), 0.35)
    tween.tween_callback(func():
        get_tree().change_scene_to_file(path)
    )
    tween.tween_property(overlay, "color", Color(0, 0, 0, 0), 0.35)
    tween.tween_callback(func(): is_transitioning = false)
