extends Node
const TXT := "지금 해볼 일 · 이야기 2/3 · 저녁에 등대곶에서 불 켜진 등대 사진 남기기 (저녁에)"
func _ready() -> void:
	var theme := load("res://assets/themes/quple_bold.tres") as Theme
	var fnt := theme.get_font("font", "Label")
	for mode: int in [TextServer.AUTOWRAP_ARBITRARY, TextServer.AUTOWRAP_WORD,
			TextServer.AUTOWRAP_WORD_SMART]:
		var tp := TextParagraph.new()
		tp.width = 720
		tp.break_flags = mode
		tp.add_string(TXT, fnt, 24)
		var out: Array = []
		for i in tp.get_line_count():
			var r := tp.get_line_range(i)
			out.append(TXT.substr(r.x, r.y - r.x))
		print("mode=", mode, " -> ", out)
	get_tree().quit()
