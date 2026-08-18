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
