extends Control

var main_scene: Node

func _input(event: InputEvent) -> void:
	return
	if not visible: return
	if event.is_action_pressed("quit"):
		# BUG this dont work for some reason
		#get_tree().paused = false
		#main_scene.unpause()
		%ResumeButton.emit_signal("button_up")
		#event.
		
	if event.is_action_released("primary_action"):
		var focused := get_viewport().gui_get_focus_owner()
		# NOTE CheckButton must be first
		# because focused can be Button and
		# CheckButton at the same time
		if focused is CheckButton:
			focused.button_pressed = !focused.button_pressed
		elif focused is Button:
			focused.emit_signal("button_up")
