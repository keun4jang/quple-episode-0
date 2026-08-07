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

	# 회사 건물. 오른쪽에 서 있고, 4층 창 하나에만 불이 켜져 있다.
	var b := Node2D.new()
	b.z_index = -20
	add_child(b)
	_rect(b, Vector2(2200, FLOOR_Y - 980), Vector2(1300, 980), Color("#26324C"))
	_rect(b, Vector2(2200, FLOOR_Y - 980), Vector2(1300, 26), Color("#33415F"))
	for row in range(5):
		for col in range(5):
			# 4층 왼쪽 끝 하나만 켜져 있다. 그 창이 이 이야기의 시작이다.
			var lit := row == 1 and col == 0
			_rect(b, Vector2(2270 + col * 240, FLOOR_Y - 900 + row * 170),
				Vector2(150, 110), Color("#FFE7A8") if lit else Color("#1B2540"))
	_rect(b, Vector2(2180, FLOOR_Y - 300), Vector2(1340, 24), Color("#3A4A6A"))

	# 회사 앞은 먼 하늘만 그림으로 바꾸므로 인도는 늘 코드가 그린다.
	Parts.platform(self, -200, FLOOR_Y, 4000, 320, false,
		Color("#4C5570"), Color("#333B52"))
	# 가로등. 밤길이 새까맣기만 하면 걸어갈 마음이 안 난다.
	for x in [700.0, 1900.0, 3100.0]:
		_lamp(x)

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
		await say("빛나는 자리에 서서 눌러요.", 0.0)


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
	SaveManager.autosave("res://scenes/maps/CompanyFront3D.tscn")
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


func _lamp(x: float) -> void:
	var n := Node2D.new()
	n.z_index = -10
	add_child(n)
	_rect(n, Vector2(x - 9, FLOOR_Y - 420), Vector2(18, 420), Color("#3D4A66"))
	_rect(n, Vector2(x - 52, FLOOR_Y - 448), Vector2(104, 30), Color("#FFD76D"))
	_rect(n, Vector2(x - 200, FLOOR_Y - 430), Vector2(400, 440), Color(1, 0.86, 0.5, 0.06))


func _rect(p: Node, pos: Vector2, size: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.color = col
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(r)
