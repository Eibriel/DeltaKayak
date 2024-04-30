# plugin.gd
@tool
extends EditorPlugin

var LocalizationMenu = preload("res://addons/dkdata/dkdata_menu.tscn")
var menu

func _enter_tree():
	menu = LocalizationMenu.instantiate()
	menu.name = "DK Data"
	get_editor_interface().get_editor_main_screen().add_child(menu)
	_make_visible(false)

func _exit_tree():
	if menu:
		menu.queue_free()
	menu = null

func _make_visible(visible):
	if menu:
		menu.visible = visible

func _has_main_screen() -> bool:
	return true

func _get_plugin_name():
	return "DK Data"
