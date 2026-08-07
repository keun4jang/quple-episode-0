extends RefCounted
class_name TravelScenery
## 여행 화면의 배경 그림과 쿼카 커플 컷아웃을 고른다.
##
## 지금까지 여행 중 화면은 120px 짜리 색 띠와 이모지 한 글자였다. 그릴 그릇이
## 없어서였다 — 3D 맵은 짓는 데 오래 걸리고, 여행지는 197곳이다.
##
## 그런데 막(chapter) 마다 그려 둔 배경이 이미 있었고, 캐릭터 삼면도도 잘라
## 뒀다. 둘을 겹치면 여행지 화면이 된다. 그림 한 장이 맵 하나를 대신하니
## 여행지를 늘리는 값이 훨씬 싸진다.

## 막별 배경 그림. 여행지에 `chapter` 가 없으면 국내로 본다.
const CHAPTER_ART := {
	"korea": "res://assets/travel/chapter-korea.png",
	"world": "res://assets/travel/chapter-world.png",
	"space": "res://assets/travel/chapter-space.png",
	"beyond": "res://assets/travel/chapter-beyond.png",
}
## 목적지를 고르는 동안 머무는 방.
const ROOM_ART := "res://assets/travel/hub-bg.png"

const LEADER_FRONT := "res://assets/mascots/sheet/leader-front.png"
const LEADER_SIDE := "res://assets/mascots/sheet/leader-side.png"
const PARTNER_FRONT := "res://assets/mascots/sheet/partner-front.png"
const PARTNER_SIDE := "res://assets/mascots/sheet/partner-side.png"


## 이 여행지가 어느 그림 위에서 벌어지는가.
static func art_for(dest: Dictionary) -> String:
	var ch := str(dest.get("chapter", ""))
	if CHAPTER_ART.has(ch):
		return CHAPTER_ART[ch]
	return CHAPTER_ART["korea"]


static func tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
