@tool
extends Control

@onready var items_tree: Tree = %ItemsTree
@onready var item_name_label: Label = %ItemNameLabel

const DKDATA = preload("res://dkdata/dkdata.tres")

var undo_redo

func _ready() -> void:
	setup_character()
	setup_items()

func setup_items() -> void:
	items_tree.clear()
	var root = items_tree.create_item()
	items_tree.hide_root = true
	for i in DKDATA.items:
		var child1 = items_tree.create_item(root)
		child1.set_text(0, i.id)
		child1.set_metadata(0, i)

func _on_item_selection() -> void:
	var selected = items_tree.get_selected()
	var item:ItemResource = selected.get_metadata(0)
	item_name_label.text = item.id

func _on_add_item() -> void:
	var item := ItemResource.new()
	item.id = "New Item"
	DKDATA.items.append(item)
	setup_items()

func setup_character() -> void:
	remove_focus(%CharacterXPosition)
	remove_focus(%CharacterYPosition)
	remove_focus(%CharacterZPosition)
	#
	remove_focus(%CharacterXRotation)
	remove_focus(%CharacterYRotation)
	remove_focus(%CharacterZRotation)
	
	direct_connection(DKDATA, "character_position:x", %CharacterXPosition, "value_changed")
	direct_connection(DKDATA, "character_position:y", %CharacterYPosition, "value_changed")
	direct_connection(DKDATA, "character_position:z", %CharacterZPosition, "value_changed")
	#
	direct_connection(DKDATA, "character_rotation:x", %CharacterXRotation, "value_changed")
	direct_connection(DKDATA, "character_rotation:y", %CharacterYRotation, "value_changed")
	direct_connection(DKDATA, "character_rotation:z", %CharacterZRotation, "value_changed")

func direct_connection(resource:Resource, data: String, object: Object, signal_name: String) -> void:
	object.value = resource.get_indexed(data)
	var f = func(new_value):
		var current_value = resource.get_indexed(data)
		undo_redo.create_action("Undo generated %d %d" % [new_value, current_value])
		undo_redo.add_do_method(resource, "set_indexed", data, new_value)
		undo_redo.add_undo_method(resource, "set_indexed", data, current_value)
		undo_redo.add_undo_method(object, "set_value_no_signal", current_value)
		undo_redo.commit_action()
	object.connect(signal_name, f)

func remove_focus(spinbox: SpinBox):
	(spinbox.get_line_edit() as LineEdit).focus_mode = Control.FOCUS_NONE
