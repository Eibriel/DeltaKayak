extends Node

signal dropped_item(item_id: int, amount: int, position: Vector3)
signal claimed_item(item_id: int, amount: int)

var player: Player
var enemies_node: Node3D

const enemies = [
	"medusa"
]

const weapons = [
	"fireball",
	"laser"
]

const ITEMS = {
	"XP":0,
	"COINS": 1
}

func drop_item(item_id: int, amount: int, position: Vector3):
	emit_signal("dropped_item", item_id, amount, position)

func claim_item(item_id: int, amount: int):
	emit_signal("claimed_item", item_id, amount)
