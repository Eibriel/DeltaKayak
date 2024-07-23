extends Control

func _input(event: InputEvent) -> void:
	if not visible: return
		
	if event.is_action_released("primary_action"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button:
			focused.emit_signal("button_up")
