extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	match action_id:
		"look_key":
			main_scene.say_dialogue("look_next_door_key")
		"take_key":
			main_scene.say_dialogue("take_next_door_key")
			_game_state.misc_data.has_next_door_key = true
			main_scene.sync_misc_data()
