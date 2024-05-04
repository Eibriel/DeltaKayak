@tool
class_name DKDataResource
extends Resource

@export var character_position: Vector3
@export var character_rotation: Vector3

@export_group("Items")
@export var items: Array[ItemResource]

@export_group("Dialogue")
@export var exchanges: Array[DialogueExchangeResource]

@export_group("Selected")
var selected_item: ItemResource
var selected_exchange: DialogueExchangeResource


func _get(property: StringName) -> Variant:
	match property:
		"selected_item":
			return selected_item
		"selected_exchange":
			return selected_exchange
	return null

func _set(property: StringName, value: Variant) -> bool:
	match property:
		"selected_item":
			selected_item = value
			return true
		"selected_exchange":
			selected_exchange = value
			return true
	return false

func _get_property_list() -> Array[Dictionary]:
	var properties:Array[Dictionary] = []

	properties.push_back({
		"name": "selected_item",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "ItemResource",
		"usage": PROPERTY_USAGE_EDITOR
	})
	
	properties.push_back({
		"name": "selected_exchange",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "DialogueExchangeResource",
		"usage": PROPERTY_USAGE_EDITOR
	})

	return properties
