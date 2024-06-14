class_name Interactive

var main_node:Node

func _on_trigger(_main, _state, _action_id:String):
	pass

func _on_unhandled_trigger(_main, _state, _trigger_id:String):
	pass

func _register_main(main:Node):
	main_node = main
