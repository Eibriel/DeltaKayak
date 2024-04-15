# terrain_plugin.gd
@tool
extends EditorPlugin

var import_plugin

func _enter_tree():
	import_plugin = preload("terrain_plugin.gd")
	var icon = preload("icon.svg")
	add_custom_type("Eibriel Terrain", "MeshInstance3D", import_plugin, icon)
	#add_import_plugin(import_plugin)
	#add_scene_format_importer_plugin(import_plugin)


func _exit_tree():
	#remove_import_plugin(import_plugin)
	#remove_scene_format_importer_plugin(import_plugin)
	remove_custom_type("Eibriel Terrain")
	import_plugin = null
