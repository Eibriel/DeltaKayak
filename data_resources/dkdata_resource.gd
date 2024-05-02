class_name DKDataResource
extends Resource

@export var character_position: Vector3
@export var character_rotation: Vector3

@export_group("Items")
@export var items: Array[ItemResource]

@export_group("Dialogue")
@export var exchanges: Array[DialogueExchangeResource]
