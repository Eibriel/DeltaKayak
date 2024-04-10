# dkworld_import.gd
@tool
extends EditorPlugin

var import_plugin

func _enter_tree():
	import_plugin = preload("import_plugin.gd").new()
	add_import_plugin(import_plugin)
	#add_scene_format_importer_plugin(import_plugin)


func _exit_tree():
	remove_import_plugin(import_plugin)
	#remove_scene_format_importer_plugin(import_plugin)
	import_plugin = null
