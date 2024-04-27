extends  Interactive

func _register_trigger():
	var triggers = {
		"trigger_001_001": [
			"trigger_visible",
			"trigger_entered",
			"trigger_close",
			"trigger_action",
			"trigger_far",
			"trigger_exited"
		]
	}
	return triggers


func _on_trigger(id:String, type:String):
	#prints(id, type)
	if type == "trigger_entered":
		main_node.set_dialogue("Hay un carpincho en el muelle...")
	elif type == "trigger_action":
		main_node.set_dialogue("Carpincho: ¡Hola!")
