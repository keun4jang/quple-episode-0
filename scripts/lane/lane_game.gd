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
## 빨리 감기 배속 - 표는 LaneData.SPEEDS (불러올 때 단계를 자르는 LaneState 와 같은 표를 본다).
const SPEEDS := LaneData.SPEEDS


static func _speed() -> float:
	return float(SPEEDS[clampi(LaneState.speed_lv, 0, SPEEDS.size() - 1)])
const FX_PIX := 2
## 공격 모양 - 유닛마다 다르게 보여야 누가 무얼 하는지 안다. [모양, 색]
## slash 베기 · pierce 찌르기 · smash 내리찍기(충격파) · shot 던지기(날아감) · magic 마법 구슬 · quake 땅울림 ·
## claw 세 갈래 할퀴기 · ice 얼음 · tongue 혀 · dive 하늘에서 내리꽂기 · peck 쪼기 · splash 물보라 · bonk 콩 박기
## 바주카포 포탄이 성에서 둥지까지 날아가는 시간 (초).
const CANNON_FLY := 0.55
## 이 사거리 이하는 근접 - 상대에게 덤벼든다.
const MELEE_RANGE := 230.0
## 쏘거나 던지는 공격 (덤벼들지 않는다).
const RANGED_FX := ["shot", "magic", "ice", "tongue", "splash", "dive"]
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
const ROLE_COL := {"벽": "#8FB5FF", "근접": "#FF9F7A", "범위": "#FF9FB0", "돌격": "#7FE0FF", "원거리": "#9CE07A",
	"마법": "#C58CFF", "거대": "#E0A060"}
## 후퇴해도 이만큼(초) 싸웠으면 다시 도전 응원을 받는다.
const CHEER_MIN_FIGHT := 60.0
## 우리 성 앞(길의 0) 화면 높이 - 위 단추 줄(72) 아래로 작게 그린 망루가 들어가는 자리.
const FORT_Y := 250.0
## 배경 그림 위 길의 처음·끝 (그림 높이 비율). tools/art/make_layout.py 의 ROAD_TOP·ROAD_BOT 와 맞춘다.
const ART_ROAD := Vector2(0.2, 0.8)
var _art_bg: TextureRect
var _fort_spr: Sprite2D
var _nest_spr: Sprite2D
## 그림 모델로 만든 그림의 픽셀 한 칸 = 화면 2점.
const ART_PX := 2.0


## 성·둥지 그림 자리 - 성은 밑동이 길 시작, 둥지는 밑동이 길 끝. 맞으면 살짝 흔들린다.
func _place_art_props() -> void:
	if _fort_spr == null or _field == null:
		return
	var fs := _fort_spr.texture.get_size() * ART_PX
	var fp := _field.fort_pos()
	_fort_spr.position = (Vector2(fp.x - fs.x * 0.5 + randf_range(-1, 1) * _field.shake_our, fp.y - fs.y + 24.0)).round()
	var ns := _nest_spr.texture.get_size() * ART_PX
	var np := _field.nest_pos()
	_nest_spr.position = (Vector2(np.x - ns.x * 0.5 + randf_range(-1, 1) * _field.shake_nest, np.y - ns.y + 6.0)).round()


## 시트의 앞모습 첫 칸 - 칸 위쪽의 무기 여유(칸 높이 - 칸 폭)는 빼고 몸만.
static func _face_region(tex: Texture2D, col := 0) -> Rect2:
	var w := tex.get_width() / 4.0
	var h := tex.get_height() / 3.0
	var pad := maxf(0.0, h - w)
	return Rect2(col * w, pad, w, h - pad)


## 버튼에 들어갈 짧은 이름 ("도토리 다람쥐" → "다람쥐").
static func _short_name(id: String) -> String:
	var n := LaneData.unit_name(id, LaneState.level_of(id))
	if n.length() <= 6:
		return n
	# 진화 쿼카는 꾸밈말이 그 친구다 ("산만한 쿼카" → 산만한). 예전엔 마지막 낱말만 남겨 전부 "쿼카"가 됐다.
	if n.ends_with(" 쿼카"):
		return n.trim_suffix(" 쿼카")
	var parts := n.split(" ")
	return parts[parts.size() - 1]


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


## 흰 카드 위의 맨(테두리 없는) 분홍·파랑 글씨. 밝은 색을 그냥 넘기면 IdleUi.readable() 이
## 밤색·올리브로 어둡게 바꿔 버려서, 팔레트 안의 진한 색을 정해 둔다.
const PINK_TXT := Color("#B4507A")
const STAR_TXT := Color("#2F6CB0")

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
var _swing_to: Dictionary = {}  ## uid → 그때 노린 상대 uid (-1 = 성·둥지) - 근접은 그 자리까지 덤벼든다
var _hit_at: Dictionary = {}    ## uid → 마지막으로 맞은 때 (실제 시간 _t) - 살짝 밀린다
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
## 쓰러진 친구·벌레의 그림 (uid → 액터). 막타의 늦게 그리는 맞음(근접 0.07초·바주카 포탄)과
## 같은 틱에 뒤따르는 스킬 효과가 _actor_of 에서 지워진 뒤에도 그 자리를 찾게 한다.
var _dying: Dictionary = {}
var _hit_due: Dictionary = {}      ## uid → 늦게 그리는 맞음이 뜨는 때 (실제 시간 _t) - 쓰러짐은 그 뒤에 그린다
var _cannon_land_t := -99.0        ## 마지막 바주카 포탄이 닿는 때 (실제 시간 _t) - 승리 폭발은 그 뒤에
var _stop_until := 0.0             ## hitstop 이 끝나는 때 (실제 시계, 초) - 겹쳐 걸려도 가장 늦은 것까지
var _stop_id := 0                  ## 마지막으로 건 hitstop 번호 - 그 타이머만 time_scale 을 되돌린다
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
var _cutin_t := -99.0      ## 마지막 스킬 컷인 때 (실제 시간)
var _ended := false
var _won := false

# 홈
var _home: Control
var _home_body: VBoxContainer
var _home_tab := "map"
## 지도에서 보고 있는 장 (0 = 1장). -1 이면 다음 판이 있는 장.
var _map_ch := -1
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
	# 안드로이드 뒤로가기가 close_panel() 을 부른다 (back_handler.gd)
	add_to_group("idle_game")
	if not LaneState.load_save():
		LaneState.reset()
	AudioManager.play_bgm("home")
	_build_home()
	# 알림은 알약 모양 판 위에 - 글씨가 아래 화면과 겹쳐 지저분해 보이지 않게
	_toast_box = PanelContainer.new()
	var tsb := IdleUi.box(Color.WHITE, IdleUi.LAV, 26, 4, 14)
	_toast_box.add_theme_stylebox_override("panel", tsb)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.modulate.a = 0.0
	add_child(_toast_box)
	_toast_lbl = IdleUi.label("", 26, IdleUi.CREAM)
	_toast_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
		_toast("쉬는 동안 쿼카들이 행복 조각 %s개를 모았어요" % _num(int(r["xp"])))
	var old := LaneState.migrate_from_idle()
	var gift := LaneState.claim_daily(_local_now())
	if not LaneState.seen_intro:
		# 처음 온 사람은 한 걸음씩 안내(`_tut_*`)가 대신 알려 준다
		LaneState.seen_intro = true
	# 처음 안내 중엔 알림을 띄우지 않는다 (선물은 그대로 받는다) - 안내 말풍선과 겹쳐 어수선했다
	var quiet := LaneState.tut != 99
	if quiet:
		pass
	elif not old.is_empty():
		_later(2.8, func() -> void:
			_toast("지난 모험에서 온 선물!  행운별 %s · 티켓 %d장 · 행복 조각 %s" % [_num(int(old["stars"])), int(old["tickets"]),
				_num(int(old["xp"]))]))
	elif not gift.is_empty():
		_toast("매일 선물 %d일째!  티켓 %d장 · 행운별 %d" % [int(gift["streak"]), int(gift["tickets"]), int(gift["stars"])])
	_rng.randomize()
	LaneState.save(int(Time.get_unix_time_from_system()))
	_tut = LaneTutorial.new()
	_tut.add_to_group("modal")
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


## 뒤로가기 (back_handler 가 부른다). 무엇이든 처리했으면 true - false 면 종료 카운터에 쌓인다.
## 맨 위 창부터 하나씩 닫고, 싸움 중에는 아무것도 안 하고 누름만 먹는다(앱이 꺼지지 않게),
## 홈에서는 메인 메뉴로 돌아간다. 앱 종료는 메뉴에서만 일어난다.
func close_panel() -> bool:
	for i in range(get_child_count() - 1, -1, -1):
		var c := get_child(i)
		if c.is_queued_for_deletion():
			continue
		if c == _tut:
			# 안내 말풍선은 닫지 않는다 - 건너뛰기는 버튼으로만. 누름만 먹는다.
			if _tut.visible:
				return true
		elif c is LaneGacha:
			(c as LaneGacha).close()
			return true
		elif String(c.name).begins_with("Evolve"):
			var tw: Tween = c.get_meta("tw") if c.has_meta("tw") else null
			if tw != null and tw.is_valid() and tw.is_running():
				tw.custom_step(60.0)     # 연출 중이면 끝난 모습으로 - 한 번 더 누르면 닫힌다
			else:
				c.queue_free()
			return true
		elif String(c.name).begins_with("Popup"):
			c.queue_free()
			return true
	if mode == "battle":
		if is_instance_valid(_result) and not _result.is_queued_for_deletion() and LaneState.tut != 2:
			_show_home()
		return true
	LaneState.save(int(Time.get_unix_time_from_system()))
	SceneTransition.go_to(MENU_PATH, "normal")
	return true


## 위아래 여백 (화면 점) - 폰의 상태 표시줄·노치·아래 제스처 막대 높이를 읽고, 없어도 최소 PAD_MIN 만큼은 띄운다.
const PAD_TOP_MIN := 28.0
const PAD_BOT_MIN := 24.0


func _insets() -> Vector2:
	var top := PAD_TOP_MIN
	var bot := PAD_BOT_MIN
	var ss := DisplayServer.screen_get_size()
	var sa := DisplayServer.get_display_safe_area()
	if ss.y > 0 and sa.size.y > 0 and sa.size.y < ss.y:
		var k := size.y / float(ss.y)
		top = maxf(top, float(sa.position.y) * k)
		bot = maxf(bot, float(ss.y - sa.end.y) * k)
	return Vector2(top, bot)


func _layout() -> void:
	if _home != null:
		_home.size = size
	if _world != null:
		_world.size = size
		_pix.size = size
		_fx_pix.size = size
		_bg.size = size
		_field.size = size
		# 우리 성이 위(위 단추 줄 밑), 둥지가 아래 - 쿼카가 화면 아래로 걸어와 얼굴이 보인다
		_field.y_front = FORT_Y
		_field.y_far = size.y - 500.0
		if _art_bg != null:
			# 폭에 맞춰 깐다 (폭 720 = 2배). 길은 그림 높이의 ART_ROAD 구간 - 밑그림(make_layout.py)과 같은 비율
			var tex := _art_bg.texture
			var s := size.x / float(tex.get_width())
			_art_bg.position = Vector2.ZERO
			_art_bg.size = Vector2(tex.get_width(), tex.get_height()) * s
			_field.y_front = _art_bg.size.y * ART_ROAD.x
		_flash_rect.size = size
		if _danger != null:
			_danger.size = size
		_hud.size = size
		_layout_hud()
	if _tut != null:
		_tut.top_inset = _insets().x
	_toast_box.position = Vector2(10, 6 + _insets().x)
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
	deco.zone = 8          # 벚꽃 풍경 (홈 분위기: 라벤더 + 벚꽃 분홍)
	deco.ground = 0.24
	_home_pix.get_node("VP").add_child(deco)
	# 위 재화 줄
	var top := HBoxContainer.new()
	top.name = "Top"
	top.add_theme_constant_override("separation", 8)
	_home.add_child(top)
	_xp_lbl = _res_pill(top, "coin", IdleUi.GOLD_DK)
	_star_lbl = _res_pill(top, "star", LaneData.STAR_COL)
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
	var sub := IdleUi.label("벌레들에게서 행복을 지켜요", 22, Color.WHITE, true)
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
	DragScroll.attach(sc)      # 카드·단추 위를 잡고 끌어도 넘어가게
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
	# 진한 라벤더 - 고르지 않은 탭의 흰 글씨가 읽히게 (연한 라벤더 위 흰 글씨는 대비가 2.4:1 밖에 안 됐다)
	var bsb := IdleUi.box(Color(IdleUi.LAV_DK.r, IdleUi.LAV_DK.g, IdleUi.LAV_DK.b, 0.97), IdleUi.LAV, 0, 0, 8)
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
		# 알림 점: 아이콘 오른쪽 위에 흰 테두리 두른 벚꽃 분홍 점 (글자 말고 직접 그린다)
		var dot := Control.new()
		dot.name = "Dot"
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(38.0, 0.0)
		dot.visible = false
		dot.draw.connect(func() -> void:
			dot.draw_circle(Vector2.ZERO, 11.0, Color.WHITE)
			dot.draw_circle(Vector2.ZERO, 8.5, IdleUi.GOLD_DK))
		ic.add_child(dot)
		b.pressed.connect(func() -> void:
			AudioManager.ui_click()
			if _home_tab != String(k[0]):
				# 다른 탭으로 가면 맨 위부터 (앞 탭의 스크롤이 남아 첫 카드가 잘려 보였다)
				sc.scroll_vertical = 0
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
	(b.get_node("V/Icon") as Control).self_modulate = col     # 흰 아이콘에 색을 곱한다 (알림 점은 그대로)
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
		_add_wear(a, String(ids[i]))
		_place_wear(a)


func _layout_home() -> void:
	var w := size.x
	var h := size.y
	_home_pix.size = size
	(_home_pix.get_node("VP/Back") as Control).size = size
	var ins := _insets()
	var top := _home.get_node("Top") as Control
	top.position = Vector2(14, 14 + ins.x)
	top.size = Vector2(w - 28, 64)
	var hero_h := clampf(h * 0.24, 230.0, 380.0)
	(_home.get_node("Title") as Control).position = Vector2(0, 86 + ins.x)
	(_home.get_node("Title") as Control).size = Vector2(w, 76)
	(_home.get_node("Sub") as Control).position = Vector2(0, 156 + ins.x)
	(_home.get_node("Sub") as Control).size = Vector2(w, 32)
	(_home.get_node("Parade") as Node2D).position = Vector2(0, 86.0 + ins.x + hero_h - 6.0)
	# 아래 탭 줄은 화면 끝까지 깔되, 버튼은 아래 여백만큼 올린다
	var tabs_h := 112.0 + ins.y
	var bar := _home.get_node("TabBar") as Control
	bar.position = Vector2(0, h - tabs_h)
	bar.size = Vector2(w, tabs_h)
	var bsb := bar.get_theme_stylebox("panel") as StyleBoxFlat
	if bsb != null:
		bsb.content_margin_bottom = ins.y
	var go := _home.get_node("Go") as Control
	go.position = Vector2(24, h - tabs_h - 16.0 - 108.0)
	go.size = Vector2(w - 48, 108)
	var card := _home.get_node("Card") as Control
	var cy := 86.0 + ins.x + hero_h + 4.0
	card.position = Vector2(14, cy)
	card.size = Vector2(w - 28, go.position.y - 14.0 - cy)


func _show_home() -> void:
	mode = "home"
	Engine.time_scale = 1.0
	if _world != null:
		_world.queue_free()
		_world = null
	_home.visible = true
	AudioManager.play_bgm("home")
	_layout_home()
	_fill_home()
	# 켜 둔 채로 자정이 지났으면 홈으로 돌아올 때 선물
	var g := LaneState.claim_daily(_local_now())
	if not g.is_empty() and LaneState.tut == 99:
		LaneState.save()
		_refresh_home_top()
		_toast("매일 선물 %d일째!  티켓 %d장 · 행운별 %d" % [int(g["streak"]), int(g["tickets"]), int(g["stars"])])


## 기기 시간대의 '지금' (매일 선물이 그 나라 자정에 바뀌게).
static func _local_now() -> int:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	return int(Time.get_unix_time_from_system()) + bias * 60


func _refresh_home_top() -> void:
	_xp_lbl.text = _num(LaneState.xp)
	_star_lbl.text = _num(LaneState.stars)
	_ticket_lbl.text = str(LaneState.tickets)
	var nxt := mini(LaneState.cleared + 1, LaneData.STAGE_MAX)
	if LaneState.cleared >= LaneData.STAGE_MAX:
		(_home.get_node("Go") as Button).text = "▶  다시 출전!   %s" % LaneData.stage_label(nxt)
	else:
		(_home.get_node("Go") as Button).text = "▶  출전!   %s" % LaneData.stage_label(nxt)
	for k in ["map", "units", "lineup", "gacha"]:
		var b := _home.get_node("TabBar/Tabs/Tab_" + k) as Button
		_style_tab(b, _home_tab == k)
	(_home.get_node("TabBar/Tabs/Tab_gacha/V/Icon/Dot") as Control).visible = LaneState.can_pull(1)
	_card_title.text = {"map": "지도 · 판 고르기", "units": "동물 친구들", "lineup": "편성 · 콤보", "gacha": "행복 캡슐 뽑기"}[_home_tab]
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
	# 장 고르기 - 1장을 다 깨야 2장 단추가 열린다
	var next_ch := LaneData.chapter_of(LaneState.cleared + 1)
	var ch := next_ch if _map_ch < 0 else mini(_map_ch, next_ch)
	if LaneState.cleared >= LaneData.CH_STAGES:
		var chrow := HBoxContainer.new()
		chrow.add_theme_constant_override("separation", 12)
		_home_body.add_child(chrow)
		for c in LaneData.CHAPTERS:
			var done_all := LaneState.cleared >= (c + 1) * LaneData.CH_STAGES
			var cb := IdleUi.button("%d장%s" % [c + 1, "  ✓" if done_all else ""], 24, "gold" if c == ch else "plum")
			cb.custom_minimum_size = Vector2(0, 72)
			cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cb.pressed.connect(func() -> void:
				_map_ch = c
				AudioManager.ui_click()
				_fill_home())
			chrow.add_child(cb)
		if ch == 1:
			var note := IdleUi.label("2장: 같은 곳, 더 센 벌레. 처음부터 벌레가 다 섞여 나오고 떼도 커요. 보물은 좋은 등급이 잘 나와요.",
				19, IdleUi.LAV_DK)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_home_body.add_child(note)
	var in_ch := LaneState.cleared - ch * LaneData.CH_STAGES
	var last_zone := clampi(in_ch / LaneData.STAGES_PER_ZONE, 0, LaneData.ZONES.size() - 1)
	# 1번 구역이 맨 위, 지금 도전 중인 구역이 맨 아래 - 열면 그 구역까지 내려 준다
	for zi in range(0, last_zone + 1):
		var z: Dictionary = LaneData.ZONES[zi]
		var card := _card()
		_home_body.add_child(card)
		if zi == last_zone and last_zone > 0:
			_later(0.05, func() -> void:
				if is_instance_valid(card):
					var sc := _home.find_child("Scroll", true, false) as ScrollContainer
					if sc != null:
						sc.ensure_control_visible(card))
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
			var tn := IdleUi.label(String(t["name"]) if g > 0 else "???", 18, IdleUi.CREAM if g > 0 else IdleUi.MUTED)
			tn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(tn)
			var te := IdleUi.label("%s %s" % [String(LaneData.GRADE_NAME[g]), LaneData.bonus_text(String(t["kind"]),
				float(t["per"]) * float(maxi(1, g)))] if g > 0 else LaneData.bonus_text(String(t["kind"]), float(t["per"]) * 3.0) + "까지",
				16, Color(LaneData.GRADE_COL[g]) if g > 0 else IdleUi.MUTED)
			te.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(te)
		var gr := GridContainer.new()
		gr.columns = 5
		gr.add_theme_constant_override("h_separation", 8)
		gr.add_theme_constant_override("v_separation", 8)
		v.add_child(gr)
		for i in range(1, LaneData.STAGES_PER_ZONE + 1):
			var n := LaneData.stage_no(ch, zi, i)
			var open := n <= LaneState.cleared + 1
			var done := n <= LaneState.cleared
			var lbl := ("왕" if i == 10 else str(i)) + (" ✓" if done else "")
			var b := IdleUi.button(lbl, 22, "gold" if n == LaneState.cleared + 1 else "plum")
			b.custom_minimum_size = Vector2(118, 64)
			b.disabled = not open
			b.pressed.connect(_start_battle.bind(n))
			gr.add_child(b)


## 우리 성 강화 카드 (바주카포 카드 아래).
func _fort_card() -> void:
	var lv := LaneState.fort_lv
	var card := _card()
	_home_body.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(96, 96)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.texture = load("res://assets/sprites/lane-fort.png") as Texture2D
	row.add_child(pic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	row.add_child(v)
	v.add_child(IdleUi.label("우리 성  Lv %d" % lv, 26, PINK_TXT))
	v.add_child(IdleUi.label("무너지면 져요 - 튼튼할수록 오래 버텨요", 19, IdleUi.SUB))
	v.add_child(IdleUi.label("체력 %s" % _num(int(round(LaneData.fort_hp(lv)))), 19, IdleUi.CREAM))
	if lv < LaneData.FORT_LV_MAX:
		v.add_child(IdleUi.label("다음: 체력 %s" % _num(int(round(LaneData.fort_hp(lv + 1)))), 18, IdleUi.GREEN))
	var b := IdleUi.button("", 20, "gold")
	b.name = "Lv_fort"
	# 줄 높이만큼 늘어나지 않게 - 설명이 길어도 버튼은 제 크기로
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(150, 76)
	if lv >= LaneData.FORT_LV_MAX:
		b.text = "최고 레벨"
		b.disabled = true
	else:
		b.text = "강화
✦ %s" % _num(LaneData.fort_cost(lv))
		_set_short(b, not LaneState.can_level_fort())
	b.pressed.connect(func() -> void:
		if LaneState.level_fort():
			AudioManager.ui_confirm()
			LaneState.save()
			_toast("우리 성 Lv %d!  체력 %s" % [LaneState.fort_lv, _num(int(round(LaneData.fort_hp(LaneState.fort_lv))))])
			_fill_home()
		elif LaneState.fort_lv < LaneData.FORT_LV_MAX:
			_short_xp(b, LaneData.fort_cost(LaneState.fort_lv)))
	row.add_child(b)


## 바주카포 강화 카드 (동물 탭 맨 위).
func _bazooka_card() -> void:
	var lv := LaneState.bazooka_lv
	var card := _card()
	_home_body.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(_bazooka_icon(96.0))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	row.add_child(v)
	v.add_child(IdleUi.label("바주카포  Lv %d" % lv, 26, PINK_TXT))
	v.add_child(IdleUi.label("둥지까지 날아가 길 위 벌레를 모두 맞혀요", 19, IdleUi.SUB))
	v.add_child(IdleUi.label("피해 x%.2f · 충전 %d초 · 둥지 %.1f%%" % [LaneData.bazooka_dmg_mult(lv),
		int(round(LaneData.bazooka_charge(lv))), LaneData.bazooka_nest(lv) * 100.0], 19, IdleUi.CREAM))
	if lv < LaneData.BAZOOKA_LV_MAX:
		v.add_child(IdleUi.label("다음: 피해 x%.2f · 충전 %d초 · 둥지 %.1f%%" % [LaneData.bazooka_dmg_mult(lv + 1),
			int(round(LaneData.bazooka_charge(lv + 1))), LaneData.bazooka_nest(lv + 1) * 100.0], 18, IdleUi.GREEN))
	var b := IdleUi.button("", 20, "gold")
	b.name = "Lv_bazooka"
	# 줄 높이만큼 늘어나지 않게 - 설명이 길어도 버튼은 제 크기로
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(150, 76)
	if lv >= LaneData.BAZOOKA_LV_MAX:
		b.text = "최고 레벨"
		b.disabled = true
	else:
		b.text = "강화
✦ %s" % _num(LaneData.bazooka_cost(lv))
		_set_short(b, not LaneState.can_level_bazooka())
	b.pressed.connect(func() -> void:
		if LaneState.level_bazooka():
			AudioManager.ui_confirm()
			LaneState.save()
			_toast("바주카포 Lv %d!" % LaneState.bazooka_lv)
			_fill_home()
		elif LaneState.bazooka_lv < LaneData.BAZOOKA_LV_MAX:
			_short_xp(b, LaneData.bazooka_cost(LaneState.bazooka_lv)))
	row.add_child(b)


## 바주카포 그림 (직접 그린다) - 비스듬한 포신 + 손잡이 + 끝의 포탄.
func _bazooka_icon(sz: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz, sz)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var u := sz / 96.0
		c.draw_set_transform(Vector2(sz * 0.5, sz * 0.55), -0.45, Vector2(u, u))
		var ink := Color("#4A2E5E")
		c.draw_rect(Rect2(-40, -12, 70, 24), ink)                       # 테두리
		c.draw_rect(Rect2(-37, -9, 64, 18), Color("#BF94E4"))           # 포신
		c.draw_rect(Rect2(-37, -9, 64, 5), Color("#E2CCF5"))            # 빛
		c.draw_rect(Rect2(26, -15, 12, 30), ink)                        # 포구
		c.draw_rect(Rect2(28, -12, 8, 24), Color("#F7A8C4"))
		c.draw_rect(Rect2(-14, 9, 10, 20), ink)                         # 손잡이
		c.draw_rect(Rect2(-12, 11, 6, 16), Color("#8A6FB8"))
		c.draw_circle(Vector2(48, 0), 9.0, ink)                        # 포탄
		c.draw_circle(Vector2(48, 0), 6.5, Color("#F7A8C4"))
		c.draw_circle(Vector2(46, -2), 2.0, Color.WHITE))
	return c


func _fill_units() -> void:
	_home_body.add_child(IdleUi.label("도감  %d / %d  -  뽑기에서 새 친구를 만나요" % [LaneState.owned_count(),
		LaneData.ALL_ORDER.size()], 24, IdleUi.CREAM))
	_bazooka_card()
	_fort_card()
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
				v.add_child(IdleUi.label("%s까지 깨면 합류해요" % LaneData.stage_label(int(u["unlock"])), 20, IdleUi.MUTED))
			else:
				v.add_child(IdleUi.label("???  %s %s" % ["★".repeat(int(LaneData.RARITY_STARS[rr])),
					String(LaneData.RARITY_NAME[rr])], 26, LaneData.RARITY_TXT[rr]))
				v.add_child(IdleUi.label("행복 캡슐에서 만나요", 20, IdleUi.MUTED))
			continue
		var lv := LaneState.level_of(String(id))
		var s := LaneState.unit_stats(String(id))
		var title := "%s  Lv %d" % [LaneData.unit_name(String(id), lv), lv]
		if rr != "base":
			title = "★".repeat(int(LaneData.RARITY_STARS[rr])) + " " + title
		v.add_child(IdleUi.label(title, 26, LaneData.RARITY_TXT[rr] if rr != "base" else
			(PINK_TXT if LaneState.is_evolved(String(id)) else IdleUi.CREAM)))
		# 줄마다 한 가지만: 역할 / 특성 / 스킬 이름 / 스킬 설명 / 능력치 / 진화
		v.add_child(IdleUi.label("[%s] %s" % [role_of(String(id)), String(u["role"])], 20, IdleUi.SUB))
		var tt := LaneData.trait_text(String(id))
		if tt != "":
			v.add_child(IdleUi.label(tt, 20, IdleUi.GREEN))
		v.add_child(IdleUi.label("스킬  " + String(LaneData.SKILLS[id]["name"]), 21,
			Color(String(LaneData.SKILLS[id]["col"]))))
		v.add_child(IdleUi.label(LaneData.skill_desc(String(id)), 18, IdleUi.SUB))
		v.add_child(IdleUi.label("체력 %s · 공격 %s · 웃음 %d" % [_num(int(s["hp"])), _num(int(s["atk"])),
			int(u["cost"])], 19, IdleUi.CREAM))
		if LaneState.is_evolved(String(id)):
			v.add_child(IdleUi.label("진화 완료", 18, PINK_TXT))
		elif lv < LaneData.EVOLVE_LV:
			v.add_child(IdleUi.label("Lv %d에 진화할 수 있어요" % LaneData.EVOLVE_LV, 18, PINK_TXT))
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
		# 줄 높이만큼 늘어나지 않게 - 설명이 길어도 버튼은 제 크기로
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.custom_minimum_size = Vector2(150, 76)
		if LaneState.evolve_ready(String(id)):
			b.text = "진화!\n✦ %s" % _num(LaneData.evolve_cost(String(id)))
			_set_short(b, not LaneState.can_evolve(String(id)))
			b.custom_minimum_size = Vector2(150, 86)
		elif lv >= LaneData.UNIT_LV_MAX:
			b.text = "최고 레벨"
			b.disabled = true
		else:
			b.text = "레벨 업\n✦ %s" % _num(LaneData.level_cost(String(id), lv))
			_set_short(b, not LaneState.can_level(String(id)))
		b.pressed.connect(func() -> void:
			if LaneState.evolve_ready(String(id)):
				if LaneState.evolve(String(id)):
					LaneState.save()
					_fill_home()
					_evolve_show(String(id))
				else:
					_short_xp(b, LaneData.evolve_cost(String(id)))
				return
			if LaneState.level_up(String(id)):
				AudioManager.ui_confirm()
				LaneState.save()
				if LaneState.evolve_ready(String(id)):
					_toast("%s, 이제 진화할 수 있어요!" % LaneData.unit_name(String(id), 0))
				_fill_home()
			elif LaneState.level_of(String(id)) < LaneState.level_cap(String(id)):
				_short_xp(b, LaneData.level_cost(String(id), LaneState.level_of(String(id)))))
		row.add_child(b)
		# 긴 설명은 줄을 바꿔 버튼을 밀어내지 않게
		for c in v.get_children():
			if c is Label:
				(c as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				(c as Label).custom_minimum_size.x = 10


## 진화 연출: 어두워지고 → 옛 모습이 떨며 빛에 휩싸이고 → 번쩍 → 커진 새 모습이 튀어나오며 빛살이 돈다.
func _evolve_show(id: String) -> void:
	var lay := Control.new()
	lay.name = "Evolve"
	lay.set_anchors_preset(Control.PRESET_FULL_RECT)
	lay.mouse_filter = Control.MOUSE_FILTER_STOP
	lay.add_to_group("modal")
	add_child(lay)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.04, 0.14, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(dim)
	var rays := EvoRays.new()
	rays.col = Color(String(LaneData.SKILLS[id]["col"])) if LaneData.SKILLS.has(id) else IdleUi.GOLD
	rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.modulate.a = 0.0
	lay.add_child(rays)
	var c := size * Vector2(0.5, 0.42)
	rays.center = c
	# 옛 모습 (진화 전 그림)
	var old := TextureRect.new()
	old.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	old.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	old.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var otex := load(LaneData.sheet_path(id, 1).replace("-2.png", ".png")) as Texture2D
	if otex != null:
		var oa := AtlasTexture.new()
		oa.atlas = otex
		oa.region = _face_region(otex)
		old.texture = oa
	old.size = Vector2(200, 200)
	old.position = c - old.size * 0.5
	old.pivot_offset = old.size * 0.5
	old.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(old)
	var neu := _portrait(id, 280.0)
	neu.position = c - neu.size * 0.5
	neu.pivot_offset = neu.size * 0.5
	neu.scale = Vector2(0.2, 0.2)
	neu.modulate.a = 0.0
	lay.add_child(neu)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(flash)
	var title := IdleUi.label("진화!", 84, IdleUi.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(size.x, 110)
	title.position = Vector2(0, c.y - 300)
	title.modulate.a = 0.0
	lay.add_child(title)
	var nm := IdleUi.label(LaneData.unit_name(id, 0), 40, Color.WHITE, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.size = Vector2(size.x, 60)
	nm.position = Vector2(0, c.y + 170)
	nm.modulate.a = 0.0
	lay.add_child(nm)
	var info := IdleUi.label("체력·공격 ×%s · 스킬이 더 자주 나와요\n레벨을 %d까지 올릴 수 있어요" % [str(LaneData.EVOLVE_ATK),
		LaneData.UNIT_LV_MAX], 24, IdleUi.INK, true)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.size = Vector2(size.x, 80)
	info.position = Vector2(0, c.y + 236)
	info.modulate.a = 0.0
	lay.add_child(info)
	var hint := IdleUi.label("화면을 눌러 닫아요", 22, IdleUi.LAV_LT, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(size.x, 40)
	hint.position = Vector2(0, size.y - 160)
	hint.modulate.a = 0.0
	lay.add_child(hint)
	AudioManager.warm_swell()
	var tw := create_tween()
	lay.set_meta("tw", tw)
	tw.tween_property(dim, "color:a", 0.86, 0.3)
	tw.parallel().tween_property(rays, "modulate:a", 0.6, 0.6)
	# 떨며 빛에 휩싸인다
	for i in 10:
		var k := float(i) / 10.0
		tw.tween_property(old, "position:x", c.x - 100.0 + (6.0 + 10.0 * k) * (1.0 if i % 2 == 0 else -1.0), 0.06)
		tw.parallel().tween_property(old, "modulate", Color(1.0 + k * 2.0, 1.0 + k * 2.0, 1.0 + k * 2.0), 0.06)
	tw.tween_callback(func() -> void:
		flash.color.a = 1.0
		old.visible = false
		rays.burst = 1.0
		AudioManager.souvenir_get())
	tw.tween_property(flash, "color:a", 0.0, 0.5)
	tw.parallel().tween_property(neu, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(neu, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(rays, "modulate:a", 1.0, 0.3)
	tw.tween_property(title, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(nm, "modulate:a", 1.0, 0.3)
	tw.tween_property(info, "modulate:a", 1.0, 0.3)
	tw.tween_property(hint, "modulate:a", 1.0, 0.3)
	lay.gui_input.connect(func(ev: InputEvent) -> void:
		var tap: bool = (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)
		if tap and hint.modulate.a > 0.5:
			var tw2 := create_tween()
			tw2.tween_property(lay, "modulate:a", 0.0, 0.25)
			tw2.tween_callback(lay.queue_free))


## 진화 연출 뒤에 도는 빛살 + 반짝이 (그림 파일 없이).
class EvoRays extends Control:
	var col := Color.WHITE
	var center := Vector2.ZERO
	var burst := 0.0
	var _t := 0.0
	var _sparks: Array = []

	func _process(dt: float) -> void:
		_t += dt
		if burst > 0.0:
			for i in 60:
				var a := randf() * TAU
				_sparks.append({"p": center, "v": Vector2(cos(a), sin(a)) * randf_range(200.0, 900.0), "l": 0.0,
					"m": randf_range(0.6, 1.4), "s": randf_range(6.0, 14.0)})
			burst = 0.0
		for sp in _sparks:
			sp["l"] = float(sp["l"]) + dt
			sp["v"] = (sp["v"] as Vector2) * (1.0 - minf(0.9, 2.0 * dt))
			sp["p"] = (sp["p"] as Vector2) + (sp["v"] as Vector2) * dt
		_sparks = _sparks.filter(func(sp) -> bool: return float(sp["l"]) < float(sp["m"]))
		queue_redraw()

	func _draw() -> void:
		var n := 16
		for i in n:
			var a := _t * 0.6 + TAU * float(i) / float(n)
			var w := 0.09
			var r := maxf(size.x, size.y)
			var pts := PackedVector2Array([center, center + Vector2(cos(a - w), sin(a - w)) * r,
				center + Vector2(cos(a + w), sin(a + w)) * r])
			draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.22 if i % 2 == 0 else 0.12))
		draw_circle(center, 150.0 + sin(_t * 4.0) * 10.0, Color(1, 1, 1, 0.12))
		draw_circle(center, 100.0 + sin(_t * 5.0) * 8.0, Color(col.r, col.g, col.b, 0.25))
		for sp in _sparks:
			var k := 1.0 - float(sp["l"]) / float(sp["m"])
			var s := float(sp["s"]) * k
			draw_rect(Rect2((sp["p"] as Vector2) - Vector2(s, s) * 0.5, Vector2(s, s)),
				Color(1, 1, 0.9, k) if randf() < 0.5 else Color(col.r, col.g, col.b, k))


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
		v.add_child(IdleUi.label(("✓ " if on else "") + String(c["name"]), 22, PINK_TXT if on else IdleUi.CREAM))
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
	v.add_child(_center(IdleUi.label("행복 캡슐", 44, IdleUi.GOLD, true)))
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
			LaneData.RARITY_TXT["legend"])
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
		one.text = "1번 뽑기   행운별 %d" % LaneData.GACHA_COST
	_set_short(one, not LaneState.can_pull(1))
	one.name = "PullOne"
	one.pressed.connect(func() -> void:
		if LaneState.can_pull(1):
			_do_pull(1)
		else:
			_short_stars(one, LaneData.GACHA_COST))
	v.add_child(one)
	var ten := IdleUi.button("10번 뽑기   행운별 %d\n특급 이상 1마리 확정" % LaneData.GACHA10_COST, 26, "plum")
	ten.custom_minimum_size = Vector2(0, 110)
	_set_short(ten, not LaneState.can_pull(10))
	ten.pressed.connect(func() -> void:
		if LaneState.can_pull(10):
			_do_pull(10)
		else:
			_short_stars(ten, LaneData.GACHA10_COST))
	v.add_child(ten)
	var how := IdleUi.label("행운별은 판을 처음 깨면 받고(뒤 구역일수록 많이, 우두머리는 티켓도), 다시 깨면 1개, 매일 선물로도 받아요.\n진짜 돈은 쓰지 않아요.",
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
	var tex := load(LaneData.bug_sheet(kind)) as Texture2D
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
	layer.add_to_group("modal")
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.09, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			layer.queue_free())
	layer.add_child(dim)
	var card := PanelContainer.new()
	card.name = "Card"
	card.add_theme_stylebox_override("panel", IdleUi.panel_style())
	card.position = Vector2(24, 140)
	card.size = Vector2(size.x - 48, size.y - 280)
	layer.add_child(card)
	# 내용만큼만 - 텅 빈 창이 화면을 다 먹지 않게 (내용을 채운 뒤에 잰다)
	_later(0.0, func() -> void:
		if not is_instance_valid(card):
			return
		var want: float = (card.get_node("V/Scroll/Body") as Control).get_combined_minimum_size().y + 130.0
		var hh := clampf(want, 260.0, size.y - 280.0)
		card.size = Vector2(size.x - 48, hh)
		card.position = Vector2(24, (size.y - hh) * 0.5))
	var outer := VBoxContainer.new()
	outer.name = "V"
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
	sc.name = "Scroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	IdleUi.style_scroll(sc)
	DragScroll.attach(sc)
	outer.add_child(sc)
	var body := VBoxContainer.new()
	body.name = "Body"
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
	var body := _popup("%s의 장신구" % LaneData.unit_name(unit, LaneState.level_of(unit)))
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
			v.add_child(IdleUi.label("%s 착용 중" % String(LaneData.UNITS[who]["name"]), 18, IdleUi.SUB))
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
		up.disabled = lv >= LaneData.ACC_LV_MAX
		_set_short(up, lv < LaneData.ACC_LV_MAX and not LaneState.can_level_acc(acc))
		up.pressed.connect(func() -> void:
			if LaneState.level_acc(acc):
				LaneState.save()
				AudioManager.ui_confirm()
				_open_acc_picker(unit)
				_refresh_home_top()
			else:
				_short_xp(up, LaneData.acc_level_cost(lv)))
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
		# 2배 아래로 줄이거나 늘리면 픽셀을 그대로 빼면 들쭉날쭉하다 - 그땐 부드럽게
		if sz / maxf(a.region.size.x, a.region.size.y) < 2.0:
			t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	# 판마다 번호(uid)가 1부터 다시 붙는다 - 지난 판의 기록을 다 비워야 한다.
	# (예전엔 `_dead` 가 남아, 지난 판에 쓰러진 번호를 받은 새 친구가 안 그려지다가 갑자기 나타났다)
	_actor_of = {}
	_lat = {}
	_dead = {}
	_ent_of = {}
	_swing_at = {}
	_swing_to = {}
	_hit_at = {}
	_dying = {}
	_hit_due = {}
	_cannon_land_t = -99.0
	_fx_t = {}
	_lunge = {}
	_tut_pause = false
	battle.start(n)
	battle.auto = LaneState.auto_summon
	_build_battle()
	_layout()
	var info := battle.info
	# 구역마다 다른 전투곡, 우두머리는 앞 구역 / 뒤 구역이 다르다
	var zi := int(info["zone"])
	var ch := int(info["chapter"])
	if bool(info["boss"]):
		AudioManager.play_bgm("boss" if zi < 5 and ch == 0 else "boss2")
	else:
		# 2장은 곡 순서를 둘씩 밀어 같은 구역이라도 1장과 다른 곡이 나온다
		AudioManager.play_bgm(String(AudioManager.BATTLE_TRACKS[(zi + ch * 2) % AudioManager.BATTLE_TRACKS.size()]))
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
	# 구역 배경 그림이 있으면 그걸 깐다 (그림 모델로 그려 픽셀로 정리한 것 - tools/art/import_lane_art.py).
	# 픽셀 판(_pix)에 넣으면 1/3 로 줄었다 커져 뭉개지므로, 화면에 바로 정수배로 깐다.
	_art_bg = null
	var bgp := "res://assets/sprites/lane-bg-%d.png" % (int(battle.info["zone"]) + 1)
	if ResourceLoader.exists(bgp):
		_art_bg = TextureRect.new()
		_art_bg.texture = load(bgp)
		_art_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_art_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art_bg.stretch_mode = TextureRect.STRETCH_SCALE
		_art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_world.add_child(_art_bg)
	# 성·둥지 그림 (배경 그림이 있을 때만 - 코드 그림 배경과는 화풍이 안 맞는다)
	_fort_spr = null
	_nest_spr = null
	if _art_bg != null and ResourceLoader.exists("res://assets/sprites/lane-fort.png") \
			and ResourceLoader.exists("res://assets/sprites/lane-nest.png"):
		for k in ["fort", "nest"]:
			var sp := Sprite2D.new()
			sp.texture = load("res://assets/sprites/lane-%s.png" % k)
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.centered = false
			sp.scale = Vector2(ART_PX, ART_PX)
			_world.add_child(sp)
			if k == "fort":
				_fort_spr = sp
			else:
				_nest_spr = sp
	_pix = _pixel_layer()
	_world.add_child(_pix)
	var vp := _pix.get_node("VP")
	_bg = IdleBackdrop.new()
	_bg.zone = int(battle.info["theme"])
	_bg.ground = 0.13
	_bg.visible = _art_bg == null
	vp.add_child(_bg)
	_field = LaneField.new()
	_field.art_bg = _art_bg != null
	_field.art_props = _fort_spr != null
	var th: Dictionary = IdleBackdrop.THEMES[_bg.zone]
	_field.lane_col = Color(th["ground"]).lightened(0.18)
	vp.add_child(_field)
	if int(battle.info["chapter"]) > 0:
		# 2장은 해 질 녘 라벤더빛 - 같은 곳이어도 다른 판인 게 한눈에 보이게
		_bg.modulate = Color(0.86, 0.78, 1.0)
		_field.modulate = Color(0.88, 0.8, 1.0)
		if _art_bg != null:
			_art_bg.modulate = Color(0.86, 0.78, 1.0)
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
	# 3배속에선 효과가 실제 시간당 3배로 쌓인다 - 한꺼번에 떠 있는 수를 묶어 둔다 (안전장치)
	_fx.max_texts = 40
	_vfx.max_nodes = 60
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_flash_rect)
	_danger = Control.new()
	_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_speed_btn.custom_minimum_size = Vector2(132, 60)
	_speed_btn.pressed.connect(func() -> void:
		LaneState.speed_lv = (LaneState.speed_lv + 1) % SPEEDS.size()
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

	# ── 아래 판: [수입] [웃음] [바주카포] / 유닛 버튼 (얼굴·이름·역할·비용)
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
		if _ended:
			return
		if battle.upgrade_worker():
			AudioManager.ui_confirm()
		elif battle.worker_cost() >= 0:
			_shake_ctrl(_worker_btn)
			var need := float(battle.worker_cost()) - battle.wallet
			if need > 0.0:
				_toast("웃음이 모자라요 (✦%d 더 모이면 올려요)" % int(ceil(need))))
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
		if _ended:
			return
		if battle.fire_cannon():
			AudioManager.ui_confirm()
		else:
			_shake_ctrl(_cannon_btn)
			_toast("바주카포를 채우는 중이에요 (%d%%)" % int(battle.cannon / battle.cannon_max * 100.0)))
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
		b.custom_minimum_size = Vector2(0, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_contents = true
		if rr != "base":
			var bsb := IdleUi.box(Color.WHITE, LaneData.RARITY_COL[rr], 22, 4, 6)
			b.add_theme_stylebox_override("normal", bsb)
			b.add_theme_stylebox_override("hover", bsb)
		var col := VBoxContainer.new()
		col.name = "Col"
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 0)
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		# 아래 띠 자리(10)는 비워 둔다 - 비용 글자가 카드 밑에서 잘리고 띠가 숫자를 덮었다
		col.offset_bottom = -10.0
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
		cl.add_theme_font_size_override("font_size", 16)
		cl.add_theme_color_override("font_color", Color("#2E1A4A"))
		chip.add_child(cl)
		col.add_child(chip)
		var pic := _portrait(uid_s, 60.0)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(pic)
		var nm := IdleUi.label(_short_name(uid_s), 19, IdleUi.CREAM)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		col.add_child(nm)
		var cost := IdleUi.label("", 22, IdleUi.GOLD_DK)
		cost.name = "Cost"
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(cost)
		# 웃음이 모이는 띠 (모자랄 때만, 버튼 아래쪽) - 쿨타임과 헷갈리지 않게 따로
		var money := ColorRect.new()
		money.name = "Money"
		money.color = Color(IdleUi.GOLD.r, IdleUi.GOLD.g, IdleUi.GOLD.b, 0.9)
		money.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(money)
		# 쿨타임은 그 친구 버튼에만: 어두운 막 + 남은 초
		# 둥근 카드 밖으로 네모 모서리가 삐져나오지 않게 같은 반지름의 둥근 막
		var cd := Panel.new()
		cd.name = "Cd"
		var cdsb := StyleBoxFlat.new()
		cdsb.bg_color = Color(0.17, 0.1, 0.27, 0.62)
		cdsb.set_corner_radius_all(22)
		cd.add_theme_stylebox_override("panel", cdsb)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cd)
		var cdt := IdleUi.label("", 24, Color.WHITE, true)
		cdt.name = "CdText"
		cdt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cdt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(cdt)
		b.pressed.connect(func() -> void:
			if _ended:
				return
			if battle.summon(uid_s):
				AudioManager.pickup()
			else:
				_shake_ctrl(b)
				var need := float(battle.stats[uid_s]["cost"]) - battle.wallet
				if float(battle.cds.get(uid_s, 0.0)) <= 0.0 and need > 0.0:
					_toast("웃음이 모자라요 (✦%d 더 모이면 불러요)" % int(ceil(need))))
		gr.add_child(b)
		_unit_btns[id] = b
	_refresh_hud_toggles()


func _layout_hud() -> void:
	var w := size.x
	var h := size.y
	var ins := _insets()
	var top := _hud.get_node("Top") as Control
	top.position = Vector2(12, 12 + ins.x)
	top.size = Vector2(w - 24, 60)
	var panel := _hud.get_node("Panel") as Control
	# 유닛 줄 수만큼만 - 빈 판이 화면 아래를 먹지 않게
	var rows := maxi(1, int(ceil(float(battle.lineup.size()) / 5.0)))
	# 카드 높이(150)와 같게 - 예전 134 로 남아 있어 둘째 줄이 판 밖 화면 끝까지 삐져나왔다
	var ph := 28.0 + 92.0 + 10.0 + float(rows) * 150.0 + float(rows - 1) * 8.0 + 14.0
	panel.position = Vector2(8, h - ph - 8.0 - ins.y)
	panel.size = Vector2(w - 16, ph)
	# 효과 층은 판 윗부분까지만 - 큰 고리(바주카·스킬)가 판 아래 여백으로 새어 나왔다
	if _fx_pix != null:
		_fx_pix.size = Vector2(w, panel.position.y + 40.0)
	if _field != null:
		_field.y_far = panel.position.y - 120.0
		if _art_bg != null:
			# 폭에 맞추되, 버튼 판 위까지 빈틈이 없게 (모자라면 조금 더 키우고 양옆을 같이 자른다)
			var tex := _art_bg.texture
			var s := maxf(w / float(tex.get_width()), (panel.position.y + 40.0) / float(tex.get_height()))
			_art_bg.size = Vector2(tex.get_width(), tex.get_height()) * s
			_art_bg.position = Vector2((w - _art_bg.size.x) * 0.5, 0.0)
			_field.y_front = _art_bg.size.y * ART_ROAD.x
			_field.y_far = minf(_field.y_far, _art_bg.size.y * ART_ROAD.y)


func _refresh_hud_toggles() -> void:
	_speed_btn.text = "%d배 %s" % [int(_speed()), "▶".repeat(LaneState.speed_lv + 1)]
	_auto_btn.text = "자동 켜짐" if LaneState.auto_summon else "자동 소환"
	# 켜지면 분홍 버튼으로 (예전엔 초록을 곱해 라벤더가 회색이 돼, 켜진 게 꺼진 것처럼 보였다)
	var ref := IdleUi.button("", 22, "gold" if LaneState.auto_summon else "plum")
	for st in ["normal", "hover", "pressed"]:
		_auto_btn.add_theme_stylebox_override(st, ref.get_theme_stylebox(st))
	for st in ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color"]:
		_auto_btn.add_theme_color_override(st, ref.get_theme_color(st))
	ref.free()


func _process(dt: float) -> void:
	_t += dt
	_save_t += dt
	if _save_t > SAVE_EVERY:
		_save_t = 0.0
		LaneState.save(int(Time.get_unix_time_from_system()))
	if mode == "battle" and _world != null:
		_place_art_props()
	if mode != "battle" or _world == null:
		return
	var rdt := dt / maxf(Engine.time_scale, 0.001)
	_trauma = maxf(0.0, _trauma - rdt * 1.3)
	var sh := _trauma * _trauma
	var st := Time.get_ticks_msec() / 1000.0 * 30.0
	_world.position = Vector2(14.0 * sh * sin(st * 1.1), 10.0 * sh * sin(st * 1.7 + 2.0))
	# 흔들림은 싸움터만 - 단추 판(HUD)은 _world 안에 있어 같이 떨렸다(누르려는 손가락 밑에서 움직임)
	_hud.position = -_world.position
	_flash_rect.color.a = maxf(0.0, _flash_rect.color.a - dt * 2.5)
	if not _ended and not _tut_pause:
		var sdt := minf(dt, 0.25) * _speed()
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
		# 우리 편은 체력이 깎였거나 방금 맞았을 때만 - 몰리면 가득 찬 초록 띠 수십 개가 얼굴을 가렸다
		if e["side"] == "q" and r >= 0.999 and _t - float(_hit_at.get(int(uid), -99.0)) > 2.0:
			continue
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
	_wallet_lbl.text = "웃음 %d / %d" % [int(battle.wallet), battle.wallet_cap()]
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
	# 최고 단계만 막고, 웃음이 모자랄 땐 흐리게만 - 누르면 얼마나 모자란지 알려 준다
	_worker_btn.disabled = wc < 0
	_set_short(_worker_btn, wc >= 0 and not battle.can_worker())
	var ready := battle.cannon_ready()
	_cannon_btn.text = "바주카포!\n누르면 발사" if ready else "바주카포\n충전 %d%%" % int(battle.cannon / battle.cannon_max * 100.0)
	_set_short(_cannon_btn, not ready)
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
		# 친구마다 따로: 쿨타임은 그 버튼에만 막 + 초, 웃음이 모자라면 비용만 빨갛게 + 모이는 띠.
		# (예전엔 웃음이 모자란 버튼도 쿨타임처럼 흐려져서, 하나를 부르면 다른 친구도 쿨타임이 도는 것처럼 보였다)
		var short := battle.wallet < float(cost)
		var cl := b.get_node("Col/Cost") as Label
		cl.text = "✦%d" % cost
		cl.add_theme_color_override("font_color", IdleUi.RED if short else IdleUi.GOLD_DK)
		b.disabled = false
		b.modulate = Color.WHITE
		var cd := b.get_node("Cd") as Panel
		var k := clampf(left / maxf(0.01, float(s2["cd"])), 0.0, 1.0)
		# 막이 아래에서부터 차므로 위 모서리는 가득 찼을 때만 둥글게
		var csb := cd.get_theme_stylebox("panel") as StyleBoxFlat
		var tr := 22 if k > 0.97 else 0
		csb.corner_radius_top_left = tr
		csb.corner_radius_top_right = tr
		cd.size = Vector2(b.size.x, b.size.y * k)
		cd.position = Vector2(0, b.size.y * (1.0 - k))
		# 남은 초는 값 자리에 - 얼굴과 이름을 덮지 않게
		var cdt := b.get_node("CdText") as Label
		cdt.size = Vector2(b.size.x, 30.0)
		cdt.position = Vector2(0.0, b.size.y - 36.0)
		cdt.text = ("%.1f초" % left) if left > 0.0 else ""
		cl.modulate.a = 0.0 if left > 0.0 else 1.0
		var mb := b.get_node("Money") as ColorRect
		var mk := clampf(battle.wallet / maxf(1.0, float(cost)), 0.0, 1.0)
		mb.visible = short and left <= 0.0
		# 카드 맨 아래, 둥근 모서리 안쪽으로 들여서 (비용 글자와 겹치지 않게)
		mb.size = Vector2((b.size.x - 36.0) * mk, 4.0)
		mb.position = Vector2(18.0, b.size.y - 9.0)


# ── 그림 맞추기 ───────────────────────────────────────────────────────

## 맞은 그림 - 번쩍임·공격 모양·숫자.
func _show_hit(e: Dictionary) -> void:
	if _fx == null or not is_instance_valid(_fx):
		return
	_hit_at[int(e["uid"])] = _t
	var a = _actor_any(int(e["uid"]))
	if a != null:
		a.flash = 0.9
		a.flash_col = Color.WHITE if e["side"] == "b" else Color("#FF8080")
		var p: Vector2 = a.position + Vector2(0, -a.body_height() * 0.5)
		if e["side"] == "b":
			if String(e.get("eff", "")) != "skill":
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


func _is_melee(src: Dictionary) -> bool:
	if float(src["range"]) > MELEE_RANGE:
		return false
	return not (src["side"] == "q" and String(FX_STYLE.get(String(src["kind"]), ["slash"])[0]) in RANGED_FX)


## 근접 공격은 노린 상대 바로 앞까지 덤벼든다 (좌우로 흩어져 서 있어서, 앞으로만 찌르면 허공을 쳤다).
## 멀리서 쏘는 친구는 제자리에서 앞으로 살짝 - 쏜 것이 날아가 맞는다. 그림만 움직이고 판정은 그대로다.
func _lunge_vec(e: Dictionary, uid: int, p: Vector2, fwd: float) -> Vector2:
	var small := Vector2(0, fwd * 27.0)
	if float(e["range"]) > MELEE_RANGE:
		return small
	if e["side"] == "q" and String(FX_STYLE.get(String(e["kind"]), ["slash"])[0]) in RANGED_FX:
		return small
	var to := int(_swing_to.get(uid, -2))
	var tp: Vector2
	if to >= 0:
		var ta = _actor_of.get(to)
		if ta == null or not is_instance_valid(ta):
			return small
		tp = ta.position
	elif to == -1:
		tp = _field.nest_pos() if e["side"] == "q" else _field.fort_pos()
	else:
		return small
	var d := tp - p
	var n := d.length()
	if n < 1.0:
		return small
	# 상대 몸에 닿을 만큼만 (겹치지 않게 조금 앞에서 멈춘다)
	return d / n * clampf(n - 26.0, 27.0, 170.0)

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
		# 공격 동작: 웅크림(공격 0.25초 전) → 쭉 뻗으며 덤벼듦 → 돌아옴. 앞쪽 = 쿼카는 아래, 벌레는 위.
		var fwd := 1.0 if e["side"] == "q" else -1.0
		var atk_f := -1
		if e["state"] == "fight":
			# 실제 시간으로 잰다 - 3배속에서도 휘두르는 게 눈에 보이게
			var since := _t - float(_swing_at.get(uid, -99.0))
			var until := float(e["t_atk"]) / _speed()
			# 덤벼듦 한 번(0.37초)이 다음 휘두름 전에 끝나게 - 3배속에서 빠른 친구는 줄여서 세 동작을 다 그린다
			var sw := clampf(float(e["every"]) / _speed() * 0.9 / 0.37, 0.05, 1.0)
			var lunge := 0.0
			if since < 0.08 * sw:
				atk_f = 1
				lunge = since / (0.08 * sw)
				a.squash = Vector2(0.84, 1.2)
			elif since < 0.21 * sw:
				atk_f = 2
				lunge = 1.0
				a.squash = Vector2(0.9, 1.1)
			elif since < 0.37 * sw:
				atk_f = 3
				lunge = 1.0 - (since - 0.21 * sw) / (0.16 * sw)
			elif until <= 0.22:
				atk_f = 0
				lunge = -0.33 * (1.0 - until / 0.22)
				a.squash = Vector2(1.12, 0.88)
			else:
				atk_f = 3
			p += _lunge_vec(e, uid, p, fwd) * lunge
		# 맞으면 뒤로 살짝 밀린다 (실제 시간 - 3배속에서도 눈에 보이게)
		var hs := _t - float(_hit_at.get(uid, -99.0))
		if hs >= 0.0 and hs < 0.12:
			p.y -= fwd * 9.0 * (1.0 - hs / 0.12)
		# 픽셀 격자에 맞춰 놓고, 크기는 원근과 관계없이 한 가지 (도트 규칙: 픽셀 크기는 하나)
		a.position = (p / float(PIX)).round() * float(PIX)
		a.px = LaneData.sheet_px(a.tex.resource_path, a.tex.get_height() / 3.0) if a.tex != null else (UNIT_PX if e["side"] == "q" else BUG_PX)
		_place_wear(a)
		a.walking = e["state"] == "walk"
		if e["side"] == "q":
			# 앞모습으로 걸어오고, 싸울 땐 휘두르고, 밀려나면 아파한다. 이기면 환호.
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
	for uid in _dying.keys():
		if not is_instance_valid(_dying[uid]):
			_dying.erase(uid)


func _make_actor(e: Dictionary) -> IdleActor:
	var a := IdleActor.new()
	var uid := int(e["uid"])
	_lat[uid] = randf_range(-150.0, 150.0)
	if e["side"] == "q":
		a.set_sheet(unit_sheet(String(e["kind"])))
		_add_wear(a, String(e["kind"]))
	else:
		a.set_sheet(LaneData.bug_sheet(String(e["kind"])))
	_actors.add_child(a)
	_actor_of[uid] = a
	return a


## 장신구를 단 친구는 싸움 그림에도 그 장신구를 얹는다 (캐릭터와 같은 픽셀 크기).
func _add_wear(a: IdleActor, kind: String) -> void:
	var acc := String(LaneState.acc_on.get(kind, ""))
	if acc == "" or not LaneData.ACCESSORIES.has(acc):
		return
	var tex := load("res://assets/sprites/lane-wear.png") as Texture2D
	var i := LaneData.ACC_ORDER.find(acc)
	if tex == null or i < 0:
		return
	var sp := Sprite2D.new()
	sp.name = "Wear"
	sp.texture = tex
	sp.region_enabled = true
	sp.region_rect = Rect2(i * 12, 0, 12, 12)
	sp.centered = false
	sp.offset = Vector2(-6, -12)          # 아래 가운데가 붙는 점
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.set_meta("wear", String(LaneData.ACCESSORIES[acc].get("wear", "side")))
	a.add_child(sp)


## 장신구 자리 - 몸 크기에 맞춰 매 프레임 (공격 자세에 따라 몸이 늘고 줄어도 따라간다).
func _place_wear(a: IdleActor) -> void:
	var sp := a.get_node_or_null("Wear") as Sprite2D
	if sp == null:
		return
	var px := a.px
	sp.scale = Vector2(px, px)
	var bh := a.body_height() * a.squash.y
	var bw := a.cell.x * px * a.squash.x
	var p := Vector2.ZERO
	match String(sp.get_meta("wear", "side")):
		"head":
			p = Vector2(0, -bh * 0.84)
		"neck":
			p = Vector2(0, -bh * 0.38)
		"hand":
			p = Vector2(bw * 0.36, -bh * 0.2)
		"feet":
			p = Vector2(-bw * 0.12, 0)
		_:
			p = Vector2(-bw * 0.42, -bh * 0.36)
	sp.position = (p / px).round() * px


## 살아 있는 그림, 없으면 쓰러지는 중인 그림 (막타 맞음·스킬 효과가 그 자리를 찾게).
func _actor_any(uid: int):
	var a = _actor_of.get(uid)
	if a != null and is_instance_valid(a):
		return a
	a = _dying.get(uid)
	if a != null and is_instance_valid(a):
		return a
	return null


func _actor_pos(uid: int) -> Vector2:
	var a = _actor_of.get(uid)
	if a == null or not is_instance_valid(a):
		return Vector2(size.x * 0.5, size.y * 0.5)
	return a.position + Vector2(0, -a.body_height() * 0.5)


# ── 사건 → 연출 ───────────────────────────────────────────────────────

## 쓰러지는 그림 - 녹아 사라짐·보상 글자 (늦게 그리는 막타 맞음이 먼저 뜬 뒤에).
func _die_fx(e: Dictionary, a) -> void:
	if a == null or not is_instance_valid(a) or _fx == null or not is_instance_valid(_fx):
		return
	var p: Vector2 = a.position + Vector2(0, -a.body_height() * 0.5)
	a.dissolve = 0.01
	a.edge_col = Color("#FFE7A0") if e["side"] == "b" else Color("#FFB0C0")
	var wear = a.get_node_or_null("Wear")
	if wear != null:
		wear.queue_free()
	var tw: Tween = a.create_tween()   # 그림에 붙여 판이 풀리면 같이 멈춘다
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
						# 성 앞은 화면 위쪽이라 머리 위 이름이 위 단추 줄(1배·자동) 뒤에 깔렸다 - 그 아래로 막는다
						var np: Vector2 = a.position + Vector2(0, -a.body_height() - 30.0)
						np.y = maxf(np.y, 12.0 + _insets().x + 60.0 + 60.0)
						_fx.text(np, LaneData.unit_name(kid, LaneState.level_of(kid)),
							LaneData.RARITY_COL[rr] if rr != "base" else Color.WHITE, 22, 1.0, 0.0, 30.0)
						if LaneState.is_evolved(kid):
							# 진화한 친구: 금빛 고리 + 솟는 별
							_fx.ring(a.position + Vector2(0, -a.body_height() * 0.5), 10.0, 120.0, IdleUi.GOLD, 10.0, 0.45)
							_fx.burst(a.position, Color("#FFE7A0"), 12, 260.0, 7.0, 0.7, -200.0, "star", 0.0, true)
						if rr == "legend":
							# 전설이 나오면 판 전체가 알아챈다
							_fx.ring(a.position, 20.0, 260.0, LaneData.RARITY_COL["legend"], 14.0, 0.6)
							_vfx.burst(a.position, LaneData.RARITY_COL["legend"], 24, 380.0, 0.9, 0.5, true)
							_flash(0.25)
							_add_trauma(0.35)
							_banner_show("전설 출전! %s" % LaneData.unit_name(String(e["kind"]),
								LaneState.level_of(String(e["kind"]))), LaneData.RARITY_COL["legend"])
							AudioManager.souvenir_get()
						elif rr == "super":
							_fx.ring(a.position, 16.0, 160.0, LaneData.RARITY_COL["super"], 10.0, 0.45)
							_vfx.burst(a.position, LaneData.RARITY_COL["super"], 12, 260.0, 0.6, 0.4, true))
			elif bool(e.get("boss", false)):
				_banner_show("%s 등장!" % String(LaneData.BUGS[String(e["kind"])]["name"]), Color("#FF8A8A"))
				_add_trauma(0.8)
				AudioManager.sky_crack()
		"skill":
			_skill_fx(e)
		"dash":
			_dash_fx(e)
		"heal":
			var ha = _actor_of.get(int(e["uid"]))
			if ha != null and is_instance_valid(ha):
				var hp2: Vector2 = ha.position + Vector2(0, -ha.body_height() * 0.5)
				_fx.text(hp2 + Vector2(randf_range(-12, 12), -20), "+%s" % _num(int(e["amt"])), Color("#7FF0A0"), 28, 0.9, 0.0, 60.0)
				_fx.burst(hp2, Color("#B8FFC8"), 10, 200.0, 7.0, 0.8, -300.0, "star", 0.0, true)
				ha.flash = 0.8
				ha.flash_col = Color("#B8FFC8")
		"swing":
			var a = _actor_of.get(int(e["uid"]))
			if a != null and is_instance_valid(a):
				# 휘두른 때를 적어 두면 `_sync_actors` 가 덤벼드는 동작을 그린다
				_swing_at[int(e["uid"])] = _t
				_swing_to[int(e["uid"])] = int(e.get("to", -1))
		"hit":
			# 근접은 덤벼들어 닿는 때(0.08초 뒤)에 맞는다 - 휘두르자마자 번쩍이면 허공을 친 것처럼 보였다
			var src = _ent_of.get(int(e.get("by", -1)))
			if bool(e.get("cannon", false)):
				# 바주카포 포탄이 그 벌레에 닿는 때에
				var ha = _actor_of.get(int(e["uid"]))
				var k := 0.0
				if ha != null and is_instance_valid(ha):
					var y0 := _field.fort_pos().y
					var y1 := _field.nest_pos().y - 50.0
					k = clampf((ha.position.y - y0) / maxf(1.0, y1 - y0), 0.0, 1.0)
				_hit_due[int(e["uid"])] = _t + CANNON_FLY * k
				_later(CANNON_FLY * k, _show_hit.bind(e))
			elif src != null and String(e.get("eff", "")) != "skill" and _is_melee(src):
				_hit_due[int(e["uid"])] = _t + 0.07
				_later(0.07, _show_hit.bind(e))
			else:
				_show_hit(e)
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
				_dying[uid] = a
				# 막타가 늦게 그려지면(근접 덤벼듦·바주카 포탄) 그게 닿은 뒤에 쓰러진다
				var wait := float(_hit_due.get(uid, -99.0)) - _t
				if wait > 0.0:
					_later(wait, _die_fx.bind(e, a))
				else:
					_die_fx(e, a)
		"base_hit":
			if e["side"] == "b":
				_field.shake_nest = 6.0
				_vfx.burst(_field.nest_pos() + Vector2(0, -40), Color("#C9A27A"), 4, 200.0, 0.4, 0.35)
			else:
				_field.shake_our = 6.0
				_add_trauma(0.05)
		"shock":
			_add_trauma(0.9)
			_flash(0.3)
			_fx.ring(_field.nest_pos() + Vector2(0, -100), 30.0, 700.0, Color("#FF9A9A"), 18.0, 0.8)
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
			var cp := _field.fort_pos()
			_fx.ring(cp, 30.0, 420.0, IdleUi.GOLD, 16.0, 0.7)
			_vfx.burst(cp, IdleUi.GOLD, 30, 500.0, 0.9, 0.5, true)
			AudioManager.souvenir_get()
		"rush":
			_toast("둥지가 흔들려요! 벌레가 몰려와요")
		"worker":
			_fx.text(_worker_btn.global_position + Vector2(75, -10) - _world.global_position, "수입 UP!", IdleUi.GOLD, 30, 0.9)
		"cannon", "cannon_fx":
			if String(e["k"]) == "cannon":
				_cannon_fx(e)
		"multi":
			# 여럿 맞히기 - 손으로 잘 모아 쏜 바주카의 손맛
			var mp := _field.to_screen(LaneData.LEN * 2.0 / 3.0, 0.0)
			_fx.text(mp, "여럿 맞히기! %d마리" % int(e["hit"]), PINK_TXT, 34, 1.2, 0.15)
			_fx.text(mp + Vector2(0, 46), "+%d" % int(e["gain"]), IdleUi.GOLD, 30, 1.1, 0.3)
			_shake_ctrl(_wallet_lbl)
		"wave_hold":
			var hp := _field.to_screen(LaneData.LEN * 0.5, 0.0)
			_fx.ring(hp, 30.0, 300.0, IdleUi.LAV, 14.0, 0.7)
			_fx.text(hp, "떼를 막았어요! +%d" % int(e.get("gain", LaneData.WAVE_HOLD)), IdleUi.LAV_DK, 32, 1.3)
			_shake_ctrl(_wallet_lbl)
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
				_fx.meteor(from, p, col, 0.24)   # 독수리 자리에서 벌레에게로 내리꽂는다
			_vfx.burst(p, col, 8, 300.0, 0.35, 0.4, false, 0.24)


## 벌레가 맞았을 때. 평소엔 작게, 특성·치명타일 때만 크게 - 그래야 '강한 한 방' 이 눈에 띈다.
func _hit_fx(e: Dictionary, p: Vector2) -> void:
	var dmg := int(e["dmg"])
	var eff := String(e.get("eff", ""))
	var crit := bool(e.get("crit", false))
	var legend := String(e.get("by_rarity", "")) == "legend"
	if eff == "skill":
		# 스킬로 맞은 벌레 - 친구의 스킬 색으로 크게
		var src = _ent_of.get(int(e.get("by", -1)))
		var sc := Color("#FFD0F0")
		if src != null and LaneData.SKILLS.has(String(src["kind"])):
			sc = Color(String(LaneData.SKILLS[String(src["kind"])]["col"]))
		_vfx.burst(p, sc, 18, 420.0, 0.55, 0.5)
		_fx.burst(p, Color.WHITE, 8, 360.0, 7.0, 0.45, 500.0, "star")
		_fx.ring(p, 8.0, 100.0, sc, 9.0, 0.32)
		_fx.text(p + Vector2(randf_range(-18, 18), -36), _num(dmg), sc.lightened(0.35), clampi(30 + int(sqrt(float(dmg)) * 0.5), 30, 52),
			0.95, 0.0, 70.0)
		return
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


## 스킬 효과 - 친구 둘레가 번쩍이고(빛기둥·집중선·고리) 스킬 이름이 뜬다. 종류마다 터지는 모양이 다르다.
## 피해 숫자·맞은 벌레의 번쩍임은 `_hit_fx` (eff = "skill") 가 따로 그린다.
func _skill_fx(e: Dictionary) -> void:
	var id := String(e["id"])
	var k: Dictionary = LaneData.SKILLS[id]
	var col := Color(String(k["col"]))
	var kind := String(e["kind"])
	var a = _actor_of.get(int(e["uid"]))
	var p := _field.to_screen(float(e["pos"]), 0.0)
	if a != null and is_instance_valid(a):
		p = a.position + Vector2(0, -a.body_height() * 0.5)
		a.flash = 1.0
		a.flash_col = col.lightened(0.4)
		a.squash = Vector2(1.25, 0.8)
	var depth := _field.scale_at(float(e["pos"]))
	# 공통: 시전 - 친구 둘레 고리 + 이름. (하늘로 솟는 빛기둥·별은 뺐다 - 허공에 힘을 쓰는 것처럼 보였다.
	# 힘은 맞는 쪽에서 터진다 - 아래 종류별 효과)
	_fx.ring(p, 10.0, 120.0, col, 12.0, 0.4)
	_fx.ring(p, 6.0, 80.0, Color.WHITE, 8.0, 0.3, 0.06)
	_vfx.burst(p, col, 14, 300.0, 0.6, 0.5, true)
	# 스킬 띠가 뜨면 이름은 띠에 있다 - 머리 위에 또 띄우면 글자가 겹친다
	if not _cutin(id):
		_fx.text(p + Vector2(0, -72), String(k["name"]), col.lightened(0.45), 34, 1.25, 0.0, 70.0)
	_flash(0.12)
	_add_trauma(0.18)
	var hits: Array = []
	for u in e.get("hits", []):
		# 이 스킬로 쓰러진 벌레도 (같은 틱의 'die' 가 먼저 _actor_of 에서 지운다)
		var ha = _actor_any(int(u))
		if ha != null:
			hits.append(ha.position + Vector2(0, -ha.body_height() * 0.5))
	var allies: Array = []
	for u in e.get("allies", []):
		var aa = _actor_of.get(int(u))
		if aa != null and is_instance_valid(aa):
			allies.append(aa)
	match kind:
		"smash":
			for i in 3:
				_fx.ring(p, 20.0, (float(k["r"]) * 0.55 + 60.0 * i) * depth, col if i != 1 else Color.WHITE, 16.0 - i * 4.0, 0.5, i * 0.09)
			_fx.wave(p + Vector2(0, 30), float(k["r"]) * 0.8 * depth, col, 16.0, 0.6)
			_fx.burst(p, col, 34, 620.0, 10.0, 0.8, 600.0, "star")
			_hitstop(0.05)
			AudioManager.battle_hit()
		"quake":
			for i in 3:
				_fx.wave(p + Vector2(0, 34), (float(k["r"]) * 0.7 + 70.0 * i) * depth, col if i % 2 == 0 else Color.WHITE, 18.0, 0.55, i * 0.1)
			_vfx.burst(p + Vector2(0, 34), Color("#C9A27A"), 40, 520.0, 0.9, 0.6, true)
			_fx.rays(p + Vector2(0, 30), Color("#FFE7B0"), 16, 40.0, 300.0, 0.35, 0.05)
			_add_trauma(0.5)
			_hitstop(0.06)
			AudioManager.battle_hit()
		"pierce":
			var far := _field.to_screen(float(e["pos"]) + float(k["r"]), 0.0) + Vector2(0, -30)
			for i in 3:
				_fx.arrow(p + Vector2((i - 1) * 14, 0), far + Vector2((i - 1) * 22, 0), col if i != 1 else Color.WHITE, 0.16, i * 0.04)
			for i in 7:
				var q := p.lerp(far, float(i + 1) / 7.0)
				_fx.ring(q, 6.0, 60.0, col, 8.0, 0.3, 0.03 * i)
				_vfx.burst(q, col, 8, 300.0, 0.4, 0.4, false, 0.03 * i)
			_fx.slash(far, PI * 0.5, 90.0, Color.WHITE, 16.0, 0.25, 0.15)
			AudioManager.battle_hit()
		"storm":
			var i := 0
			for q in hits:
				for j in 2:
					_fx.orb(p, q + Vector2(randf_range(-16, 16), randf_range(-16, 16)), col if j == 0 else Color.WHITE, 0.16, 0.07 * i)
					i += 1
				_fx.ring(q, 6.0, 80.0, col, 9.0, 0.3, 0.07 * i)
				_fx.burst(q, col, 12, 380.0, 8.0, 0.5, 400.0, "star", 0.07 * i)
			_fx.rays(p, Color.WHITE, 12, 20.0, 160.0, 0.3, 0.1)
			AudioManager.battle_hit()
		"thunder":
			# 쓴 친구에게서 맞는 벌레에게로 번개가 날아간다 (하늘에서 내리꽂던 것은 뺐다)
			for q in hits:
				_fx.meteor(p, q, col, 0.28)
				_fx.rays(q, col, 16, 30.0, 200.0, 0.4, 0.28)
				_fx.ring(q, 20.0, 200.0, Color.WHITE, 16.0, 0.45, 0.28)
				_vfx.burst(q, col, 30, 500.0, 0.8, 0.6, false, 0.28)
			if hits.is_empty():
				var nq := _field.nest_pos() + Vector2(0, -50)
				_fx.meteor(p, nq, col, 0.28)
			_later(0.28, func() -> void:
				_flash(0.4)
				_add_trauma(0.6)
				_hitstop(0.08))
			AudioManager.sky_crack()
		"freeze":
			for i in 2:
				_fx.ring(p, 20.0, float(k["r"]) * 0.8 * depth + 40.0 * i, col if i == 0 else Color.WHITE, 14.0, 0.6, i * 0.12)
			_fx.wave(p + Vector2(0, 30), float(k["r"]) * depth, Color("#DFF5FF"), 14.0, 0.7)
			# 얼음이 쓴 친구에게서 벌레에게로 날아가 얼린다
			var fi := 0
			for q in hits:
				_fx.orb(p, q, col, 0.16, 0.04 * fi)
				_fx.ring(q, 6.0, 70.0, Color.WHITE, 8.0, 0.35, 0.16 + 0.04 * fi)
				_fx.burst(q, Color.WHITE, 10, 240.0, 7.0, 0.6, 300.0, "sq", 0.16 + 0.04 * fi)
				fi += 1
			_fx.burst(p, Color("#DFF5FF"), 16, 360.0, 8.0, 0.7, 300.0, "star")
			AudioManager.water_ripple()
		"heal":
			for aa in allies:
				var q: Vector2 = aa.position + Vector2(0, -aa.body_height() * 0.5)
				_fx.ring(q, 6.0, 70.0, Color("#B8FFC8"), 8.0, 0.4)
			_fx.burst(p, Color("#B8FFC8"), 16, 260.0, 8.0, 0.7, 200.0, "star", 0.0, true)
			AudioManager.battle_heal()
		"guard", "rally":
			var word := "방어 UP" if kind == "guard" else "공격 UP"
			for aa in allies:
				var q: Vector2 = aa.position + Vector2(0, -aa.body_height() * 0.5)
				_fx.ring(q, 40.0, 10.0, col, 8.0, 0.4)
				_fx.ring(q, 10.0, 70.0, Color.WHITE, 6.0, 0.4, 0.15)
				_fx.text(q + Vector2(0, -34), word, col.lightened(0.3), 20, 0.9, 0.1, 40.0)
				aa.flash = 0.8
				aa.flash_col = col.lightened(0.3)
			_fx.ring(p, 20.0, float(k["r"]) * depth, col, 12.0, 0.6, 0.05)
			AudioManager.warm_swell()


## 돌진: 지나온 길에 잔상과 먼지.
func _dash_fx(e: Dictionary) -> void:
	var a := _field.to_screen(float(e["from"]), float(_lat.get(int(e["uid"]), 0.0)))
	var b := _field.to_screen(float(e["to"]), float(_lat.get(int(e["uid"]), 0.0)))
	var k: Dictionary = LaneData.SKILLS.get(String(_ent_of.get(int(e["uid"]), {}).get("kind", "")), {})
	var col := Color(String(k.get("col", "#FFFFFF")))
	for i in 6:
		var t := float(i) / 5.0
		var q := a.lerp(b, t) + Vector2(0, -30)
		_fx.ring(q, 4.0, 50.0, col, 8.0, 0.35, 0.03 * i)
		_vfx.burst(q + Vector2(0, 20), Color("#E8DCC8"), 8, 200.0, 0.5, 0.4, true, 0.03 * i)
	_fx.arrow(a + Vector2(0, -30), b + Vector2(0, -30), Color.WHITE, 0.2)
	_fx.slash(b + Vector2(0, -20), PI * 0.5, 80.0, col, 18.0, 0.25, 0.1)


## 스킬 컷인: 화면을 가로지르는 띠에 친구 얼굴 + 스킬 이름. 너무 자주 나오면 정신없어서
## 하나가 떠 있는 동안은 다음 것을 건너뛴다 (전설은 2초 뒤면 다시, 나머지는 4초).
func _cutin(id: String) -> bool:
	if _calm or _hud == null:
		return false
	var legend := LaneData.rarity(id) == "legend"
	if _t - _cutin_t < (2.0 if legend else 4.0):
		return false
	_cutin_t = _t
	var k: Dictionary = LaneData.SKILLS[id]
	var col := Color(String(k["col"]))
	var band := Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.size = Vector2(size.x + 80.0, 118.0)
	# 가운데 띠(_banner, 높이 30%)와 겹치지 않게 그 아래에
	band.position = Vector2(size.x, size.y * 0.4)
	_hud.add_child(band)
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.07, 0.22, 0.86)
	bg.size = band.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(bg)
	for yy in [0.0, band.size.y - 8.0]:
		var stripe := ColorRect.new()
		stripe.color = col
		stripe.size = Vector2(band.size.x, 8.0)
		stripe.position = Vector2(0, yy)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(stripe)
	var pic := _portrait(id, 96.0)
	pic.position = Vector2(36, 11)
	band.add_child(pic)
	var nm := IdleUi.label(LaneData.unit_name(id, LaneState.level_of(id)), 22, IdleUi.INK, true)
	nm.position = Vector2(150, 14)
	band.add_child(nm)
	var sk := IdleUi.label(String(k["name"]) + "!", 46, col.lightened(0.35), true)
	sk.position = Vector2(150, 40)
	band.add_child(sk)
	# 띠에 붙인 트윈 - 판이 바뀌어 띠가 풀리면 같이 멈춘다
	var tw := band.create_tween()
	tw.tween_property(band, "position:x", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(band, "position:x", -24.0, 0.6)
	tw.tween_property(band, "position:x", -size.x - 120.0, 0.16).set_ease(Tween.EASE_IN)
	tw.tween_callback(band.queue_free)
	return true


func _cannon_fx(e: Dictionary = {}) -> void:
	# 바주카포 - 이 게임에서 가장 큰 한 방. 발사(포구 섬광·반동) → 빛 포탄이 길을 가르며 날아감 → 둥지에서 대폭발.
	# 강화 단계가 높을수록 더 크게. (번쩍임·흔들림은 '줄이기' 설정을 따른다 - _flash·_add_trauma·_hitstop)
	var lv := int(e.get("lv", LaneState.bazooka_lv))
	var big := 1.0 + 0.08 * float(lv - 1)
	var base := _field.fort_pos() + Vector2(0, 30)
	var nest := _field.nest_pos() + Vector2(0, -50)
	var fly := CANNON_FLY
	_cannon_land_t = maxf(_cannon_land_t, _t + fly)
	var gold := IdleUi.GOLD
	var hot := Color("#FFF3D0")
	# 1) 발사 - 포구 섬광 · 충격파 세 겹 · 빛살 · 연기 · 반동
	_flash(0.55)
	_add_trauma(0.6)
	_hitstop(0.05)
	_bazooka_band(lv)
	_fx.rays(base, hot, int(26 * big), 30.0, 340.0 * big, 0.35)
	for k in 3:
		_fx.ring(base, 10.0, (150.0 + 90.0 * k) * big, [Color.WHITE, gold, Color("#BF94E4")][k], 16.0 - 4.0 * k, 0.4, 0.05 * k)
	_vfx.burst(base, Color("#E8DCC8"), int(24 * big), 380.0, 0.8, 0.7, true)
	_fx.burst(base, hot, int(20 * big), 520.0, 9.0, 0.5, 300.0, "star")
	_field.shake_our = 16.0   # 반동
	# 2) 비행 - 굵은 빛 포탄(겹친 구슬) + 꼬리 + 지나는 길마다 땅이 울린다
	_fx.meteor(base, nest, gold, fly)
	for k in 5:
		_fx.orb(base, nest, [Color.WHITE, hot, gold, Color("#F7A8C4"), Color("#BF94E4")][k], fly, 0.025 * k)
	var steps := 12
	for i in steps:
		var t := float(i + 1) / float(steps + 1)
		var p := base.lerp(nest, t)
		var d := t * fly
		_fx.wave(p + Vector2(0, 30), 120.0 * big, Color("#FFE7B0"), 10.0, 0.45, d)
		_fx.ring(p, 8.0, 80.0 * big, hot, 10.0, 0.3, d)
		_fx.burst(p, [gold, Color("#F7A8C4"), Color.WHITE][i % 3], 6, 300.0, 7.0, 0.6, 500.0, "star", d)
		_vfx.burst(p, gold, 6, 260.0, 0.45, 0.4, false, d)
	_later(fly * 0.5, func() -> void: _add_trauma(0.25))
	# 3) 착탄 - 화면 전체 번쩍 · 잠깐 멈춤 · 고리 네 겹 · 긴 빛살 · 버섯 폭발 · 잔해 · 이어지는 작은 폭발
	var nd := int(e.get("nest", 0))
	_later(fly, func() -> void:
		if _field == null:
			return
		_field.shake_nest = 22.0
		_flash(0.85)
		_add_trauma(1.0)
		_hitstop(0.1)
		_fx.rays(nest, hot, int(36 * big), 40.0, 520.0 * big, 0.5)
		var cols := [Color.WHITE, gold, Color("#F7A8C4"), Color("#BF94E4")]
		for k in 4:
			_fx.ring(nest, 20.0, (180.0 + 110.0 * k) * big, cols[k], 22.0 - 4.0 * k, 0.6, 0.06 * k)
		_fx.wave(nest + Vector2(0, 40), 420.0 * big, Color("#FFE7B0"), 20.0, 0.7)
		_fx.wave(nest + Vector2(0, 40), 300.0 * big, Color.WHITE, 12.0, 0.55, 0.1)
		_fx.burst(nest, hot, int(40 * big), 760.0, 12.0, 0.9, 700.0, "star")
		_fx.burst(nest, gold, int(30 * big), 600.0, 10.0, 1.0, -260.0, "star", 0.05)   # 버섯처럼 솟는 불꽃
		_fx.burst(nest, Color.WHITE, int(20 * big), 480.0, 8.0, 0.7, 600.0, "sq", 0.03)
		_vfx.burst(nest, Color("#C9A27A"), int(50 * big), 640.0, 1.0, 0.8, true)          # 흙·잔해
		_vfx.burst(nest, Color("#8A6F8F"), int(24 * big), 300.0, 1.4, 1.0, true, 0.1)      # 연기
		for k in int(5 * big):
			var q := nest + Vector2(randf_range(-150, 150), randf_range(-90, 50)) * big
			var dl := 0.12 + 0.09 * k
			_fx.ring(q, 8.0, 110.0, [gold, Color.WHITE, Color("#F7A8C4")][k % 3], 10.0, 0.35, dl)
			_fx.burst(q, hot, 10, 380.0, 8.0, 0.5, 500.0, "star", dl)
			_vfx.burst(q, Color("#C9A27A"), 8, 300.0, 0.5, 0.5, true, dl)
		_later(0.3, func() -> void: _add_trauma(0.4))
		if nd > 0:
			_fx.text(nest + Vector2(0, -80), "-%s" % _num(nd), hot, 56, 1.3, 0.05, 80.0)
		AudioManager.sky_crack())
	AudioManager.battle_hit()


## 바주카포 띠 - 화면을 가로지르는 띠에 바주카 그림 + "바주카포 발사!" (스킬 띠와 같은 높이·모양).
func _bazooka_band(lv: int) -> void:
	if _hud == null:
		return
	var band := Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.size = Vector2(size.x + 80.0, 118.0)
	# 스킬 띠(높이 40%)가 아직 떠 있으면 그 아래에 - 띠끼리 겹치지 않게
	var busy := _t - _cutin_t < 1.2
	band.position = Vector2(-size.x - 80.0, size.y * 0.4 + (136.0 if busy else 0.0))
	_hud.add_child(band)
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.07, 0.22, 0.9)
	bg.size = band.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(bg)
	for yy in [0.0, band.size.y - 8.0]:
		var stripe := ColorRect.new()
		stripe.color = IdleUi.GOLD
		stripe.size = Vector2(band.size.x, 8.0)
		stripe.position = Vector2(0, yy)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(stripe)
	# 그림 + [Lv 칩 / 제목] 을 한 묶음으로 띠 한가운데에 (띠는 화면 정가운데에 멈춘다)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.position = Vector2(0, 8)
	hb.size = Vector2(band.size.x, band.size.y - 16.0)
	band.add_child(hb)
	var ic := _bazooka_icon(92.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tv)
	var chip := PanelContainer.new()
	var csb := IdleUi.box(IdleUi.GOLD, IdleUi.GOLD_DK, 12, 2, 2, false)
	csb.content_margin_left = 12
	csb.content_margin_right = 12
	chip.add_theme_stylebox_override("panel", csb)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl := Label.new()
	cl.text = "Lv %d" % lv
	cl.add_theme_font_size_override("font_size", 20)
	cl.add_theme_color_override("font_color", Color("#4A1D3A"))
	chip.add_child(cl)
	tv.add_child(chip)
	var t := IdleUi.label("바주카포 발사!", 50, IdleUi.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t)
	# 그림 폭만큼 왼쪽에 무게가 실리지 않게, 오른쪽에 같은 폭의 빈칸
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(92, 1)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(pad)
	# 왼쪽에서 휙 들어와 가운데에 머물다 오른쪽으로 빠진다 (스킬 띠와 반대 방향)
	var mid := -40.0
	var tw := band.create_tween()
	tw.tween_property(band, "position:x", mid - 8.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(band, "position:x", mid + 8.0, 0.7)
	tw.tween_property(band, "position:x", size.x + 40.0, 0.16).set_ease(Tween.EASE_IN)
	tw.tween_callback(band.queue_free)
	_cutin_t = _t   # 띠가 겹치지 않게 - 이 동안 스킬 띠는 쉰다


# ── 끝 ───────────────────────────────────────────────────────────────

func _end_battle(res: String) -> void:
	_ended = true
	Engine.time_scale = 1.0
	var win := res == "win"
	_won = win
	var r := {}
	if win:
		r = LaneState.on_win(stage_n)
		# 바주카포가 마지막 한 방이면 포탄이 둥지에 닿은 뒤에 터진다 (누르는 순간 피해가 들어가 승리가 먼저 났다)
		_later(maxf(0.0, _cannon_land_t - _t), func() -> void:
			if _field == null or not is_instance_valid(_field) or not is_instance_valid(_fx):
				return
			_flash(0.5)
			_add_trauma(1.0)
			var np := _field.nest_pos() + Vector2(0, -40)
			_vfx.burst(np, Color("#FFD27A"), 40, 600.0, 1.2, 0.8)
			_fx.ring(np, 20.0, 400.0, IdleUi.GOLD, 20.0, 0.8)
			AudioManager.souvenir_get())
	else:
		# 응원은 진짜로 싸우다 진 판에만 - 바로 후퇴를 눌러 쌓지 못하게
		if battle.result == "lose" or _battle_t >= CHEER_MIN_FIGHT:
			LaneState.on_lose(stage_n)
		AudioManager.battle_defeat()
	LaneState.save(int(Time.get_unix_time_from_system()))
	_later((1.0 + maxf(0.0, _cannon_land_t - _t)) if win else 0.6, func() -> void: _show_result(win, r))


func _show_result(win: bool, r: Dictionary) -> void:
	_result = Control.new()
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_result)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.03, 0.1, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
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
		v.add_child(_center(IdleUi.label("✦ 행복 조각 +%s" % _num(int(r["xp"])), 30, PINK_TXT)))
		if int(r["stars"]) > 0:
			# 행운별은 위 알약과 같은 파란 반짝이 (★ 글자는 희귀도에만 쓴다)
			var srow := HBoxContainer.new()
			srow.alignment = BoxContainer.ALIGNMENT_CENTER
			srow.add_theme_constant_override("separation", 6)
			v.add_child(srow)
			srow.add_child(IdleUi.icon("star", 34.0, LaneData.STAR_COL))
			srow.add_child(IdleUi.label("행운별 +%d" % int(r["stars"]), 28, STAR_TXT))
		if int(r.get("tickets", 0)) > 0:
			v.add_child(_center(IdleUi.label("뽑기 티켓 +%d장" % int(r["tickets"]), 28, PINK_TXT)))
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
			arow.add_child(IdleUi.label("장신구! %s" % String(ad["name"]), 28, PINK_TXT))
		for id in r.get("new_units", []):
			v.add_child(_center(IdleUi.label("새 친구! %s 합류" % String(LaneData.UNITS[id]["name"]), 28, IdleUi.GREEN)))
		if bool(r.get("first", false)) and stage_n == LaneData.CH_STAGES:
			v.add_child(_center(IdleUi.label("2장이 열렸어요! 더 센 벌레가 기다려요", 28, IdleUi.LAV_DK)))
			_map_ch = -1
		elif bool(r.get("first", false)) and stage_n == LaneData.STAGE_MAX:
			v.add_child(_center(IdleUi.label("모든 판을 지켜 냈어요! 고마워요", 28, IdleUi.LAV_DK)))
		elif stage_n >= LaneData.STAGE_MAX:
			v.add_child(_center(IdleUi.label("모든 판을 깼어요 - 지도에서 판을 골라 다시 해 봐요", 22, IdleUi.SUB)))
	else:
		if LaneState.cheer_for(stage_n) > 0.0:
			v.add_child(_center(IdleUi.label("다시 도전하면 응원을 받아 +%d%% 강해져요" % int(LaneState.cheer_for(stage_n)), 24,
				IdleUi.LAV_DK)))
		v.add_child(_center(IdleUi.label("레벨 업 · 장신구 · 편성을 바꿔 봐도 좋아요", 20, IdleUi.SUB)))
	# 판 기록 - 손맛 보너스를 받은 횟수 (승패와 상관없이)
	if battle != null:
		var m5 := int(battle.tally.get("multi5", 0))
		var hd := int(battle.tally.get("holds", 0))
		if m5 > 0 or hd > 0:
			v.add_child(_center(IdleUi.label("여럿 맞히기 %d번 · 떼 막기 %d번" % [m5, hd], 20, IdleUi.SUB)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var home := IdleUi.button("홈으로", 28)
	home.custom_minimum_size = Vector2(240, 90)
	home.pressed.connect(_show_home)
	_result_home = home
	row.add_child(home)
	# 마지막 판 뒤에는 다음 판이 없다 - 같은 판을 '다시'로 부른다
	var last := win and stage_n >= LaneData.STAGE_MAX
	var next := IdleUi.button("다음 판 ▶" if win and not last else "다시 ▶", 28, "gold")
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
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
			_tut.point(null, "벌레들이 행복을 갉아먹고 있어요. 함께 막아 봐요", _tut_home_intro.bind(2))
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
			_tut.point(null, "벌레는 아래 둥지에서 와요. 위 우리 성을 지켜요!", _tut_battle_guide.bind(1))
		1:
			battle.wallet = maxf(battle.wallet, 60.0)
			_tut.point(_unit_btns.get("tiny"), "꼬마 쿼카를 눌러 불러 보세요", _tut_run.bind(2.5, 2))
		2:
			battle.wallet = maxf(battle.wallet, 110.0)
			_tut.point(_unit_btns.get("shield"), "방패 쿼카도 불러요. 튼튼한 벽이에요", _tut_run.bind(3.0, 3))
		3:
			battle.wallet = maxf(battle.wallet, float(battle.worker_cost()) + 5.0)
			_tut.point(_worker_btn, "수입을 올리면 웃음이 더 빨리 차요", _tut_run.bind(3.5, 4))
		4:
			battle.cannon = battle.cannon_max
			_tut.point(_cannon_btn, "바주카포가 찼어요! 눌러서 쏴요", _tut_run.bind(2.0, 5))
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
			# 단계 번호는 저장하지 않는다 - 안내 중간에 껐다 켜면 0 부터 다시 돈다.
			# 이미 뽑았거나(이 단계를 지난 것) 행복 조각이 모자라면 건너뛴다 (못 누르는 단추를 가리키며 멈추지 않게)
			if LaneState.pulls > 0 or not LaneState.can_level("tiny"):
				_tut_home_guide(2)
				return
			_tut.point(_home.find_child("Lv_tiny", true, false) as Control, "행복 조각으로 레벨 업! 더 튼튼해져요",
				_tut_later.bind(2))
		2:
			_tut.point(_home.get_node("TabBar/Tabs/Tab_gacha") as Control, "이번엔 뽑기 탭이에요", _tut_later.bind(3))
		3:
			# 이미 뽑았거나 티켓·행운별이 없으면 뽑기는 건너뛴다
			if LaneState.pulls > 0 or not LaneState.can_pull(1):
				_tut_home_guide(4)
				return
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
				_toast("이제 혼자서도 할 수 있어요! 파이팅"))


## 탭을 바꾼 뒤 화면이 다시 그려질 때까지 잠깐 기다렸다가 다음 단계.
func _tut_later(i: int) -> void:
	_later(0.35, _tut_home_guide.bind(i))


# ── 도우미 ───────────────────────────────────────────────────────────

func _add_trauma(a: float) -> void:
	_trauma = clampf(_trauma + a * (0.25 if _calm else 1.0), 0.0, 1.0)


func _hitstop(d: float) -> void:
	if _calm or _ended:
		return
	# 치명타·스킬은 판 시간으로 일어난다 - 배속만큼 짧게 해야 실제 시간당 멈춤이 늘지 않는다
	d /= _speed()
	if d < 0.01:
		return
	# 겹쳐 걸리면 가장 늦게 끝나는 때까지 (먼저 끝난 짧은 것이 긴 멈춤을 잘라 내지 않게)
	var now := Time.get_ticks_msec() / 1000.0
	if now + d <= _stop_until:
		return
	_stop_until = now + d
	_stop_id += 1
	var id := _stop_id
	Engine.time_scale = 0.06
	# 마지막에 건 것만 되돌린다 (가장 늦게 끝나는 것)
	get_tree().create_timer(d, true, false, true).timeout.connect(func() -> void:
		if id == _stop_id:
			Engine.time_scale = 1.0)


func _flash(a: float) -> void:
	if _flash_rect != null:
		_flash_rect.color = Color(1, 1, 1, maxf(_flash_rect.color.a, a * (0.3 if _calm else 1.0)))


func _later(d: float, f: Callable) -> void:
	if d <= 0.0:
		f.call_deferred()
		return
	create_tween().tween_callback(f).set_delay(d)


## 못 누를 때 좌우로 흔든다. 제자리는 처음 흔들 때 한 번만 기억한다 - 흔들리는 중에 또 누르면
## 그때의 (비껴 있는) 자리를 제자리로 삼아, 연타할수록 카드가 옆으로 밀려 화면 밖으로 나갔다.
func _shake_ctrl(c: Control) -> void:
	var old = c.get_meta("shake_tw", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	if not c.has_meta("shake_x"):
		c.set_meta("shake_x", c.position.x)
	var x := float(c.get_meta("shake_x"))
	var tw := create_tween()
	c.set_meta("shake_tw", tw)
	for i in 4:
		tw.tween_property(c, "position:x", x + (8.0 if i % 2 == 0 else -8.0), 0.035)
	tw.tween_property(c, "position:x", x, 0.035)
	tw.finished.connect(func() -> void:
		if is_instance_valid(c):
			c.remove_meta("shake_x")
			c.remove_meta("shake_tw")
			if c.get_parent() is Container:
				(c.get_parent() as Container).queue_sort())


## 돈이 모자란 단추: 회색으로 막지(disabled) 않고 흐리게만 둔다 - 누르면 흔들고 무엇이 모자란지 알려 준다.
## (disabled 단추는 pressed 를 내지 않아 흔들림·안내가 나올 수 없었다)
func _set_short(b: Button, short: bool) -> void:
	if short:
		b.disabled = false
	b.modulate = Color(1, 1, 1, 0.55) if short else Color.WHITE


func _short_xp(b: Control, cost: int) -> void:
	_shake_ctrl(b)
	_toast("행복 조각이 ✦%s 모자라요 - 판을 깨면 모여요" % _num(maxi(1, cost - LaneState.xp)))


func _short_stars(b: Control, cost: int) -> void:
	_shake_ctrl(b)
	_toast("행운별이 %s개 모자라요 - 판을 처음 깨면 받아요" % _num(maxi(1, cost - LaneState.stars)))


func _toast(t: String) -> void:
	if _tut != null and _tut.visible:
		return
	_toast_lbl.text = t
	# 폭을 먼저 정하고(글씨도 같이) 높이는 글씨만큼 - 화면 크기가 정해지기 전(첫 실행)에 재면
	# 폭 0 으로 줄바꿈을 계산해 판이 화면 절반만큼 길어졌다.
	# 위 재화 줄(높이 64)을 통째로 덮는 자리 - 제목 위에 걸치면 뒤 글자가 위아래로 삐져나와 겹쳐 보였다
	var w := maxf(320.0, (size.x if size.x > 0.0 else 720.0) - 20.0)
	_toast_lbl.custom_minimum_size = Vector2(w - 40.0, 0)
	_toast_box.custom_minimum_size = Vector2(w, 80)
	_toast_box.size = Vector2(w, 80)
	_toast_box.reset_size()
	_toast_box.position = Vector2(10, 6 + _insets().x)
	# 한 프레임 뒤 다시 줄인다 (줄바꿈이 제 폭으로 다시 계산된 뒤)
	_later(0.0, func() -> void:
		_toast_box.size = Vector2(w, 80)
		_toast_box.reset_size())
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
