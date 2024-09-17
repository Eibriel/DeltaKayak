extends Control

var boat_model := BoatModel.new()
var simple_boat_model := SimpleBoatModel.new()
var aprox_boat_model := AproxBoatModel.new()

var revs_per_second := 0.0
var rudder_angle := 0.0

#var revss_per_second
#var rudder_angles

var forces = {
	"force": Vector2(0.0, 0.0),
	"moment": 0.0
}

var sbm_mass := 10.0

func _ready() -> void:
	boat_model.load_parameters()
	boat_model.tests()
	boat_model.linear_velocity = Vector2(0.0, 0.0) # m/s
	boat_model.angular_velocity = 0.0 # r/s
	#boat_model.p.yaw_rate = 0.0 #r/s
	
	simple_boat_model.configure(sbm_mass)
	simple_boat_model.rotation = deg_to_rad(0)
	
	#revss_per_second = aprox_boat_model.revss_per_second
	#revss_per_second = [2, 1, 0, -1, -2]
	#rudder_angles = aprox_boat_model.rudder_angles
	
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


func _physics_process(delta: float) -> void:
	#params = best_parameters()
	#simple_boat_model.simulared_annealing()
	real_time(delta)
	pass

func real_time(delta: float) -> void:
	%ControlsLabel.text = "%.1f rps\n%dº" % [revs_per_second, rudder_angle]
	process_mmg(delta)
	var sbm_forces := process_sbm(delta)
	#process_nn(delta)
	process_rigid(delta, sbm_forces)

func process_rigid(delta:float, sbm_forces:Vector3):
	%Boat3.p_longitudinal_damp_coef = simple_boat_model.p_longitudinal_damp_coef
	%Boat3.p_lateral_damp_coef = simple_boat_model.p_lateral_damp_coef
	%Boat3.p_vel_damp_rel = simple_boat_model.p_vel_damp_rel
	%Boat3.p_angular_damp_coef = simple_boat_model.p_angular_damp_coef
	%Boat3.apply_central_force(Vector2(sbm_forces.x, sbm_forces.y))
	%Boat3.apply_torque(sbm_forces.z)
	%Rudder3.rotation = -deg_to_rad(rudder_angle)

var nn_linear_velocity := Vector2.ZERO
var nn_angular_velocity := 0.0
func process_nn(delta: float):
	
	var f = aprox_boat_model.get_velocity(nn_linear_velocity, nn_angular_velocity, rudder_angle, revs_per_second)
	
	nn_linear_velocity += Vector2(f.x, f.y) * delta
	nn_angular_velocity += f.z * delta
	
	%Boat2.rotation += nn_angular_velocity * delta
	%Boat2.position += nn_linear_velocity.rotated(%Boat2.rotation) * delta
	%Rudder2.rotation = -rudder_angle
	%TreeKeysLabel.text = "%.2f, %.2f, %.2f" % [f.x, f.y, f.z]

var linear_angular_velocity:Vector3
func process_sbm(delta: float) -> Vector3:
	#set_parameters(params)
	var sbm_forces := simple_boat_model.calculate_boat_forces(
		revs_per_second,
		deg_to_rad(rudder_angle)
	)
	simple_boat_model.step(delta)
	
	%Boat2.position = simple_boat_model.position
	%Boat2.rotation = simple_boat_model.rotation
	%Rudder2.rotation = -deg_to_rad(rudder_angle)
	
	%SimpleForceLabel.text = "SF: %.4f : %.4f : %.4f" % [
		simple_boat_model.get_local_velocity().x,
		simple_boat_model.get_local_velocity().y,
		simple_boat_model.angular_velocity
	]
	
	#print("SMB")
	#prints("linear_velocity", simple_boat_model.get_local_velocity())
	#prints("angular_velocity", simple_boat_model.angular_velocity)
	return sbm_forces

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
		revs_per_second,
		deg_to_rad(rudder_angle))

	forces.force += f.force * delta
	forces.moment += f.moment * delta
	
	%Boat.rotation += forces.moment * delta
	%Boat.position += forces.force.rotated(%Boat.rotation) * delta
	%Rudder.rotation = -deg_to_rad(rudder_angle)

	%ForceLabel.text = "F: %.4f : %.4f" % [forces.force.x, forces.force.y]
	%MomentLabel.text = "M: %.4f" % forces.moment


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		rudder_angle += 10
	elif event.is_action_pressed("ui_right"):
		rudder_angle -= 10
	
	if event.is_action_pressed("ui_up"):
		revs_per_second += 5
	elif event.is_action_pressed("ui_down"):
		revs_per_second -= 5

	if event.is_action_pressed("ui_accept"):
		simple_boat_model.add_force(Vector2(50000, 0))

	rudder_angle = clampf(rudder_angle, -50, 50)
	revs_per_second = clampf(revs_per_second, -20, 20)
	#rudder_angle = clampi(rudder_angle, 0, rudder_angles.size()-1)
	#revs_per_second = clampi(revs_per_second, 0, revss_per_second.size()-1)

func get_xy(vec3: Vector3)-> Vector2:
	return Vector2(vec3.x, vec3.y)
