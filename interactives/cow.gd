extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	match action_id:
		"look_cow":
			main_scene.say_dialogue("look_cow")
