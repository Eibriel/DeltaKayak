extends RigidBody3D

@onready var target_box = $CSGBox3D
@onready var pepa: Node3D = %pepa
@onready var camera: Camera3D = %CharacterCamera3D
@onready var marker_3d: Marker3D = $Marker3D

var soft_camera_rotation: float
var speed := 0.0
var torque := 0.0

var kayak_speed := 15.0 + 5.0
var temp_speed := 0.0
var temp_time := 0.0
var strength := 0

var last_rotation := 0.0
var target_direction := 0.0

var current := Vector3.ZERO
var current_direction = Vector3.FORWARD
var current_speed := 0.2

func _ready():
	#position = Vector3(-31.8, 0, -5)
	#position = Vector3(34.7, 0, -5)
	last_rotation = rotation.y
	Global.character = self
	pepa.get_node("AnimationPlayer").play("Sitting")
	print("Transform")
	print($CSGCylinder3D3.transform)
	print($CSGCylinder3D3.global_transform)

func _process(delta: float) -> void:
	if temp_time > 0:
		temp_time -= delta
	elif temp_time < 0:
		temp_time = 0
	marker_3d.position = position
	var input_dir:Vector2 = Input.get_vector("left", "right", "up", "down")
	var movement_direction:Vector2 = input_dir * delta * 2.0
	var current_camera:Camera3D = get_viewport().get_camera_3d()
	
	var ration:float = 0.99-(0.1*delta)
	soft_camera_rotation = lerp_angle(current_camera.rotation.y, soft_camera_rotation, ration)
	
	var local_target_position := movement_direction.rotated(-soft_camera_rotation) * 100.0
	target_box.global_position = position + Vector3(local_target_position.x, 0.0, local_target_position.y)
	
	var target_position_with_rotation := local_target_position.rotated(rotation.y)
	var global_target_rotation := -Vector2.UP.angle_to(target_position_with_rotation)
	target_direction = global_target_rotation
	
	#Global.log_text += "\ntarget_direction: %f" % target_direction
	#Global.log_text += "\nrotation.y: %f" % (rotation.y)
	if temp_time == 0:
		temp_speed = 0.0
	speed = -max(0, -target_position_with_rotation.y) * delta * (kayak_speed + temp_speed + (strength * 5))
	var error := target_direction
	#Global.log_text += "\nerror: %f" % error
	#Global.log_text += "\nproportional: %f" % get_proportional(error)
	#Global.log_text += "\nintegral: %f" % get_integral(error)
	#Global.log_text += "\nderivative: %f" % get_derivative(error)
	torque = 0.0
	if input_dir.length() > 0:
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
#

func _physics_process(delta: float):
	apply_torque(Vector3(0, torque, 0))
	go_forward(speed)
	get_current()
	# Current
	#current *= 0.999
	current = current_direction * current_speed * delta
	#Global.log_text += "\ncurrent.x: %f" % current.x
	#Global.log_text += "\ncurrent.y: %f" % current.y
	#Global.log_text += "\ncurrent.z: %f" % current.z

func go_forward(_speed:float):
	var direction := (transform.basis * Vector3.BACK).normalized()
	apply_central_force(direction * _speed)

func _integrate_forces(state:PhysicsDirectBodyState3D):
	if true:#paddle_status !=0 and holding:
		state.linear_velocity *= 0.999
		state.angular_velocity *= 0.999
	else:
		state.linear_velocity *= 0.999
		state.angular_velocity *= 0.99
	#Global.log_text += "\nvelocity.x: %f" % state.linear_velocity.x
	#Global.log_text += "\nvelocity.z: %f" % state.linear_velocity.z
	# TODO make it smooth intead of step
	if state.linear_velocity.length() > 1.0:
		var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
		var forward_component: Vector3 = forward_direction * state.linear_velocity.dot(forward_direction)
		var side_component: Vector3 = state.linear_velocity - forward_component
		var side_drag := 0.99
		state.linear_velocity = (side_component * side_drag) + forward_component + current
	else:
		state.linear_velocity += current

func get_current() -> void:
	current_direction = Vector3.FORWARD
	current_speed = 0.2
	var world_definition = Global.main_scene.dk_world.world_definition
	var min_dist = null
	var min_rotation: Vector3
	var min_scale: Vector3
	for s in world_definition:
		for c in world_definition[s].current:
			var dist := position.distance_squared_to(array_to_vector3(c.position))
			if min_dist == null:
				min_dist = dist
				min_rotation = array_to_vector3(c.rotation)
				min_scale = array_to_vector3(c.scale)
			if dist < min_dist:
				min_dist = dist
				min_rotation = array_to_vector3(c.rotation)
				min_scale = array_to_vector3(c.scale)
	current_direction = Vector3.FORWARD.rotated(Vector3.UP, min_rotation.y)
	current_speed = min_scale.length() * 10
	if min_dist > 10:
		current_speed = 0.0

func array_to_vector3(array: Array) -> Vector3:
	return Vector3(array[0], array[1], array[2])

func array_to_quaternion(array: Array) -> Quaternion:
	return Quaternion(array[0], array[1], array[2], array[3])


func _on_interaction_area_area_entered(area: Area3D) -> void:
	if area.has_meta("oil_spill"):
		temp_speed = 10.0
		temp_time = 3.0
	elif area.has_meta("strength"):
		area.free()
		strength += 1
