# my_inspector_plugin.gd
extends EditorInspectorPlugin

const ItemsEditor = preload("res://addons/dkdata_inspector/items_editor.gd")
const CSVExporter = preload("res://addons/dkdata_inspector/csv_exporter.gd")
# const IntTextEditor = preload("res://addons/dkdata_inspector/inttext_editor.gd")

func _can_handle(object):
	if object is DKDataResource:
		return true
	elif object is ItemResource:
		return true
	elif object is ActionResource:
		return true
	elif object is DialogueExchangeResource:
		return true
	return false

func _parse_begin(object: Object) -> void:
	if object is DKDataResource:
		add_custom_control(CSVExporter.new())

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	if object is DKDataResource:
		if name == "items":
			var editor := ItemsEditor.new()
			editor.setup(ItemResource)
			add_property_editor(name, editor, true)
			return true
		if name == "exchanges":
			var editor := ItemsEditor.new()
			editor.setup(DialogueExchangeResource)
			add_property_editor(name, editor, true)
			return true
	if object is ItemResource or object is ActionResource:
		#if name == "label":
		#	add_property_editor(name, IntTextEditor.new(), true)
		#	return false
		if name == "actions":
			var editor := ItemsEditor.new()
			editor.setup(ActionResource)
			add_property_editor(name, editor, true)
			return true
	if object is DialogueExchangeResource:
		if name == "dialogues":
			var editor := ItemsEditor.new()
			editor.setup(DialogueResource)
			add_property_editor(name, editor, true)
			return true
	return false
