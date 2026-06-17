extends Node

enum State {
    START,
    ENTER_COMPANY,
    FIND_PARTNER,
    TALK_PARTNER,
    CHOICE_WAIT,
    EAVESDROP_BOSS,
    RETURN_TO_PARTNER,
    COLLECT_TRAVEL_ITEMS,
    RETURN_BADGE,
    PARTNER_JOINED,
    FIRST_PHOTO,
    ALBUM_CREATED,
    CLEAR
}

var current_state: State = State.START
var has_camera: bool = false
var has_notebook: bool = false
var has_travel_bag: bool = false
var badge_returned: bool = false
var partner_joined: bool = false
var first_photo_taken: bool = false
var album_created: bool = false
var episode0_cleared: bool = false

signal state_changed(new_state: State)

func advance_to(new_state: State) -> void:
    current_state = new_state
    state_changed.emit(new_state)

func all_items_collected() -> bool:
    return has_camera and has_notebook and has_travel_bag
