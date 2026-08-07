extends SideEpisode
## 로비. 회사 앞과 사무실 사이.
##
## 여기서 엘리베이터를 탄다. 3D 때는 문 하나로 순간이동하듯 층이 바뀌었는데,
## 옆에서 보면 **층이 실제로 있다** — 아래에서 위로 올라가는 것이 눈에 보이고,
## 나올 때 사원증을 반납하는 자리도 그 아래에 남는다.

## 2층 높이. 여기서 사무실로 넘어간다.
const UPPER_Y := 320.0

var _badge_spot: Area2D


func map_title() -> String:
	return "쿼카전자 로비"


func build() -> void:
	set_bounds(3400.0, 380.0)
	# 그려 받은 그림이 있으면 그것을 쓰고, 없으면 코드로 그린다.
	if not use_backdrop("lobby"):
		IndoorParts.skyline(self, 3400.0, FLOOR_Y, 3)
		IndoorParts.room(self, 3400.0, FLOOR_Y, 300.0, 620.0, 520.0)
		IndoorParts.ceiling_lights(self, 3400.0, 120.0, 700.0)
		IndoorParts.floor_pools(self, 3400.0, FLOOR_Y, 700.0)
	var painted := _backdrop != null
	IndoorParts.floor_slab(self, -200, FLOOR_Y, 3800, 320.0, painted)

	# 안내 데스크
	IndoorParts.desk(self, 900, FLOOR_Y, 420, false, painted)

	# 사원증 반납함
	var bx := 1500.0
	var n := Node2D.new()
	add_child(n)
	# 반납함도 그림에 맞춘다. 남색 상자에 형광 하늘색 화면이 박혀 있으면
	# 크림·나무 톤 로비에서 그것만 튀어 캐릭터에게 갈 시선을 뺏는다.
	_rect(n, Vector2(bx - 70, FLOOR_Y - 210), Vector2(140, 210),
		IndoorParts.WARM_LEG if painted else Color("#46587A"))
	_rect(n, Vector2(bx - 54, FLOOR_Y - 190), Vector2(108, 26),
		Color("#3A2E2B") if painted else Color("#1B2438"))
	_rect(n, Vector2(bx - 46, FLOOR_Y - 140), Vector2(92, 60),
		Color("#C7A98C") if painted else Color("#7FA6C4"))
	_badge_spot = spot(bx, "사원증 반납하기", _return_badge)

	# 2층 통로와 엘리베이터
	Parts.platform(self, 2100, UPPER_Y, 1300, 40, true,
		IndoorParts.WARM_TOP if painted else IndoorParts.FLOOR_TOP,
		IndoorParts.WARM_LEG if painted else IndoorParts.FLOOR_BODY)
	# 엘리베이터 바닥판(두께 20, 가운데 기준)의 **윗면**이 로비 바닥과
	# 정확히 같은 높이여야 한다. 10px 만 솟아도 옆에서 걸어오다 그 턱에
	# 막힌다 — 시뮬레이션이 실제로 여기서 걸어오다 멈췄다. 위층도 같은
	# 이유로 통로 윗면과 맞춘다.
	Parts.elevator(self, 2260, UPPER_Y + 10, FLOOR_Y + 10)
	# 계단으로도 올라갈 수 있게 둔다. 엘리베이터를 못 찾아 갇히면 안 된다.
	#
	# 색은 반드시 실내 것으로 준다. 기본값이 풀·흙이라 그대로 두면 로비
	# 한가운데에 초록 계단이 선다 — 실제로 그렇게 나왔다.
	Parts.stairs(self, 2600, UPPER_Y, 620, FLOOR_Y - UPPER_Y, 9, true,
		IndoorParts.WARM_TOP if painted else IndoorParts.FLOOR_TOP,
		IndoorParts.WARM_LEG if painted else IndoorParts.FLOOR_BODY)

	door(280.0, "회사 밖으로", "res://scenes/maps/CompanyFront3D.tscn")
	door(3150.0, "사무실로", "res://scenes/maps/Office3D.tscn", "normal", UPPER_Y)


func on_enter() -> void:
	AudioManager.play_ambient("room")
	if Episode0State.current_state == Episode0State.State.ENTER_COMPANY:
		Episode0State.advance_to(Episode0State.State.FIND_PARTNER)
		await get_tree().create_timer(0.5).timeout
		await say("조용한 로비. 위층에만 불이 켜져 있어요.", 0.0)


func _return_badge() -> void:
	if Episode0State.current_state < Episode0State.State.RETURN_BADGE:
		await say("사원증 반납함이에요. 회사를 나설 때 여기에 넣으면 돼요.", 0.0)
		return
	if Episode0State.badge_returned:
		await say("사원증은 이미 반납했어요.", 0.0)
		return
	Episode0State.badge_returned = true
	await say("사원증을 반납했어요. 이제 정말 나가는 거예요.", 0.0)
	Episode0State.partner_joined = true
	Episode0State.advance_to(Episode0State.State.PARTNER_JOINED)
	spawn_partner()


func _rect(p: Node, pos: Vector2, size: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.color = col
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(r)
