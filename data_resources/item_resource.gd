@tool
class_name ItemResource
extends Resource

@export var id: String
@export var label: String
@export var active: bool = true
@export var visible: bool = true
@export var trigger_name:String
@export var logic: GDScript

#@export_flags("Visible", "Entered", "Close", "Action", "Far", "Exited", "Hidden") var trigger_on = 0

#@export_group("Actions")
#@export var actions: Array[ActionResource]

@export var primary_action: String
@export var secondary_action: String

@export var actions: Array[ActionResource]

var selected_action: ActionResource


func _get(property: StringName) -> Variant:
	match property:
		"selected_action":
			return selected_action
	return null

func _set(property: StringName, value: Variant) -> bool:
	match property:
		"selected_action":
			selected_action = value
			return true
	return false

func _get_property_list() -> Array[Dictionary]:
	var properties:Array[Dictionary] = []

	properties.push_back({
		"name": "selected_action",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "ActionResource",
		"usage": PROPERTY_USAGE_EDITOR
	})

	return properties
