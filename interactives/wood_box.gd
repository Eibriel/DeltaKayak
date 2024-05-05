extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	print(action_id)
	match action_id:
		"analice_box":
			main_scene.say_dialogue("analice_box")
		"intimidate_box":
			main_scene.say_dialogue("intimidate_box")
