extends Node
## 벽을 벽으로 만든다.
##
## 이 게임의 씬에는 **solid 콜리전이 하나도 없었다.** 전 씬 StaticBody3D 0개.
## 그래서 플레이어가 벽과 건물을 그대로 통과했고, 카메라가 벽을 피하려고 쏘는
## 레이(`free_look.gd:_avoid_walls`)는 맞을 물체가 없어 죽은 코드였다.
##
## 씬마다 손으로 CollisionShape 를 다는 대신, 재질·모서리와 같은 방식으로
## 실행할 때 한 번 훑어서 붙인다. 그래야 나중에 소품을 추가해도 저절로 걸린다.
##
## 무엇에 붙일지는 **이름**으로 고른다. 이 게임의 메시는 전부 코드가 만들고
## 이름을 붙여 두기 때문에 그게 가장 확실한 단서다. 소품마다 벽을 세우면
## 좁은 실내에서 플레이어가 낀다. 막아야 하는 것만 막는다.

## 이 이름으로 시작하면 막는다.
const SOLID := [
	"Wall", "BackWall", "LeftWall", "RightWall", "FrontWall",
	"Building", "Ceiling", "Pillar", "Column",
	"Counter", "Desk", "Cabinet", "Shelf", "Locker",
	"BossDoor", "Door", "Partition", "Divider",
	"Fence", "Railing", "Parapet", "VendingMachine",
]

## 이 이름으로 시작하면 막지 않는다. 위 목록보다 우선한다.
##
## 바닥은 막지 않는다 — 이 게임은 중력을 쓰지 않고 y 를 고정해 걷는다.
## 바닥에 몸통을 세우면 캐릭터가 그 위로 튕겨 올라간다.
const OPEN := [
	"Floor", "Ground", "Road", "Sidewalk", "Rug", "Crosswalk",
	"DoorGlass", "Window", "WallShelf", "WallArt", "WallPoster",
	"Baseboard", "ShelfBoard", "ShelfBracket", "DeskLamp", "DeskMonitor",
]

## 벽 두께가 얇아도 이만큼은 두껍게 잡는다. 얇은 판은 빠르게 지나가면 뚫린다.
const MIN_THICK := 0.35

var _added := 0


func _ready() -> void:
	add_to_group("collision_kit")
	# 씬이 다 세워진 뒤에 훑는다. 스크립트가 _ready 에서 만드는 메시도 잡아야 한다.
	await get_tree().process_frame
	await get_tree().process_frame
	_walk(get_tree().current_scene)
	print("[CollisionKit] 벽 %d 개" % _added)


func _walk(n: Node) -> void:
	if n == null:
		return
	if n is MeshInstance3D and _is_solid(n.name):
		_add_body(n)
	for c in n.get_children():
		_walk(c)


func _is_solid(node_name: String) -> bool:
	for o in OPEN:
		if node_name.begins_with(o):
			return false
	for s in SOLID:
		if node_name.begins_with(s):
			return true
	return false


func _add_body(mi: MeshInstance3D) -> void:
	# 이미 몸통이 달려 있으면 두 번 달지 않는다
	for c in mi.get_children():
		if c is StaticBody3D:
			return
	var aabb := mi.get_aabb()
	if aabb.size.length() < 0.05:
		return

	var body := StaticBody3D.new()
	body.name = "AutoBody"
	# 플레이어(레이어 2)와 카메라 레이만 상대한다. 상호작용 영역과 섞이면 안 된다.
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(
		maxf(aabb.size.x, MIN_THICK),
		maxf(aabb.size.y, MIN_THICK),
		maxf(aabb.size.z, MIN_THICK))
	shape.shape = box
	shape.position = aabb.position + aabb.size * 0.5
	body.add_child(shape)
	mi.add_child(body)
	_added += 1
