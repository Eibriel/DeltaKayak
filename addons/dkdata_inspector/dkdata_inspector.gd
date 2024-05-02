# my_inspector_plugin.gd
extends EditorInspectorPlugin

const ItemsEditor = preload("res://addons/dkdata_inspector/items_editor.gd")
const IntTextEditor = preload("res://addons/dkdata_inspector/inttext_editor.gd")

func _can_handle(object):
	if object is DKDataResource:
		return true
	elif object is ItemResource:
		return true
	elif object is ActionResource:
		return true
	return false

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	if object is DKDataResource:
		if name == "items":
			add_property_editor(name, ItemsEditor.new(), true)
			return true
	if object is ItemResource or object is ActionResource:
		if name == "label":
			add_property_editor(name, IntTextEditor.new(), true)
			return false
	return false
