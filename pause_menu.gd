extends Control

var main_scene: Node

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		# BUG this dont work for some reason
		#get_tree().paused = false
		#main_scene.unpause()
		pass
