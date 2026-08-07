extends SideEpisode
## 사무실. 애인이 야근하고 있는 곳이자 0편에서 가장 오래 머무는 곳.
##
## 여행 물품 셋을 여기서 챙긴다. 3D 때는 책상 하나에 셋을 몰아 놨는데,
## 옆에서 보면 한눈에 다 보여서 찾는 맛이 없다. 그래서 사무실 전체에
## 흩어 놓고, 하나는 사다리를 타야 닿는 선반 위에 둔다.

var _partner_spot: Area2D
var _items := {}          # 이름 -> {spot, art}


func map_title() -> String:
	return "쿼카전자 4층 사무실"


func build() -> void:
	set_bounds(4200.0, 420.0)
	# 그려 받은 그림이 있으면 그것을 쓰고, 없으면 코드로 그린다.
	if not use_backdrop("office"):
		IndoorParts.skyline(self, 4200.0, FLOOR_Y, 5)
		IndoorParts.room(self, 4200.0, FLOOR_Y, 300.0, 600.0, 480.0)
		IndoorParts.ceiling_lights(self, 4200.0, 120.0, 900.0)
		IndoorParts.floor_pools(self, 4200.0, FLOOR_Y, 900.0)
	IndoorParts.floor_slab(self, -200, FLOOR_Y, 4600)

	# 애인의 책상. 여기만 모니터가 켜져 있다 —
	# 불 꺼진 사무실에서 그 빛 하나가 "아직 남아 있다" 를 말한다.
	IndoorParts.desk(self, 1180, FLOOR_Y, 360, true)
	_partner_spot = spot(1360.0, "애인에게 말 걸기", talk_to_partner)
	if partner == null and not Episode0State.partner_joined:
		_stand_partner(1420.0)

	# 다른 자리들 — 불이 꺼져 있다
	IndoorParts.desk(self, 300, FLOOR_Y, 320, false)
	IndoorParts.desk(self, 2200, FLOOR_Y, 320, false)

	# 여행 물품 셋
	_item("camera", 2340.0, FLOOR_Y - 168.0, "카메라", Color("#C9D6E4"))
	_item("notebook", 3000.0, FLOOR_Y - 20.0, "수첩", Color("#E5C98C"))
	# 가방은 선반 위. 사다리를 타야 닿는다.
	Parts.platform(self, 3300, FLOOR_Y - 420, 620, 34, true,
		IndoorParts.FLOOR_TOP, IndoorParts.FLOOR_BODY)
	Parts.ladder(self, 3380, FLOOR_Y - 420, 420)
	_item("bag", 3700.0, FLOOR_Y - 420.0, "여행 가방", Color("#D98E62"))

	door(180.0, "로비로", "res://scenes/maps/CompanyLobby3D.tscn")
	door(4020.0, "복도로", "res://scenes/maps/BossDoorHallway3D.tscn", "tense")
	_refresh_items()


func on_enter() -> void:
	AudioManager.play_ambient("room")


# ─────────────────────────────── 물품 ───────────────────────────────

func _item(id: String, x: float, y: float, label: String, col: Color) -> void:
	var art := Node2D.new()
	add_child(art)
	var r := ColorRect.new()
	r.color = col
	r.size = Vector2(64, 52)
	r.position = Vector2(x - 32, y - 52)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(r)
	var glow := ColorRect.new()
	glow.color = Color(1, 0.9, 0.6, 0.18)
	glow.size = Vector2(150, 150)
	glow.position = Vector2(x - 75, y - 110)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.z_index = -1
	art.add_child(glow)
	var s := spot(x, label + " 챙기기", func(): _pick(id), true)
	# 자리는 물건 높이에 맞춘다. 선반 위 물건을 바닥에서 집으면 안 된다.
	s.position.y = y + 10.0
	_items[id] = {"spot": s, "art": art}


func _pick(id: String) -> void:
	match id:
		"camera":
			Episode0State.has_camera = true
			await say("카메라를 챙겼어요.", 0.0)
		"notebook":
			Episode0State.has_notebook = true
			await say("수첩을 챙겼어요.", 0.0)
		"bag":
			Episode0State.has_travel_bag = true
			await say("여행 가방을 챙겼어요.", 0.0)
	_refresh_items()


## 이미 챙긴 것은 치운다. 남아 있으면 몇 개 남았는지 알 수 없다.
func _refresh_items() -> void:
	var have := {
		"camera": Episode0State.has_camera,
		"notebook": Episode0State.has_notebook,
		"bag": Episode0State.has_travel_bag,
	}
	for id in _items:
		var got: bool = have.get(id, false)
		_items[id]["art"].visible = not got
		lock_spot(_items[id]["spot"], got)


# ─────────────────────────────── 애인 ───────────────────────────────

## 아직 합류 전이면 자기 책상 앞에 서 있다.
func _stand_partner(x: float) -> void:
	var tex := load("res://assets/mascots/sheet/partner-front.png") as Texture2D
	if tex == null:
		return
	var sp := Sprite2D.new()
	sp.name = "PartnerAtDesk"
	sp.texture = tex
	var s := 168.0 / float(tex.get_height())
	sp.scale = Vector2(s, s)
	sp.offset = Vector2(0, -tex.get_height() * 0.5)
	sp.position = Vector2(x, FLOOR_Y)
	add_child(sp)


func talk_to_partner() -> void:
	var st := Episode0State.current_state
	if st == Episode0State.State.FIND_PARTNER:
		Episode0State.advance_to(Episode0State.State.TALK_PARTNER)
		await say("애인: \"아직 안 갔어? 나도 지금 막 퇴근하려던 참이야.\"", 2.0)
		hide_say()
		choice_box.show_choices("지금 같이 나가자", "조금만 더 이야기해보자")
		choice_box.choice_made.connect(_on_choice, CONNECT_ONE_SHOT)
	elif st == Episode0State.State.RETURN_TO_PARTNER:
		await say("애인: \"대표님이 뭐라고 하시던? ...괜찮아, 우리 그냥 나가자.\"", 2.0)
		hide_say()
		Episode0State.advance_to(Episode0State.State.COLLECT_TRAVEL_ITEMS)
	elif st == Episode0State.State.COLLECT_TRAVEL_ITEMS:
		if Episode0State.all_items_collected():
			await say("애인: \"다 챙겼어? 그럼 가자!\"", 0.0)
			Episode0State.advance_to(Episode0State.State.RETURN_BADGE)
		else:
			await say("애인: \"여행 물품 3가지 챙기는 거 잊지 마.\"", 0.0)
	elif st >= Episode0State.State.PARTNER_JOINED:
		await say("애인: \"이제 나가자. 밖에서 사진 한 장 찍고.\"", 0.0)
	elif st == Episode0State.State.RETURN_BADGE:
		if not Episode0State.badge_returned:
			await say("애인: \"로비에서 사원증만 반납하고 오면 돼.\"", 0.0)
		else:
			await say("애인: \"사원증 반납했구나. 그럼 나가자!\"", 0.0)
			Episode0State.partner_joined = true
			Episode0State.advance_to(Episode0State.State.PARTNER_JOINED)
			SceneTransition.go_to("res://scenes/maps/CompanyFront3D.tscn")


## 어느 쪽을 골라도 대표실 앞을 지나간다. 그 장면이 0편의 전환점이기 때문이다.
func _on_choice(index: int) -> void:
	Episode0State.advance_to(Episode0State.State.CHOICE_WAIT)
	if index == 0:
		await say("애인: \"그래, 가자. ...근데 대표님께 말은 하고 가야 하지 않을까?\"", 2.4)
	else:
		await say("애인: \"잠깐, 아까부터 대표실 쪽에서 소리가 나는 것 같아...\"", 2.4)
	hide_say()
	Episode0State.advance_to(Episode0State.State.EAVESDROP_BOSS)
	SceneTransition.go_to("res://scenes/maps/BossDoorHallway3D.tscn", "tense")
