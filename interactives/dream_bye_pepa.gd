extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	if action_id == "trigger_entered":
		#main_scene.say_dialogue("dream_start_point")
		_game_state.misc_data.pepa_visible = false
		main_scene.sync_misc_data()
		main_scene.character.position = Vector3(-1.3, 0, -4.7)
		main_scene.character.rotation = Vector3(0, deg_to_rad(-90), 0)
