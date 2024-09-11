extends RigidBody3D
class_name Boat3D

var boat_pathfinding:BoatPathfinding
var aprox_boat_model := AproxBoatModel.new()

var time := 999999999999.0
var time_horizon := 1.0
var recalc_time := 0.1
var p0 :Vector2
var p1 :Vector2
var p2 :Vector2
var p3 :Vector2

var speed := 0.0
var force_limit_mult := 1.0
var force_limit := 5.0

var boat_speed_multiplyer := 10.0
var torque_speed := 10.0
var torque_multiplier := 1.0
var waiting := false

var last_position:Vector3
var real_velocity_integral:Vector3
var real_velocity:Vector3
var last_rotationb:float
var last_angle_to_target:float
var real_angular_velocity:float
var about_to_collide:=false

var torque := 0.0
var last_applied_torque := 0.0

var target_position := Vector3.ZERO
var target_velocity := Vector3.ZERO
var current := Vector3.ZERO

var last_rotation := 0.0
var angle_to_target := 0.0
var pid_proportional_par := 200.0#175.0 #31.0 #210.0
var pid_integral_par := 760.0 #1000.0
var pid_derivative_par := 20140.0 #8180.0

var path_visualization:Path3D
var boat_pathfinding_debug:Node3D

var last_applied_force: Vector3

var inside_turn_radius:=false

var nav_regions: Array[NavigationRegion3D]

const allow_sliding := false

func _ready():
	last_rotation = rotation.y
	last_position = position
	set_physics_process(false)
	#call_deferred("setup_physics")
	#path_target_indicator = CSGBox3D.new()
	#add_child(path_target_indicator)
	path_visualization = Path3D.new()
	path_visualization.name = "PathVisualization"
	path_visualization.top_level = true
	path_visualization.curve = Curve3D.new()
	path_visualization.curve.add_point(Vector3.ZERO, Vector3.ONE, Vector3.ONE)
	path_visualization.curve.add_point(Vector3.ONE, Vector3.ONE, Vector3.ONE)
	add_child(path_visualization)
	boat_pathfinding_debug = Node3D.new()
	boat_pathfinding_debug.name = "PathfindingDebug"
	add_child(boat_pathfinding_debug)
	boat_pathfinding = BoatPathfinding.new(boat_pathfinding_debug)
	
	

#func setup_physics():
#	set_physics_process(true)

func _get_target(_delta: float):
	pass

#
func get_torque_rotation(_target_position:Vector3):
	var rotation_vector := global_position.direction_to(_target_position)
	var _angle_to_target := Vector3.BACK.signed_angle_to(rotation_vector, Vector3.UP)
	last_angle_to_target = -_angle_to_target
	
	#Global.log_text += "\nangle_to_target: %f" % angle_to_target
	var error := angle_difference(_angle_to_target, rotation.y)
	#Global.log_text += "\nrotation.y: %f" % rotation.y
	#Global.log_text += "\nerror: %f" % error
	var poportional := get_proportional(error)
	var integral := get_integral(error)
	var derivative := get_derivative(error)
	#Global.log_text += "\npoportional: %f" % poportional
	#Global.log_text += "\nintegral: %f" % integral
	#Global.log_text += "\nderivative: %f" % derivative
	#prints(poportional, integral, derivative)
	torque = 0.0
	torque += poportional
	torque += integral
	torque += derivative
	#Global.log_text += "\ntorque: %f" % torque
	last_rotation = rotation.y
	
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
#
var local_data:Dictionary
var linear_force_to_apply: Vector3
var angular_force_to_apply: float
var old_target_position: Vector3
var previous_linear_velocity := Vector2.ZERO
var previous_angular_velocity := 0.0
func _physics_process(delta: float):
	_get_target(delta)
	#
	if not boat_pathfinding.initialized:
		initialize_pathfinding()
	elif boat_pathfinding.anim_state == boat_pathfinding.ANIM_STATES.ENDED:
		initialize_pathfinding()
	elif target_position.distance_to(old_target_position) > 10.0:
		old_target_position = target_position
		initialize_pathfinding()
	
	if not boat_pathfinding.path_found:
		boat_pathfinding.iterate_pathfinding()
	
	if boat_pathfinding.path_found:
		var frame := boat_pathfinding.subtick()
		var size_scale := 0.01
		if frame.ok:
			if frame.subtick == 0:
				if frame.frame == 0:
					local_data = {
						"linear_velocity": frame.data.linear_velocity,
						"angular_velocity": frame.data.angular_velocity,
						"yaw": frame.data.yaw,
						"position": Vector2.ZERO
					}
				else:
					var new_local_velocity = aprox_boat_model.get_velocity(
						local_data.linear_velocity,
						local_data.angular_velocity,
						aprox_boat_model.get_rudder_angle_key(frame.data.steer),
						aprox_boat_model.get_revs_per_second_key(frame.data.direction)
					)
					local_data.linear_velocity += Vector2(new_local_velocity.x, new_local_velocity.y) * size_scale
					local_data.angular_velocity += new_local_velocity.z
					local_data.position += local_data.linear_velocity.rotated(local_data.yaw)
					local_data.yaw -= local_data.angular_velocity
					var rotated_linear_velocity: Vector2= boat_pathfinding.force_mmg_to_godot(local_data.linear_velocity, local_data.yaw)
					#linear_force_to_apply = Global.bi_to_tri(rotated_linear_velocity)
					#angular_force_to_apply = local_data.angular_velocity
					# Calculate forces
					var all_force_multiplier := 1490.0
					var damp_number := 0.0112
					var angular_acceleration:float = local_data.angular_velocity * damp_number
					var angular_force:float = angular_acceleration * mass
					previous_angular_velocity = local_data.angular_velocity
					var torque_multiplier := all_force_multiplier * 10.0
					angular_force_to_apply = angular_force*torque_multiplier
					
					damp_number = 0.013
					var linear_acceleration:Vector2 = rotated_linear_velocity * damp_number
					var linear_force:Vector2 = linear_acceleration * mass
					previous_linear_velocity = rotated_linear_velocity
					var force_multiplier := all_force_multiplier * 1.0
					linear_force_to_apply = Global.bi_to_tri(linear_force)*force_multiplier
			if frame.frame != 0:
				#linear_velocity = linear_force_to_apply * mass
				#angular_velocity.y = angular_force_to_apply * mass
				apply_central_force(linear_force_to_apply)
				apply_torque(Vector3(0, angular_force_to_apply, 0))

func initialize_pathfinding():
	boat_pathfinding.initialize_pathfinding(
		Global.tri_to_bi(global_position),
		rotation.y,
		Global.tri_to_bi(target_position),
		0.0,
		get_current_velocity()[0],
		get_current_velocity()[1],
		is_obstacle
	)

func get_current_velocity():
	var current_linear_velocity := Global.tri_to_bi(linear_velocity).rotated(rotation.y+deg_to_rad(90)) * 0.1
	var current_angular_velocity := -angular_velocity.y * 0.05
	
	return [
		current_linear_velocity,
		current_angular_velocity
	]

func is_obstacle(point: Vector2):
	for nr in nav_regions:
		for pidx in nr.navigation_mesh.get_polygon_count():
			var pol := nr.navigation_mesh.get_polygon(pidx)
			var is_2d := true
			var pol_2d:PackedVector2Array
			for ppoint in pol:
				var p := nr.navigation_mesh.get_vertices()[ppoint]
				if p.y != 0:
					is_2d = false
					break
				pol_2d.append(Vector2(p.x, p.z))
			if not is_2d: continue
			var shifted_point := point - Global.tri_to_bi(nr.position)
			if Geometry2D.is_point_in_polygon(shifted_point, pol_2d):
				return false
	return true
	

func bezier_path(delta: float):
	#if allow_sliding:
	#	mass = 1.1
	#prints(last_position, position, delta)
	var new_real_velocity:Vector3 = (last_position - position) / delta
	real_velocity_integral = real_velocity-new_real_velocity
	real_velocity = new_real_velocity
	last_position = position
	#
	var new_real_angular_velocity:float = (rotation.y - last_rotationb) / delta
	real_angular_velocity = new_real_angular_velocity
	last_rotationb = rotation.y
	if waiting:
		print("waiting")
		return
	"""#get_torque_path(delta)
	get_torque_rotation(delta)
	#prints(torque, angle_to_target)
	
	apply_torque(Vector3(0, torque, 0) * torque_speed * remap(linear_velocity.length(), 0, 3, 0, 1))
	go_forward(boat_speed * boat_speed_multiplyer)"""
	time += delta
	if time > recalc_time:
		time = 0.0
		time_horizon = 2.0 # Aggressiveness
		var dist := global_position.distance_to(target_position)
		dist = min(0.1, dist)
		time_horizon = dist
		var _max_force := calculate_parameters(time_horizon)
	var t := time/time_horizon
	#print(t)
	var _cb := cubic_bezier_curve(p0, p1, p2, p3, t)
	#%CSGSphere3D2.position = Vector3(cb.x, 0, cb.y)*1
	
	var der := second_derivaive_cubic_bezier(p0, p1, p2, p3, t)
	var force_to_apply := Vector3(der.x, 0, der.y)/(time_horizon*time_horizon)
	if inside_turn_radius and not allow_sliding:
		force_to_apply = real_velocity * 1.5
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var forward_component: Vector3 = forward_direction * force_to_apply.dot(forward_direction)
	
	if false:
		#Cheat
		var sensor_data := _get_sensor_data()
		if sensor_data["right_front"] or sensor_data["right_back"]:
			Global.log_text += "\nRight"
			var left_direction := (transform.basis * Vector3.LEFT).normalized()
			apply_central_force(left_direction*10)
			if sensor_data["right_front"] and not sensor_data["right_back"]:
				apply_torque(Vector3(0, 100, 0) * torque_speed * delta)
			elif not sensor_data["right_front"] and sensor_data["right_back"]:
				apply_torque(Vector3(0, -100, 0) * torque_speed * delta)
		if sensor_data["left_front"] or sensor_data["left_back"]:
			var right_direction := (transform.basis * Vector3.RIGHT).normalized()
			apply_central_force(right_direction*10)
			if sensor_data["left_front"] and not sensor_data["left_back"]:
				apply_torque(Vector3(0, -100, 0) * torque_speed * delta)
			elif not sensor_data["left_front"] and sensor_data["left_back"]:
				apply_torque(Vector3(0, 100, 0) * torque_speed * delta)
		if sensor_data["behind"]:
			apply_central_force(forward_direction*50)
		if sensor_data["ahead"]:
			apply_central_force(-forward_direction*50)
	
	if forward_component.length() > (force_limit*force_limit_mult):
		forward_component = forward_component.normalized() * (force_limit*force_limit_mult)
	
	if allow_sliding:
		apply_central_force(force_to_apply)
		#prints("force_to_apply", force_to_apply)
		#print("target_velocity", target_velocity)
		last_applied_force = force_to_apply
	else:
		apply_central_force(forward_component)
		#prints("forward_component", forward_component)
		last_applied_force = forward_component
	#Global.log_text += "\nEnemy forward_component: %.2f" % forward_component.length()
	#var rotated_force := force_to_apply.rotated(Vector3.UP, rotation.y)
	#print(rotated_force)
	#var torque := -rotated_force.x
	get_torque_rotation(Global.bi_to_tri(p3))
	var torque_to_apply = Vector3(0, torque, 0) * torque_speed * torque_multiplier * delta
	apply_torque(torque_to_apply)
	last_applied_torque = torque_to_apply.y
	#Global.log_text += "\ntorque: %.2f" % torque
	#%CSGSphere3D.position = Vector3(der.x, 0, der.y)*1

#func go_forward(_speed:float):
	#var direction := (transform.basis * Vector3.FORWARD).normalized()
	#apply_central_force(direction * _speed)

func _integrate_forces(state:PhysicsDirectBodyState3D):
	_handle_contacts(state)
	#state.linear_velocity *= 0.9
	#state.angular_velocity *= 0.9
	var _liner_damp := 0.9
	var _angular_damp := 0.9
	
	linear_velocity *= 1.0 - _liner_damp / Engine.physics_ticks_per_second
	angular_velocity *= 1.0 - _angular_damp / Engine.physics_ticks_per_second
	
	if not allow_sliding:
		# TODO what happens when going backwards?
		var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
		# Gets only the energy going forward
		var forward_component: Vector3 = forward_direction * state.linear_velocity.dot(forward_direction)
		# Gets only the energy not going forward
		var side_component: Vector3 = state.linear_velocity - forward_component
		#prints("side_component",side_component)
		# Transfers the energy not going forward to going forward
		var transferred_energy: Vector3 = forward_direction * side_component.length()
		var side_drag := 0.4 # TODO depends on velocity
		var calculated_velocity := Vector3.ZERO
		calculated_velocity += side_component * side_drag
		calculated_velocity += forward_component
		#calculated_velocity += transferred_energy * (1.0 - side_drag)
		calculated_velocity += current
		state.linear_velocity = calculated_velocity

func _handle_contacts(_state: PhysicsDirectBodyState3D):
	pass

func _get_sensor_data() -> Dictionary:
	return {}

# Cubic Bezier path planning
func calculate_parameters(_time_horizon:float) -> float:
	var start_pos := Global.tri_to_bi(position)
	var start_vel := Vector2.ZERO #Global.tri_to_bi(linear_velocity)
	#var predicted_pos: Vector3= target_position+(target_velocity*_time_horizon)
	#var end_pos := Global.tri_to_bi(predicted_pos)
	var end_pos := Global.tri_to_bi(target_position)
	var end_vel :=  Global.tri_to_bi(target_velocity)
	p0 = start_pos
	p1 = start_pos + (start_vel * (_time_horizon/3.0) )
	p2 = end_pos - (end_vel * (_time_horizon/3.0) )
	p3 = end_pos
	path_visualization.curve.set_point_position(0, Global.bi_to_tri(p0, 0.2))
	path_visualization.curve.set_point_out(0, Global.bi_to_tri(p1)-Global.bi_to_tri(p0))
	path_visualization.curve.set_point_in(1, Global.bi_to_tri(p2)-Global.bi_to_tri(p3))
	path_visualization.curve.set_point_position(1, Global.bi_to_tri(p3, 0.2))
	
	var max_force_a := Global.bi_to_tri(second_derivaive_cubic_bezier(p0, p1, p2, p3, 0))
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var forward_component: Vector3 = forward_direction * max_force_a.dot(forward_direction)
	return forward_component.length()
	
func cubic_bezier_curve(_p0:Vector2, _p1:Vector2, _p2:Vector2, _p3:Vector2, i:float) -> Vector2:
	var xya:Vector2 = lerp(_p0, _p1, i)
	var xyb:Vector2 = lerp(_p1, _p2, i)
	var xyc:Vector2 = lerp(_p2, _p3, i)
	var xym:Vector2 = lerp(xya, xyb, i)
	var xyn:Vector2 = lerp(xyb, xyc, i)
	var xy:Vector2 = lerp(xym, xyn, i)
	return xy

func second_derivaive_cubic_bezier(_p0:Vector2, _p1:Vector2, _p2:Vector2, _p3:Vector2, i:float) -> Vector2:
	var der:=Vector2.ZERO
	der.x = (6.0*(1.0-i)*(_p2.x-(2.0*_p1.x)+_p0.x)) + (6.0*i*(_p3.x - (2.0*_p2.x) + _p1.x))
	der.y = (6.0*(1.0-i)*(_p2.y-(2.0*_p1.y)+_p0.y)) + (6.0*i*(_p3.y - (2.0*_p2.y) + _p1.y))
	return der
