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

func configure(mass:float) -> void:
	self.mass = mass
	self.inertia = 1.0
	set_parameters( best_parameters() )

func calculate_boat_forces(revs_per_second: float, rudder_angle: float)->Vector3:
	var local_velocity := linear_velocity.rotated(rotation)
	
	# More rudder_angle, the less effect revs_per_second has on longitudinal force
	var rudder_profile_coef:float= clampf(1.0 - absf(rudder_angle) * p_rudder_profile_coef, 0.0, 1.0)
	var surge_force := revs_per_second * p_surge_multiplier * rudder_profile_coef
	var surge_force_v := Vector2(surge_force, 0.0).rotated(rotation)
	var linear_force_to_apply := surge_force_v
	# More longirudinal velocity, more rudder angular_force
	# More revs_per_second, more rudder angular_force
	var rudder_force := rudder_angle * p_rudder_multiplier + (local_velocity.x * p_vel_rudder_rel)
	# More velocity, the more the boat rotates towards direction of motion
	# (hull is acting as a rudder)
	var direction_of_motion := local_velocity.normalized()
	var angle_to_motion := direction_of_motion.angle_to(Vector2.RIGHT.rotated(rotation))
	#rudder_force += angle_to_motion * p_hull_torque_coef
	var angular_force_to_apply := rudder_force
	#
	add_force(linear_force_to_apply)
	add_torque(angular_force_to_apply)
	return Vector3(linear_force_to_apply.x, linear_force_to_apply.y, angular_force_to_apply)

func damping():
	#prints("SBM", rotation)
	var local_velocity_b := linear_velocity.rotated(-rotation)
	var longitudinal_damp := clampf(p_longitudinal_damp_coef * (1.0 - (local_velocity_b.x * p_vel_damp_rel)), 0.0, 1.0)
	local_velocity_b.x *= longitudinal_damp
	local_velocity_b.y *= p_lateral_damp_coef
	linear_velocity = local_velocity_b.rotated(rotation)
	
	#linear_velocity.x = 0.2
	
	angular_velocity *= p_angular_damp_coef


func get_torque() -> float:
	return angular_force

func step(delta:float) -> void:
	assert(mass > 0)
	assert(inertia > 0)
	
	damping()
	
	# Symplectic Euler
	linear_velocity += (1.0/mass * linear_force) * delta
	angular_velocity += (1.0/inertia * angular_force) * delta
	
	position += linear_velocity * delta
	rotation += angular_velocity * delta
	pi_2_pi(rotation)
	
	reset_forces()

func add_force(force:Vector2) -> void:
	linear_force += force

func add_torque(torque:float) -> void:
	angular_force += torque

func add_force_at_pos(force: Vector2, pos: Vector2) -> void:
	add_force(force)
	add_torque(pos.cross(force))

func reset_forces() -> void:
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
var temperature := 1200.0
var step_size := 0.01
var params :Dictionary
func train():
	if iteration == 0:
		start_params = best_parameters()
		start_cost = evaluate(start_params)
		params = start_params.duplicate()
		
	var current_params = new_step(params, step_size)
	var cost := evaluate(current_params)
	#params_tested.append(params)
	if cost < start_cost:
		start_cost = cost
		params = current_params.duplicate()
		
		#print()
		#prints(start_cost, cost)
		#print("NEW BEST!")
		#print(start_params)
		#print()
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

func evaluate(params:Dictionary) -> float:
	var boat_model := BoatModel.new()
	boat_model.load_parameters()
	boat_model.tests()
	
	var tests = []
	
	var cost := 0.0
	for t in tests:
		# Velocity is local
		var p_linear_velocity :Vector2= t.p_linear_velocity
		var p_angular_velocity :float= t.p_angular_velocity
		var p_revs_per_second :float= t.p_revs_per_second
		var p_rudder_angle :float= t.p_rudder_angle
		
		var velocity_mmg = boat_model.extended_boat_model(
			p_linear_velocity,
			p_angular_velocity,
			p_revs_per_second,
			p_rudder_angle)
		
		set_parameters(params)
		configure(10.0)
		# Since rotation is 0, there is no need to
		# transfor velocity to global
		linear_velocity = p_linear_velocity
		angular_velocity = p_angular_velocity
		calculate_boat_forces( p_revs_per_second, p_rudder_angle)
		step(1.0)
		
		var sub_cost := 0.0
		#sub_cost += abs(velocity_mmg.force.x - get_local_velocity().x)
		#sub_cost += abs(velocity_mmg.force.y - get_local_velocity().y)
		sub_cost += abs(velocity_mmg.moment - angular_velocity)**2
		cost += abs(sub_cost)**2
	
	return cost

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
	
	new_params.p_surge_multiplier += randf_range(-1.0, 1.0) * step
	new_params.p_rudder_multiplier += randf_range(-0.01, 0.01) * step
	new_params.p_rudder_profile_coef += randf_range(-0.01, 0.01) * step
	new_params.p_vel_rudder_rel += randf_range(-0.01, 0.01) * step
	new_params.p_longitudinal_damp_coef += randf_range(-0.01, 0.01) * step
	new_params.p_lateral_damp_coef += randf_range(-0.01, 0.01) * step
	new_params.p_vel_damp_rel += randf_range(-0.01, 0.01) * step
	new_params.p_angular_damp_coef += randf_range(-0.01, 0.01) * step
	new_params.p_hull_torque_coef += randf_range(-0.0001, 0.0001) * step
	
	return new_params

func set_parameters(params:Dictionary) -> void:
	p_surge_multiplier = params.p_surge_multiplier
	p_rudder_multiplier = params.p_rudder_multiplier
	p_rudder_profile_coef = params.p_rudder_profile_coef
	p_vel_rudder_rel = params.p_vel_rudder_rel
	p_longitudinal_damp_coef = params.p_longitudinal_damp_coef
	p_lateral_damp_coef = params.p_lateral_damp_coef
	p_vel_damp_rel = params.p_vel_damp_rel
	p_angular_damp_coef = params.p_angular_damp_coef
	p_hull_torque_coef = params.p_hull_torque_coef

func best_parameters() -> Dictionary:
	#return { "p_surge_multiplier": 6169.64253489751, "p_rudder_multiplier": 221.868745309197, "p_rudder_profile_coef": 0.00154199424716, "p_vel_rudder_rel": 0.06886962224811, "p_longitudinal_damp_coef": 0.71958338313647, "p_lateral_damp_coef": 0.64801322157792, "p_vel_damp_rel": 0.01824952930452, "p_angular_damp_coef": 0.06293648327298 }
	#return { "p_surge_multiplier": 17.3101124668683, "p_rudder_multiplier": 0.25131513607523, "p_rudder_profile_coef": 3.77157371083673, "p_vel_rudder_rel": 0.46645479538681, "p_longitudinal_damp_coef": 0.16744544960587, "p_lateral_damp_coef": 0.19517443047424, "p_vel_damp_rel": 0.01462197290325, "p_angular_damp_coef": 0.07823172949465, "p_hull_torque_coef": 0.00849381151196 }
	#return { "p_surge_multiplier": 31.2315564079564, "p_rudder_multiplier": 0.35581225495361, "p_rudder_profile_coef": 3.58741242162619, "p_vel_rudder_rel": 0.40727548161475, "p_longitudinal_damp_coef": 0.04999269509298, "p_lateral_damp_coef": 0.3728959483561, "p_vel_damp_rel": 0.00167257869297, "p_angular_damp_coef": 0.10653559081847, "p_hull_torque_coef": 0.00650692686409 }
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
