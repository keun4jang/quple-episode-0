class_name Paper
## 판과 버튼의 "종이 한 장" 마감.
##
## 이 게임의 판들은 색만 칠한 민판이라 화면에 붙은 스티커처럼 보였다.
## 세 겹을 준다 — 테두리(이미 있음) 안쪽 위에 1px 밝은 선(햇빛 받는
## 모서리), 아래로 2px 그림자(종이가 바닥에서 살짝 떠 있음).
## 눌린 버튼은 그림자를 거둔다 — 눌렸으니 바닥에 닿았다.


## 판·버튼 겉면에 그림자와 윗빛을 얹는다. 만든 자리에서 한 번 부른다.
static func lift(sb: StyleBoxFlat) -> StyleBoxFlat:
	sb.shadow_color = Color(0.227, 0.188, 0.169, 0.18)  # 3A302B
	sb.shadow_offset = Vector2(0, 2)
	sb.shadow_size = 2
	# 위 테두리만 살짝 두껍게 — 밝은 윗선 노릇. 색을 섞어 만든다.
	sb.border_blend = true
	return sb


## 눌린 상태 — 그림자를 거두고 내용이 1px 내려앉게 여백을 민다.
static func press(sb: StyleBoxFlat) -> StyleBoxFlat:
	sb.shadow_size = 0
	sb.shadow_offset = Vector2.ZERO
	sb.content_margin_top += 1
	sb.content_margin_bottom = maxf(0.0, sb.content_margin_bottom - 1)
	return sb


## 코드로 만드는 버튼을 알약 하나로 완성한다. **정성껏 만든 판 안에
## 배경 없는 버튼이 섞여 있는 사고**가 되풀이됐다 — 설정 버튼, 배낭
## 안 "길잡이 다시 보기"·"화면 보는 법", 인트로의 "건너뛰기" 가
## 전부 이 한 줄을 안 불러서 종이 질감 판 위에 엔진 기본 회색
## 사각형으로 떴다. 전역 테마(`quple_bold.tres`)는 폰트만 정하고
## 버튼 배경은 안 정하므로, 안 부르면 그대로 밋밋하게 남는다.
static func button(b: Button, bg: Color, border: Color, font_col: Color,
		corner := 16) -> void:
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(corner)
	sb.set_border_width_all(2)
	sb.border_color = border
	lift(sb)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = bg.lightened(0.1)
	press(pr)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_color_override("font_color", font_col)
