extends SideEpisode
## 회사 앞. 0편이 시작하고 끝나는 곳.
##
## 들어갈 때는 불 켜진 창 하나를 올려다보는 자리고, 나올 때는 첫 사진을
## 찍는 자리다. 같은 화면이 처음과 끝에 다른 뜻으로 쓰인다.

const PHOTO_X := 1500.0

var _photo_spot: Area2D
var _photo_glow: Node2D
var _photo_done := false
var _t := 0.0


func map_title() -> String:
	return "쿼카전자 앞 · 밤 11시"


func build() -> void:
	set_bounds(3600.0, 420.0)
	# 그려 받은 그림이 있으면 **먼 밤도시만** 그것으로 바꾼다.
	#
	# 회사 건물과 가로등은 그림에 맡기지 않는다. 불 켜진 4층 창 하나가
	# 이 이야기의 시작인데, 배경 그림은 맵 길이만큼 좌우로 이어 붙이므로
	# 그 창이 여러 개로 늘어나 버린다. 하나뿐이어야 하는 것은 코드가 놓는다.
	if not use_backdrop("front"):
		IndoorParts.skyline(self, 3600.0, FLOOR_Y, 11)

	# 쿼카전자. 이 건물만은 코드가 그린다.
	#
	# 그림으로 뽑으면 좌우로 이어 붙일 때 여러 채가 된다. 그런데 이
	# 건물은 하나뿐이어야 하고, 그 4층의 불 켜진 창 하나가 0편의 시작이다.
	#
	# 색은 뒤의 밤도시보다 **진하고 또렷하게** 잡는다. 뒤가 안개에 잠긴
	# 그림이라, 같은 톤으로 두면 건물이 배경에 녹아 어디가 회사인지
	# 알 수 없다. 가까운 것은 흐리지 않아야 가까워 보인다.
	var b := Node2D.new()
	b.z_index = -20
	add_child(b)
	_rect(b, Vector2(2200, FLOOR_Y - 980), Vector2(1300, 980), Color("#222C46"))
	_rect(b, Vector2(2200, FLOOR_Y - 980), Vector2(1300, 22), Color("#39476A"))
	_rect(b, Vector2(2200, FLOOR_Y - 980), Vector2(14, 980), Color("#2C3856"))
	for row in range(5):
		for col in range(5):
			# 4층 왼쪽 끝 하나만 켜져 있다. 그 창이 이 이야기의 시작이다.
			var lit := row == 1 and col == 0
			var wx := 2270 + col * 240
			var wy := FLOOR_Y - 900 + row * 170
			if lit:
				# 켜진 창은 빛이 새어 나와야 눈에 띈다. 창만 노랗게
				# 칠하면 스티커처럼 붙어 보인다.
				_rect(b, Vector2(wx - 90, wy - 80), Vector2(330, 270),
					Color(1, 0.87, 0.55, 0.10))
				_rect(b, Vector2(wx - 40, wy - 34), Vector2(230, 178),
					Color(1, 0.87, 0.55, 0.13))
			_rect(b, Vector2(wx, wy), Vector2(150, 110),
				Color("#FFE7A8") if lit else Color("#1A2338"))
	# 1층 입구. 유리문 너머로 로비 불빛이 조금 비친다.
	_rect(b, Vector2(2180, FLOOR_Y - 300), Vector2(1340, 20), Color("#39476A"))
	_rect(b, Vector2(2600, FLOOR_Y - 250), Vector2(340, 250), Color("#2E3C5C"))
	_rect(b, Vector2(2620, FLOOR_Y - 232), Vector2(300, 232), Color("#54658A"))
	_rect(b, Vector2(2560, FLOOR_Y - 300), Vector2(420, 300), Color(1, 0.9, 0.66, 0.07))

	# 인도. 하늘만 그림으로 바꾸므로 여기는 늘 코드가 그린다.
	# 인도는 배경보다 확실히 진해야 한다. 하늘 그림이 뿌옇게 밝아지면서
	# 인도(#5A6480)와 안개(#617094)의 밝기 차가 4/255 로 붙어, 발밑에
	# 바닥이 있다는 것이 안 보였다.
	Parts.platform(self, -200, FLOOR_Y, 4000, 320, false,
		Color("#3E465E"), Color("#262C3E"))
	# 보도블록 이음매. 한 줄씩 그어 두면 걸을 때 지나가는 것이 보여
	# 실제로 나아가고 있다는 느낌이 난다.
	var pave := Node2D.new()
	pave.z_index = -2
	add_child(pave)
	for px in range(-200, 3900, 170):
		_rect(pave, Vector2(px, FLOOR_Y + 26), Vector2(3, 40), Color(0, 0, 0, 0.22))
	_rect(pave, Vector2(-200, FLOOR_Y + 24), Vector2(4200, 3), Color(0, 0, 0, 0.26))
	# 인도 앞턱에 밝은 줄 하나. 바닥선이 어디인지 한눈에 말해 준다.
	_rect(pave, Vector2(-200, FLOOR_Y - 2), Vector2(4200, 5), Color(1, 1, 1, 0.20))

	# 가로등. 밤길이 새까맣기만 하면 걸어갈 마음이 안 난다.
	for lx in [700.0, 1900.0, 3100.0]:
		_lamp(lx)

	# 첫 사진 자리
	_photo_glow = Node2D.new()
	add_child(_photo_glow)
	_rect(_photo_glow, Vector2(PHOTO_X - 190, FLOOR_Y - 26), Vector2(380, 30),
		Color(1, 0.85, 0.43, 0.55))
	for i in range(7):
		_rect(_photo_glow, Vector2(PHOTO_X - 170 + i * 56, FLOOR_Y - 150), Vector2(14, 14),
			Color("#FFE7A8"))
	_photo_spot = spot(PHOTO_X, "사진 찍기", _try_photo)

	door(2760.0, "쿼카전자 안으로", "res://scenes/maps/CompanyLobby3D.tscn")
	_refresh_photo_stage()


func on_enter() -> void:
	AudioManager.play_ambient("wind")
	if Episode0State.current_state == Episode0State.State.START:
		await get_tree().create_timer(0.8).timeout
		await say("늦은 밤, 쿼카전자에는 딱 하나의 불빛만 남아 있어요.", 0.0)
		Episode0State.advance_to(Episode0State.State.ENTER_COMPANY)
	elif Episode0State.current_state >= Episode0State.State.PARTNER_JOINED \
			and not Episode0State.first_photo_taken:
		Episode0State.advance_to(Episode0State.State.FIRST_PHOTO)
		spawn_partner()
		_refresh_photo_stage()
		await get_tree().create_timer(0.8).timeout
		await say("애인: \"오늘이 그 언젠가야.\"", 2.4)
		await say("빛나는 자리에 서서 '선택' 을 눌러 볼까요.", 0.0)


func _process(delta: float) -> void:
	super._process(delta)
	if _photo_glow != null and _photo_glow.visible:
		_t += delta
		_photo_glow.modulate.a = 0.75 + sin(_t * 2.0) * 0.25


## 사진 자리는 찍을 때가 됐을 때만 열린다.
func _refresh_photo_stage() -> void:
	var on := Episode0State.current_state >= Episode0State.State.FIRST_PHOTO \
		and not Episode0State.first_photo_taken
	if _photo_glow != null:
		_photo_glow.visible = on
	if _photo_spot != null:
		lock_spot(_photo_spot, not on)


func _try_photo() -> void:
	if _photo_done or Episode0State.current_state < Episode0State.State.FIRST_PHOTO:
		return
	_photo_done = true
	Episode0State.first_photo_taken = true
	AudioManager.shutter()
	_flash()
	await say("찰칵!", 0.9)
	_refresh_photo_stage()

	Episode0State.advance_to(Episode0State.State.ALBUM_CREATED)
	await say("앨범의 첫 페이지가 생겼어요.", 1.6)
	SaveManager.autosave("res://scenes/maps/CompanyFront3D.tscn")
	await say("여행 기록 저장 완료", 1.6)
	hide_say()

	Episode0State.advance_to(Episode0State.State.CLEAR)
	SaveManager.mark_episode0_cleared()
	# 이어하기 자리를 여행 허브로 옮긴다. 0편은 끝났고, 이 화면에는
	# 이제 할 일이 없다 — 여기를 저장해 두면 다음에 켤 때 빈 밤거리에
	# 떨어진다.
	SaveManager.autosave("res://scenes/travel/TravelHub.tscn")
	var cs := load("res://scenes/ui/ClearScreen.tscn") as PackedScene
	if cs != null:
		add_child(cs.instantiate())


func _flash() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 15
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, 0.9)
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(f)
	add_child(cl)
	var tw := create_tween()
	tw.tween_property(f, "color", Color(1, 1, 1, 0), 0.2)
	tw.tween_callback(cl.queue_free)


## 가로등. 밤길에서 유일하게 따뜻한 것이라 대충 그리면 티가 크게 난다.
func _lamp(x: float) -> void:
	var n := Node2D.new()
	n.z_index = -10
	add_child(n)
	_rect(n, Vector2(x - 8, FLOOR_Y - 430), Vector2(16, 430), Color("#2B3550"))
	_rect(n, Vector2(x - 16, FLOOR_Y - 14), Vector2(32, 14), Color("#232C44"))
	# 등갓과 알
	_rect(n, Vector2(x - 46, FLOOR_Y - 462), Vector2(92, 16), Color("#2B3550"))
	_rect(n, Vector2(x - 36, FLOOR_Y - 446), Vector2(72, 20), Color("#FFE3A0"))
	# 빛. 위는 넓게, 아래로 갈수록 좁아지게 겹쳐 원뿔을 흉내 낸다.
	for i in range(5):
		var t := float(i) / 4.0
		var half := lerpf(150.0, 42.0, t)
		_rect(n, Vector2(x - half, FLOOR_Y - 440 + t * 220.0),
			Vector2(half * 2.0, 240.0 - t * 40.0), Color(1, 0.88, 0.58, 0.035))
	# 바닥에 고이는 빛
	_rect(n, Vector2(x - 170, FLOOR_Y - 20), Vector2(340, 24), Color(1, 0.88, 0.58, 0.10))
	_rect(n, Vector2(x - 100, FLOOR_Y - 14), Vector2(200, 16), Color(1, 0.88, 0.58, 0.10))


func _rect(p: Node, pos: Vector2, size: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.color = col
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(r)
