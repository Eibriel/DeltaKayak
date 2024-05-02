# plugin.gd
@tool
extends EditorPlugin

var plugin


func _enter_tree():
	plugin = preload("res://addons/dkdata_inspector/dkdata_inspector.gd").new()
	add_inspector_plugin(plugin)


func _exit_tree():
	remove_inspector_plugin(plugin)
