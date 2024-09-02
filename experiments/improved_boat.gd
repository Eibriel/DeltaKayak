extends RigidBody3D

"""
Boat issues:
	- Oscilación al rotar (no se decide para que lado girar)
	- Rotating also changes the position, if center of mass is at 0,0,0
	- Force boat to manage bad curves

Navigation Issues:
	- How to get curve cost?
"""

var time := 999999999999.0
var time_horizon := 2.0
var recalc_time := 0.01
var p0 :Vector2
var p1 :Vector2
var p2 :Vector2
var p3 :Vector2

var last_rotation := 0.0
var angle_to_target := 0.0
var pid_proportional_par := 200.0 #210.0
var pid_integral_par := 760.0 #1000.0
var pid_derivative_par := 20140.0 #8180.0

var torque := 0.0
var torque_speed := 1.0

var previous_forward_component:Vector3

var target_position:Vector3 = Vector3.ONE
var target_velocity:Vector3 = Vector3.ONE

enum TEST_SESSIONS {ONLY_PATH, REACH_TARGET, NAVIGATION}
const TEST_SESSSION = TEST_SESSIONS.NAVIGATION

const scenarios = [
	{
		"name": "stright line",
		"velocity": 0,
		"rotation": 0,
		"target": Vector2(0, 20),
		"target_velocity": Vector2(0, 10)
	},
	{
		"name": "oposite velocity easy",
		"velocity": 10,
		"rotation": 0,
		"target": Vector2(0, 20),
		"target_velocity": Vector2(0, 10)
	},
	{
		"name": "u turn",
		"velocity": 10,
		"rotation": 0,
		"target": Vector2(20, 0),
		"target_velocity": Vector2(0, 10)
	},
	{
		"name": "s turn",
		"velocity": 10,
		"rotation": 0,
		"target": Vector2(20, 0),
		"target_velocity": Vector2(0, -10)
	}
]

const scenarios_path =[
	{
		"time": 0.1, # Down
		"start_pos": Vector2(0,0),
		"start_vel": Vector2(0,0),
		"target_pos": Vector2(0,20),
		"target_vel": Vector2(0,0)
	},
	{
		"time": 0.1, # Right
		"start_pos": Vector2(0,0),
		"start_vel": Vector2(0,0),
		"target_pos": Vector2(20,0),
		"target_vel": Vector2(0,0)
	},
	{
		"time": 0.1, # Up Right
		"start_pos": Vector2(0,0),
		"start_vel": Vector2(0,0),
		"target_pos": Vector2(20,-10),
		"target_vel": Vector2(0,0)
	},
	{
		"time": 2.0, # Down Right Curve
		"start_pos": Vector2(0,0),
		"start_vel": Vector2(0,0),
		"target_pos": Vector2(20,20),
		"target_vel": Vector2(20,0)
	},
	{
		"time": 2.0, # Up Right Curve
		"start_pos": Vector2(0,0),
		"start_vel": Vector2(0,0),
		"target_pos": Vector2(20,-20),
		"target_vel": Vector2(20,0)
	}
]

var current_scenario = 0
var set_scenario = -1

var current_nav_point = -1

func _ready() -> void:
	%TimeHorizonSlider.value = time_horizon
	%TimeRefreshSlider.value = recalc_time
	set_scenario = current_scenario

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		match TEST_SESSSION:
			TEST_SESSIONS.REACH_TARGET:
				current_scenario += 1
				if current_scenario >= scenarios.size():
					current_scenario = 0
				set_scenario = current_scenario
				set_physics_process(true)
				#configure_scenario(current_scenario)
			TEST_SESSIONS.NAVIGATION:
				next_navigation_point()

func _physics_process(delta: float) -> void:
	time += delta
	match TEST_SESSSION:
		TEST_SESSIONS.ONLY_PATH:
			test_path(delta)
		TEST_SESSIONS.REACH_TARGET:
			if set_scenario >= 0:
				configure_scenario(set_scenario)
				set_scenario = -1
			recalculate(delta)
		TEST_SESSIONS.NAVIGATION:
			recalculate(delta)

func test_path(delta:float) -> void:
	var scenario := scenarios_path[0]
	var params := get_parameters(
		scenario.time,
		scenario.start_pos,
		scenario.start_vel,
		scenario.target_pos,
		scenario.target_vel
	)
	p0 = params[0]
	p1 = params[1]
	p2 = params[2]
	p3 = params[3]
	draw_curve()
	var forces := get_forces(0.01, delta)
	apply_limited_force(forces[0])
	apply_torque(forces[1])

func recalculate(delta: float) -> void:
	if time > recalc_time:
		time = 0.0
		var params = fit_parameters()
		if params.ok:
			time_horizon = params.time
			p0 = params.p[0]
			p1 = params.p[1]
			p2 = params.p[2]
			p3 = params.p[3]
		else:
			set_physics_process(false)
			return
		draw_curve()
	var t := time/time_horizon
	if t > 1: return
	var forces := get_forces(0.01, delta)
	apply_limited_force(forces[0])
	apply_torque(forces[1])
	
	%WallSensor.force_shapecast_update()
	if %WallSensor.is_colliding():
		print("Colliding with wall")
	
	#if global_position != forces[2]:
	#	look_at(forces[2])
	

func get_forces(t:float, delta:float) -> Array[Vector3]:
	var cb := cubic_bezier_curve(p0, p1, p2, p3, t)
	%FunctionPoint.position = Global.bi_to_tri(cb)
	
	var derivative_point := derivaive_cubic_bezier(p0, p1, p2, p3, t) * 10.0
	%DerivativePoint.position = Global.bi_to_tri(derivative_point)*1.0
	
	var force_to_apply :Vector3
	var der :Vector2
	if false:
		der = second_derivaive_cubic_bezier(p0, p1, p2, p3, t)
		force_to_apply = Global.bi_to_tri(der)/(time_horizon*time_horizon)
	else:
		force_to_apply = Global.bi_to_tri(derivative_point).normalized() * 10
		#force_to_apply = (transform.basis * Vector3.FORWARD).normalized()
		#force_to_apply *= 10
	%ForceValues.text = "F: %.1f, %.1f, %.1f" % [force_to_apply.x, force_to_apply.y, force_to_apply.z]
	#print(force_to_apply)
	if force_to_apply.length() < 1.0:
		force_to_apply *= 0.0
	force_to_apply *= mass
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var forward_component: Vector3 = forward_direction * force_to_apply.dot(forward_direction)
	#print(force_to_apply.normalized().dot(forward_direction.normalized()))
	var is_facing_force := force_to_apply.normalized().dot(forward_direction.normalized())
	is_facing_force = abs(is_facing_force)
	forward_component *= is_facing_force
	forward_component = lerp(previous_forward_component, forward_component, 0.1*delta)
	previous_forward_component = forward_component
	
	var derivative_target := Global.bi_to_tri(derivative_point+p0)
	var final_target := Global.bi_to_tri(p3)
	var final_target_weight := remap(derivative_point.length(), 0.0, 10.0, 1.0, 0.0)
	final_target_weight = clampf(final_target_weight, 0.0, 1.0)
	var rotation_target:Vector3 = lerp(derivative_target, final_target, final_target_weight)
	%TorqueValues.text = "T: %.1f, %.1f, %.1f" % [rotation_target.x, rotation_target.y, rotation_target.z]
	get_torque_rotation(rotation_target)
	var _torque := Vector3(0, torque, 0) * torque_speed
	
	%CSGSphere3D.position = Vector3(der.x, 0, der.y)*1
	
	%ForceTarget.global_position = global_position + (forward_component*0.5)
	%TorqueTarget.global_position = rotation_target
	
	return [
		forward_component,
		_torque,
		rotation_target
	]

func apply_limited_force(force_to_apply:Vector3) -> void:
	force_to_apply = force_to_apply.clamp(Vector3.ONE*-10, Vector3.ONE*10)
	apply_central_force(force_to_apply)

func next_navigation_point():
	current_nav_point += 1
	if current_nav_point >= %NavPoints.get_child_count():
		current_nav_point = 0
	var point:Node3D = %NavPoints.get_children()[current_nav_point]
	target_position.x = point.global_position.x
	target_position.z = point.global_position.z
	%NavTarget.global_position = target_position
	target_velocity.x = 0
	target_velocity.z = 0
	%NavVelocity.position = target_velocity

func configure_scenario(_scenario_id:int) -> void:
	var scenario = scenarios[_scenario_id]
	prints("configure_scenario", _scenario_id, scenario.name)
	target_position.x = scenario.target.x
	target_position.z = scenario.target.y
	%NavTarget.global_position = target_position
	target_velocity.x = scenario.target_velocity.x
	target_velocity.z = scenario.target_velocity.y
	%NavVelocity.position = target_velocity
	time = 9999999.0
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	rotation.y = scenario.rotation
	var direction := (transform.basis * Vector3.FORWARD).normalized()
	linear_velocity = direction * scenario.velocity
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func fit_parameters() -> Dictionary:
	var options := []
	for n in 100:
		var o_time := randf_range(0.01, 10.0)
		var o_target_velocity := randf_range(0.01, 1.0)
		options.append({
			"ok": true,
			"time": o_time,
			"target_velocity": o_target_velocity,
			"p": []
		})
	
	var min_cost := 9999999.0
	var min_option: Dictionary = {"ok":false}
	for o in options:
		var params := get_parameters(
			o.time,
			Global.tri_to_bi(position),
			Global.tri_to_bi(linear_velocity),
			Global.tri_to_bi(target_position),
			Global.tri_to_bi(target_velocity * o.target_velocity)
		)
		var o_p0 := params[0]
		var o_p1 := params[1]
		var o_p2 := params[2]
		var o_p3 := params[3]
	
		var max_force := get_max_force(o_p0, o_p1, o_p2, o_p3)
		var max_slope := get_max_slope(o_p0, o_p1, o_p2, o_p3)
		var cost:float = max_force + max_slope + (1.0 - o.target_velocity)
		if cost < min_cost:
			min_cost = cost
			min_option = o
			min_option.p = [o_p0, o_p1, o_p2, o_p3]
	#print(min_cost)
	return min_option

func get_max_slope(_p0, _p1, _p2, _p3) -> float:
	var prev_slope:float
	var acumulated_slope := 0.0
	var max_diff := 0.0
	for t1 in 100:
		var ft1 := float(t1) / 100.0
		var dp1 := derivaive_cubic_bezier(_p0, _p1, _p2, _p3, ft1)
		var slope := dp1.angle()
		if not prev_slope:
			prev_slope = slope
			continue
		acumulated_slope += abs(prev_slope - slope)
		if abs(prev_slope - slope) > max_diff:
			max_diff = abs(prev_slope - slope)
	return max_diff

func get_max_force(_p0, _p1, _p2, _p3) -> float:
	var max_force_a := Global.bi_to_tri(second_derivaive_cubic_bezier(_p0, _p1, _p2, _p3, 0))
	return max_force_a.length()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state.angular_velocity *= 0.999
	#var t := time/time_horizon
	#var der := second_derivaive_cubic_bezier(p0, p1, p2, p3, t)
	#apply_central_force(Vector3(der.x, 0, der.y)*delta)
	#%CSGSphere3D.position = Vector3(der.x, 0, der.y)*1
	#linear_velocity = Vector3(der.x, 0, der.y) / time_horizon
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var forward_component: Vector3 = forward_direction * state.linear_velocity.dot(forward_direction)
	var side_component: Vector3 = state.linear_velocity - forward_component
	state.linear_velocity = forward_component
	state.linear_velocity += side_component * 0.1

func get_torque_rotation(target_position: Vector3):
	var rotation_vector := global_position.direction_to(target_position)
	var angle_to_target := Vector3.BACK.signed_angle_to(rotation_vector, Vector3.UP)
	
	#Global.log_text += "\nangle_to_target: %f" % angle_to_target
	var error := angle_difference(angle_to_target, rotation.y)
	#prints(angle_to_target, rotation.y)
	if error < 0.01 and error > -0.01:
		if error < 0:
			error = -0.01
		else:
			error = 0.01
	#Global.log_text += "\nrotation.y: %f" % rotation.y
	#Global.log_text += "\nerror: %f" % error
	var poportional := get_proportional(error)
	var integral := get_proportional(error)
	var derivative := get_derivative(error)
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

func calculate_parameters(time_horizon:float) -> void:
	var params := get_parameters(
		time_horizon,
		Global.tri_to_bi(position),
		Global.tri_to_bi(linear_velocity),
		Global.tri_to_bi(target_position),
		Global.tri_to_bi(target_velocity)
	)
	p0 = params[0]
	p1 = params[1]
	p2 = params[2]
	p3 = params[3]

func get_parameters(time_horizon:float, start_pos:Vector2, start_vel:Vector2, target_pos:Vector2, target_vel:Vector2) -> Array[Vector2]:
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var forward_component: Vector3 = forward_direction * linear_velocity.dot(forward_direction)
	start_vel = Global.tri_to_bi(forward_component)
	# NOTE start_vel should always be zero
	start_vel = Vector2.ZERO
	#var predicted_pos: Vector3= target_position+(target_velocity*time_horizon)
	#var predicted_pos := target_position - target_velocity
	var end_pos := target_pos
	var end_vel := target_vel
	var _p0 := start_pos
	var _p1 := start_pos + (start_vel * (time_horizon/3.0) )
	var _p2 := end_pos - (end_vel * (time_horizon/3.0) )
	var _p3 := end_pos
	return [_p0, _p1, _p2, _p3]


func draw_curve() -> void:
	%Path3D.curve.set_point_position(0, Global.bi_to_tri(p0))
	%Path3D.curve.set_point_out(0, Global.bi_to_tri(p1)-Global.bi_to_tri(p0))
	%Path3D.curve.set_point_in(1, Global.bi_to_tri(p2)-Global.bi_to_tri(p3))
	%Path3D.curve.set_point_position(1, Global.bi_to_tri(p3))
	#
	%P0.global_position = Global.bi_to_tri(p0)
	# BUG setting Z modifies X and Y?
	%P0.scale.z = Global.bi_to_tri(p0).distance_to(Global.bi_to_tri(p1)) * 1.0
	%P0.scale.y = 1.0
	%P0.scale.x = 1.0
	if Global.bi_to_tri(p1) != %P0.global_position:
		%P0.look_at(Global.bi_to_tri(p1))
	#
	%P3.global_position = Global.bi_to_tri(p3)
	# BUG setting Z modifies X and Y?
	%P3.scale.z = Global.bi_to_tri(p2).distance_to(Global.bi_to_tri(p3)) * 1.0
	%P3.scale.y = 1.0
	%P3.scale.x = 1.0
	if Global.bi_to_tri(p2) != %P3.global_position:
		%P3.look_at(Global.bi_to_tri(p2))


func cubic_bezier_curve(p0:Vector2, p1:Vector2, p2:Vector2, p3:Vector2, i:float) -> Vector2:
	var xya:Vector2 = lerp(p0, p1, i)
	var xyb:Vector2 = lerp(p1, p2, i)
	var xyc:Vector2 = lerp(p2, p3, i)
	var xym:Vector2 = lerp(xya, xyb, i)
	var xyn:Vector2 = lerp(xyb, xyc, i)
	var xy:Vector2 = lerp(xym, xyn, i)
	return xy

func derivaive_cubic_bezier(p0:Vector2, p1:Vector2, p2:Vector2, p3:Vector2, i:float) -> Vector2:
	var der:=Vector2.ZERO
	der.x = ((3.0*((1.0-i)**2))*(p1.x-p0.x)) + ((6.0*(1.0-i))*i*(p2.x-p1.x)) + ((3.0*i**2)*(p3.x-p2.x))
	der.y = ((3.0*((1.0-i)**2))*(p1.y-p0.y)) + ((6.0*(1.0-i))*i*(p2.y-p1.y)) + ((3.0*i**2)*(p3.y-p2.y))
	return der


func second_derivaive_cubic_bezier(p0:Vector2, p1:Vector2, p2:Vector2, p3:Vector2, i:float) -> Vector2:
	var der:=Vector2.ZERO
	der.x = (6.0*(1.0-i)*(p2.x-(2.0*p1.x)+p0.x)) + (6.0*i*(p3.x - (2.0*p2.x) + p1.x))
	der.y = (6.0*(1.0-i)*(p2.y-(2.0*p1.y)+p0.y)) + (6.0*i*(p3.y - (2.0*p2.y) + p1.y))
	return der


func _on_time_horizon_slider_drag_ended(value_changed: bool) -> void:
	time_horizon = %TimeHorizonSlider.value
	print(time_horizon)


func _on_time_refresh_slider_drag_ended(value_changed: bool) -> void:
	recalc_time = %TimeRefreshSlider.value
	print(recalc_time)
