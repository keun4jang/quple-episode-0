class_name Wrap
## 낱말 한가운데서 줄이 안 끊기게 한다.
##
## 폰에서 찍은 화면을 보니 "…등대 사진 남기 / 기 (저녁에)" 로 끊겨
## 있었다. 라벨의 `autowrap_mode` 를 무엇으로 두든 똑같다 - 넷을 다
## 재 봤다:
##
##   ARBITRARY  : 아무 데서나 끊는다
##   WORD       : "…사진 남기 / 기 (저녁에)"
##   WORD_SMART : "…사진 남기 / 기 (저녁에)"
##
## 엔진 탓이 아니라 유니코드 줄바꿈 규칙(UAX #14) 이 그렇다. 한글은
## **음절 사이가 전부 끊어도 되는 자리**로 되어 있다 - 한국어 조판에서
## 원래 그렇게 해도 되는 것으로 치기 때문이다.
##
## 그런데 이 게임의 글은 대사와 안내문이라 죄다 짧다. 낱말이 갈리면
## 읽다가 한 번 걸린다. 그래서 **띄어쓰기에서만 끊는다** (웹의
## `word-break: keep-all` 과 같은 규칙이다).
##
## 쓰는 법 - 글을 넣을 때 라벨째로 넘긴다:
##
##   Wrap.put(label, "지금 해볼 일 · 저녁에 등대 사진 남기기")
##
## 폭을 아는 자리에서는 글만 접어도 된다:
##
##   var s := Wrap.fit(글, 폰트, 크기, 폭)

## 글을 넣는다. 자동 줄바꿈은 꺼 두고 여기서 접는다.
##
## Label 도 Button 도 받는다 - 배낭의 할 일 줄이 Button 이라
## 둘 다 필요했다. `text` 와 `autowrap_mode` 를 가진 것이면 된다.
##
## 폭을 못 구하면(아직 자리를 안 잡았고 최소 폭도 없는 것) **손대지
## 않는다** - 엉뚱한 데서 접느니 여태처럼 두는 편이 낫다.
static func put(c: Control, s: String) -> void:
	var w := width_of(c)
	if w < 1.0:
		c.set("autowrap_mode", TextServer.AUTOWRAP_WORD_SMART)
		c.set("text", s)
		return
	c.set("autowrap_mode", TextServer.AUTOWRAP_OFF)
	c.set("text", fit(s, c.get_theme_font("font"),
		c.get_theme_font_size("font_size"), w))


## 글이 쓸 수 있는 가로 폭. 자리를 잡았으면 실제 폭을, 아직이면
## 앵커 오프셋이나 최소 폭을 쓴다.
##
## 두 가지를 미리 뺀다 - 테두리(outline)는 글자 바깥으로 번지는데
## 길이 재기에 안 잡히고, 버튼은 겉면에 안여백이 있다.
static func width_of(c: Control) -> float:
	var w := c.size.x
	if w < 1.0:
		w = c.offset_right - c.offset_left
	if w < 1.0:
		w = c.custom_minimum_size.x
	if w < 1.0:
		return 0.0
	w -= float(c.get_theme_constant("outline_size"))
	var sb := c.get_theme_stylebox("normal") if c is Button else null
	if sb != null:
		w -= sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
	return w


## 글을 접는다. `\n` 은 그대로 두고 줄마다 따로 잰다.
##
## `hard` 를 끄면 **띄어쓰기를 줄바꿈으로 바꾸기만 한다** - 글자 수가
## 안 변해서, 한 자씩 찍어 내는 대사창처럼 자리로 세는 곳에서 쓴다.
static func fit(s: String, font: Font, size: int, width: float,
		hard := true) -> String:
	if font == null or width < 1.0 or s == "":
		return s
	var out: Array[String] = []
	for para in s.split("\n"):
		out.append(_one(para, font, size, width, hard))
	return "\n".join(out)


static func _one(para: String, font: Font, size: int, width: float,
		hard: bool) -> String:
	# `split(" ", false)` 는 이어진 빈칸을 삼킨다. 글자 수를 지키려면
	# 빈칸 하나하나가 그대로 남아야 해서 true 로 나눈다.
	var words := para.split(" ")
	var out := ""
	var line := ""
	for word: String in words:
		var one := word if line == "" else line + " " + word
		if _w(font, one, size) <= width:
			line = one
			continue
		if line == "":
			# 낱말 하나가 이미 폭보다 길다. 접을 자리가 없다.
			if not hard:
				line = word
				continue
			var cut := _chop(word, font, size, width)
			out += "\n".join(cut.slice(0, cut.size() - 1)) + "\n"
			line = cut[cut.size() - 1]
			continue
		out += line + "\n"
		line = word
	return out + line


## 낱말 하나가 폭보다 길 때만 부른다. 한 글자씩 채워 넣는다.
static func _chop(word: String, font: Font, size: int,
		width: float) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for i in word.length():
		var c := word[i]
		if line != "" and _w(font, line + c, size) > width:
			out.append(line)
			line = ""
		line += c
	out.append(line)
	return out


static func _w(font: Font, s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## 받침을 보고 조사를 골라 붙인다. `with`(을/를) 은 기본이고, `and`(와/과) 도
## 있다.
##
## "부두 청년와 인사하기" 처럼 화면에 그대로 찍히고 있었다 —
## `journey_hud.gd` 의 `_with_josa` 는 을/를 만 골랐지 인사 라벨(`%s와
## 인사하기`)의 와/과는 안 봤다. 이름이 정해진 몇 안 되는 인연 이름뿐이라
## 표를 만들 것도 없다. 한글이 아니면 아쉬운 대로 받침 있는 쪽으로 붙인다.
enum Josa { WITH, AND }

static func with_josa(word: String, kind: Josa = Josa.WITH) -> String:
	if word.is_empty():
		return word
	var c := word.unicode_at(word.length() - 1)
	var has_batchim: bool
	if c < 0xAC00 or c > 0xD7A3:
		has_batchim = true            # 한글이 아니면 아쉬운 대로
	else:
		has_batchim = (c - 0xAC00) % 28 != 0
	match kind:
		Josa.AND:
			return word + ("과" if has_batchim else "와")
		_:
			return word + ("을" if has_batchim else "를")
