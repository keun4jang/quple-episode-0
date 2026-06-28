extends CanvasLayer

# 첫 플레이 시 1회 조작 안내. SaveManager에 본 적 있으면 표시 안 함.
@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/VBox/Label
@onready var ok_btn: Button = $Panel/VBox/OkBtn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	ok_btn.pressed.connect(_close)

func maybe_show() -> void:
	var cfg = ConfigFile.new()
	var seen = false
	if cfg.load("user://settings.cfg") == OK:
		seen = cfg.get_value("tutorial", "seen", false)
	if seen:
		return
	label.text = "조이스틱(왼쪽 아래)으로 이동해요.\n빛나는 자리에 가까이 가면\n오른쪽 ✦ 버튼으로 행동해요.\n\n파랑=이동  분홍=대화  금색=줍기"
	visible = true
	get_tree().paused = true

func _close() -> void:
	visible = false
	get_tree().paused = false
	var cfg = ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("tutorial", "seen", true)
	cfg.save("user://settings.cfg")
