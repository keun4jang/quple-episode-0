class_name DreamRoom
extends Place
## 꿈의 틈 너머 - **싸우러 들어가는** 작은 맵들의 바탕.
##   `BossRoad`   우두머리의 길 - 졸개들이 선 구불구불한 길
##   `BossLair`   우두머리 방 - 구역 보스와 곁의 졸개 둘
##   `TowerFloor` 꿈의 탑 한 층
##
## 가게·등대와 같은 실내 씬이다 (들어온 마을로 나간다, 할 일은 들어온
## 마을 것을 잇는다). 다른 것은 하나 - **몬스터가 선다** (`fights_here`).
##
## 지도는 손으로 안 그린다. 마을마다 바닥·가장자리·소품 결(`THEME`)만
## 적고 모양은 코드로 짓는다 - 아홉 마을에 세 씬씩 스물일곱 장을 손으로
## 그리면 하나만 고쳐도 나머지가 어긋난다.

## 마을 → {floor 바닥, edge 못 가는 가장자리, deco 소품 셋, road 길 이름}.
const THEME := {
	"윤슬": {"floor": "sand", "edge": "water", "deco": ["boulder", "beach-grass", "buoy"],
		"road": "물거품 굴길"},
	"볕뉘": {"floor": "dirt", "edge": "basalt", "deco": ["stone-wall", "shrub", "tree"],
		"road": "도깨비불 고샅길"},
	"가풀재": {"floor": "clay-earth", "edge": "basalt", "deco": ["boulder", "pine", "shrub"],
		"road": "바위 비탈길"},
	"하늬섬": {"floor": "basalt", "edge": "water", "deco": ["boulder", "beach-grass", "stone-wall"],
		"road": "태풍 벼랑길"},
	"굽이나루": {"floor": "grass", "edge": "water", "deco": ["tree", "shrub", "boulder"],
		"road": "소용돌이 여울길"},
	"방울못": {"floor": "grass", "edge": "water", "deco": ["tree", "shrub", "beach-grass"],
		"road": "연꽃 수렁길"},
	"갈밭머리": {"floor": "dry-grass", "edge": "water", "deco": ["beach-grass", "shrub", "boulder"],
		"road": "가시덩굴 갈대길"},
	"솔은재": {"floor": "grass", "edge": "basalt", "deco": ["pine", "boulder", "pine"],
		"road": "두더지 굴길"},
	"꽃눈벌": {"floor": "grass", "edge": "basalt", "deco": ["tree", "fence", "shrub"],
		"road": "불꽃 들길"},
}

## 들어온 마을. 정상적인 길로는 늘 있다 - 비었으면 윤슬 결로 짓는다.
##
## `village_we_came_from()` 을 쓰면 안 된다 - 그 기본값이 `place_name()` 인데
## 여기 이름은 마을에서 나오므로(길 이름·보스 이름) 서로를 끝없이 부른다.
func village() -> String:
	var v := String(VILLAGE_OF_SCENE.get(JourneyState.exit_scene.get_file().get_basename(), ""))
	return v if THEME.has(v) else "윤슬"


func village_we_came_from() -> String:
	return village()


func theme() -> Dictionary:
	return THEME[village()]


func _ready() -> void:
	legend = {"f": String(theme()["floor"]), "x": String(theme()["edge"])}
	solid_tiles.clear()
	solid_tiles.append(String(theme()["edge"]))
	super()


func is_indoors() -> bool:
	return true


func fights_here() -> bool:
	return true


## 꿈의 틈 너머도 꿈결 하늘 아래다 (`DreamSky`).
func sky_open() -> bool:
	return true


func pad_wide() -> bool:
	return false


func quest_village() -> String:
	return village()


## 여기서는 안 잔다.
func sleep_tile() -> Vector2i:
	return Vector2i(-1, -1)


func on_built() -> void:
	JourneyState.here = place_name()


func bgm_track() -> String:
	return "wind"


## 아직 서 있는 몬스터 수.
func foes_left() -> int:
	var n := 0
	for sh in _shades:
		if is_instance_valid(sh) and sh.state != "gone":
			n += 1
	return n


## 꿈의 틈 안은 시계와 상관없이 늘 같은 빛이다.
func room_tint() -> Color:
	return Color(0.84, 0.78, 0.94)


func sky_tint(_mins: float) -> Color:
	return room_tint()


# ── 우두머리 체력 막대 ───────────────────────────────────────────────
#
# 우두머리는 체력이 열 배라 머리 위 작은 막대로는 얼마나 남았는지
# 안 읽힌다. 싸움이 붙으면 화면 위에 이름과 긴 막대를 띄운다.

var _boss_bar: Control
var _boss_name: Label


func _process(delta: float) -> void:
	super(delta)
	_tick_boss_bar()


func _boss_shade() -> Shade:
	for sh in _shades:
		if is_instance_valid(sh) and sh.state != "gone" and bool(sh.foe.get("boss", false)):
			return sh
	return null


func _tick_boss_bar() -> void:
	var b := _boss_shade()
	var show := b != null and walker != null and (b.is_fighting()
		or walker.global_position.distance_to(b.global_position) < 150.0)
	if not show:
		if _boss_bar != null:
			_boss_bar.visible = false
		return
	if _boss_bar == null:
		var layer := CanvasLayer.new()
		layer.name = "BossBarLayer"
		layer.layer = 4
		add_child(layer)
		_boss_bar = Control.new()
		_boss_bar.name = "BossBar"
		_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_bar.position = Vector2(390, 64)
		_boss_bar.size = Vector2(500, 44)
		layer.add_child(_boss_bar)
		_boss_name = Label.new()
		_boss_name.add_theme_font_size_override("font_size", 18)
		_boss_name.add_theme_color_override("font_color", Color("#FFD43B"))
		_boss_name.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.14))
		_boss_name.add_theme_constant_override("outline_size", 6)
		_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_boss_name.size = Vector2(500, 22)
		_boss_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_bar.add_child(_boss_name)
		_boss_bar.draw.connect(_draw_boss_bar)
	_boss_bar.visible = true
	_boss_bar.set_meta("k", clampf(float(b.foe["hp"]) / maxf(1.0, float(b.foe["hp_max"])), 0.0, 1.0))
	_boss_bar.set_meta("elem", String(b.foe.get("elem", "none")))
	_boss_name.text = "우두머리 Lv.%d %s" % [int(b.foe["lv"]),
		String(Battle.ENEMIES[b.shade_kind]["name"])]
	_boss_bar.queue_redraw()


func _draw_boss_bar() -> void:
	var k := float(_boss_bar.get_meta("k", 1.0))
	var r := Rect2(0, 26, 500, 14)
	_boss_bar.draw_rect(r.grow(3), Color(0.12, 0.09, 0.14, 0.95))
	_boss_bar.draw_rect(r.grow(1), Battle.elem_col(String(_boss_bar.get_meta("elem", "none"))))
	_boss_bar.draw_rect(r, Color(0.22, 0.14, 0.2))
	_boss_bar.draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)),
		Color("#FF6B6B") if k < 0.3 else Color("#E8495E"))
	# 네 칸 눈금 - 얼마나 깎았는지 한눈에.
	for i in range(1, 4):
		var x := r.size.x * float(i) / 4.0
		_boss_bar.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y),
			Color(0.12, 0.09, 0.14, 0.6), 2.0)
