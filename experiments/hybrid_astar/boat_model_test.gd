extends Control

var boat_model := BoatModel.new()
var simple_boat_model := SimpleBoatModel.new()
var aprox_boat_model := AproxBoatModel.new()

var revs_per_second := 0
var rudder_angle := 0

var revss_per_second
var rudder_angles

var forces = {
	"force": Vector2(3.85, 0.0),
	"moment": 0.0
}

var sbm_mass := 10

func _ready() -> void:
	boat_model.load_parameters()
	boat_model.tests()
	boat_model.linear_velocity = Vector2(3.85, 0.0) # m/s
	boat_model.angular_velocity = 0.0 # r/s
	#boat_model.p.yaw_rate = 0.0 #r/s
	
	simple_boat_model.configure(sbm_mass)
	set_parameters( best_parameters() )
	
	revss_per_second = aprox_boat_model.revss_per_second
	rudder_angles = aprox_boat_model.rudder_angles
	
	#aprox_boat_model.nearest_neighbor_fit()
	
	if false:
		#print(rudder_angle)
		var f = {
			"force": Vector2(3.85, 0.0),
			"moment": 0.0
		}
		for _n in range(10):
			#prints("n", _n)
			var linear_velocity:Vector2 = f.force
			var angular_velocity:float = f.moment
			var new_f = boat_model.extended_boat_model(
				linear_velocity,
				angular_velocity,
				revs_per_second,
				rudder_angle)
			#prints("Raw:", new_f.force, new_f.moment)
			assert(new_f.force.x != NAN)
			f.force += new_f.force
			f.moment += new_f.moment
			#prints(f.force, f.moment)


func _process(delta: float) -> void:
	#params = best_parameters()
	#train()
	real_time(delta)
	pass


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
	%LogText.text = "%.2f - %.2f" % [t, start_cost]
	iteration += 1

func evaluate(params:Dictionary) -> float:
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
		
		simple_boat_model = SimpleBoatModel.new()
		set_parameters(params)
		simple_boat_model.configure(sbm_mass)
		# Since rotation is 0, there is no need to
		# transfor velocity to global
		simple_boat_model.linear_velocity = p_linear_velocity
		simple_boat_model.angular_velocity = p_angular_velocity
		simple_boat_model.calculate_boat_forces( p_revs_per_second, p_rudder_angle)
		simple_boat_model.step(1.0)
		
		var sub_cost := 0.0
		#sub_cost += abs(velocity_mmg.force.x - simple_boat_model.get_local_velocity().x)
		#sub_cost += abs(velocity_mmg.force.y - simple_boat_model.get_local_velocity().y)
		sub_cost += abs(velocity_mmg.moment - simple_boat_model.angular_velocity)**2
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
	simple_boat_model.p_surge_multiplier = params.p_surge_multiplier
	simple_boat_model.p_rudder_multiplier = params.p_rudder_multiplier
	simple_boat_model.p_rudder_profile_coef = params.p_rudder_profile_coef
	simple_boat_model.p_vel_rudder_rel = params.p_vel_rudder_rel
	simple_boat_model.p_longitudinal_damp_coef = params.p_longitudinal_damp_coef
	simple_boat_model.p_lateral_damp_coef = params.p_lateral_damp_coef
	simple_boat_model.p_vel_damp_rel = params.p_vel_damp_rel
	simple_boat_model.p_angular_damp_coef = params.p_angular_damp_coef
	simple_boat_model.p_hull_torque_coef = params.p_hull_torque_coef

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

func real_time(delta: float) -> void:
	%ControlsLabel.text = "%.1f rps\n%dº - %.1f" % [revss_per_second[revs_per_second]*10.0, rad_to_deg(rudder_angles[rudder_angle]), rudder_angle]
	process_mmg(delta)
	#process_sbm(delta)
	process_nn(delta)

var nn_linear_velocity := Vector2.ZERO
var nn_angular_velocity := 0.0
func process_nn(delta: float):
	
	var f = aprox_boat_model.get_velocity(nn_linear_velocity, nn_angular_velocity, rudder_angle, revs_per_second)
	
	nn_linear_velocity += Vector2(f.x, f.y) * delta
	nn_angular_velocity += f.z * delta
	
	%Boat2.rotation += nn_angular_velocity * delta
	%Boat2.position += nn_linear_velocity.rotated(%Boat2.rotation) * delta
	%Rudder2.rotation = -rudder_angles[rudder_angle]
	%TreeKeysLabel.text = "%.2f, %.2f, %.2f" % [f.x, f.y, f.z]

var linear_angular_velocity:Vector3
func process_sbm(delta: float):
	set_parameters(params)
	simple_boat_model.calculate_boat_forces( revs_per_second, rudder_angle)
	simple_boat_model.step(delta)
	
	%Boat2.position = simple_boat_model.position
	%Boat2.rotation = simple_boat_model.rotation
	%Rudder2.rotation = -rudder_angle

	print("SMB")
	prints("linear_velocity", simple_boat_model.get_local_velocity())
	prints("angular_velocity", simple_boat_model.angular_velocity)

var captured_velocity:Array[Array]
var capture_time := 99.0
func process_mmg(delta: float):
	var linear_velocity:Vector2 = forces.force
	var angular_velocity:float = forces.moment
	
	capture_time += delta
	if capture_time > 1.0 and false:
		capture_time = 0.0
		captured_velocity.append([linear_velocity.x, linear_velocity.y, angular_velocity])
		#print(captured_velocity)
		var json_string := JSON.stringify(captured_velocity)
		var file_access := FileAccess.open("captured_velocity.json", FileAccess.WRITE)
		if not file_access:
			print("An error happened while saving data: ", FileAccess.get_open_error())
		else:
			file_access.store_line(json_string)
			file_access.close()
	
	if false:
		print("MMG")
		prints("linear_velocity", linear_velocity)
		prints("angular_velocity", angular_velocity)
		print("DATA")
		prints("revs_per_second", revs_per_second)
		prints("rudder_angle", rudder_angle)
	
	var f := boat_model.extended_boat_model(
		linear_velocity,
		angular_velocity,
		revss_per_second[revs_per_second] * 10.0,
		rudder_angles[rudder_angle])

	forces.force += f.force * delta
	forces.moment += f.moment * delta
	
	%Boat.rotation += forces.moment * delta
	%Boat.position += forces.force.rotated(%Boat.rotation) * delta
	%Rudder.rotation = -rudder_angles[rudder_angle]

	%ForceLabel.text = "F: %.4f : %.4f" % [forces.force.x, forces.force.y]
	%MomentLabel.text = "M: %.4f" % forces.moment


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		rudder_angle += 1
	elif event.is_action_pressed("ui_right"):
		rudder_angle -= 1
	
	if event.is_action_pressed("ui_up"):
		revs_per_second += 1
	elif event.is_action_pressed("ui_down"):
		revs_per_second -= 1

	rudder_angle = clampi(rudder_angle, 0, rudder_angles.size()-1)
	revs_per_second = clampi(revs_per_second, 0, revss_per_second.size()-1)

func get_xy(vec3: Vector3)-> Vector2:
	return Vector2(vec3.x, vec3.y)

const tests = [
	{
		"p_linear_velocity" : Vector2(0,0),
		"p_angular_velocity" : 0.0,
		"p_revs_per_second" : 4.0,
		"p_rudder_angle" : 10.0,
	},
	{
		"p_linear_velocity" : Vector2(23.79405, -5.107617),
		"p_angular_velocity" : 0.2212544671444,
		"p_revs_per_second" : 74.0,
		"p_rudder_angle" : 0.24434609527921,
	},
	{
		"p_linear_velocity" : Vector2(5.556712, 0.666201),
		"p_angular_velocity" : -0.05407901690924,
		"p_revs_per_second" : 24.0,
		"p_rudder_angle" : -0.24434609527921,
	},
	{
		"p_linear_velocity" : Vector2(-4.292821, -0.496721),
		"p_angular_velocity" : -0.00710030534819,
		"p_revs_per_second" : 54.0,
		"p_rudder_angle" : 0.01745329251994,
	},
	{
		"p_linear_velocity" : Vector2(3.352231, 0.549797),
		"p_angular_velocity" : -0.03031655608699,
		"p_revs_per_second" : 4.0,
		"p_rudder_angle" : -0.82030474843734,
	},
]
