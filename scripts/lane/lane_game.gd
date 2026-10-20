extends Control
## 쿼카 군단 - 세로 한 줄 싸움 (냥코대전쟁의 규칙을 빌려 왔다. 이름·그림은 우리 것).
## 홈(지도·쿼카·편성) 과 판(싸움) 두 모드. 규칙은 LaneBattle/LaneState, 여기는 그리기·버튼·연출만.

const MENU_PATH := "res://scenes/menu/MainMenu3D.tscn"
const SAVE_EVERY := 10.0
const UNIT_PX := 3.0
const BUG_PX := 3.0
## 픽셀 한 칸 = 화면 3점. 배경·길도 1/3 크기로 그려 3배로 키운다 - 캐릭터 도트와 픽셀 크기를 하나로 맞춘다.
## (예전엔 배경만 매끈한 그림이라 도트 캐릭터와 따로 놀았다.)
const PIX := 3
const FX_PIX := 2
## 공격 모양 - 유닛마다 다르게 보여야 누가 무얼 하는지 안다. [모양, 색]
## slash 베기 · pierce 찌르기 · smash 내리찍기(충격파) · shot 던지기(날아감) · magic 마법 구슬 · quake 땅울림 ·
## claw 세 갈래 할퀴기 · ice 얼음 · tongue 혀 · dive 하늘에서 내리꽂기 · peck 쪼기 · splash 물보라 · bonk 콩 박기
const FX_STYLE := {
	"tiny": ["slash", "#FFF1C2"], "shield": ["bonk", "#9CC8FF"], "spear": ["pierce", "#E8F4FF"],
	"hammer": ["smash", "#FFC24A"], "runner": ["slash", "#7FE0FF"], "sling": ["shot", "#C9C2B8"],
	"mage": ["magic", "#C58CFF"], "giant": ["quake", "#E0A060"],
	"chick": ["peck", "#FFE15A"], "hedgehog": ["bonk", "#C99466"], "squirrel": ["shot", "#B07A44"],
	"frog": ["tongue", "#FF8FB8"], "rabbit": ["slash", "#FFFFFF"], "duck": ["splash", "#7FD0FF"],
	"mole": ["smash", "#B0906A"], "sheep": ["bonk", "#FFFFFF"], "turtle": ["bonk", "#7CC48A"],
	"penguin": ["ice", "#BFF0FF"], "owl": ["magic", "#D9B8FF"], "panda": ["smash", "#9CE07A"],
	"otter": ["splash", "#6FC8FF"], "tiger": ["claw", "#FFD23F"], "polar": ["ice", "#E0F8FF"],
	"eagle": ["dive", "#FFD23F"],
}
## 역할 이름 (버튼·카드에 붙는 작은 딱지)
const ROLE_COL := {"벽": "#8FB5FF", "근접": "#FF9F7A", "범위": "#FFB84A", "돌격": "#7FE0FF", "원거리": "#9CE07A",
	"마법": "#C58CFF", "거대": "#E0A060"}
## 후퇴해도 이만큼(초) 싸웠으면 다시 도전 응원을 받는다.
const CHEER_MIN_FIGHT := 60.0


## 시트의 앞모습 첫 칸 - 칸 위쪽의 무기 여유(칸 높이 - 칸 폭)는 빼고 몸만.
static func _face_region(tex: Texture2D, col := 0) -> Rect2:
	var w := tex.get_width() / 4.0
	var h := tex.get_height() / 3.0
	var pad := maxf(0.0, h - w)
	return Rect2(col * w, pad, w, h - pad)


## 버튼에 들어갈 짧은 이름 ("도토리 다람쥐" → "다람쥐").
static func _short_name(id: String) -> String:
	var n := LaneData.unit_name(id, LaneState.level_of(id))
	var parts := n.split(" ")
	return parts[parts.size() - 1] if n.length() > 5 else n


## 안에 넣은 그림을 1/PIX 크기로 그려 PIX 배로 키우는 판. 안의 노드는 화면 좌표 그대로 그리면 된다.
func _pixel_layer(shrink := PIX) -> SubViewportContainer:
	var c := SubViewportContainer.new()
	c.stretch = true
	c.stretch_shrink = shrink
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.name = "VP"
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	c.add_child(vp)
	# 트리에 들어간 뒤에 줄인다 (그 전에 넣으면 그릴 판이 없다는 오류가 난다)
	vp.ready.connect(func() -> void: vp.canvas_transform = Transform2D.IDENTITY.scaled(Vector2.ONE / float(shrink)))
	return c


## 유닛 역할 한 단어.
static func role_of(id: String) -> String:
	var u: Dictionary = LaneData.UNITS[id]
	if LaneData.is_wall(id):
		return "벽"
	if bool(u.get("no_kb", false)):
		return "거대"
	if FX_STYLE.has(id) and String(FX_STYLE[id][0]) == "magic":
		return "마법"
	if float(u["range"]) >= 280.0:
		return "원거리"
	if float(u["speed"]) >= 250.0:
		return "돌격"
	if bool(u["area"]):
		return "범위"
	return "근접"


## 쿼카 그림 — 레벨 10 부터 진화한 모습.
static func unit_sheet(id: String) -> String:
	return LaneData.sheet_path(id, LaneState.level_of(id))


const RARITY_COL := {"base": Color("#F3E7C8"), "rare": Color("#7FD0FF"), "super": Color("#C58CFF"),
	"legend": Color("#FFD15A")}

var battle := LaneBattle.new()
var mode := "home"
var stage_n := 1

# 판
var _world: Control
var _bg: IdleBackdrop
var _field: LaneField
var _actors: Node2D
var _fx: IdleFx
var _vfx: IdleVfx
var _flash_rect: ColorRect
var _danger: Control          ## 성이 위험하면 화면 가장자리가 붉게 맥박친다
var _pix: SubViewportContainer    ## 배경·길을 픽셀로 그리는 판
var _home_pix: SubViewportContainer
var _fx_pix: SubViewportContainer
var _bars: Node2D             ## 머리 위 체력 띠
var _ent_of: Dictionary = {}  ## uid → 판의 몸 (공격한 쪽이 누구인지 효과에 쓴다)
var _fx_t: Dictionary = {}    ## uid → 마지막으로 공격 효과를 낸 때 (범위 공격이 여러 번 터지지 않게)
var _swing_at: Dictionary = {}  ## uid → 마지막으로 휘두른 때 (판 시간) - 공격 그림을 실제 타격에 맞춘다
var _hit_at: Dictionary = {}    ## uid → 마지막으로 맞은 때 - 살짝 밀린다
var _calm := false            ## 설정: 화면 흔들림·번쩍임 줄이기
var _toast_box: PanelContainer
var _tut: LaneTutorial
var _tut_pause := false          ## 안내 말풍선이 떠 있는 동안 싸움을 멈춘다
var _tut_after_gacha := Callable()
var _result_home: Button
var _actor_of: Dictionary = {}     ## uid → IdleActor
var _lat: Dictionary = {}          ## uid → 옆 위치
var _lunge: Dictionary = {}        ## uid → 덤벼듦 (1 → 0)
var _dead: Dictionary = {}         ## 녹아 사라지는 중인 uid - 규칙 쪽엔 넉백 동안 몸이 남아 있지만 그림은 다시 만들지 않는다
var _hud: Control
var _wallet_lbl: Label
var _wallet_bar: ProgressBar
var _worker_btn: Button
var _cannon_btn: Button
var _unit_btns: Dictionary = {}
var _speed_btn: Button
var _auto_btn: Button
var _stage_lbl: Label
var _our_bar: ProgressBar
var _our_lbl: Label
var _result: Control
var _trauma := 0.0
var _battle_t := 0.0
var _ended := false
var _won := false

# 홈
var _home: Control
var _home_body: VBoxContainer
var _home_tab := "map"
var _xp_lbl: Label
var _ticket_lbl: Label
var _card_title: Label
var _star_lbl: Label
var _toast_lbl: Label
var _banner: Label

var _t := 0.0
var _save_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if not LaneState.load_save():
		LaneState.reset()
	AudioManager.play_bgm("adventure")
	_build_home()
	# 알림은 알약 모양 판 위에 - 글씨가 아래 화면과 겹쳐 지저분해 보이지 않게
	_toast_box = PanelContainer.new()
	var tsb := IdleUi.box(Color(1, 1, 1, 0.97), IdleUi.LAV, 26, 4, 16)
	_toast_box.add_theme_stylebox_override("panel", tsb)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.modulate.a = 0.0
	add_child(_toast_box)
	_toast_lbl = IdleUi.label("", 26, IdleUi.CREAM)
	_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_box.add_child(_toast_lbl)
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		_calm = bool(cfg.get_value("fx", "calm", false))
	_banner = IdleUi.label("", 56, Color.WHITE, true)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	add_child(_banner)
	resized.connect(_layout)
	_layout()
	var r := LaneState.claim_offline(int(Time.get_unix_time_from_system()))
	if not r.is_empty():
		_toast("자는 동안 쿼카들이 꿈조각 %s개를 모았어요" % _num(int(r["xp"])))
	var old := LaneState.migrate_from_idle()
	var gift := LaneState.claim_daily(_local_now())
	if not LaneState.seen_intro:
		# 처음 온 사람은 한 걸음씩 안내(`_tut_*`)가 대신 알려 준다
		LaneState.seen_intro = true
	if not old.is_empty():
		_later(2.8, func() -> void:
			_toast("옛 꿈결에서 온 선물!  ★ %s · 티켓 %d장 · ✦ %s" % [_num(int(old["stars"])), int(old["tickets"]),
				_num(int(old["xp"]))]))
	elif not gift.is_empty():
		_toast("매일 선물 %d일째!  티켓 %d장 · 꿈별 %d" % [int(gift["streak"]), int(gift["tickets"]), int(gift["stars"])])
	_rng.randomize()
	LaneState.save(int(Time.get_unix_time_from_system()))
	_tut = LaneTutorial.new()
	_tut.visible = false
	_tut.skipped.connect(_tut_skip)
	add_child(_tut)
	_show_home()
	if LaneState.tut == 0:
		_later(0.6, _tut_home_intro.bind(0))
	elif LaneState.tut == 3:
		_later(0.6, _tut_home_guide.bind(0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		LaneState.save(int(Time.get_unix_time_from_system()))


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _layout() -> void:
	if _home != null:
		_home.size = size
	if _world != null:
		_world.size = size
		_pix.size = size
		_fx_pix.size = size
		_bg.size = size
		_field.size = size
		_field.y_front = size.y - 470.0
		_field.y_far = size.y * 0.15
		_flash_rect.size = size
		if _danger != null:
			_danger.size = size
		_hud.size = size
		_layout_hud()
	_toast_box.position = Vector2(30, 96)
	_toast_box.size = Vector2(size.x - 60, 0)
	_banner.position = Vector2(0, size.y * 0.3)
	_banner.size = Vector2(size.x, 80)


# ══ 홈 ════════════════════════════════════════════════════════════════

func _build_home() -> void:
	# 홈 (다른 모바일 게임들처럼): 위 재화 줄 → 친구들이 서 있는 무대 → 내용 카드 → 엄지 자리의 큰 출전 → 아이콘 탭
	_home = Control.new()
	add_child(_home)
	var bg := ColorRect.new()
	bg.color = Color("#F3EAFB")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_home.add_child(bg)
	_home_pix = _pixel_layer()
	_home_pix.name = "Deco"
	_home.add_child(_home_pix)
	var deco := IdleBackdrop.new()
	deco.name = "Back"
	deco.zone = 1
	deco.ground = 0.24
	_home_pix.get_node("VP").add_child(deco)
	# 위 재화 줄
	var top := HBoxContainer.new()
	top.name = "Top"
	top.add_theme_constant_override("separation", 8)
	_home.add_child(top)
	_xp_lbl = _res_pill(top, "coin", IdleUi.GOLD_DK)
	_star_lbl = _res_pill(top, "star", Color("#4A90D9"))
	_ticket_lbl = _res_pill(top, "chest", IdleUi.LAV_DK)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var menu := IdleUi.round_button("gear", 60.0, "plum")
	menu.pressed.connect(func() -> void:
		LaneState.save(int(Time.get_unix_time_from_system()))
		SceneTransition.go_to(MENU_PATH, "normal"))
	top.add_child(menu)
	# 무대: 제목 + 편성한 친구들
	var title := IdleUi.label("쿼카 군단", 60, IdleUi.GOLD, true)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home.add_child(title)
	var sub := IdleUi.label("벌레들에게서 꿈결을 지켜요", 22, Color.WHITE, true)
	sub.name = "Sub"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home.add_child(sub)
	var stage := Node2D.new()
	stage.name = "Parade"
	_home.add_child(stage)
	# 내용 카드 (머리띠 + 굴러가는 내용)
	var card := PanelContainer.new()
	card.name = "Card"
	var csb := IdleUi.box(Color(1, 1, 1, 0.97), IdleUi.LAV, 26, 4, 0)
	card.add_theme_stylebox_override("panel", csb)
	_home.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	card.add_child(cv)
	var head := PanelContainer.new()
	var hsb := IdleUi.box(IdleUi.LAV, IdleUi.LAV, 22, 0, 10, false)
	hsb.corner_radius_bottom_left = 0
	hsb.corner_radius_bottom_right = 0
	head.add_theme_stylebox_override("panel", hsb)
	cv.add_child(head)
	_card_title = IdleUi.label("", 26, Color.WHITE, true)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_card_title)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 12)
	cv.add_child(margin)
	var sc := ScrollContainer.new()
	sc.name = "Scroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	IdleUi.style_scroll(sc)
	margin.add_child(sc)
	_home_body = VBoxContainer.new()
	_home_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_body.add_theme_constant_override("separation", 10)
	sc.add_child(_home_body)
	# 큰 출전 단추 (엄지 자리)
	var go := IdleUi.button("", 38, "gold")
	go.name = "Go"
	go.pressed.connect(func() -> void: _start_battle(mini(LaneState.cleared + 1, LaneData.STAGE_MAX)))
	_home.add_child(go)
	# 아래 아이콘 탭
	var bar := PanelContainer.new()
	bar.name = "TabBar"
	var bsb := IdleUi.box(Color(IdleUi.LAV.r, IdleUi.LAV.g, IdleUi.LAV.b, 0.97), IdleUi.LAV_DK, 0, 0, 8)
	bsb.corner_radius_top_left = 26
	bsb.corner_radius_top_right = 26
	bsb.border_width_top = 4
	bar.add_theme_stylebox_override("panel", bsb)
	_home.add_child(bar)
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 6)
	bar.add_child(tabs)
	for k in [["map", "지도", "map"], ["units", "동물", "hero"], ["lineup", "편성", "sword"], ["gacha", "뽑기", "chest"]]:
		var b := Button.new()
		b.name = "Tab_" + String(k[0])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.name = "V"
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var ic := IdleUi.icon(String(k[2]), 38.0, Color.WHITE)
		ic.name = "Icon"
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var l := IdleUi.label(String(k[1]), 22, Color.WHITE)
		l.name = "Label"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		var dot := IdleUi.label("●", 20, IdleUi.GOLD)
		dot.name = "Dot"
		dot.position = Vector2(8, 4)
		dot.visible = false
		b.add_child(dot)
		b.pressed.connect(func() -> void:
			AudioManager.ui_click()
			_home_tab = String(k[0])
			_fill_home())
		tabs.add_child(b)


## 위 재화 알약 (아이콘 + 숫자).
func _res_pill(parent: Control, kind: String, col: Color) -> Label:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", IdleUi.pill_style())
	parent.add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	pill.add_child(row)
	row.add_child(IdleUi.icon(kind, 36.0, col))
	var l := IdleUi.label("", 24, IdleUi.CREAM)
	row.add_child(l)
	return l


## 탭 모양: 고른 탭은 흰 바탕에 라벤더 글씨로 떠오른다.
func _style_tab(b: Button, on: bool) -> void:
	var sb := IdleUi.box(Color.WHITE if on else Color(1, 1, 1, 0.0), Color.WHITE if on else Color(1, 1, 1, 0.0), 20, 0, 4,
		false)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var col := IdleUi.LAV_DK if on else Color.WHITE
	(b.get_node("V/Icon") as Control).modulate = col     # 흰 아이콘에 색을 곱한다
	(b.get_node("V/Label") as Label).add_theme_color_override("font_color", col)
	b.position.y = -6.0 if on else 0.0


## 무대 위 친구들 (편성 앞쪽 다섯) - 숨 쉬듯 살짝 움직인다.
func _fill_parade() -> void:
	var stage := _home.get_node("Parade") as Node2D
	for c in stage.get_children():
		c.queue_free()
	var ids: Array = LaneState.lineup.slice(0, 5)
	var n := ids.size()
	var gap := minf(120.0, (size.x - 80.0) / maxf(1.0, float(n)))
	for i in n:
		var a := IdleActor.new()
		a.set_sheet(unit_sheet(String(ids[i])))
		a.row = 0
		a.px = 3.0
		a.walking = false
		a.position = Vector2(size.x * 0.5 + (float(i) - float(n - 1) * 0.5) * gap, 0)
		a.position = (a.position / 3.0).round() * 3.0
		stage.add_child(a)


func _layout_home() -> void:
	var w := size.x
	var h := size.y
	_home_pix.size = size
	(_home_pix.get_node("VP/Back") as Control).size = size
	var top := _home.get_node("Top") as Control
	top.position = Vector2(14, 14)
	top.size = Vector2(w - 28, 64)
	var hero_h := clampf(h * 0.24, 230.0, 380.0)
	(_home.get_node("Title") as Control).position = Vector2(0, 86)
	(_home.get_node("Title") as Control).size = Vector2(w, 76)
	(_home.get_node("Sub") as Control).position = Vector2(0, 156)
	(_home.get_node("Sub") as Control).size = Vector2(w, 32)
	(_home.get_node("Parade") as Node2D).position = Vector2(0, 86.0 + hero_h - 6.0)
	var tabs_h := 112.0
	var bar := _home.get_node("TabBar") as Control
	bar.position = Vector2(0, h - tabs_h)
	bar.size = Vector2(w, tabs_h)
	var go := _home.get_node("Go") as Control
	go.position = Vector2(24, h - tabs_h - 16.0 - 108.0)
	go.size = Vector2(w - 48, 108)
	var card := _home.get_node("Card") as Control
	var cy := 86.0 + hero_h + 4.0
	card.position = Vector2(14, cy)
	card.size = Vector2(w - 28, go.position.y - 14.0 - cy)


func _show_home() -> void:
	mode = "home"
	Engine.time_scale = 1.0
	if _world != null:
		_world.queue_free()
		_world = null
	_home.visible = true
	AudioManager.play_bgm("adventure")
	_layout_home()
	_fill_home()
	# 켜 둔 채로 자정이 지났으면 홈으로 돌아올 때 선물
	var g := LaneState.claim_daily(_local_now())
	if not g.is_empty():
		LaneState.save()
		_refresh_home_top()
		_toast("매일 선물 %d일째!  티켓 %d장 · 꿈별 %d" % [int(g["streak"]), int(g["tickets"]), int(g["stars"])])


## 기기 시간대의 '지금' (매일 선물이 그 나라 자정에 바뀌게).
static func _local_now() -> int:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	return int(Time.get_unix_time_from_system()) + bias * 60


func _refresh_home_top() -> void:
	_xp_lbl.text = _num(LaneState.xp)
	_star_lbl.text = _num(LaneState.stars)
	_ticket_lbl.text = str(LaneState.tickets)
	var nxt := mini(LaneState.cleared + 1, LaneData.STAGE_MAX)
	(_home.get_node("Go") as Button).text = "▶  출전!   %s" % LaneData.stage_label(nxt)
	for k in ["map", "units", "lineup", "gacha"]:
		var b := _home.get_node("TabBar/Tabs/Tab_" + k) as Button
		_style_tab(b, _home_tab == k)
	(_home.get_node("TabBar/Tabs/Tab_gacha/Dot") as Control).visible = LaneState.can_pull(1)
	_card_title.text = {"map": "지도 · 판 고르기", "units": "동물 친구들", "lineup": "편성 · 콤보", "gacha": "꿈 캡슐 뽑기"}[_home_tab]
	_fill_parade()


func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _fill_home() -> void:
	_refresh_home_top()
	_clear(_home_body)
	match _home_tab:
		"map":
			_fill_map()
		"units":
			_fill_units()
		"lineup":
			_fill_lineup()
		"gacha":
			_fill_gacha()


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", IdleUi.card_style())
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _fill_map() -> void:
	# 보물 효과 모아 보기
	var tb := LaneState.treasure_bonus()
	var parts: Array = []
	for k in ["atk", "hp", "rate", "cannon", "xp", "wallet"]:
		if tb.has(k):
			parts.append(LaneData.bonus_text(k, float(tb[k])))
	var sum := IdleUi.label("보물 효과:  " + (" · ".join(parts) if not parts.is_empty() else "아직 없어요 - 판을 깨면 가끔 나와요"),
		20, IdleUi.GOLD)
	sum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_home_body.add_child(sum)
	var last_zone := clampi(LaneState.cleared / LaneData.STAGES_PER_ZONE, 0, LaneData.ZONES.size() - 1)
	for zi in range(last_zone, -1, -1):
		var z: Dictionary = LaneData.ZONES[zi]
		var card := _card()
		_home_body.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		card.add_child(v)
		var boss_name := String(LaneData.BUGS[String(z["boss"])]["name"])
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		v.add_child(head)
		head.add_child(_bug_face(String(z["boss"]), 72.0))
		var hv := VBoxContainer.new()
		hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(hv)
		hv.add_child(IdleUi.label("%d. %s" % [zi + 1, String(z["name"])], 28, IdleUi.CREAM))
		hv.add_child(IdleUi.label("우두머리 %s · 보물 %d / 9" % [boss_name, LaneState.treasure_count(zi)], 19, IdleUi.SUB))
		# 보물 셋 - 등급 색 테두리, 없으면 흐리게
		var trow := HBoxContainer.new()
		trow.add_theme_constant_override("separation", 6)
		v.add_child(trow)
		for ti in 3:
			var t: Dictionary = LaneData.TREASURES[zi][ti]
			var g := int(LaneState.treasures[zi][ti])
			var cell := PanelContainer.new()
			cell.add_theme_stylebox_override("panel", IdleUi.card_style(Color(LaneData.GRADE_COL[g])))
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			trow.add_child(cell)
			var cv := VBoxContainer.new()
			cv.alignment = BoxContainer.ALIGNMENT_CENTER
			cell.add_child(cv)
			var ic := _icon(String(t["icon"]), Color(t["col"]) if g > 0 else Color(0.25, 0.22, 0.3), 44.0)
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cv.add_child(ic)
			var tn := IdleUi.label(String(t["name"]) if g > 0 else "???", 16, IdleUi.CREAM if g > 0 else IdleUi.MUTED)
			tn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(tn)
			var te := IdleUi.label("%s %s" % [String(LaneData.GRADE_NAME[g]), LaneData.bonus_text(String(t["kind"]),
				float(t["per"]) * float(maxi(1, g)))] if g > 0 else LaneData.bonus_text(String(t["kind"]), float(t["per"]) * 3.0) + " 까지",
				14, Color(LaneData.GRADE_COL[g]) if g > 0 else IdleUi.MUTED)
			te.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(te)
		var gr := GridContainer.new()
		gr.columns = 5
		gr.add_theme_constant_override("h_separation", 8)
		gr.add_theme_constant_override("v_separation", 8)
		v.add_child(gr)
		for i in range(1, LaneData.STAGES_PER_ZONE + 1):
			var n := zi * LaneData.STAGES_PER_ZONE + i
			var open := n <= LaneState.cleared + 1
			var done := n <= LaneState.cleared
			var lbl := ("왕" if i == 10 else str(i)) + (" ✓" if done else "")
			var b := IdleUi.button(lbl, 22, "gold" if n == LaneState.cleared + 1 else "plum")
			b.custom_minimum_size = Vector2(118, 64)
			b.disabled = not open
			b.pressed.connect(_start_battle.bind(n))
			gr.add_child(b)


func _fill_units() -> void:
	_home_body.add_child(IdleUi.label("도감  %d / %d  -  뽑기에서 새 친구를 만나요" % [LaneState.owned_count(),
		LaneData.ALL_ORDER.size()], 24, IdleUi.CREAM))
	for id in LaneData.ALL_ORDER:
		var u: Dictionary = LaneData.UNITS[id]
		var rr := LaneData.rarity(String(id))
		var card := _card()
		_home_body.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		row.add_child(_portrait(String(id), 96.0))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 2)
		row.add_child(v)
		if not LaneState.has_unit(String(id)):
			if rr == "base":
				v.add_child(IdleUi.label("??? 쿼카", 26, IdleUi.MUTED))
				v.add_child(IdleUi.label("%s 를 깨면 합류해요" % LaneData.stage_label(int(u["unlock"])), 20, IdleUi.MUTED))
			else:
				v.add_child(IdleUi.label("???  %s %s" % ["★".repeat(int(LaneData.RARITY_STARS[rr])),
					String(LaneData.RARITY_NAME[rr])], 26, (RARITY_COL[rr] as Color).darkened(0.35)))
				v.add_child(IdleUi.label("꿈 캡슐에서 만나요", 20, IdleUi.MUTED))
			continue
		var lv := LaneState.level_of(String(id))
		var s := LaneState.unit_stats(String(id))
		var title := "%s  Lv %d" % [LaneData.unit_name(String(id), lv), lv]
		if rr != "base":
			title = "★".repeat(int(LaneData.RARITY_STARS[rr])) + " " + title
		v.add_child(IdleUi.label(title, 26, RARITY_COL[rr] if rr != "base" else
			(IdleUi.GOLD if lv >= LaneData.EVOLVE_LV else IdleUi.CREAM)))
		var tt := LaneData.trait_text(String(id))
		if tt != "":
			v.add_child(IdleUi.label(tt, 19, IdleUi.GREEN))
		var role := "[%s] %s" % [role_of(String(id)), String(u["role"])]
		if lv < LaneData.EVOLVE_LV:
			role += "  ·  Lv %d 에 진화!" % LaneData.EVOLVE_LV
		v.add_child(IdleUi.label(role, 19, IdleUi.SUB))
		v.add_child(IdleUi.label("체력 %s · 공격 %s · 사거리 %d · 꿈빛 %d" % [_num(int(s["hp"])), _num(int(s["atk"])),
			int(u["range"]), int(u["cost"])], 18, IdleUi.SUB))
		var accrow := HBoxContainer.new()
		accrow.add_theme_constant_override("separation", 6)
		v.add_child(accrow)
		var cur := String(LaneState.acc_on.get(String(id), ""))
		var ab := IdleUi.button("장신구 +" if cur == "" else "", 18, "ghost")
		ab.custom_minimum_size = Vector2(0, 48)
		if cur != "":
			var ad: Dictionary = LaneData.ACCESSORIES[cur]
			ab.text = "     %s Lv%d" % [String(ad["name"]), int(LaneState.accs[cur])]
			var ic := _icon(String(ad["icon"]), Color(ad["col"]), 36.0)
			ic.position = Vector2(8, 6)
			ab.add_child(ic)
		ab.pressed.connect(_open_acc_picker.bind(String(id)))
		accrow.add_child(ab)
		var b := IdleUi.button("", 20, "gold")
		b.name = "Lv_" + String(id)
		b.custom_minimum_size = Vector2(150, 76)
		if lv >= LaneData.UNIT_LV_MAX:
			b.text = "최고 레벨"
			b.disabled = true
		else:
			b.text = "레벨 업\n✦ %s" % _num(LaneData.level_cost(String(id), lv))
			b.disabled = not LaneState.can_level(String(id))
		b.pressed.connect(func() -> void:
			if LaneState.level_up(String(id)):
				AudioManager.ui_confirm()
				LaneState.save()
				if LaneState.level_of(String(id)) == LaneData.EVOLVE_LV:
					AudioManager.souvenir_get()
					_toast("진화! %s → %s" % [String(LaneData.UNITS[id]["name"]), LaneData.unit_name(String(id), LaneData.EVOLVE_LV)])
				_fill_home())
		row.add_child(b)
		# 긴 설명은 줄을 바꿔 버튼을 밀어내지 않게
		for c in v.get_children():
			if c is Label:
				(c as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				(c as Label).custom_minimum_size.x = 10


func _fill_lineup() -> void:
	_lineup_grid()
	var active := LaneState.active_combos()
	_home_body.add_child(IdleUi.label("콤보 %d / %d  -  같이 편성하면 힘이 나요" % [active.size(), LaneData.COMBOS.size()], 24,
		IdleUi.GOLD))
	for c in LaneData.COMBOS:
		var on := active.has(c)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", IdleUi.card_style(IdleUi.GOLD if on else IdleUi.LINE))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_home_body.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		card.add_child(row)
		for u in c["units"]:
			var face := _portrait(String(u), 52.0)
			if LaneState.has_unit(String(u)) and not LaneState.lineup.has(u):
				face.modulate = Color(1, 1, 1, 0.4)
			row.add_child(face)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		v.add_child(IdleUi.label(("✓ " if on else "") + String(c["name"]), 22, IdleUi.GOLD if on else IdleUi.CREAM))
		v.add_child(IdleUi.label(LaneData.bonus_text(String(c["kind"]), float(c["v"])), 18,
			IdleUi.GREEN if on else IdleUi.SUB))


func _lineup_grid() -> void:
	_home_body.add_child(IdleUi.label("편성 %d / %d  -  눌러서 넣고 빼요" % [LaneState.lineup.size(), LaneData.LINEUP_MAX], 24,
		IdleUi.CREAM))
	var gr := GridContainer.new()
	gr.columns = 3
	gr.add_theme_constant_override("h_separation", 10)
	gr.add_theme_constant_override("v_separation", 10)
	_home_body.add_child(gr)
	for id in LaneData.ALL_ORDER:
		if not LaneState.has_unit(String(id)):
			continue
		var on := LaneState.lineup.has(id)
		var b := IdleUi.button("", 20, "gold" if on else "ghost")
		b.custom_minimum_size = Vector2(212, 180)
		b.text = "\n\n\n%s\n%s" % [LaneData.unit_name(String(id), LaneState.level_of(String(id))), "출전 ✓" if on else "쉬는 중"]
		var p := _portrait(String(id), 84.0)
		p.position = Vector2(64, 8)
		b.add_child(p)
		b.pressed.connect(func() -> void:
			if LaneState.toggle_lineup(String(id)):
				AudioManager.ui_click()
				LaneState.save()
			_fill_home())
		gr.add_child(b)


func _fill_gacha() -> void:
	var card := _card()
	_home_body.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	v.add_child(_center(IdleUi.label("꿈 캡슐", 44, IdleUi.GOLD, true)))
	v.add_child(_center(IdleUi.label("동물 친구들이 캡슐 속에서 기다려요", 22, IdleUi.SUB)))
	# 전설 친구들 미리 보기 - 아직 없으면 그림자
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	for id in ["tiger", "polar", "eagle"]:
		var col := VBoxContainer.new()
		row.add_child(col)
		col.add_child(_portrait(id, 120.0))
		var nm := IdleUi.label(String(LaneData.UNITS[id]["name"]) if LaneState.has_unit(id) else "★★★ ???", 18,
			RARITY_COL["legend"])
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nm)
	v.add_child(_center(IdleUi.label("희귀 72%  ·  특급 24%  ·  전설 4%", 22, IdleUi.CREAM)))
	v.add_child(_center(IdleUi.label("%d번 안에 전설 확정 (남은 %d번)  ·  같은 친구는 레벨 +1" % [LaneData.PITY_LEGEND,
		LaneData.PITY_LEGEND - LaneState.pity], 19, IdleUi.SUB)))
	var one := IdleUi.button("", 30, "gold")
	one.custom_minimum_size = Vector2(0, 110)
	if LaneState.tickets > 0:
		one.text = "티켓으로 1번 뽑기  (%d장)" % LaneState.tickets
	else:
		one.text = "1번 뽑기   ★ %d" % LaneData.GACHA_COST
	one.disabled = not LaneState.can_pull(1)
	one.name = "PullOne"
	one.pressed.connect(_do_pull.bind(1))
	v.add_child(one)
	var ten := IdleUi.button("10번 뽑기   ★ %d\n특급 이상 1마리 확정" % LaneData.GACHA10_COST, 26, "plum")
	ten.custom_minimum_size = Vector2(0, 110)
	ten.disabled = not LaneState.can_pull(10)
	ten.pressed.connect(_do_pull.bind(10))
	v.add_child(ten)
	var how := IdleUi.label("꿈별은 판을 처음 깨면 받고(뒤 구역일수록 많이, 우두머리는 티켓도), 다시 깨면 1개, 매일 선물로도 받아요.\n진짜 돈은 쓰지 않아요.",
		19, IdleUi.SUB)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(how)


func _do_pull(count: int) -> void:
	var res := LaneState.pull(count, _rng)
	if res.is_empty():
		return
	LaneState.save(int(Time.get_unix_time_from_system()))
	AudioManager.ui_confirm()
	var g := LaneGacha.new()
	g.size = size
	add_child(g)
	g.finished.connect(func() -> void:
		_fill_home()
		if _tut_after_gacha.is_valid():
			var f := _tut_after_gacha
			_tut_after_gacha = Callable()
			_later(0.3, f))
	g.play(res)


## 보물·장신구 아이콘 (회색 그림에 색을 곱한다).
func _icon(name: String, col: Color, sz: float) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(sz, sz)
	t.size = Vector2(sz, sz)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := load("res://assets/sprites/lane-icons.png") as Texture2D
	var i := LaneData.ICONS.find(name)
	if tex != null and i >= 0:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 16, 0, 16, 16)
		t.texture = a
	t.modulate = col
	return t


## 벌레 얼굴 (지도의 우두머리).
func _bug_face(kind: String, sz: float) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(sz, sz)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := load("res://assets/sprites/bug-%s.png" % kind) as Texture2D
	if tex != null:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = _face_region(tex)
		t.texture = a
	return t


## 화면 위에 뜨는 창 (장신구 고르기 등). 바깥을 누르면 닫힌다.
func _popup(title: String) -> VBoxContainer:
	var layer := Control.new()
	layer.name = "Popup"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.size = size
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.09, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.size = size
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			layer.queue_free())
	layer.add_child(dim)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", IdleUi.panel_style())
	card.position = Vector2(24, 140)
	card.size = Vector2(size.x - 48, size.y - 280)
	layer.add_child(card)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	card.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var tl := IdleUi.label(title, 34, IdleUi.GOLD, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	var close := IdleUi.button("닫기", 22)
	close.custom_minimum_size = Vector2(100, 60)
	close.pressed.connect(layer.queue_free)
	head.add_child(close)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	IdleUi.style_scroll(sc)
	outer.add_child(sc)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	sc.add_child(body)
	return body


func _close_popup() -> void:
	var p := get_node_or_null("Popup")
	if p != null:
		p.queue_free()


## 이 유닛에 달 장신구 고르기.
func _open_acc_picker(unit: String) -> void:
	_close_popup()
	var body := _popup("%s 의 장신구" % LaneData.unit_name(unit, LaneState.level_of(unit)))
	if LaneState.accs.is_empty():
		body.add_child(IdleUi.label("아직 장신구가 없어요.\n구역 우두머리를 처음 잡으면 하나씩 얻어요.", 24, IdleUi.SUB))
		return
	if LaneState.acc_on.has(unit):
		var off := IdleUi.button("빼기", 24, "plum")
		off.custom_minimum_size = Vector2(0, 70)
		off.pressed.connect(func() -> void:
			LaneState.unequip(unit)
			LaneState.save()
			AudioManager.ui_click()
			_close_popup()
			_fill_home())
		body.add_child(off)
	for acc in LaneData.ACC_ORDER:
		if not LaneState.accs.has(acc):
			continue
		var a: Dictionary = LaneData.ACCESSORIES[acc]
		var lv := int(LaneState.accs[acc])
		var card := _card()
		body.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		row.add_child(_icon(String(a["icon"]), Color(a["col"]), 72.0))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		v.add_child(IdleUi.label("%s  Lv %d" % [String(a["name"]), lv], 24, IdleUi.CREAM))
		v.add_child(IdleUi.label(LaneData.acc_text(acc, lv), 19, IdleUi.GREEN))
		var who := LaneState.wearer(acc)
		if who != "":
			v.add_child(IdleUi.label("%s 이(가) 달고 있어요" % String(LaneData.UNITS[who]["name"]), 18, IdleUi.SUB))
		var bv := VBoxContainer.new()
		row.add_child(bv)
		var on := IdleUi.button("달고 있음" if who == unit else "달기", 20, "ghost" if who == unit else "gold")
		on.custom_minimum_size = Vector2(130, 56)
		on.disabled = who == unit
		on.pressed.connect(func() -> void:
			LaneState.equip(unit, acc)
			LaneState.save()
			AudioManager.ui_confirm()
			_close_popup()
			_fill_home())
		bv.add_child(on)
		var up := IdleUi.button("최고" if lv >= LaneData.ACC_LV_MAX else "강화 ✦%s" % _num(LaneData.acc_level_cost(lv)), 18)
		up.custom_minimum_size = Vector2(130, 56)
		up.disabled = not LaneState.can_level_acc(acc)
		up.pressed.connect(func() -> void:
			if LaneState.level_acc(acc):
				LaneState.save()
				AudioManager.ui_confirm()
				_open_acc_picker(unit)
				_refresh_home_top())
		bv.add_child(up)


## 쿼카 얼굴 (앞모습 첫 칸).
func _portrait(id: String, sz: float) -> Control:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(sz, sz)
	t.size = Vector2(sz, sz)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := load(unit_sheet(id)) as Texture2D
	if tex != null:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = _face_region(tex)
		t.texture = a
	if not LaneState.has_unit(id):
		t.modulate = Color(0.1, 0.08, 0.15, 0.9)
	return t


# ══ 판 ════════════════════════════════════════════════════════════════

func _start_battle(n: int) -> void:
	stage_n = n
	AudioManager.ui_confirm()
	_home.visible = false
	mode = "battle"
	_ended = false
	_won = false
	_battle_t = 0.0
	_actor_of = {}
	_lat = {}
	battle.start(n)
	battle.auto = LaneState.auto_summon
	_build_battle()
	_layout()
	var info := battle.info
	AudioManager.play_bgm("boss" if bool(info["boss"]) else "adventure")
	_banner_show(LaneData.stage_label(n), Color.WHITE)
	if battle.cheer > 0.0:
		_toast("다시 도전 응원!  공격·체력 +%d%%" % int(battle.cheer))
	# 출전 단추를 누른 '뒤에' 안내 단계가 1이 되므로 조금 뒤에 본다
	_later(0.4, func() -> void:
		if LaneState.tut == 1 and stage_n == 1:
			_tut_battle_guide(0))


func _build_battle() -> void:
	_world = Control.new()
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)
	move_child(_world, 0)
	_pix = _pixel_layer()
	_world.add_child(_pix)
	var vp := _pix.get_node("VP")
	_bg = IdleBackdrop.new()
	_bg.zone = int(battle.info["theme"])
	_bg.ground = 0.13
	vp.add_child(_bg)
	_field = LaneField.new()
	var th: Dictionary = IdleBackdrop.THEMES[_bg.zone]
	_field.lane_col = Color(th["ground"]).lightened(0.18)
	vp.add_child(_field)
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	_world.add_child(_actors)
	_bars = Node2D.new()
	_bars.draw.connect(_draw_bars)
	_world.add_child(_bars)
	# 효과도 도트로 - 글씨(숫자)가 읽히게 배경보다 한 단계 덜(2배) 거칠게
	_fx_pix = _pixel_layer(FX_PIX)
	_world.add_child(_fx_pix)
	_fx = IdleFx.new()
	_fx_pix.get_node("VP").add_child(_fx)
	_vfx = IdleVfx.new()
	_fx_pix.get_node("VP").add_child(_vfx)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_flash_rect)
	_danger = Control.new()
	_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger.set_anchors_preset(Control.PRESET_FULL_RECT)
	_danger.draw.connect(_draw_danger)
	_world.add_child(_danger)
	_build_hud()


func _build_hud() -> void:
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_hud)
	var top := HBoxContainer.new()
	top.name = "Top"
	top.add_theme_constant_override("separation", 8)
	_hud.add_child(top)
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", IdleUi.pill_style())
	_stage_lbl = IdleUi.label(LaneData.stage_label(stage_n), 24, IdleUi.CREAM)
	sp.add_child(_stage_lbl)
	top.add_child(sp)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_speed_btn = IdleUi.button("", 22)
	_speed_btn.custom_minimum_size = Vector2(88, 60)
	_speed_btn.pressed.connect(func() -> void:
		LaneState.speed2 = not LaneState.speed2
		AudioManager.ui_click()
		_refresh_hud_toggles())
	top.add_child(_speed_btn)
	_auto_btn = IdleUi.button("", 22)
	_auto_btn.custom_minimum_size = Vector2(120, 60)
	_auto_btn.pressed.connect(func() -> void:
		LaneState.auto_summon = not LaneState.auto_summon
		battle.auto = LaneState.auto_summon
		AudioManager.ui_click()
		_refresh_hud_toggles())
	top.add_child(_auto_btn)
	var quit := IdleUi.button("후퇴", 22, "danger")
	quit.custom_minimum_size = Vector2(88, 60)
	quit.pressed.connect(func() -> void:
		if not _ended:
			_end_battle("lose"))
	top.add_child(quit)

	# ── 아래 판: [수입] [꿈빛] [꿈 대포] / 유닛 버튼 (얼굴·이름·역할·비용)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	var psb := IdleUi.panel_style()
	psb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", psb)
	_hud.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	panel.add_child(pv)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	pv.add_child(row1)
	_worker_btn = IdleUi.button("", 20, "plum")
	_worker_btn.custom_minimum_size = Vector2(136, 92)
	_worker_btn.pressed.connect(func() -> void:
		if battle.upgrade_worker():
			AudioManager.ui_confirm()
		else:
			_shake_ctrl(_worker_btn))
	row1.add_child(_worker_btn)
	var wv := VBoxContainer.new()
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	wv.add_theme_constant_override("separation", 4)
	row1.add_child(wv)
	_wallet_lbl = IdleUi.label("", 28, IdleUi.GOLD, true)
	_wallet_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wv.add_child(_wallet_lbl)
	_wallet_bar = IdleUi.bar(IdleUi.GOLD, Vector2(200, 16))
	_wallet_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wv.add_child(_wallet_bar)
	var orow := HBoxContainer.new()
	orow.add_theme_constant_override("separation", 6)
	wv.add_child(orow)
	_our_lbl = IdleUi.label("", 16, IdleUi.CREAM)
	_our_lbl.custom_minimum_size = Vector2(150, 0)
	orow.add_child(_our_lbl)
	_our_bar = IdleUi.bar(IdleUi.GREEN, Vector2(100, 14))
	_our_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_our_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	orow.add_child(_our_bar)
	_cannon_btn = IdleUi.button("", 22, "gold")
	_cannon_btn.custom_minimum_size = Vector2(150, 92)
	_cannon_btn.pressed.connect(func() -> void:
		if battle.fire_cannon():
			AudioManager.ui_confirm()
		else:
			_shake_ctrl(_cannon_btn))
	row1.add_child(_cannon_btn)
	var gr := GridContainer.new()
	gr.name = "Units"
	gr.columns = 5
	gr.add_theme_constant_override("h_separation", 8)
	gr.add_theme_constant_override("v_separation", 8)
	pv.add_child(gr)
	_unit_btns = {}
	for id in battle.lineup:
		var uid_s := String(id)
		var rr := LaneData.rarity(uid_s)
		var b := IdleUi.button("", 18, "ghost")
		b.custom_minimum_size = Vector2(0, 134)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_contents = true
		if rr != "base":
			var bsb := IdleUi.box(Color.WHITE, RARITY_COL[rr], 22, 4, 6)
			b.add_theme_stylebox_override("normal", bsb)
			b.add_theme_stylebox_override("hover", bsb)
		var col := VBoxContainer.new()
		col.name = "Col"
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 0)
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(col)
		var role := role_of(uid_s)
		var chip := PanelContainer.new()
		var csb := IdleUi.box(Color(ROLE_COL[role]), Color(ROLE_COL[role]).darkened(0.25), 10, 2, 2, false)
		csb.content_margin_left = 8
		csb.content_margin_right = 8
		chip.add_theme_stylebox_override("panel", csb)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cl := Label.new()
		cl.text = role
		cl.add_theme_font_size_override("font_size", 14)
		cl.add_theme_color_override("font_color", Color("#2E1A4A"))
		chip.add_child(cl)
		col.add_child(chip)
		var pic := _portrait(uid_s, 54.0)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(pic)
		var nm := IdleUi.label(_short_name(uid_s), 15, IdleUi.CREAM)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		col.add_child(nm)
		var cost := IdleUi.label("", 20, IdleUi.GOLD_DK)
		cost.name = "Cost"
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(cost)
		var cd := ColorRect.new()
		cd.name = "Cd"
		cd.color = Color(0.23, 0.15, 0.35, 0.45)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cd)
		b.pressed.connect(func() -> void:
			if battle.summon(uid_s):
				AudioManager.pickup()
			else:
				_shake_ctrl(b))
		gr.add_child(b)
		_unit_btns[id] = b
	_refresh_hud_toggles()


func _layout_hud() -> void:
	var w := size.x
	var h := size.y
	var top := _hud.get_node("Top") as Control
	top.position = Vector2(12, 12)
	top.size = Vector2(w - 24, 60)
	var panel := _hud.get_node("Panel") as Control
	# 유닛 줄 수만큼만 - 빈 판이 화면 아래를 먹지 않게
	var rows := maxi(1, int(ceil(float(battle.lineup.size()) / 5.0)))
	var ph := 28.0 + 92.0 + 10.0 + float(rows) * 134.0 + float(rows - 1) * 8.0 + 6.0
	panel.position = Vector2(8, h - ph - 8.0)
	panel.size = Vector2(w - 16, ph)
	if _field != null:
		_field.y_front = h - ph - 8.0 - 86.0


func _refresh_hud_toggles() -> void:
	_speed_btn.text = "2배 ▶▶" if LaneState.speed2 else "1배 ▶"
	_auto_btn.text = "자동 켜짐" if LaneState.auto_summon else "자동 소환"
	_auto_btn.modulate = Color("#B8F0A8") if LaneState.auto_summon else Color.WHITE


func _process(dt: float) -> void:
	_t += dt
	_save_t += dt
	if _save_t > SAVE_EVERY:
		_save_t = 0.0
		LaneState.save(int(Time.get_unix_time_from_system()))
	if mode != "battle" or _world == null:
		return
	var rdt := dt / maxf(Engine.time_scale, 0.001)
	_trauma = maxf(0.0, _trauma - rdt * 1.3)
	var sh := _trauma * _trauma
	var st := Time.get_ticks_msec() / 1000.0 * 30.0
	_world.position = Vector2(14.0 * sh * sin(st * 1.1), 10.0 * sh * sin(st * 1.7 + 2.0))
	_flash_rect.color.a = maxf(0.0, _flash_rect.color.a - dt * 2.5)
	if not _ended and not _tut_pause:
		var sdt := minf(dt, 0.25) * (2.0 if LaneState.speed2 else 1.0)
		_battle_t += sdt
		for e in battle.tick(sdt):
			_on_event(e)
		if battle.done and not _ended:
			_end_battle(battle.result)
	_sync_actors()
	_refresh_hud()
	_danger.queue_redraw()
	_bars.queue_redraw()


## 머리 위 체력 띠 - 우리 편 초록, 벌레 빨강, 우두머리는 굵고 길게.
func _draw_bars() -> void:
	for uid in _actor_of.keys():
		var a = _actor_of[uid]
		var e = _ent_of.get(uid)
		if a == null or not is_instance_valid(a) or e == null or a.dissolve > 0.0:
			continue
		var r := clampf(float(e["hp"]) / maxf(1.0, float(e["max"])), 0.0, 1.0)
		var boss := bool(e.get("boss", false))
		# 도트 띠: 크기·위치를 픽셀(PIX) 칸에 맞춘다
		var px := float(PIX)
		var w := (36.0 if boss else 14.0) * px
		var h := (3.0 if boss else 2.0) * px
		var p: Vector2 = a.position + Vector2(-w * 0.5, -a.body_height() - 3.0 * px - h)
		p = (p / px).round() * px
		var fill := floorf(w * r / px) * px
		var col := Color("#5CCB7A") if e["side"] == "q" else Color("#F0506E")
		if e["side"] == "q" and r < 0.35:
			col = Color("#FFB84A")
		_bars.draw_rect(Rect2(p - Vector2(px, px), Vector2(w + 2.0 * px, h + 2.0 * px)), Color("#2B1B2E"))
		_bars.draw_rect(Rect2(p, Vector2(w, h)), Color("#5A4A66"))
		_bars.draw_rect(Rect2(p, Vector2(fill, h)), col)
		_bars.draw_rect(Rect2(p, Vector2(fill, px)), col.lightened(0.35))


## 성 체력이 반 아래면 가장자리가 붉게 - 낮을수록 진하고 빠르게 뛴다.
func _draw_danger() -> void:
	if battle == null or _ended:
		return
	var r := battle.our_hp / maxf(1.0, battle.our_max)
	if r >= 0.5:
		return
	var k := (0.5 - r) / 0.5
	var beat := 0.55 + 0.45 * sin(_t * (5.0 + 6.0 * k))
	var a := (0.12 + 0.3 * k) * beat
	var w := 70.0
	for i in 7:
		var c := Color(0.9, 0.1, 0.25, a * (1.0 - float(i) / 7.0) * 0.5)
		var o := float(i) * w / 7.0
		var t := w / 7.0
		_danger.draw_rect(Rect2(0, o, size.x, t), c)
		_danger.draw_rect(Rect2(0, size.y - o - t, size.x, t), c)
		_danger.draw_rect(Rect2(o, 0, t, size.y), c)
		_danger.draw_rect(Rect2(size.x - o - t, 0, t, size.y), c)

func _refresh_hud() -> void:
	_wallet_lbl.text = "꿈빛 %d / %d" % [int(battle.wallet), battle.wallet_cap()]
	_wallet_bar.max_value = battle.wallet_cap()
	_wallet_bar.value = battle.wallet
	_our_bar.max_value = battle.our_max
	_our_bar.value = battle.our_hp
	_field.our_ratio = battle.our_hp / maxf(1.0, battle.our_max)
	_our_lbl.text = "우리 성 %s" % _num(int(battle.our_hp))
	_our_lbl.add_theme_color_override("font_color", IdleUi.RED if battle.our_hp < battle.our_max * 0.4 else IdleUi.CREAM)
	_field.nest_ratio = battle.nest_hp / maxf(1.0, battle.nest_max)
	var wc := battle.worker_cost()
	_worker_btn.text = "수입 Lv%d\n%s" % [battle.worker, ("최고" if wc < 0 else "올리기 ✦%d" % wc)]
	_worker_btn.disabled = not battle.can_worker()
	var ready := battle.cannon_ready()
	_cannon_btn.text = "꿈 대포!\n누르면 발사" if ready else "꿈 대포\n충전 %d%%" % int(battle.cannon / LaneData.CANNON_CHARGE * 100.0)
	_cannon_btn.disabled = not ready
	if ready:
		var s := 1.0 + 0.05 * sin(_t * 8.0)
		_cannon_btn.scale = Vector2(s, s)
	else:
		_cannon_btn.scale = Vector2.ONE
	for id in _unit_btns.keys():
		var b: Button = _unit_btns[id]
		var s2: Dictionary = battle.stats[id]
		var left := float(battle.cds.get(id, 0.0))
		var cost := int(s2["cost"])
		(b.get_node("Col/Cost") as Label).text = "✦%d" % cost
		b.disabled = battle.wallet < float(cost) or left > 0.0
		b.modulate = Color(1, 1, 1, 0.55) if b.disabled else Color.WHITE
		var cd := b.get_node("Cd") as ColorRect
		var k := clampf(left / maxf(0.01, float(s2["cd"])), 0.0, 1.0)
		cd.size = Vector2(b.size.x, b.size.y * k)
		cd.position = Vector2(0, b.size.y * (1.0 - k))


# ── 그림 맞추기 ───────────────────────────────────────────────────────

func _sync_actors() -> void:
	var alive := {}
	_ent_of = {}
	for e in battle.ents:
		var uid := int(e["uid"])
		_ent_of[uid] = e
		alive[uid] = true
		if _dead.has(uid):
			continue
		var a = _actor_of.get(uid)
		if a == null or not is_instance_valid(a):
			a = _make_actor(e)
		var pos := float(e["pos"])
		var depth := _field.scale_at(pos)
		var p := _field.to_screen(pos, float(_lat.get(uid, 0.0)))
		# 공격 동작: 웅크림(공격 0.25초 전) → 쭉 뻗으며 덤벼듦 → 돌아옴. 앞쪽 = 쿼카는 위, 벌레는 아래.
		var fwd := -1.0 if e["side"] == "q" else 1.0
		var atk_f := -1
		if e["state"] == "fight":
			# 실제 시간으로 잰다 - 2배속에서도 휘두르는 게 눈에 보이게
			var since := _t - float(_swing_at.get(uid, -99.0))
			var until := float(e["t_atk"]) / (2.0 if LaneState.speed2 else 1.0)
			var lunge := 0.0
			if since < 0.08:
				atk_f = 1
				lunge = 27.0 * since / 0.08
				a.squash = Vector2(0.84, 1.2)
			elif since < 0.21:
				atk_f = 2
				lunge = 27.0
				a.squash = Vector2(0.9, 1.1)
			elif since < 0.37:
				atk_f = 3
				lunge = 27.0 * (1.0 - (since - 0.21) / 0.16)
			elif until <= 0.22:
				atk_f = 0
				lunge = -9.0 * (1.0 - until / 0.22)
				a.squash = Vector2(1.12, 0.88)
			else:
				atk_f = 3
			p.y += fwd * lunge
		# 맞으면 뒤로 살짝 밀린다
		var hs := _battle_t - float(_hit_at.get(uid, -99.0))
		if hs < 0.12:
			p.y -= fwd * 9.0 * (1.0 - hs / 0.12)
		# 픽셀 격자에 맞춰 놓고, 크기는 원근과 관계없이 한 가지 (도트 규칙: 픽셀 크기는 하나)
		a.position = (p / float(PIX)).round() * float(PIX)
		a.px = UNIT_PX if e["side"] == "q" else BUG_PX
		a.walking = e["state"] == "walk"
		if e["side"] == "q":
			# 뒷모습으로 걷고, 싸울 땐 휘두르고, 밀려나면 앞을 보며 아파한다. 이기면 환호.
			a.frame_override = -1
			if _ended and _won:
				a.row = 0
				a.walking = false
				a.frame_override = 1 if int(Time.get_ticks_msec() / 220) % 2 == 0 else 0
			elif e["state"] == "kb":
				a.row = 0
				a.frame_override = 3
			elif e["state"] == "fight":
				a.row = 1
				a.walking = false
				a.frame_override = atk_f
			else:
				a.row = 2
		else:
			a.row = 2 if e["state"] == "kb" else (1 if e["state"] == "fight" else 0)
			a.frame_override = atk_f if e["state"] == "fight" else -1
			if e["state"] == "fight":
				a.walking = false
	for uid in _actor_of.keys():
		if not alive.has(uid):
			var a2 = _actor_of[uid]
			_actor_of.erase(uid)
			if is_instance_valid(a2) and a2.dissolve <= 0.0:
				a2.queue_free()
	for uid in _dead.keys():
		if not alive.has(uid):
			_dead.erase(uid)


func _make_actor(e: Dictionary) -> IdleActor:
	var a := IdleActor.new()
	var uid := int(e["uid"])
	_lat[uid] = randf_range(-150.0, 150.0)
	if e["side"] == "q":
		a.set_sheet(unit_sheet(String(e["kind"])))
	else:
		a.set_sheet("res://assets/sprites/bug-%s.png" % String(e["kind"]))
	_actors.add_child(a)
	_actor_of[uid] = a
	return a


func _actor_pos(uid: int) -> Vector2:
	var a = _actor_of.get(uid)
	if a == null or not is_instance_valid(a):
		return Vector2(size.x * 0.5, size.y * 0.5)
	return a.position + Vector2(0, -a.body_height() * 0.5)


# ── 사건 → 연출 ───────────────────────────────────────────────────────

func _on_event(e: Dictionary) -> void:
	match String(e["k"]):
		"spawn":
			var uid := int(e["uid"])
			if e["side"] == "q":
				var rr := LaneData.rarity(String(e["kind"]))
				_later(0.0, func() -> void:
					var a = _actor_of.get(uid)
					if a != null and is_instance_valid(a):
						a.squash = Vector2(1.3, 0.7)
						_vfx.burst(a.position, Color("#F2E2C2"), 6, 140.0, 0.4, 0.35, true)
						# 누가 나왔는지 머리 위에 이름
						var kid := String(e["kind"])
						_fx.text(a.position + Vector2(0, -a.body_height() - 30.0), LaneData.unit_name(kid, LaneState.level_of(kid)),
							RARITY_COL[rr] if rr != "base" else Color.WHITE, 22, 1.0, 0.0, 30.0)
						if rr == "legend":
							# 전설이 나오면 판 전체가 알아챈다
							_fx.pillar(a.position, RARITY_COL["legend"], 0.8)
							_fx.ring(a.position, 20.0, 260.0, RARITY_COL["legend"], 14.0, 0.6)
							_vfx.burst(a.position, RARITY_COL["legend"], 24, 380.0, 0.9, 0.5, true)
							_flash(0.25)
							_add_trauma(0.35)
							_banner_show("전설 출전! %s" % LaneData.unit_name(String(e["kind"]),
								LaneState.level_of(String(e["kind"]))), RARITY_COL["legend"])
							AudioManager.souvenir_get()
						elif rr == "super":
							_fx.ring(a.position, 16.0, 160.0, RARITY_COL["super"], 10.0, 0.45)
							_vfx.burst(a.position, RARITY_COL["super"], 12, 260.0, 0.6, 0.4, true))
			elif bool(e.get("boss", false)):
				_banner_show("%s 등장!" % String(LaneData.BUGS[String(e["kind"])]["name"]), Color("#FF8A8A"))
				_add_trauma(0.8)
				AudioManager.sky_crack()
		"swing":
			var a = _actor_of.get(int(e["uid"]))
			if a != null and is_instance_valid(a):
				# 휘두른 때를 적어 두면 `_sync_actors` 가 덤벼드는 동작을 그린다
				_swing_at[int(e["uid"])] = _t
		"hit":
			_hit_at[int(e["uid"])] = _battle_t
			var a = _actor_of.get(int(e["uid"]))
			if a != null and is_instance_valid(a):
				a.flash = 0.9
				a.flash_col = Color.WHITE if e["side"] == "b" else Color("#FF8080")
				var p: Vector2 = a.position + Vector2(0, -a.body_height() * 0.5)
				if e["side"] == "b":
					_attack_fx(int(e.get("by", -1)), p, a)
					_hit_fx(e, p)
				else:
					# 우리 편이 맞았다 - 빨간 숫자 + 할퀸 자국
					_fx.slash(p, randf_range(-0.8, 0.8), 30.0, Color("#FF7A8A"), 8.0, 0.16)
					_vfx.burst(p, Color("#FF9A9A"), 5, 200.0, 0.3, 0.3)
					_fx.text(p + Vector2(randf_range(-14, 14), -18), "-%s" % _num(int(e["dmg"])), Color("#FF5A6A"), 22,
						0.55, 0.0, 34.0)
			if randf() < 0.35:
				AudioManager.battle_weak_hit()
		"kb":
			var a = _actor_of.get(int(e["uid"]))
			if a != null and is_instance_valid(a):
				_vfx.burst(a.position, Color("#E8DCC8"), 6, 160.0, 0.45, 0.35, true)
				_add_trauma(0.06)
		"die":
			var uid := int(e["uid"])
			var a = _actor_of.get(uid)
			_actor_of.erase(uid)
			_dead[uid] = true
			if a != null and is_instance_valid(a):
				var p: Vector2 = a.position + Vector2(0, -a.body_height() * 0.5)
				a.dissolve = 0.01
				a.edge_col = Color("#FFE7A0") if e["side"] == "b" else Color("#FFB0C0")
				var tw := create_tween()
				tw.tween_property(a, "dissolve", 1.0, 0.45)
				tw.tween_callback(a.queue_free)
				if e["side"] == "b":
					_vfx.burst(p, Color("#FFD27A"), 14, 320.0, 0.7, 0.5, true)
					_fx.text(p + Vector2(0, -30), "+%d" % int(e["reward"]), IdleUi.GOLD, 26, 0.9, 0.05, 40.0)
					if bool(e.get("boss", false)):
						_add_trauma(0.9)
						_hitstop(0.12)
						_flash(0.4)
						_fx.ring(p, 20.0, 300.0, IdleUi.GOLD, 16.0, 0.6)
						_banner_show("우두머리를 물리쳤어요!", IdleUi.GOLD)
					else:
						_add_trauma(0.08)
					AudioManager.battle_hit()
				else:
					_vfx.burst(p, Color("#FFC0D0"), 8, 200.0, 0.6, 0.4, true)
		"base_hit":
			if e["side"] == "b":
				_field.shake_nest = 6.0
				_vfx.burst(Vector2(size.x * 0.5, _field.y_far - 30.0), Color("#C9A27A"), 4, 200.0, 0.4, 0.35)
			else:
				_field.shake_our = 6.0
				_add_trauma(0.05)
		"shock":
			_add_trauma(0.9)
			_flash(0.3)
			_fx.ring(Vector2(size.x * 0.5, _field.y_far + 40.0), 30.0, 700.0, Color("#FF9A9A"), 18.0, 0.8)
		"wave_warn":
			_banner_show("벌레 떼가 몰려와요!", Color("#FF9A9A"))
			_field.shake_nest = 8.0
		"wave":
			_add_trauma(0.25)
		"crisis":
			# 위기 역전 - 성의 힘
			_flash(0.5)
			_add_trauma(0.5)
			_banner_show("위기! 성의 힘이 깨어나요", IdleUi.GOLD)
			var cp := Vector2(size.x * 0.5, _field.y_front + 20.0)
			_fx.pillar(cp, IdleUi.LAV, 0.9)
			_fx.ring(cp, 30.0, 420.0, IdleUi.GOLD, 16.0, 0.7)
			_vfx.burst(cp, IdleUi.GOLD, 30, 500.0, 0.9, 0.5, true)
			AudioManager.souvenir_get()
		"rush":
			_toast("둥지가 흔들려요! 벌레가 몰려와요")
		"worker":
			_fx.text(_worker_btn.global_position + Vector2(75, -10) - _world.global_position, "수입 UP!", IdleUi.GOLD, 30, 0.9)
		"cannon", "cannon_fx":
			if String(e["k"]) == "cannon":
				_cannon_fx()
		"slow":
			var a = _actor_of.get(int(e["uid"]))
			if a != null and is_instance_valid(a):
				_vfx.burst(a.position + Vector2(0, -a.body_height() * 0.5), Color("#9FD8FF"), 8, 120.0, 0.6, 0.35, true)


## 공격한 쪽의 모양대로 - 베기·찌르기·충격파·탄·마법·얼음·할퀴기·내리꽂기.
func _attack_fx(by: int, p: Vector2, target) -> void:
	var src = _ent_of.get(by)
	if src == null or String(src["side"]) != "q":
		return
	var kind := String(src["kind"])
	var st: Array = FX_STYLE.get(kind, ["slash", "#FFFFFF"])
	var col := Color(String(st[1]))
	var depth := _field.scale_at(float(src["pos"]))
	var aa = _actor_of.get(by)
	var from: Vector2 = p + Vector2(0, 80)
	if aa != null and is_instance_valid(aa):
		from = aa.position + Vector2(0, -aa.body_height() * 0.6)
	# 범위 공격이면 맞은 놈마다 터지지 않게 한 번만 크게
	var now := _battle_t
	var first: bool = now - float(_fx_t.get(by, -9.0)) > 0.12
	if first:
		_fx_t[by] = now
	match String(st[0]):
		"slash":
			_fx.slash(p, randf_range(-0.9, 0.9), 54.0 * depth, col, 14.0, 0.2)
			_vfx.burst(p, col, 8, 300.0, 0.3, 0.4)
		"pierce":
			if first:
				_fx.arrow(from, p, col, 0.1)
			_fx.ring(p, 4.0, 40.0 * depth, col, 6.0, 0.2)
			_vfx.burst(p, col, 6, 320.0, 0.25, 0.35)
		"bonk", "peck":
			_fx.ring(p, 6.0, 44.0 * depth, col, 8.0, 0.22)
			_vfx.burst(p, col, 7, 220.0, 0.3, 0.4)
		"smash":
			if first:
				_fx.ring(p + Vector2(0, 20), 10.0, 120.0 * depth, col, 12.0, 0.32)
				_fx.wave(p + Vector2(0, 30), 150.0 * depth, col.darkened(0.2), 10.0, 0.4)
				_vfx.burst(p + Vector2(0, 26), Color("#E8DCC8"), 12, 260.0, 0.45, 0.45, true)
				_add_trauma(0.05)
			_vfx.burst(p, col, 8, 300.0, 0.35, 0.45)
		"shot":
			if first:
				_fx.orb(from, p, col, 0.16)
			_vfx.burst(p, col, 9, 280.0, 0.35, 0.4, false, 0.14)
			_fx.ring(p, 6.0, 50.0 * depth, col, 7.0, 0.22, 0.14)
		"magic":
			if first:
				_fx.orb(from, p, col, 0.2)
				_fx.rays(p, col, 10, 12.0, 110.0 * depth, 0.3, 0.18)
				_fx.ring(p, 10.0, 130.0 * depth, col, 10.0, 0.35, 0.18)
			_vfx.burst(p, col, 12, 340.0, 0.45, 0.45, false, 0.18)
			_fx.burst(p, Color.WHITE, 6, 260.0, 6.0, 0.4, 0.0, "star", 0.18)
		"quake":
			if first:
				_fx.wave(p + Vector2(0, 30), 220.0 * depth, col, 16.0, 0.5)
				_fx.ring(p, 20.0, 180.0 * depth, Color.WHITE, 10.0, 0.35)
				_vfx.burst(p + Vector2(0, 30), Color("#C9A27A"), 20, 360.0, 0.6, 0.55, true)
				_add_trauma(0.14)
			_vfx.burst(p, col, 10, 300.0, 0.4, 0.5)
		"claw":
			for k in 3:
				_fx.slash(p + Vector2(-16 + 16 * k, 0) * depth, 0.9, 60.0 * depth, col, 10.0, 0.22, 0.03 * k)
			_vfx.burst(p, col, 12, 380.0, 0.35, 0.45)
		"ice":
			if first:
				_fx.orb(from, p, col, 0.14)
				_fx.ring(p, 8.0, 100.0 * depth, col, 10.0, 0.4, 0.12)
			_fx.burst(p, col, 10, 300.0, 7.0, 0.5, 300.0, "sq", 0.12)
			_vfx.burst(p, Color.WHITE, 8, 240.0, 0.4, 0.35, true, 0.12)
		"tongue":
			if first:
				_fx.arrow(from, p, col, 0.12)
			_vfx.burst(p, col, 8, 260.0, 0.3, 0.4)
		"splash":
			if first:
				_fx.orb(from, p, col, 0.16)
				_fx.wave(p + Vector2(0, 20), 130.0 * depth, col, 10.0, 0.4, 0.14)
			_vfx.burst(p, col, 12, 320.0, 0.45, 0.4, true, 0.14)
		"dive":
			if first:
				_fx.meteor(p + Vector2(randf_range(-60, 60), -320), p, col, 0.24)
			_vfx.burst(p, col, 8, 300.0, 0.35, 0.4, false, 0.24)


## 벌레가 맞았을 때. 평소엔 작게, 특성·치명타일 때만 크게 - 그래야 '강한 한 방' 이 눈에 띈다.
func _hit_fx(e: Dictionary, p: Vector2) -> void:
	var dmg := int(e["dmg"])
	var eff := String(e.get("eff", ""))
	var crit := bool(e.get("crit", false))
	var legend := String(e.get("by_rarity", "")) == "legend"
	if crit:
		_vfx.burst(p, IdleUi.GOLD, 22, 460.0, 0.6, 0.55)
		_fx.slash(p, randf_range(-0.6, 0.6), 70.0, Color("#FFF3B0"), 18.0, 0.22)
		_fx.ring(p, 10.0, 120.0, IdleUi.GOLD, 10.0, 0.35)
		_fx.text(p + Vector2(0, -40), "치명타! %s" % _num(dmg), IdleUi.GOLD, 40, 0.9, 0.0, 70.0)
		_add_trauma(0.25)
		_hitstop(0.045)
		AudioManager.battle_hit()
		return
	if eff == "massive":
		var c := Color("#FF7AD9")
		_vfx.burst(p, c, 16, 380.0, 0.5, 0.5)
		_fx.ring(p, 8.0, 90.0, c, 8.0, 0.3)
		_fx.text(p + Vector2(randf_range(-16, 16), -30), "굉장! %s" % _num(dmg), c, 32, 0.8, 0.0, 55.0)
		_add_trauma(0.12)
		return
	if eff == "strong":
		_vfx.burst(p, Color("#9CF0A0"), 9, 280.0, 0.4, 0.4)
		_fx.text(p + Vector2(randf_range(-16, 16), -24), _num(dmg), Color("#9CF0A0"), 28, 0.7, 0.0, 45.0)
		return
	_vfx.burst(p, Color("#FFE7B0") if not legend else IdleUi.GOLD, 7 if not legend else 12, 260.0, 0.35, 0.35)
	# 숫자는 맞을 때마다 - 세게 맞을수록 크게
	var fs := clampi(22 + int(sqrt(float(dmg)) * 0.6), 22, 44)
	_fx.text(p + Vector2(randf_range(-20, 20), -24), _num(dmg), Color("#FFF27A") if not legend else Color("#FFB84A"), fs, 0.75, 0.0, 46.0)


func _cannon_fx() -> void:
	var base := Vector2(size.x * 0.5, _field.y_front + 20.0)
	var reach := _field.to_screen(LaneData.CANNON_REACH, 0.0)
	_flash(0.45)
	_add_trauma(0.7)
	_hitstop(0.06)
	_fx.pillar(base, Color("#9FD8FF"), 0.7)
	_fx.rays(base, IdleUi.GOLD, 16, 40.0, 320.0, 0.35)
	_fx.ring(base, 20.0, 360.0, Color.WHITE, 16.0, 0.45)
	_banner_show("꿈 대포 발사!", IdleUi.GOLD)
	for i in 12:
		var t2 := float(i) / 11.0
		var q := base.lerp(reach, t2)
		_fx.burst(q, IdleUi.GOLD, 8, 420.0, 8.0, 0.5, 400.0, "star", t2 * 0.2)
	for i in 8:
		var t := float(i) / 7.0
		var p := base.lerp(reach, t)
		_fx.ring(p, 10.0, 120.0 * (1.0 - t * 0.5), Color("#BFEFFF"), 10.0, 0.4, t * 0.15)
		_vfx.burst(p, Color("#BFEFFF"), 6, 300.0, 0.5, 0.45, false, t * 0.15)
	AudioManager.battle_hit()


# ── 끝 ───────────────────────────────────────────────────────────────

func _end_battle(res: String) -> void:
	_ended = true
	Engine.time_scale = 1.0
	var win := res == "win"
	_won = win
	var r := {}
	if win:
		r = LaneState.on_win(stage_n)
		_flash(0.5)
		_add_trauma(1.0)
		var np := Vector2(size.x * 0.5, _field.y_far - 30.0)
		_vfx.burst(np, Color("#FFD27A"), 40, 600.0, 1.2, 0.8)
		_fx.ring(np, 20.0, 400.0, IdleUi.GOLD, 20.0, 0.8)
		AudioManager.souvenir_get()
	else:
		# 응원은 진짜로 싸우다 진 판에만 - 바로 후퇴를 눌러 쌓지 못하게
		if battle.result == "lose" or _battle_t >= CHEER_MIN_FIGHT:
			LaneState.on_lose(stage_n)
		AudioManager.battle_defeat()
	LaneState.save(int(Time.get_unix_time_from_system()))
	_later(1.0 if win else 0.6, func() -> void: _show_result(win, r))


func _show_result(win: bool, r: Dictionary) -> void:
	_result = Control.new()
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.size = size
	_hud.add_child(_result)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.03, 0.1, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.size = size
	_result.add_child(dim)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", IdleUi.panel_style())
	_result.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var t := IdleUi.label("승리!" if win else "후퇴…", 64, IdleUi.GOLD if win else IdleUi.SUB, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_center(IdleUi.label(LaneData.stage_label(stage_n), 26, IdleUi.CREAM)))
	if win:
		v.add_child(_center(IdleUi.label("✦ 꿈조각 +%s" % _num(int(r["xp"])), 30, IdleUi.GOLD)))
		if int(r["stars"]) > 0:
			v.add_child(_center(IdleUi.label("★ 꿈별 +%d" % int(r["stars"]), 28, Color("#9FD8FF"))))
		if int(r.get("tickets", 0)) > 0:
			v.add_child(_center(IdleUi.label("뽑기 티켓 +%d장" % int(r["tickets"]), 28, IdleUi.GOLD)))
		var tr: Dictionary = r.get("treasure", {})
		if not tr.is_empty():
			var tre: Dictionary = LaneData.TREASURES[int(tr["zone"])][int(tr["idx"])]
			var g := int(tr["grade"])
			var trow := HBoxContainer.new()
			trow.alignment = BoxContainer.ALIGNMENT_CENTER
			trow.add_theme_constant_override("separation", 8)
			v.add_child(trow)
			trow.add_child(_icon(String(tre["icon"]), Color(tre["col"]), 56.0))
			var msg := "보물! %s %s" % [String(LaneData.GRADE_NAME[g]), String(tre["name"])]
			if not bool(tr["up"]):
				msg += " (이미 더 좋은 걸 가졌어요)"
			trow.add_child(IdleUi.label(msg, 26, Color(LaneData.GRADE_COL[g]) if bool(tr["up"]) else IdleUi.SUB))
		if String(r.get("acc", "")) != "":
			var ad: Dictionary = LaneData.ACCESSORIES[String(r["acc"])]
			var arow := HBoxContainer.new()
			arow.alignment = BoxContainer.ALIGNMENT_CENTER
			arow.add_theme_constant_override("separation", 8)
			v.add_child(arow)
			arow.add_child(_icon(String(ad["icon"]), Color(ad["col"]), 56.0))
			arow.add_child(IdleUi.label("장신구! %s" % String(ad["name"]), 28, IdleUi.GOLD))
		for id in r.get("new_units", []):
			v.add_child(_center(IdleUi.label("새 친구! %s 합류" % String(LaneData.UNITS[id]["name"]), 28, IdleUi.GREEN)))
	else:
		if LaneState.cheer_for(stage_n) > 0.0:
			v.add_child(_center(IdleUi.label("다시 도전하면 응원을 받아 +%d%% 강해져요" % int(LaneState.cheer_for(stage_n)), 24,
				IdleUi.LAV_DK)))
		v.add_child(_center(IdleUi.label("레벨업 · 장신구 · 편성을 바꿔 봐도 좋아요", 20, IdleUi.SUB)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var home := IdleUi.button("홈으로", 28)
	home.custom_minimum_size = Vector2(240, 90)
	home.pressed.connect(_show_home)
	_result_home = home
	row.add_child(home)
	var next := IdleUi.button("다음 판 ▶" if win else "다시 ▶", 28, "gold")
	next.custom_minimum_size = Vector2(240, 90)
	var nn := mini(stage_n + 1, LaneData.STAGE_MAX) if win else stage_n
	next.pressed.connect(func() -> void:
		_world.queue_free()
		_world = null
		_start_battle(nn))
	row.add_child(next)
	card.reset_size()
	var cs := card.get_combined_minimum_size()
	card.position = (size - cs) * 0.5
	card.scale = Vector2(0.8, 0.8)
	card.pivot_offset = cs * 0.5
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if LaneState.tut == 2 and win:
		_later(0.6, func() -> void:
			_tut.point(_result_home, "이겼어요! 홈으로 가서 친구들을 키워 봐요", _tut_to_home))


func _tut_to_home() -> void:
	LaneState.tut = 3
	LaneState.save()
	_later(0.5, _tut_home_guide.bind(0))


func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# ── 처음 안내 (한 걸음씩) ───────────────────────────────────────────────

func _tut_skip() -> void:
	LaneState.tut = 99
	LaneState.save()
	_tut.visible = false
	_tut_pause = false
	_tut_after_gacha = Callable()


## 홈 첫 안내: 0 환영 · 1 이야기 · 2 출전.
func _tut_home_intro(i := 0) -> void:
	if mode != "home":
		return
	match i:
		0:
			_tut.point(null, "쿼카 군단에 온 걸 환영해요!", _tut_home_intro.bind(1))
		1:
			_tut.point(null, "벌레들이 꿈결을 갉아먹고 있어요. 함께 막아 봐요", _tut_home_intro.bind(2))
		2:
			_tut.point(_home.get_node("Go") as Control, "출전을 눌러 첫 싸움을 해 봐요", func() -> void:
				LaneState.tut = 1
				LaneState.save())


## 첫 싸움 안내. 말풍선이 떠 있는 동안은 싸움이 멈추고, 단추를 누르면 몇 초 흘려 보여 준다.
func _tut_battle_guide(i := 0) -> void:
	if mode != "battle" or _ended or LaneState.tut != 1:
		_tut_pause = false
		return
	_tut_pause = true
	match i:
		0:
			_tut.point(null, "위에서 벌레가 내려와요. 아래 우리 성을 지켜요!", _tut_battle_guide.bind(1))
		1:
			battle.wallet = maxf(battle.wallet, 60.0)
			_tut.point(_unit_btns.get("tiny"), "꼬마 쿼카를 눌러 불러 보세요", _tut_run.bind(2.5, 2))
		2:
			battle.wallet = maxf(battle.wallet, 110.0)
			_tut.point(_unit_btns.get("shield"), "방패 쿼카도 불러요. 튼튼한 벽이에요", _tut_run.bind(3.0, 3))
		3:
			battle.wallet = maxf(battle.wallet, float(battle.worker_cost()) + 5.0)
			_tut.point(_worker_btn, "수입을 올리면 꿈빛이 더 빨리 차요", _tut_run.bind(3.5, 4))
		4:
			battle.cannon = LaneData.CANNON_CHARGE
			_tut.point(_cannon_btn, "꿈 대포가 찼어요! 눌러서 쏴요", _tut_run.bind(2.0, 5))
		5:
			_tut.point(_auto_btn, "자동 소환을 켜면 알아서 불러 줘요", _tut_battle_guide.bind(6))
		6:
			_tut.point(null, "이제 직접 해 봐요. 벌레 둥지를 부수면 이겨요!", func() -> void:
				LaneState.tut = 2
				LaneState.save()
				_tut_pause = false)


## 안내 사이에 싸움을 잠깐 흘려 본다 (방금 한 일이 어떻게 되는지 보이게).
func _tut_run(secs: float, next: int) -> void:
	_tut_pause = false
	_later(secs, _tut_battle_guide.bind(next))


## 홈 키우기 안내: 동물 → 레벨 업 → 뽑기 → (캡슐) → 편성 → 콤보 → 출전.
func _tut_home_guide(i := 0) -> void:
	if mode != "home" or LaneState.tut != 3:
		return
	match i:
		0:
			_tut.point(_home.get_node("TabBar/Tabs/Tab_units") as Control, "동물 탭을 눌러 보세요", _tut_later.bind(1))
		1:
			_tut.point(_home.find_child("Lv_tiny", true, false) as Control, "꿈조각으로 레벨 업! 더 튼튼해져요",
				_tut_later.bind(2))
		2:
			_tut.point(_home.get_node("TabBar/Tabs/Tab_gacha") as Control, "이번엔 뽑기 탭이에요", _tut_later.bind(3))
		3:
			_tut_after_gacha = _tut_home_guide.bind(4)
			_tut.point(_home.find_child("PullOne", true, false) as Control, "선물 티켓으로 새 친구를 뽑아 봐요!", Callable())
		4:
			_tut.point(_home.get_node("TabBar/Tabs/Tab_lineup") as Control, "새 친구는 편성에 들어가요. 편성을 볼까요?",
				_tut_later.bind(5))
		5:
			_tut.point(null, "같이 편성하면 힘이 세지는 콤보도 있어요", _tut_home_guide.bind(6))
		6:
			_tut.point(_home.get_node("Go") as Control, "준비 끝! 출전해서 다음 판으로 가요", func() -> void:
				LaneState.tut = 99
				LaneState.save()
				_toast("이제 혼자서도 할 수 있어요! 화이팅"))


## 탭을 바꾼 뒤 화면이 다시 그려질 때까지 잠깐 기다렸다가 다음 단계.
func _tut_later(i: int) -> void:
	_later(0.35, _tut_home_guide.bind(i))


# ── 도우미 ───────────────────────────────────────────────────────────

func _add_trauma(a: float) -> void:
	_trauma = clampf(_trauma + a * (0.25 if _calm else 1.0), 0.0, 1.0)


func _hitstop(d: float) -> void:
	if _calm:
		return
	Engine.time_scale = 0.06
	get_tree().create_timer(d, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _flash(a: float) -> void:
	if _flash_rect != null:
		_flash_rect.color = Color(1, 1, 1, maxf(_flash_rect.color.a, a * (0.3 if _calm else 1.0)))


func _later(d: float, f: Callable) -> void:
	if d <= 0.0:
		f.call_deferred()
		return
	create_tween().tween_callback(f).set_delay(d)


func _shake_ctrl(c: Control) -> void:
	var x := c.position.x
	var tw := create_tween()
	for i in 4:
		tw.tween_property(c, "position:x", x + (8.0 if i % 2 == 0 else -8.0), 0.035)
	tw.tween_property(c, "position:x", x, 0.035)


func _toast(t: String) -> void:
	_toast_lbl.text = t
	# 폭을 붙잡아 둔다 - 안 그러면 글씨가 한 글자씩 세로로 늘어선다
	_toast_box.custom_minimum_size = Vector2(size.x - 60, 0)
	_toast_box.size = Vector2(size.x - 60, 0)
	_toast_box.reset_size()
	_toast_box.position = Vector2(30, 96 if mode == "home" else 90)
	_toast_box.modulate.a = 1.0
	move_child(_toast_box, get_child_count() - 1)
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(_toast_box, "modulate:a", 0.0, 0.5)


func _banner_show(t: String, col: Color) -> void:
	_banner.text = t
	_banner.add_theme_color_override("font_color", col)
	_banner.modulate.a = 1.0
	move_child(_banner, get_child_count() - 1)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(1.4, 1.4)
	var tw := create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)


static func _num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out
