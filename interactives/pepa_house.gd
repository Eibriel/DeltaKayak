extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	match action_id:
		"this_is_pepas_home":
			main_scene.say_dialogue("i_must_add_food")
		"i_miss_pepa":
			main_scene.say_dialogue("why_pepa_left")
