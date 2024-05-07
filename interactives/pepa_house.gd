extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	match action_id:
		"i_miss_pepa":
			main_scene.say_dialogue("why_pepa_left")
