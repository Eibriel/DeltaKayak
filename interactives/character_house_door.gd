extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	match action_id:
		"open_house_door":
			main_scene.say_dialogue("open_house_door")
			_game_state.misc_data.house_door_open = true
			main_scene.sync_misc_data()
