extends Node
## Episode 0 (사무실 → 출발) 진행 상태.
## current_state 는 정수처럼 비교되므로 순서가 곧 진행도다. (앨범 해금이 이 순서에 의존)

enum State {
	START = 0,
	ENTER_COMPANY = 1,
	FIND_PARTNER = 2,
	TALK_PARTNER = 3,
	CHOICE_WAIT = 4,
	EAVESDROP_BOSS = 5,
	RETURN_TO_PARTNER = 6,
	COLLECT_TRAVEL_ITEMS = 7,
	RETURN_BADGE = 8,
	PARTNER_JOINED = 9,
	FIRST_PHOTO = 10,
	ALBUM_CREATED = 11,
	CLEAR = 12,
}

signal state_changed(new_state: int)

## 상태별 바람 노트 목표
const OBJECTIVES := {
	State.START: "쿼카전자 안으로 들어가기",
	State.ENTER_COMPANY: "쿼카전자 안으로 들어가기",
	State.FIND_PARTNER: "사무실에서 애인 찾기",
	State.TALK_PARTNER: "애인과 이야기하기",
	State.CHOICE_WAIT: "애인과 이야기하기",
	State.EAVESDROP_BOSS: "대표실 앞에서 들어보기",
	State.RETURN_TO_PARTNER: "애인에게 돌아가기",
	State.COLLECT_TRAVEL_ITEMS: "여행 물품 3가지 챙기기",
	State.RETURN_BADGE: "로비에서 사원증 반납하기",
	State.PARTNER_JOINED: "둘이 함께 회사 밖으로 나가기",
	State.FIRST_PHOTO: "회사 앞에서 첫 사진 찍기 (F)",
	State.ALBUM_CREATED: "앨범 확인하기 (B)",
	State.CLEAR: "0편 완료",
}

func get_objective() -> String:
	return OBJECTIVES.get(current_state, "")

var current_state: int = State.START

var has_camera: bool = false
var has_notebook: bool = false
var has_travel_bag: bool = false
var badge_returned: bool = false
var partner_joined: bool = false
var first_photo_taken: bool = false
var album_created: bool = false
var episode0_cleared: bool = false
var memos_found: Array = []

func advance_to(new_state: int) -> void:
	# 되돌아가지 않는다 — 진행도는 단조 증가
	if new_state <= current_state:
		return
	current_state = new_state
	if new_state >= State.FIRST_PHOTO:
		first_photo_taken = true
	if new_state >= State.ALBUM_CREATED:
		album_created = true
	if new_state >= State.CLEAR:
		episode0_cleared = true
	state_changed.emit(new_state)

func all_items_collected() -> bool:
	return has_camera and has_notebook and has_travel_bag

func reset() -> void:
	current_state = State.START
	has_camera = false
	has_notebook = false
	has_travel_bag = false
	badge_returned = false
	partner_joined = false
	first_photo_taken = false
	album_created = false
	episode0_cleared = false
	memos_found = []

func to_dict() -> Dictionary:
	return {
		"current_state": current_state,
		"has_camera": has_camera,
		"has_notebook": has_notebook,
		"has_travel_bag": has_travel_bag,
		"badge_returned": badge_returned,
		"partner_joined": partner_joined,
		"first_photo_taken": first_photo_taken,
		"album_created": album_created,
		"episode0_cleared": episode0_cleared,
		"memos_found": memos_found,
	}

func from_dict(d: Dictionary) -> void:
	current_state = int(d.get("current_state", State.START))
	has_camera = bool(d.get("has_camera", false))
	has_notebook = bool(d.get("has_notebook", false))
	has_travel_bag = bool(d.get("has_travel_bag", false))
	badge_returned = bool(d.get("badge_returned", false))
	partner_joined = bool(d.get("partner_joined", false))
	first_photo_taken = bool(d.get("first_photo_taken", false))
	album_created = bool(d.get("album_created", false))
	episode0_cleared = bool(d.get("episode0_cleared", false))
	memos_found = d.get("memos_found", [])
