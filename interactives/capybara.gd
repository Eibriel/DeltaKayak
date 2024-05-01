extends  Interactive

func _on_trigger_entered(main: DKWorld, trigger_id:String):
	main.say_dialogue("capybara1")
	
func _on_trigger_action(main: DKWorld,trigger_id:String):
	main.say_dialogue("capybara2")
