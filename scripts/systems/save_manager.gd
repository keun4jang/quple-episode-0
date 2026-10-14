extends Node
## 저장 창구. 자동 로드 목록(`project.godot`)은 APK 를 새로 깔아야 바뀌어서 이름과 자리를 그대로 둔다.
## 예전 게임의 저장은 없애고, 지금 게임의 저장(`IdleState`)으로 이어 주는 얇은 껍데기다.


func has_save() -> bool:
	return IdleState.has_save()


func save_now() -> void:
	# 게임 화면이 아닐 때(메뉴 등)는 아직 안 읽은 상태일 수 있어 덮어쓰지 않는다.
	if IdleState.has_save() and IdleState.kills > 0:
		IdleState.save(int(Time.get_unix_time_from_system()))


func clear_save() -> void:
	IdleState.clear_save()
