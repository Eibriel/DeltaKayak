extends  Interactive

func _on_unhandled_trigger(main_scene, _game_state, trigger_id:String):
	var handled := true
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
		"triggerpath_demo1_003":
			pass
		"triggerpath_demo2_003":
			pass
		"triggerpath_demo_door_003":
			pass
		"triggerpath_demo_exit_003":
			print("Demo ended")
		_:
			handled = false
	print(handled)
