extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	if action_id == "trigger_entered":
		main_scene.say_dialogue("demo_start_point")
