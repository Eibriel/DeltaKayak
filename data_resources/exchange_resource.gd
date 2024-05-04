@tool
class_name DialogueExchangeResource
extends Resource

@export var id: String
@export var dialogues: Array[DialogueResource]

var selected_dialogue: DialogueResource


func _get(property: StringName) -> Variant:
	match property:
		"selected_dialogue":
			return selected_dialogue
	return null

func _set(property: StringName, value: Variant) -> bool:
	match property:
		"selected_dialogue":
			selected_dialogue = value
			return true
	return false

func _get_property_list() -> Array[Dictionary]:
	var properties:Array[Dictionary] = []

	properties.push_back({
		"name": "selected_dialogue",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "DialogueResource",
		"usage": PROPERTY_USAGE_EDITOR
	})

	return properties
