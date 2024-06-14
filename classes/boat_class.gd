extends RigidBody3D
class_name Boat3D

var speed := 0.0

var boat_speed := 1.0
var torque := 0.0

var target := Vector3.ZERO
var target_direction := 0.0

var last_rotation := 0.0

func _ready():
	last_rotation = rotation.y

func _get_target(delta: float):
	pass

func get_torque(delta:float):
	var rotation_vector := global_position.direction_to(Global.character.global_position)
	var angle_to_target := Vector3.BACK.signed_angle_to(rotation_vector, Vector3.UP)
	
	#Global.log_text += "\nangle_to_target: %f" % angle_to_target
	var error := angle_difference(angle_to_target, rotation.y)
	#Global.log_text += "\nrotation.y: %f" % rotation.y
	#Global.log_text += "\nerror: %f" % error
	torque = 0.0
	torque += get_proportional(error) * delta
	torque += get_integral(error) * delta
	torque += get_derivative(error) * delta
	#Global.log_text += "\ntorque: %f" % torque
	last_rotation = rotation.y
	
# PID control
func get_proportional(error) -> float:
	# Minimizes error
	# Adds
	var proportional = error
	proportional *= 20.0
	return proportional

func get_integral(_error) -> float:
	# External perturvations (inertia)
	# Compensates
	var integral = angular_velocity.y
	return integral

func get_derivative(_error) -> float:
	# Error change speed
	# Substracts
	var derivative = last_rotation - rotation.y
	if absf(derivative) > PI:
		if rotation.y > last_rotation:
			derivative = -(last_rotation + rotation.y)
		else:
			derivative = -(rotation.y + last_rotation)
	
	return derivative*1000.0

func _physics_process(delta: float):
	get_torque(delta)
	apply_torque(Vector3(0, torque, 0))
	go_forward(boat_speed)

func go_forward(_speed:float):
	var direction := (transform.basis * Vector3.FORWARD).normalized()
	apply_central_force(direction * _speed)

