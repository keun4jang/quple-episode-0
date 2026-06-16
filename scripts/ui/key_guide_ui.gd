extends CanvasLayer

@onready var label: Label = $PanelRect/MarginContainer/Label

const DEFAULT_GUIDE_LINES: Array[String] = [
	"Space 조사/대화",
	"F 사진",
	"D 바람 노트",
	"B 앨범",
	"Esc 메뉴",
]

func _ready() -> void:
	set_guide_lines(DEFAULT_GUIDE_LINES)

func set_guide_lines(lines: Array[String]) -> void:
	label.text = "\n".join(lines)
