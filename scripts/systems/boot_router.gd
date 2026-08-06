extends Node
## 게임을 메인 화면부터 시작하게 한다.
##
## project.godot 의 run/main_scene 은 오래 거리 씬을 가리키고 있었다.
## 그래서 메인 화면이 만들어져 있는데도 아무도 못 봤다.
##
## 그 값은 APK 에 구워져서 리소스 팩 갱신으로는 못 바꾼다. 그래서 두 가지를 같이 한다.
##   1. project.godot 을 고친다 — 다음 APK 부터는 이 파일이 할 일이 없다.
##   2. 이미 깔린 앱에서는 부팅 첫 프레임에 메인 화면으로 돌린다 — 갱신으로 전달된다.
##
## 부팅 때 딱 한 번만 돈다. CompanyFront3D 는 게임 중에도 다시 들어오는 씬이라,
## 매번 검사하면 이야기 도중에 메뉴로 튕겨 나간다.

const MENU := "res://scenes/menu/MainMenu3D.tscn"
const LEGACY_BOOT := "res://scenes/maps/CompanyFront3D.tscn"

var _routed := false


func _ready() -> void:
	add_to_group("boot_router")
	await get_tree().process_frame
	_route_once()


func _route_once() -> void:
	if _routed:
		return
	_routed = true
	var scene := get_tree().current_scene
	if scene == null:
		return
	# 구운 시작 씬이 옛 값일 때만 돌린다
	if scene.scene_file_path != LEGACY_BOOT:
		return
	if not ResourceLoader.exists(MENU):
		return
	get_tree().change_scene_to_file(MENU)
