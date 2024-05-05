extends RigidBody3D

@onready var target_box = $CSGBox3D

var soft_camera_rotation: float
#var target_position: Vector3 = Vector3.ZERO
var speed := 0.0
var torque := 0.0

var last_rotation := 0.0
var integral := 0.0

#TODO kayak points backwards

func _ready():
	#position = Vector3(-31.8, 0, -5)
	#position = Vector3(34.7, 0, -5)
	last_rotation = rotation.y
	Global.character = self

func _process(delta: float) -> void:
	var input_dir:Vector2 = Input.get_vector("left", "right", "up", "down")
	var movement_direction:Vector3 = Vector3(input_dir.x, 0, input_dir.y) * delta * 2.0
	var current_camera:Camera3D = get_viewport().get_camera_3d()
	var ration:float = 0.99-(0.1*delta)
	soft_camera_rotation = lerp_angle(current_camera.rotation.y, soft_camera_rotation, ration)
	
	var local_target_position := movement_direction.rotated(Vector3.UP, soft_camera_rotation) * 100.0
	target_box.global_position = position + local_target_position
	# var target_distance := Vector3.ZERO.distance_to(local_target_position)
	
	# TODO the kayak points backwards
	var target_position_with_rotation := local_target_position.rotated(Vector3.DOWN, rotation.y)
	var global_target_rotation := Vector3.FORWARD.angle_to(target_position_with_rotation)
	if target_position_with_rotation.x < 0:
		global_target_rotation *= -1
	#var target_global_vector := Vector3.ZERO.direction_to(local_target_position)
	#var target_local_vector := target_global_vector.rotated(Vector3.UP, rotation.y)
	#var target_local_angle := angle_difference(target_global_angle, rotation.y)
	#prints(global_target_rotation, target_position_with_rotation)
	#prints(target_global_angle, rotation.y, target_local_angle)
	
	speed = max(0, target_position_with_rotation.z) * delta * 50.0
	#torque = global_target_rotation * 0.1
	torque = 0.0
	torque += get_proportional(global_target_rotation) * delta
	torque += get_derivative() * delta
	torque += get_integral(global_target_rotation) * delta
	#print(torque)

# PID control
func get_proportional(error) -> float:
	var proportional = error
	proportional *= 50.0
	return proportional

func get_derivative() -> float:
	var derivative =  angle_difference(rotation.y, last_rotation)
	last_rotation = rotation.y
	return derivative * 5000.0

func get_integral(error) -> float:
	integral += error
	return clamp(integral*0.001, -1.0, 1.0)
#

func _physics_process(_delta: float):
	apply_torque(Vector3(0, torque, 0))
	#prints(speed, torque)
	go_forward(speed)

func go_forward(_speed:float):
	var direction := (transform.basis * Vector3.BACK).normalized()
	apply_central_force(direction * _speed)

func _integrate_forces(state):
	if true:#paddle_status !=0 and holding:
		state.linear_velocity *= 0.99
		state.angular_velocity *= 0.999
	else:
		state.linear_velocity *= 0.999
		state.angular_velocity *= 0.99
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var forward_component: Vector3 = forward_direction * state.linear_velocity.dot(forward_direction)
	state.linear_velocity = forward_component
