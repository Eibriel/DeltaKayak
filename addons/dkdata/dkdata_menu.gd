@tool
extends Control

func _ready() -> void:
	$Button.connect("button_up", _on_button_button_up)

func _on_button_button_up() -> void:
	print("BUTTON")
	var source_file := "res://dkdata/delta_kayak.dkdata"
	var file = FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		print("File not found")
		#return FileAccess.get_open_error()
		return

	var json_string = file.get_as_text()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	var world_definition:Dictionary = {}
	if error == OK:
		world_definition = json.data
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
	
	print(world_definition)
