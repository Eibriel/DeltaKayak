extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	match action_id:
		"prices_are_up":
			main_scene.say_dialogue("prices_are_up")
