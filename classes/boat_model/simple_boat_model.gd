class_name SimpleBoatModel

var linear_velocity: Vector2
var angular_velocity:float

var linear_force: Vector2
var angular_force: float

var mass: float
var center_of_mass: = Vector2.ZERO
var inv_mass: float
var inertia: float
var inverse_inertia: float

var position:Vector2 = Vector2.ZERO
var rotation:float = 0.0

var p_surge_multiplier := 200.0
var p_rudder_multiplier := 10.0
var p_rudder_profile_coef := 1.0
var p_vel_rudder_rel := 0.01
var p_longitudinal_damp_coef := 0.99
var p_lateral_damp_coef := 0.99
var p_vel_damp_rel := 0.01
var p_angular_damp_coef := 0.99
var p_hull_torque_coef := 0.01

const MAX_STEER: = 0.8 # max rudder rotation
const N_STEER = 5.0 # amound of rudder rotations

var motion_set:Array
var rudder_angles:Array[float]
var revss_per_second:Array[int]

var nn_tree: Dictionary
var lvx_mult := exponentiate(15.0)
var lvy_mult := exponentiate(2.7)
var av_mult := exponentiate(0.15)
var vel_step = 9

var ticks_per_second := Engine.physics_ticks_per_second

func _init() -> void:
	motion_set = calc_motion_set()
	for v in motion_set[0]:
		if v not in rudder_angles:
			rudder_angles.append(v)
	rudder_angles.sort()
	for v in motion_set[1]:
		if v not in revss_per_second:
			revss_per_second.append(v)

func configure(mass:float) -> void:
	mass = 10.0
	self.mass = mass
	self.inertia = 100.0
	set_parameters( best_parameters() )


func calculate_boat_forces(revs_per_second: float, rudder_angle: float)->Vector3:
	var local_velocity := get_local_velocity()
	
	# More rudder_angle, the less effect revs_per_second has on longitudinal force
	var rudder_profile_coef:float= clampf(1.0 - absf(rudder_angle) * p_rudder_profile_coef, 0.0, 1.0)
	var surge_force := revs_per_second * p_surge_multiplier * rudder_profile_coef
	var surge_force_v := Vector2(surge_force, 0.0).rotated(rotation)
	var linear_force_to_apply := Vector2(revs_per_second * p_surge_multiplier, 0.0).rotated(rotation)
	# More longirudinal velocity, more rudder angular_force
	# More revs_per_second, more rudder angular_force
	var rudder_force := rudder_angle * p_rudder_multiplier * clampf(local_velocity.x*p_vel_rudder_rel, -1.0, 1.0)
	# More velocity, the more the boat rotates towards direction of motion
	# (hull is acting as a rudder)
	var direction_of_motion := local_velocity.normalized()
	var angle_to_motion := direction_of_motion.dot(Vector2.UP)
	#print(angle_to_motion)
	var rudder_force_to_motion := angle_to_motion * p_hull_torque_coef * clampf(local_velocity.x*0.01, -1.0, 1.0)
	var angular_force_to_apply:float = rudder_force + rudder_force_to_motion
	#
	#add_force(linear_force_to_apply)
	add_force_at_position(linear_force_to_apply, Vector2(-10, 0).rotated(rotation))
	add_torque(angular_force_to_apply)
	return Vector3(linear_force.x, linear_force.y, angular_force)

func damping():
	var damped_vels := damped_velocity(linear_velocity, angular_velocity, ticks_per_second, rotation)
	linear_velocity = damped_vels[0]
	angular_velocity = damped_vels[1]

func damped_velocity(_linear_velocity:Vector2, _angular_velocity: float, _ticks_per_second: int, _rotation:float) -> Array:
	#prints("SBM", rotation)
	#var local_velocity_b := linear_velocity.rotated(-rotation)
	#var longitudinal_damp := clampf(p_longitudinal_damp_coef * (1.0 - (local_velocity_b.x * p_vel_damp_rel)), 0.0, 1.0)
	#local_velocity_b.x *= longitudinal_damp
	#local_velocity_b.y *= p_lateral_damp_coef
	#linear_velocity = local_velocity_b.rotated(rotation)
	
	var lv: = Vector2(_linear_velocity)
	var av: float
	lv = lv.rotated(-_rotation)
	lv.x *= 1.0 - p_longitudinal_damp_coef / _ticks_per_second
	lv.y *= 1.0 - p_lateral_damp_coef / _ticks_per_second
	lv = lv.rotated(_rotation)
	
	av = _angular_velocity * (1.0 - p_angular_damp_coef / _ticks_per_second)
	return [lv, av]

func get_torque() -> float:
	return angular_force

func step(delta:float) -> void:
	assert(mass > 0)
	assert(inertia > 0)
	
	_update_forces(delta)
	
	_update_transform(delta)
	
	_reset_forces()

func get_damped_acceleration() -> Array:
	var linear_damp_acceleration:Vector2 = linear_velocity - damped_velocity(linear_velocity, angular_velocity, ticks_per_second, rotation)[0]
	var angular_damp_acceleration:float = angular_velocity - damped_velocity(linear_velocity, angular_velocity, ticks_per_second, rotation)[1]
	return [
		(1.0/mass * linear_force) - linear_damp_acceleration,
		(1.0/inertia * angular_force) - angular_damp_acceleration,
	]

func _update_forces(delta:float) -> void:
	damping()
	# Symplectic Euler
	linear_velocity += (1.0/mass * linear_force) * delta
	angular_velocity += (1.0/inertia * angular_force) * delta

func _update_transform(delta: float) -> void:
	position += linear_velocity * delta
	rotation += angular_velocity * delta
	pi_2_pi(rotation)

func add_force_at_position(force:Vector2, point:Vector2) -> void:
	linear_force += force
	angular_force += (point - center_of_mass).cross(force)

func add_force(force:Vector2) -> void:
	linear_force += force

func add_torque(torque:float) -> void:
	angular_force += torque

func add_force_at_pos(force: Vector2, pos: Vector2) -> void:
	add_force(force)
	add_torque(pos.cross(force))



func _reset_forces() -> void:
	linear_force = Vector2.ZERO
	angular_force = 0.0

func get_local_velocity() -> Vector2:
	return linear_velocity.rotated(-rotation)

# TODO: check if it exists in Godot
func pi_2_pi(theta):
	while theta > PI:
		theta -= 2.0 * PI

	while theta < -PI:
		theta += 2.0 * PI

	return theta


# Train

var params_tested := []
var start_cost := 0.0
var mia_start_cost := 0.0
var start_params:Dictionary
var mia_start_params:Dictionary
var iteration := 0
var temperature := 12.0
var step_size := 0.1
#var params :Dictionary
func simulared_annealing():
	if iteration == 0:
		start_params = best_parameters()
		start_cost = evaluate(start_params.duplicate())
		#params = start_params.duplicate()
		mia_start_params = start_params.duplicate()
		mia_start_cost = start_cost
		
	var mia_params := new_step(mia_start_params, step_size)
	var mia_step_cost := evaluate(mia_params.duplicate())
	#params_tested.append(params)
	if mia_step_cost < start_cost:
		print()
		prints(mia_step_cost)
		print("NEW BEST!")
		print(mia_params)
		var smb := get_sbm_acceleration(
			Vector2(4, 0),
			0.0,
			20.0,
			10.0,
			mia_params
		)
		var mmg := get_mmg_acceleration(
			Vector2(4, 0),
			0.0,
			20.0,
			10.0
		)
		prints(smb, mmg)
		print()
		start_params = mia_params.duplicate()
		start_cost = mia_step_cost
		
	var difference := mia_step_cost - mia_start_cost
	var t := temperature / float(iteration + 1)
	# calculate Metropolis Acceptance Criterion / Acceptance Probability
	var mac := exp(-difference / t)
	# check whether the new point is acceptable 
	if difference < 0 or randf() < mac:
		mia_start_params = mia_params.duplicate()
		mia_start_cost = mia_step_cost
	#%LogText.text = "%.2f - %.2f" % [t, start_cost]
	iteration += 1


#var learning_rate := 0.05
#var momentum := 0.8
#func gradient_descent():
	#if iteration == 0:
		#start_params = best_parameters()
		#start_cost = evaluate(start_params)
		#params = start_params.duplicate()

func evaluate(_params:Dictionary) -> float:
	#var boat_model := BoatModel.new()
	#boat_model.load_parameters()
	#boat_model.tests()
	
	#var tests = []
	
	var sum_squared_error := 0.0
	var cost_count := 0
	for rudder_angle_key in rudder_angles.size():
		for revs_per_second_key in revss_per_second.size():
			for val_linear_velocity_x in vel_step:
				for val_linear_velocity_y in vel_step:
					for val_angular_velocity in vel_step:
						#var ll := cubic_interpolate(0.0, 1.0, 0.0, 0.0, float(val_angular_velocity)/vel_step)
						#print(ll)
						sum_squared_error += evaluate_step(
							Vector2(
								#remap(val_linear_velocity_x, 0, vel_step-1, -lvx_mult, lvx_mult),
								#remap(val_linear_velocity_y, 0, vel_step-1, -lvy_mult, lvy_mult)
								remap_val(val_linear_velocity_x, vel_step, lvx_mult),
								remap_val(val_linear_velocity_y, vel_step, lvy_mult)
							),
							#remap(val_angular_velocity, 0, vel_step-1, -av_mult, av_mult),
							remap_val(val_angular_velocity, vel_step, av_mult),
							revss_per_second[revs_per_second_key]*10.0,
							rudder_angles[rudder_angle_key],
							_params
						)**2
						cost_count += 1
	# Mean square error
	return sum_squared_error / float(cost_count)

func remap_val(sample:int, steps:int, deviation: float) -> float:
	const SAMPLE_CURVE = preload("res://classes/boat_model/sample_curve.tres")
	var r := SAMPLE_CURVE.sample(remap(sample, 0.0, steps-1, 0.0, 1.0))
	#var r := remap(sample, 0, steps-1, -deviation, deviation)
	return r * deviation

func evaluate_step(
		p_linear_velocity:Vector2,
		p_angular_velocity:float,
		p_revs_per_second:float,
		p_rudder_angle:float,
		_params:Dictionary
	):
	
	var mmg := get_mmg_acceleration(
		p_linear_velocity,
		p_angular_velocity,
		p_revs_per_second,
		p_rudder_angle
	)
	
	var acc := get_sbm_acceleration(
		p_linear_velocity,
		p_angular_velocity,
		p_revs_per_second,
		p_rudder_angle,
		_params
	)
	
	# BUG greater values result in greater error
	var sub_cost := 0.0
	sub_cost += normalize_add_bias(mmg[0].x, lvx_mult) - normalize_add_bias(acc[0].x, lvx_mult)
	sub_cost += normalize_add_bias(mmg[0].y, lvy_mult) - normalize_add_bias(acc[0].y, lvy_mult)
	sub_cost += normalize_add_bias(mmg[1], av_mult) - normalize_add_bias(acc[1], av_mult)
	return sub_cost

func get_mmg_acceleration(p_linear_velocity:Vector2, p_angular_velocity:float, p_revs_per_second:float, p_rudder_angle:float) -> Array:
	# Velocity is local
	var boat_model := BoatModel.new()
	boat_model.load_parameters()
	var velocity_mmg = boat_model.BoatForces.new(p_linear_velocity, p_angular_velocity)
	var acceleration_mmg = boat_model.extended_boat_model(
		p_linear_velocity,
		p_angular_velocity,
		p_revs_per_second,
		p_rudder_angle)
	return [acceleration_mmg.force, acceleration_mmg.moment]

func get_sbm_acceleration(
			p_linear_velocity:Vector2,
			p_angular_velocity:float,
			p_revs_per_second:float,
			p_rudder_angle:float,
			_params:Dictionary
		) -> Array:
	configure(10.0) # Configure should be always before set_parameters
	ticks_per_second = 1.0
	set_parameters(_params)
	position = Vector2.ZERO
	rotation = 0.0
	linear_velocity = Vector2(p_linear_velocity)
	angular_velocity = p_angular_velocity
	calculate_boat_forces( p_revs_per_second, p_rudder_angle)
	var acc := get_damped_acceleration()
	_reset_forces()
	return acc

func normalize_add_bias(val: float, standar_debiation: float) -> float:
	#var bias := 1.0
	#return bias+(val/standar_debiation)
	return remap(val, -standar_debiation, standar_debiation, 1.0, 2.0)

func new_parameters() -> Dictionary:
	var params := {
		"p_surge_multiplier" : randf_range(10, 100), #200.0,
		"p_rudder_multiplier" : randf_range(0.001, 1.0), #10.0,
		"p_rudder_profile_coef": randf_range(0.001, 5.0), #1.0,
		"p_vel_rudder_rel": randf_range(0.001, 1.0), #0.01,
		"p_longitudinal_damp_coef": randf_range(0.001, 1.0), #0.99,
		"p_lateral_damp_coef": randf_range(0.001, 1.0), #0.99,
		"p_vel_damp_rel": randf_range(0.001, 1.0), #0.01,
		"p_angular_damp_coef": randf_range(0.001, 1.0), #0.99
		"p_hull_torque_coef": randf_range(0.00001, 0.01) #0.99
	}
	return params

func new_step(params: Dictionary, step: float) -> Dictionary:
	var new_params := params.duplicate()
	
	new_params.p_surge_multiplier += randfn(0.0, 1.0) * step
	new_params.p_rudder_multiplier += randfn(0.0, 0.01) * step
	new_params.p_rudder_profile_coef += randfn(0.0, 0.01) * step
	new_params.p_vel_rudder_rel += randfn(0.0, 0.01) * step
	new_params.p_longitudinal_damp_coef += randfn(0.0, 0.01) * step
	new_params.p_lateral_damp_coef += randfn(0.0, 0.01) * step
	new_params.p_vel_damp_rel += randfn(0.0, 0.01) * step
	new_params.p_angular_damp_coef += randfn(0.0, 0.01) * step
	new_params.p_hull_torque_coef += randfn(0.0, 0.0001) * step
	
	new_params.p_surge_multiplier = maxf(0, new_params.p_surge_multiplier)
	new_params.p_longitudinal_damp_coef = clampf(new_params.p_longitudinal_damp_coef, 0.0, 1.0)
	new_params.p_lateral_damp_coef = clampf(new_params.p_lateral_damp_coef, 0.0, 1.0)
	new_params.p_angular_damp_coef = clampf(new_params.p_angular_damp_coef, 0.0, 1.0)
	new_params.p_vel_rudder_rel = clampf(new_params.p_vel_rudder_rel, 0.0001, 1.0)
	
	return new_params

func set_parameters(_params:Dictionary) -> void:
	p_surge_multiplier = _params.p_surge_multiplier
	p_rudder_multiplier = _params.p_rudder_multiplier
	p_rudder_profile_coef = _params.p_rudder_profile_coef
	p_vel_rudder_rel = _params.p_vel_rudder_rel
	p_longitudinal_damp_coef = _params.p_longitudinal_damp_coef
	p_lateral_damp_coef = _params.p_lateral_damp_coef
	p_vel_damp_rel = _params.p_vel_damp_rel
	p_angular_damp_coef = _params.p_angular_damp_coef
	p_hull_torque_coef = _params.p_hull_torque_coef

func best_parameters() -> Dictionary:
	#return { "p_surge_multiplier": 0.01208286295468, "p_rudder_multiplier": 0.18197398393783, "p_rudder_profile_coef": 1.29562627514753, "p_vel_rudder_rel": 0.40135133627127, "p_longitudinal_damp_coef": 0.00750097905684, "p_lateral_damp_coef": 0.71044768800579, "p_angular_damp_coef": 0.60752206177752, "p_vel_damp_rel": 0.00858374920892, "p_hull_torque_coef": 0.00020219185183 }
	return {
		"p_surge_multiplier": 0.05,
		"p_rudder_multiplier": 0.2 * 200.0 * 1.9,
		"p_vel_rudder_rel": 0.4,
		"p_longitudinal_damp_coef": 0.001,
		"p_lateral_damp_coef": 0.7,
		"p_angular_damp_coef": 0.6,
		"p_hull_torque_coef": -400.0,
		# Not in use
		"p_vel_damp_rel": 0.0001,
		"p_rudder_profile_coef": 1.3,
	}

func calc_motion_set() -> Array:
	var s:Array[float] = []
	var curr_val:float = MAX_STEER / N_STEER
	s.append(curr_val)
	while curr_val < MAX_STEER:
		curr_val += MAX_STEER / N_STEER
		s.append(curr_val)

	var steer_s:Array[float]
	steer_s.append_array(s)
	steer_s.append_array([0.0])
	for _s in s:
		steer_s.append(-_s)
	
	var direc:Array[int] = []
	for _n in len(steer_s):
		direc.append(2)
	for _n in len(steer_s):
		direc.append(1)
	for _n in len(steer_s):
		direc.append(-1)
	for _n in len(steer_s):
		direc.append(-2)
	
	var steer:Array[float] = []
	for _n in 4:
		steer.append_array(steer_s)

	return [steer, direc]

func get_rudder_angle_key(angle:float):
	assert(rudder_angles.find(angle) >= 0)
	return rudder_angles.find(angle)

func get_revs_per_second_key(revs:int):
	assert(revss_per_second.find(revs) >= 0)
	return revss_per_second.find(revs)

func unexponentiate(val:float) -> float:
	#return val ** 2
	#return linear_to_db(absf(val)) * signf(val)
	return val

func exponentiate(val:float) -> float:
	#return sqrt(val)
	#return db_to_linear(absf(val)) * signf(val)
	return val
