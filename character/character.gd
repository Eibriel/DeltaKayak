extends RigidBody3D

@onready var target_box := $CSGBox3D
@onready var pepa: Node3D = %pepa
@onready var camera: Camera3D = %CharacterCamera3D
@onready var marker_3d: Marker3D = $Marker3D
@onready var grabbing_position: Marker3D = $GrabbingPosition


var soft_camera_rotation: float
var speed := 0.0
var torque := 0.0
var going_backwards := false
var damage := 0.0
var damage_timer := 0.0

var kayak_speed := 15.0
var temp_speed := 0.0
var temp_time := 0.0
var strength := 0

var last_rotation := 0.0
var target_direction := 0.0

var current := Vector3.ZERO
var current_direction = Vector3.FORWARD
var current_speed := 0.2

var grabbing_object: RigidBody3D
var grabbing_object_position: Vector3
var grabbing_state = GRABBING.NO

enum GRABBING {
	WANTS_TO,
	YES,
	NO
}

func _ready():
	#position = Vector3(-31.8, 0, -5)
	#position = Vector3(34.7, 0, -5)
	last_rotation = rotation.y
	Global.character = self
	pepa.get_node("AnimationPlayer").play("Sitting")
	#print("Transform")
	#print($CSGCylinder3D3.transform)
	#print($CSGCylinder3D3.global_transform)
	

func _process(delta: float) -> void:
	if temp_time > 0:
		temp_time -= delta
	elif temp_time < 0:
		temp_time = 0
	# Damage
	damage_timer -= delta
	if damage_timer < 0: damage_timer = 0
	damage -= delta*0.25
	if damage < 0: damage = 0
	%DamageLight.light_energy = damage * 0.1
	#
	marker_3d.position = position
	var input_dir:Vector2 = Input.get_vector("left", "right", "up", "down")
	var movement_direction:Vector2 = input_dir * delta * 2.0
	var current_camera:Camera3D = get_viewport().get_camera_3d()
	
	var ration:float = 0.99-(0.1*delta)
	soft_camera_rotation = lerp_angle(current_camera.rotation.y, soft_camera_rotation, ration)
	
	var local_target_position := movement_direction.rotated(-soft_camera_rotation) * 100.0
	
	target_box.global_position = global_position + Vector3(local_target_position.x, 0.0, local_target_position.y)
	var target_position_with_rotation := local_target_position.rotated(rotation.y)
	var global_target_rotation := -Vector2.UP.angle_to(target_position_with_rotation)
	target_direction = global_target_rotation
	going_backwards = false
	if PI - abs(target_direction) < 0.5:
		going_backwards = true
		Global.log_text += "\nBackwards"
	
	if going_backwards:
		if target_direction > 0:
			target_direction = target_direction-PI
		else:
			target_direction = target_direction+PI
	#Global.log_text += "\ntarget_direction: %f" % target_direction
	#Global.log_text += "\nrotation.y: %f" % (rotation.y)
	if temp_time == 0:
		temp_speed = 0.0
	#speed = -max(0, -target_position_with_rotation.y) * delta * (kayak_speed + temp_speed + (strength * 5))
	speed = -abs(target_position_with_rotation.y) * delta * (kayak_speed + temp_speed + (strength * 5))
	var error := target_direction
	#Global.log_text += "\nspeed: %f" % speed
	#Global.log_text += "\nerror: %f" % error
	#Global.log_text += "\nproportional: %f" % get_proportional(error)
	#Global.log_text += "\nintegral: %f" % get_integral(error)
	#Global.log_text += "\nderivative: %f" % get_derivative(error)
	torque = 0.0
	if input_dir.length() > 0:
		torque += get_proportional(error) * delta
		torque += get_integral(error) * delta
		torque += get_derivative(error) * delta
	if grabbing_state == GRABBING.YES:
		torque *= 5
	#Global.log_text += "\ntorque: %f" % torque

	last_rotation = rotation.y
	handle_grabbing()

# PID control
func get_proportional(error) -> float:
	# Minimizes error
	# Adds
	var proportional = error
	proportional *= 40.0 #20.0
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
	
	return derivative*2000.0#1000.0
#

func handle_grabbing():
	if Input.is_action_pressed("grab"):
		%GrabRay.visible = true
		match grabbing_state:
			GRABBING.NO:
				#grabbing_state = GRABBING.WANTS_TO
				grabbing_state = GRABBING.YES
				$RayCast3D.force_raycast_update()
				if $RayCast3D.is_colliding():
					var body = $RayCast3D.get_collider()
					Global.grab_joint.global_position = $GrabbingPosition.global_position
					Global.grab_joint.set_node_a(get_path())
					Global.grab_joint.set_node_b(body.get_path())

	else:
		%GrabRay.visible = false
		grabbing_state = GRABBING.NO
		Global.grab_joint.set_node_a(NodePath(""))
		Global.grab_joint.set_node_b(NodePath(""))
		set_collision_mask_value(3, true)
	#NOTE grabbing using velocity:
	"""
	if grabbing_state != GRABBING.YES: return
	var a = grabbing_object.to_global(grabbing_object_position)
	var b = grabbing_position.global_position
	grabbing_object.set_linear_velocity((b-a)*1)
	#grabbing_object.apply_force(b-a,grabbing_object_position)
	"""

func _physics_process(delta: float):
	apply_torque(Vector3(0, torque, 0))
	if not going_backwards:
		go_forward(speed)
	else:
		go_backward(speed)
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

func go_backward(_speed:float):
	var direction := (transform.basis * Vector3.FORWARD).normalized()
	apply_central_force(direction * _speed)

func _integrate_forces_old(state:PhysicsDirectBodyState3D):
	#if true:#paddle_status !=0 and holding:
		#state.linear_velocity *= 0.999
		#state.angular_velocity *= 0.999
	#else:
		#state.linear_velocity *= 0.999
		#state.angular_velocity *= 0.99
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

# TODO duplicated in boat_class.gd
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	handle_contacts(state)
	#if grabbing_state == GRABBING.YES:
	#	state.linear_velocity *= 0.99
	
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var backward_direction := (transform.basis * Vector3.BACK).normalized()
	#prints(forward_direction, backward_direction)
	# Gets only the energy going forward and backwards
	var forward_component: Vector3 = forward_direction * state.linear_velocity.dot(forward_direction)
	var backward_component: Vector3 = backward_direction * state.linear_velocity.dot(backward_direction)
	#prints(forward_component, backward_component)
	# Gets only the energy not going forward
	var side_component: Vector3 = state.linear_velocity - forward_component
	# Transfers the energy not going forward to going forward
	var transferred_energy: Vector3 = forward_direction * side_component.length()
	var side_drag := 0.99 # TODO depends on velocity
	var calculated_velocity := Vector3.ZERO
	calculated_velocity += side_component * side_drag
	calculated_velocity += forward_component
	calculated_velocity += transferred_energy * (1.0 - side_drag)
	calculated_velocity += current
	state.linear_velocity = calculated_velocity

func handle_contacts(state: PhysicsDirectBodyState3D):
	if state.get_contact_count() > 0:
		var body = state.get_contact_collider_object(0)
		if body.has_meta("grabbable"):
			if grabbing_state == GRABBING.WANTS_TO:
				grabbing_object = body
				grabbing_position.global_position = body.global_position
				grabbing_object_position = body.to_local(state.get_contact_collider_position(0))
				grabbing_state = GRABBING.YES
				#$GrabJoint3D.set_node_b(body.get_path())
				var vector_to_body = to_local(body.global_position)
				body.global_position = to_global(vector_to_body*1.2)
				#set_collision_mask_value(3, false)
				#body.set_collision_mask_value(1, false)
				print("GRAB")
			if grabbing_state == GRABBING.YES and grabbing_object == body:
				grabbing_position.global_position = body.global_position

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

func set_damage():
	if damage_timer > 0: return
	damage += 1.0
	damage_timer = 1.0
	var tween := create_tween()
	tween.tween_property(%DamageIndicator, "scale", Vector3.ZERO, 0.1)
	tween.tween_property(%DamageIndicator, "scale", Vector3.ONE, 0.1)
	tween.tween_property(%DamageIndicator, "scale", Vector3.ZERO, 0.1)
	if damage > 10:
		get_tree().quit()
