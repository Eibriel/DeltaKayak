extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	match action_id:
		"look_mascot":
			main_scene.say_dialogue("look_mascot")
