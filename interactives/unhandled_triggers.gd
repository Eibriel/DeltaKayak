extends  Interactive

func _on_unhandled_trigger(main_scene, _game_state, trigger_id:String, trigger_type:String) -> bool:
	var handled := true
	if trigger_type == "trigger_entered":
		match trigger_id:
			"triggerpath_movement_trigger_003":
				main_scene.hide_hint()
			"triggerpath_tutorial_pepa_button_003":
				main_scene.say_hint("PEPA BUTTON HINT", 10)
			"triggerpath_wrong_way_003":
				main_scene.say_dialogue("wrong_way_001", true)
			"triggerpath_wrong_wayb_003":
				main_scene.say_dialogue("wrong_way_002", true)
			"triggerpath_demo_tierra_003":
				main_scene.say_hint("LOOK BUTTON HINT", 10)
			"triggerpath_grab_tutorial_003":
				main_scene.say_hint("GRAB HINT", 20)
			"triggerpath_monster_003":
				main_scene.say_dialogue("look_monster")
				main_scene.set_player_state("monster")
	elif trigger_type == "primary_action":
		match trigger_id:
			"look_key":
				main_scene.say_dialogue("look_next_door_key")
			"take_key":
				main_scene.say_dialogue("take_next_door_key")
				_game_state.misc_data.has_next_door_key = true
				main_scene.sync_misc_data()
			"triggerpath_weird_tree_003":
				main_scene.say_dialogue("look_weird_tree")
			"triggerpath_mascot_003":
				main_scene.say_dialogue("look_mascot")
			"triggerpath_cow_003":
				main_scene.say_dialogue("look_cow")
			"triggerpath_roller_coaster_car_003":
				main_scene.say_dialogue("look_roller_coaster_car")
			"triggerpath_body_church_003":
				main_scene.say_dialogue("look_body_church")
			"triggerpath_prefectura_003":
				main_scene.say_dialogue("look_prefectura")
			"triggerpath_body_prefectura_003":
				main_scene.say_dialogue("look_body_prefectura")
			"triggerpath_gate_003":
				main_scene.say_dialogue("look_gate")
			"triggerpath_demo_door_003":
				main_scene.say_dialogue("demo_door")
				main_scene.set_player_state("puzzle_door")
			"triggerpath_demo_tierra_003":
				main_scene.say_dialogue("demo_tierra")
				main_scene.set_player_state("puzzle_tierra")
			"triggerpath_demo_carne_003":
				main_scene.say_dialogue("demo_carne")
				main_scene.set_player_state("puzzle_carne")
			"triggerpath_demo_vino_003":
				main_scene.say_dialogue("demo_vino")
				main_scene.set_player_state("puzzle_vino")
			"triggerpath_gauchito_gil_003":
				main_scene.say_dialogue("gauchito_gil")
				main_scene.set_player_state("gauchito_gil")
			"triggerpath_football_goal_003":
				main_scene.say_dialogue("football_goal")
				main_scene.set_player_state("gol")
			_:
				handled = false
	else:
		handled = false
	print(handled)
	return handled
