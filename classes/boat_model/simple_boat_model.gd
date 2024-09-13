class_name SimpleBoatModel

var linear_velocity: Vector2
var angular_velocity:float

var linear_force: Vector2
var angular_force: float

var mass: float
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
	assert(mass == 10)
	self.mass = mass
	self.inertia = 1.0
	set_parameters( best_parameters() )


func calculate_boat_forces(revs_per_second: float, rudder_angle: float)->Vector3:
	var local_velocity := linear_velocity.rotated(rotation)
	
	# More rudder_angle, the less effect revs_per_second has on longitudinal force
	var rudder_profile_coef:float= clampf(1.0 - absf(rudder_angle) * p_rudder_profile_coef, 0.0, 1.0)
	var surge_force := revs_per_second * p_surge_multiplier * rudder_profile_coef
	var surge_force_v := Vector2(surge_force, 0.0).rotated(rotation)
	var linear_force_to_apply := Vector2(revs_per_second * p_surge_multiplier, 0.0).rotated(rotation)
	# More longirudinal velocity, more rudder angular_force
	# More revs_per_second, more rudder angular_force
	var rudder_force := rudder_angle * p_rudder_multiplier + (local_velocity.x * p_vel_rudder_rel)
	# More velocity, the more the boat rotates towards direction of motion
	# (hull is acting as a rudder)
	var direction_of_motion := local_velocity.normalized()
	# var angle_to_motion := direction_of_motion.angle_to(Vector2.RIGHT.rotated(rotation))
	#rudder_force += angle_to_motion * p_hull_torque_coef
	var angular_force_to_apply := rudder_angle * p_rudder_multiplier * clampf(local_velocity.x, -1.0, 1.0)
	#
	add_force(linear_force_to_apply)
	add_torque(angular_force_to_apply)
	return Vector3(linear_force_to_apply.x, linear_force_to_apply.y, angular_force_to_apply)

func damping():
	#prints("SBM", rotation)
	#var local_velocity_b := linear_velocity.rotated(-rotation)
	#var longitudinal_damp := clampf(p_longitudinal_damp_coef * (1.0 - (local_velocity_b.x * p_vel_damp_rel)), 0.0, 1.0)
	#local_velocity_b.x *= longitudinal_damp
	#local_velocity_b.y *= p_lateral_damp_coef
	#linear_velocity = local_velocity_b.rotated(rotation)
	
	linear_velocity.x *= p_longitudinal_damp_coef
	linear_velocity.y *= p_lateral_damp_coef
	
	angular_velocity *= p_angular_damp_coef


func get_torque() -> float:
	return angular_force

func step(delta:float) -> void:
	assert(mass > 0)
	assert(inertia > 0)
	
	_update_forces(delta)
	
	_update_transform(delta)
	
	_reset_forces()

func _update_forces(delta:float) -> void:
	damping()
	# Symplectic Euler
	linear_velocity += (1.0/mass * linear_force) * delta
	angular_velocity += (1.0/inertia * angular_force) * delta

func _update_transform(delta: float) -> void:
	position += linear_velocity * delta
	rotation += angular_velocity * delta
	pi_2_pi(rotation)

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
	return linear_velocity.rotated(rotation)

# TODO: check if it exists in Godot
func pi_2_pi(theta):
	while theta > PI:
		theta -= 2.0 * PI

	while theta < -PI:
		theta += 2.0 * PI

	return theta


# Train

var params_tested := []
var start_cost := 999999999.0
var start_params:Dictionary
var iteration := 0
var temperature := 12.0
var step_size := 0.01
var params :Dictionary
func simulared_annealing():
	if iteration == 0:
		start_params = best_parameters()
		start_cost = evaluate(start_params.duplicate())
		params = start_params.duplicate()
		
	var current_params := new_step(params, step_size)
	var cost := evaluate(current_params.duplicate())
	#params_tested.append(params)
	if cost < start_cost:
		print()
		prints(start_cost, cost)
		print("NEW BEST!")
		print(params)
		print()
		start_cost = cost
		params = current_params.duplicate()
		
	var difference := cost - start_cost
	var t := temperature / float(iteration + 1)
	# calculate Metropolis Acceptance Criterion / Acceptance Probability
	var mac := exp(-difference / t)
	# check whether the new point is acceptable 
	if difference < 0 or randf() < mac:
		params = current_params
		start_cost = cost
	#%LogText.text = "%.2f - %.2f" % [t, start_cost]
	iteration += 1


var learning_rate := 0.05
var momentum := 0.8
func gradient_descent():
	if iteration == 0:
		start_params = best_parameters()
		start_cost = evaluate(start_params)
		params = start_params.duplicate()

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
	
	var delta := 1.0
	var steps := 3
	# Velocity is local
	var boat_model := BoatModel.new()
	boat_model.load_parameters()
	var velocity_mmg = boat_model.BoatForces.new(p_linear_velocity, p_angular_velocity)
	for s in steps:
		var velocity_mmg_new = boat_model.extended_boat_model(
			p_linear_velocity,
			p_angular_velocity,
			p_revs_per_second,
			p_rudder_angle)
		
		velocity_mmg.force.x += velocity_mmg_new.force.x * delta
		velocity_mmg.force.y += velocity_mmg_new.force.y * delta
		velocity_mmg.moment += velocity_mmg_new.moment * delta
	
	configure(10.0) # Configure should be always before set_parameters
	set_parameters(_params)
	position = Vector2.ZERO
	rotation = 0.0
	linear_velocity = Vector2(p_linear_velocity)
	angular_velocity = p_angular_velocity
	for s in steps:
		calculate_boat_forces( p_revs_per_second, p_rudder_angle)
		step(delta)
	
	var sub_cost := 0.0
	var velocity_local := get_local_velocity()
	var mmg_force:Vector2 = velocity_mmg.force
	sub_cost += normalize_add_bias(velocity_mmg.force.x, lvx_mult) - normalize_add_bias(velocity_local.x, lvx_mult)
	sub_cost += normalize_add_bias(velocity_mmg.force.y, lvy_mult) - normalize_add_bias(velocity_local.y, lvy_mult)
	sub_cost += normalize_add_bias(velocity_mmg.moment, av_mult) - normalize_add_bias(angular_velocity, av_mult)
	return sub_cost

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
	return { "p_surge_multiplier": 0.90663536081773, "p_rudder_multiplier": 0.06147436331775, "p_rudder_profile_coef": 1.29309803973956, "p_vel_rudder_rel": 0.04291676304433, "p_longitudinal_damp_coef": 0.80007478756412, "p_lateral_damp_coef": 0.82791043674319, "p_vel_damp_rel": 0.02382878157945, "p_angular_damp_coef": 0.72964384143233, "p_hull_torque_coef": 0.00026846818534 }
	return {
		"p_surge_multiplier": 40.0,
		"p_rudder_multiplier": 0.1,
		"p_rudder_profile_coef": 1.3,
		"p_vel_rudder_rel": 0.05,
		"p_longitudinal_damp_coef": 0.98,
		"p_lateral_damp_coef": 0.99,
		"p_vel_damp_rel": 0.0001,
		"p_angular_damp_coef": 0.99,
		"p_hull_torque_coef": 0.0001
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
