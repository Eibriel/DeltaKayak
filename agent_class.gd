class_name Agent

var INITIAL_SPEED := 10.0
var CURRENT_SPEED := INITIAL_SPEED

var INITIAL_HEALTH := 5.0
var CURRENT_HEALTH := INITIAL_HEALTH

func _init():
	pass

func spawn_multimesh(id: int, transform: Transform3D):
	pass

func remove_multimesh(id:int):
	pass

func get_speed() -> float:
	return 0.0

