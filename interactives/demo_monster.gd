extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	if action_id == "trigger_entered":
		if not _game_state.misc_data.met_monster:
			main_scene.say_dialogue("demo_monster")
			_game_state.misc_data.met_monster = true
