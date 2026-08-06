extends RefCounted
## UI 의 규칙을 한 곳에 모은다.
##
## 지금까지 대화창·버튼·카드·패널이 각자 다른 색과 간격과 모서리를 썼다.
## 필요할 때마다 그 자리에서 값을 정했기 때문이다. 화면마다 조금씩 다른 회색,
## 조금씩 다른 둥글기, 조금씩 다른 여백 — 이게 쌓이면 "누가 대충 만든 티" 가 된다.
##
## 여기 있는 값만 쓴다. 새 UI 를 만들 때 색이나 간격을 직접 적지 말고 여기서 가져와라.
## 값을 바꾸고 싶으면 여기서 바꾼다. 그러면 화면 전체가 같이 움직인다.
##
## class_name 을 쓰지 않는 이유는 .godot 이 gitignore 라 새로 클론한 곳에서
## 전역 클래스가 등록되지 않기 때문이다. const 로 preload 해서 써라:
##   const D := preload("res://scripts/ui/design.gd")

# ── 간격 ───────────────────────────────────────────────────────────────
# 4 의 배수만 쓴다. 6 이나 13 같은 값이 섞이면 정렬이 미세하게 어긋나 보인다.
const GAP_XS := 4
const GAP_S := 8
const GAP_M := 16
const GAP_L := 24
const GAP_XL := 40

# ── 모서리 ─────────────────────────────────────────────────────────────
const ROUND_S := 12      # 작은 칩·태그
const ROUND_M := 22      # 패널·카드
const ROUND_L := 34      # 큰 판
const ROUND_PILL := 999  # 완전한 알약·동그라미

# ── 글자 크기 ──────────────────────────────────────────────────────────
## 폰에서 잘 안 보인다는 피드백을 받아 한 단계씩 올렸다. 30 이 하한이다.
## 화면이 720 기준이라 여기 숫자는 "720 높이에서 몇 px" 이다.
## 실제 폰(1080 이상)에서는 그만큼 더 커진다.
const TEXT_S := 30       # 보조 설명
const TEXT_M := 36       # 본문
const TEXT_L := 44       # 소제목
const TEXT_XL := 58      # 제목

# ── 색 ─────────────────────────────────────────────────────────────────
# 파스텔 힐링 톤. 채도 높은 원색과 순검정은 쓰지 않는다.
#
# 산호(#FF6F61) 계열은 쿼카 스카프 색이라 UI 에도 배경에도 쓰지 않는다.
# 캐릭터에만 남겨 둬야 시선이 쿼카 커플로 간다. (scripts/travel/palette.gd 참고)
const INK := Color(0.10, 0.09, 0.14)          # 가장 어두운 바탕
const PANEL := Color(0.13, 0.12, 0.18, 0.88)  # 패널 바탕
const PANEL_SOLID := Color(0.15, 0.14, 0.20)
const LINE := Color(1.0, 0.88, 0.62, 0.42)    # 테두리
const TEXT := Color(1.0, 0.96, 0.89)          # 본문 글자
const TEXT_DIM := Color(0.80, 0.78, 0.84)     # 보조 글자
const ACCENT := Color(0.831, 0.686, 0.216)    # 강조 (버튼·표식) #D4AF37
const ACCENT_SOFT := Color(0.992, 0.984, 0.831) # 밝은 크림 #FDFBD4

# ── 골든 토프 ──────────────────────────────────────────────────────────
# 참고로 받은 배색. 우리 화면은 원래 보라·남색 일색이라 강조가 전부 같은 주황이었다.
# 이 넷은 서로 명도가 달라서 "지금 고른 것 / 고를 수 있는 것 / 지나간 것" 을
# 색만으로 구분할 수 있다.
#
#   GOLD   #D4AF37  지금 고른 것, 열린 것
#   KHAKI  #BDB76B  고를 수 있지만 지금이 아닌 것
#   CREAM  #FDFBD4  어두운 바탕 위의 글자
#   CARAMEL #CE8946 제일 중요한 버튼 하나
#
# 캐러멜(#CE8946)은 산호가 아니다 — 색상환에서 쿼카 스카프보다 노랑 쪽으로
# 충분히 떨어져 있어서 tools/check-design-tokens.py 의 산호 금지에 걸리지 않는다.
const GOLD := Color(0.831, 0.686, 0.216)
const KHAKI := Color(0.741, 0.718, 0.420)
const CREAM := Color(0.992, 0.984, 0.831)
const CARAMEL := Color(0.808, 0.537, 0.275)
const OUTLINE := Color(0.08, 0.06, 0.10, 0.85) # 글자 외곽선

# 비활성 상태는 지우지 말고 흐리게. 사라지면 "그런 기능이 없다" 로 읽힌다.
const DISABLED_ALPHA := 0.42


## 패널 한 장. 대화창·카드·안내판이 전부 이걸 쓴다.
static func panel(radius: int = ROUND_M, bg: Color = PANEL,
		border: Color = LINE, border_width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_width)
	sb.border_color = border
	sb.set_content_margin_all(GAP_M)
	return sb


## 동그란 버튼 배경. 터치 버튼이 쓴다.
static func round_button(tint: Color, size_px: int, alpha := 0.80) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r, tint.g, tint.b, alpha)
	sb.set_corner_radius_all(size_px / 2)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.5)
	return sb


## 화면 위에 얹는 글자. 배경이 무엇이든 읽히게 외곽선을 넣는다.
static func label(text: String, size: int = TEXT_M, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
