class_name PixelArt
extends RefCounted
## 외부 이미지 없이 문자열 배열로 픽셀 아트를 그린다.
## 각 글자를 palette에서 색으로 찾아 ColorRect 한 칸씩 배치한다.
## '.' 또는 ' ' 는 투명(빈칸).

static func build(art: Array, palette: Dictionary, cell: float, parent: Control = null) -> Control:
    var root := Control.new()
    var cols := 0
    for row in art:
        cols = max(cols, String(row).length())
    root.custom_minimum_size = Vector2(cols * cell, art.size() * cell)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for y in range(art.size()):
        var row: String = art[y]
        for x in range(row.length()):
            var ch := row[x]
            if ch == "." or ch == " ":
                continue
            if not palette.has(ch):
                continue
            var px := ColorRect.new()
            px.color = Color(palette[ch])
            px.position = Vector2(x * cell, y * cell)
            px.size = Vector2(cell, cell)
            px.mouse_filter = Control.MOUSE_FILTER_IGNORE
            root.add_child(px)
    if parent:
        parent.add_child(root)
    return root

## 적 전용 팔레트 생성 — X/D/L을 본체 색에서 만들고 눈(W/K)은 공통색
static func enemy_palette(colors: Dictionary) -> Dictionary:
    return {
        "X": colors.get("X", "#6C7BC4"),
        "D": colors.get("D", "#40406A"),
        "L": colors.get("L", "#A0A8E0"),
        "A": colors.get("A", "#FFFFFF"),
        "W": "#FFF6E4",
        "K": "#241C18",
    }
