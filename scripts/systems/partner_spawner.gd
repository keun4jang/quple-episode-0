class_name PartnerSpawner
extends RefCounted
## 애인이 합류한 뒤에는 어느 맵에 가든 함께 있어야 한다.
## 각 맵의 _ready 에서 PartnerSpawner.ensure(self, player) 한 줄만 부르면 된다.

const PARTNER_SCENE := "res://scenes/characters/PartnerQuokka3D.tscn"
const NODE_NAME := "PartnerQuokka3D"

## 합류 상태면 맵에 애인을 세우고 따라오게 한다. 이미 있으면 그대로 쓴다.
static func ensure(map: Node, player: Node3D, offset := Vector3(1.1, 0.0, 0.7)) -> Node:
	var state := _state()
	if state == null or not state.partner_joined:
		return null

	var partner: Node = map.get_node_or_null(NODE_NAME)
	if partner == null:
		var ps := load(PARTNER_SCENE) as PackedScene
		if ps == null:
			return null
		partner = ps.instantiate()
		partner.name = NODE_NAME
		map.add_child(partner)

	# 플레이어 옆에 세운다 (겹치지 않게)
	if player != null and partner is Node3D:
		(partner as Node3D).global_position = player.global_position + offset

	if partner.has_method("join_player"):
		partner.join_player()
	return partner

static func _state() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null:
		return null
	return (loop as SceneTree).root.get_node_or_null("Episode0State")
