extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	match action_id:
		"look_door":
			main_scene.say_dialogue("look_next_door")
		"open_door":
			if _game_state.misc_data.has_next_door_key:
				main_scene.say_dialogue("open_next_door")
				_game_state.misc_data.next_door_open = true
				main_scene.sync_misc_data()
			else:
				main_scene.say_dialogue("need_next_door_key")
