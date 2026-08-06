extends RefCounted
## 한국어를 어절 단위로 줄바꿈한다.
##
## Godot 의 자동 줄바꿈에 맡기면 한글이 **낱말 가운데서 끊긴다.** 유니코드
## 줄바꿈 규칙(UAX #14)이 한글 음절 사이를 전부 끊어도 되는 자리로 보기 때문이다.
## `AUTOWRAP_WORD` 로 바꿔도 같다 — 규칙 자체가 그렇다.
## 실제로 앨범에서 "아무" 가 `아` / `무` 로, 대사에서 "사라지면" 이
## `사라지` / `면` 으로 갈라졌다.
##
## 쓰는 법 — 라벨을 하나 넘기면 그 뒤로는 알아서 유지된다:
##
##     const TW := preload("res://scripts/ui/text_wrap.gd")
##     TW.keep_words(my_label)
##
## 폭이 정해진 뒤에 다시 계산해야 하므로 `resized` 에 붙는다.
## 원본 문장은 메타로 들고 있다가 매번 원본에서 다시 나눈다 —
## 이미 나눈 것을 또 나누면 줄이 계속 짧아진다.

const RAW := "quple_raw_text"


static func keep_words(lb: Label) -> void:
	if lb == null:
		return
	lb.set_meta(RAW, lb.text)
	if not lb.resized.is_connected(_on_resized):
		lb.resized.connect(_on_resized.bind(lb))
	_apply(lb)


## 문장을 바꿀 때는 `lb.text = ...` 대신 이걸 쓴다.
static func set_text(lb: Label, text: String) -> void:
	if lb == null:
		return
	lb.set_meta(RAW, text)
	_apply(lb)


static func _on_resized(lb: Label) -> void:
	_apply(lb)


static func _apply(lb: Label) -> void:
	if lb == null or not is_instance_valid(lb) or not lb.has_meta(RAW):
		return
	var raw := str(lb.get_meta(RAW))
	var w := lb.size.x
	if w <= 1.0 or raw == "":
		return
	var font := lb.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var wrapped := wrap_text(raw, w, font, lb.get_theme_font_size("font_size"))
	if lb.text != wrapped:
		lb.text = wrapped


## 띄어쓰기에서만 끊는다. 한 어절이 통째로 폭보다 길면 그 줄은 그대로 두고
## 라벨의 자동 줄바꿈에 맡긴다 — 아주 긴 지명 하나로 화면이 깨지지는 않게.
static func wrap_text(text: String, width: float, font: Font, fs: int) -> String:
	if width <= 0.0 or text == "":
		return text
	var out := ""
	var first_para := true
	for para in text.split("\n"):
		if not first_para:
			out += "\n"
		first_para = false
		var line := ""
		for word in para.split(" ", false):
			var probe: String = word if line == "" else line + " " + word
			if font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
				line = probe
			else:
				if line != "":
					out += line + "\n"
				line = word
		out += line
	return out
