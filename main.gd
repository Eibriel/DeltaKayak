extends Control

func _enter_tree():
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_button_button_up():
	var game_scene := preload("res://game.tscn")
	get_tree().change_scene_to_packed(game_scene)


func _on_button_2_button_up():
	get_tree().quit()
