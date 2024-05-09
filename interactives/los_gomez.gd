extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	match action_id:
		"look_gomez_house":
			main_scene.say_dialogue("describe_gomez_house")
