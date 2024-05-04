# inttext_editor.gd
extends EditorProperty

const INTTEXT_EDITOR_CONTROL = preload("res://addons/dkdata_inspector/inttext_editor_control.tscn")

# The main control for editing the property.
var inttext_editor: Control
# An internal value of the property.
var current_value: IntTextResource
# A guard against internal changes when the property is updated.
var updating = false

var edit_button: Button
var refresh_button: Button
var rich_text_label: RichTextLabel

func _init() -> void:
	inttext_editor = INTTEXT_EDITOR_CONTROL.instantiate()
	# Add the control as a direct child of EditorProperty node.
	add_child(inttext_editor)
	set_bottom_editor(inttext_editor)
	rich_text_label = inttext_editor.get_node("%RichTextLabel")
	edit_button = inttext_editor.get_node("%EditButton")
	refresh_button = inttext_editor.get_node("%RefreshButton")
	refresh_control_text()
	connect_signals()

func connect_signals():
	edit_button.pressed.connect(_on_edit_item_button_pressed)
	refresh_button.pressed.connect(_on_refresh_button_pressed)

func _on_refresh_button_pressed():
	if (updating):
		return
	update_property()

func _on_edit_item_button_pressed():
	# Ignore the signal if the property is currently being updated.
	if (updating):
		return
	var edit_res = get_edited_object()[get_edited_property()]
	print(edit_res)
	emit_signal("resource_selected", edit_res.resource_path, edit_res)

func refresh_control_text():
	if current_value == null: return
	var text := "en: %s\n\nes_la: %s\n\nes_es: %s" % [
		current_value.english,
		current_value.spanish_latam,
		current_value.spanish_spain
	]
	rich_text_label.text = text

func _update_property():
	# Read the current value from the property.
	var new_value = get_edited_object()[get_edited_property()]
	# TODO this may never be true, since its a duplicated
	# prints(new_value, current_value)
	if (new_value == current_value):
		return

	# Update the control with the new value.
	updating = true
	current_value = new_value.duplicate()
	refresh_control_text()
	updating = false
