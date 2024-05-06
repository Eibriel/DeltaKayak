extends  Interactive

func _on_trigger(main_scene, _game_state, action_id:String):
	match action_id:
		"pet_capybara":
			main_scene.say_dialogue("pet_capybara")
