# items_editor.gd
extends EditorProperty

const ITEMS_EDITOR_CONTROL = preload("res://addons/dkdata_inspector/items_editor_control.tscn")

# The main control for editing the property.
var items_editor: Control
# An internal value of the property.
# var current_value: Array[ItemResource]
var current_value: Array
# A guard against internal changes when the property is updated.
var updating = false

var new_item_button: Button
var remove_item_button: Button
var size_label: Label
var items_tree: Tree
var item_name_label: Label
var edit_item_button: Button
var reload_array_button: Button

var resource_type

func _init() -> void:
	items_editor = ITEMS_EDITOR_CONTROL.instantiate()
	# Add the control as a direct child of EditorProperty node.
	add_child(items_editor)
	set_bottom_editor(items_editor)
	# Make sure the control is able to retain the focus.
	# add_focusable($VBoxContainer/Button)
	# Setup the initial state and connect to the signal to track changes.
	new_item_button = items_editor.get_node("%NewItemButton")
	remove_item_button = items_editor.get_node("%RemoveItemButton")
	size_label = items_editor.get_node("%SizeLabel")
	items_tree = items_editor.get_node("%ItemsTree")
	item_name_label = items_editor.get_node("%ItemNameLabel")
	edit_item_button = items_editor.get_node("%EditItemButton")
	reload_array_button = items_editor.get_node("%ReloadArrayButton")
	refresh_control_text()
	connect_signals()

func setup(_resource_type):
	resource_type = _resource_type

func connect_signals():
	new_item_button.pressed.connect(_on_new_item_button_pressed)
	remove_item_button.pressed.connect(_on_remove_item_button_pressed)
	items_tree.cell_selected.connect(_on_item_selection)
	edit_item_button.pressed.connect(_on_edit_item_button_pressed)
	reload_array_button.pressed.connect(_on_reload_array_button_pressed)

func _on_reload_array_button_pressed():
	if (updating):
		return
	update_property()

func _on_edit_item_button_pressed():
	# Ignore the signal if the property is currently being updated.
	if (updating):
		return
	var selected = items_tree.get_selected()
	if selected == null: return
	#var item:ItemResource = selected.get_metadata(0)
	var item = selected.get_metadata(0)
	emit_signal("resource_selected", item.resource_path, item)

func _on_new_item_button_pressed():
	# Ignore the signal if the property is currently being updated.
	if (updating):
		return
	#var new_item = ItemResource.new()
	var new_item = resource_type.new()
	new_item.id = "new_item"
	current_value.append(new_item)
	refresh_control_text()
	emit_changed(get_edited_property(), current_value)

func _on_remove_item_button_pressed():
	# Ignore the signal if the property is currently being updated.
	if (updating):
		return
	var selected = items_tree.get_selected()
	if selected == null: return
	current_value.remove_at(selected.get_meta("array_id"))
	refresh_control_text()
	emit_changed(get_edited_property(), current_value)

func _on_item_selection() -> void:
	var selected = items_tree.get_selected()
	if selected == null: return
	#var item:ItemResource = selected.get_metadata(0)
	var item = selected.get_metadata(0)
	item_name_label.text = item.id
	var dkdata = get_edited_object()
	if item is ItemResource:
		dkdata.selected_item = item
	elif item is DialogueExchangeResource:
		dkdata.selected_exchange = item
	elif item is DialogueResource:
		dkdata.selected_dialogue = item
	elif item is ActionResource:
		dkdata.selected_action = item
	refresh_control_text()
	emit_changed(get_edited_property(), current_value)
	

func _update_property():
	# Read the current value from the property.
	var new_value = get_edited_object()[get_edited_property()]
	# TODO this may be always true, since its a reference
	# prints(new_value, current_value)
	if (new_value == current_value):
		return

	# Update the control with the new value.
	updating = true
	current_value = new_value.duplicate()
	refresh_control_text()
	updating = false

func refresh_control_text():
	var text := "Items: " + str(current_value.size())
	size_label.text = text

	items_tree.clear()
	var root = items_tree.create_item()
	# items_tree.hide_root = true
	var array_id := 0
	for i in current_value:
		var element = items_tree.create_item(root)
		element.set_text(0, i.id)
		element.set_metadata(0, i)
		element.set_meta("array_id", array_id)
		array_id += 1
