extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	match action_id:
		"this_is_a_big_tree":
			main_scene.say_dialogue("this_is_a_big_tree")
