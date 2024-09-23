extends RigidBody3D

var simple_boat_model := SimpleBoatModel.new()
var simple_boat_model_sim := SimpleBoatModel.new()

var revs_per_second:=10.0
var rudder_angle:=0.0

var target_position:Vector3
var subtarget_position:Vector3

func _ready() -> void:
	print("Loading BoatModel")
	simple_boat_model.configure(10.0)
	simple_boat_model_sim.configure(10.0)
	
	setup_boat_model(
		simple_boat_model_sim,
		linear_velocity,
		angular_velocity.y,
		global_position,
		rotation.y)
	
	#rotation.y = deg_to_rad(0)


func _process(delta: float) -> void:
	%SteerLabel.text = "Steer: %dº" % rad_to_deg(rudder_angle)
	%RevsLabel.text = "Revs: %d" % float(revs_per_second)
	%Rudder.rotation.y = rudder_angle + deg_to_rad(-90)
	target_position = %NavTarget.global_position
	
	%NavStart.global_position = subtarget_position

var set_count := 0
var max_dist_search := 50
var context_steering := ContextSteering.new()
func _physics_process(delta: float) -> void:
	context_steering.resolution = 4
	context_steering.next()
	context_steering.set_debug_node(%DebugMeshInstance.mesh)
	
	subtarget_position = target_position
	var direct_sight:=true
	if target_position != %BoatRayCast.global_position:
		%BoatRayCast.target_position = Vector3(0, 0, -global_position.distance_to(target_position))
		%BoatRayCast.look_at(target_position)
		%BoatRayCast.force_raycast_update()
		if %BoatRayCast.is_colliding():
			direct_sight = false
	
	if not direct_sight:
		%BoatRayCast.rotation.y = -rotation.y
		%BoatRayCast.target_position = Vector3(max_dist_search, 0, 0)
		for rad in context_steering.get_angles():
			var vect := Vector3.LEFT.rotated(Vector3.UP, rad) * max_dist_search
			%BoatRayCast.target_position = vect
			%BoatRayCast.force_raycast_update()
			if %BoatRayCast.is_colliding():
				context_steering.append(
					global_position.distance_to(%BoatRayCast.get_collision_point())
				)
			else:
				context_steering.append(max_dist_search)
	
		var angle_to_target := Global.tri_to_bi(global_position).angle_to_point(Global.tri_to_bi(target_position))
		angle_to_target = Global.pi_2_pi(-angle_to_target+deg_to_rad(180))
		var angle := context_steering.get_direction(angle_to_target, delta)
		subtarget_position = Vector3.LEFT.rotated(Vector3.UP, angle)*10 + global_position
		#subtarget_position = Vector3.RIGHT.rotated(Vector3.DOWN, angle_to_target)*10 + global_position
	
	get_action(delta)
	move_boat(delta)
	sim_step(delta)
	get_rudder_angle(
		subtarget_position
	)
	

func get_action(delta:float):
	pass

var last_rotation:float
var pid_proportional_par := 1.0
var pid_integral_par := 1.0
var pid_derivative_par := 10.0
func get_rudder_angle(target_position: Vector3):
	# TODO switch from Vector3 to Vector2
	var rotation_vector := global_position.direction_to(target_position)
	var angle_to_target := Vector3.RIGHT.signed_angle_to(rotation_vector, Vector3.UP)
	
	var forward_direction := Vector3.RIGHT.rotated(Vector3.UP, rotation.y)
	var direction_error := (target_position-global_position).normalized().dot(forward_direction)
	#%SimForce.global_position = (target_position-global_position).normalized()*5
	#%NavStart.global_position = forward_direction * 10
	#prints(direction_error)
	var error := angle_difference(angle_to_target, rotation.y)
	var poportional := get_proportional(error)
	var integral := get_proportional(error)
	var derivative := get_derivative(error)
	#prints(poportional, integral, derivative)
	rudder_angle = 0.0
	rudder_angle += poportional
	rudder_angle += integral
	rudder_angle += derivative
	rudder_angle = Global.pi_2_pi(rudder_angle)
	rudder_angle = clampf(rudder_angle, deg_to_rad(-45), deg_to_rad(45))
	last_rotation = rotation.y
	
	direction_error = Global.pi_2_pi(direction_error)
	#print(error)
	if abs(direction_error) > 0.5:
		revs_per_second = 20
	else:
		revs_per_second = 10
	if direction_error < 0:
		revs_per_second *= -1.0
		rudder_angle *= -1.0

# PID control Torque
func get_proportional(error) -> float:
	# Minimizes error
	# Adds
	return error * pid_proportional_par

func get_integral(_error) -> float:
	# External perturvations (inertia)
	# Compensates
	var integral = angular_velocity.y * pid_integral_par
	return -integral

func get_derivative(_error) -> float:
	# Error change speed
	# Substracts
	var derivative = last_rotation - rotation.y
	if absf(derivative) > PI:
		if rotation.y > last_rotation:
			derivative = -(last_rotation + rotation.y)
		else:
			derivative = -(rotation.y + last_rotation)
	return derivative * pid_derivative_par

func future_position(delta:float, _revs_per_second:float, _rudder_angle: float) -> bool:
	setup_boat_model(
			simple_boat_model,
			linear_velocity,
			angular_velocity.y,
			global_position,
			rotation.y)
	
	for _n in 500:
		simple_boat_model.calculate_boat_forces(
			_revs_per_second,
			_rudder_angle
		)
		simple_boat_model.step(delta)
	%FutureColision.global_position = Global.bi_to_tri(simple_boat_model.position)
	%FutureColision.rotation.y = -simple_boat_model.rotation
	%FutureColisionCast.force_shapecast_update()
	return %FutureColisionCast.is_colliding()

func move_boat(delta: float) -> void:
	setup_boat_model(
			simple_boat_model,
			linear_velocity,
			angular_velocity.y,
			global_position,
			rotation.y)
	
	var forces_to_apply := simple_boat_model.calculate_boat_forces(
		revs_per_second,
		rudder_angle
	)
	simple_boat_model.step(delta)
	
	var torque_to_apply := forces_to_apply.z
	var force_to_apply := Vector3(forces_to_apply.x, 0.0, forces_to_apply.y)
	apply_torque(Vector3(0, -torque_to_apply, 0))
	apply_central_force(force_to_apply)

func sim_step(delta):
	simple_boat_model_sim.calculate_boat_forces(
		revs_per_second,
		rudder_angle
	)
	simple_boat_model_sim.step(delta)
	%SimBoat.global_position = Global.bi_to_tri(simple_boat_model_sim.position)
	%SimBoat.rotation.y = -simple_boat_model_sim.rotation

func setup_boat_model(
		boat_model:SimpleBoatModel,
		_linear_velocity:Vector3,
		_angular_velocity:float,
		_position:Vector3,
		_rotation:float):
	boat_model.linear_velocity = Global.tri_to_bi(_linear_velocity)
	boat_model.angular_velocity = _angular_velocity
	boat_model.position = Global.tri_to_bi(_position)
	#boat_model.rotation = -_rotation+deg_to_rad(90)
	boat_model.rotation = -_rotation

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var dvel := simple_boat_model.damped_velocity(
		Global.tri_to_bi(state.linear_velocity),
		state.angular_velocity.y,
		Engine.physics_ticks_per_second,
		-rotation.y
	)
	state.linear_velocity = Global.bi_to_tri(dvel[0])
	state.angular_velocity = Vector3(0, dvel[1], 0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		#new_path_requested = true
		pass
	elif event.is_action_pressed("ui_up"):
		#apply_impulse(Vector3.FORWARD.rotated(Vector3.UP, rotation.y)*10)
		%NavTarget.position.z -= 5.0
	elif event.is_action_pressed("ui_down"):
		#apply_impulse(Vector3.BACK.rotated(Vector3.UP, rotation.y)*10)
		%NavTarget.position.z += 5.0
	elif event.is_action_pressed("ui_right"):
		#apply_torque_impulse(Vector3(0,+50,0))
		%NavTarget.position.x += 5.0
	elif event.is_action_pressed("ui_left"):
		#apply_torque_impulse(Vector3(0,-50,0))
		%NavTarget.position.x -= 5.0
