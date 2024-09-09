## This boat model aproximates MMG using Machine Learning
class_name AproxBoatModel

var motion_set:Array #= hybrid_astar.calc_motion_set()
var rudder_angles:Array[float]
var revss_per_second:Array[int]

const MAX_STEER: = 0.8 # max rudder rotation
const N_STEER = 5.0 # amound of rudder rotations

var nn_tree: Dictionary
var lvx_mult := exponentiate(15.0)
var lvy_mult := exponentiate(2.7)
var av_mult := exponentiate(0.15)
var vel_step = 20

func _init() -> void:
	motion_set = calc_motion_set()
	for v in motion_set[0]:
		if v not in rudder_angles:
			rudder_angles.append(v)
	rudder_angles.sort()
	for v in motion_set[1]:
		if v not in revss_per_second:
			revss_per_second.append(v)
	
	#nearest_neighbor_fit()
	load_parameters()


func load_parameters():
	var save_path := "nn_tree.res"
	var loaded_tree = load(save_path)
	nn_tree = loaded_tree.parameters


func nearest_neighbor_fit() -> void:
	if false:
		var save_path := "captured_velocity.json"
		if not FileAccess.file_exists(save_path):
			return
		var file_access := FileAccess.open(save_path, FileAccess.READ)
		var json_string := file_access.get_line()
		file_access.close()

		var json := JSON.new()
		var error := json.parse(json_string)
		if error:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			return
		# We saved a dictionary, lets assume is a dictionary
		var data: Array = json.data
	
		var lvx:Array
		var lvy:Array
		var av:Array
		for k in data.size():
			lvx.append(data[k][0])
			lvy.append(data[k][1])
			av.append(data[k][2])
	
	var boat_model := BoatModel.new()
	boat_model.load_parameters()
	boat_model.tests()
	
	var json_array:Array = []
	for rudder_angle_key in rudder_angles.size():
		for revs_per_second_key in revss_per_second.size():
			for val_linear_velocity_x in vel_step:
				for val_linear_velocity_y in vel_step:
					for val_angular_velocity in vel_step:
						var linear_velocity := Vector2(
							#((float(val_linear_velocity_x) / vel_step * lvx_mult * 2.0) - lvx_mult) ** 2,
							#((float(val_linear_velocity_y) / vel_step * lvy_mult * 2.0) - lvy_mult) ** 2,
							unexponentiate(remap(val_linear_velocity_x, 0, vel_step, -lvx_mult, lvx_mult)),
							unexponentiate(remap(val_linear_velocity_y, 0, vel_step, -lvy_mult, lvy_mult)),
						)
						#var angular_velocity:float = ((float(val_angular_velocity) / vel_step * av_mult * 2.0) - av_mult) ** 2
						var angular_velocity:float = unexponentiate(remap(val_angular_velocity, 0, vel_step, -av_mult, av_mult))
						var t_rudder_angle:float = rudder_angles[rudder_angle_key]
						var t_revs_per_second:float = revss_per_second[revs_per_second_key] * 10.0
						var f := boat_model.extended_boat_model(
							linear_velocity,
							angular_velocity,
							t_revs_per_second,
							t_rudder_angle)
						var tree_key := Vector3i(val_linear_velocity_x, val_linear_velocity_y, val_angular_velocity)
						if tree_key not in nn_tree:
							nn_tree[tree_key] = {}
						var tree_key_2 := Vector2i(rudder_angle_key, revs_per_second_key)
						assert(tree_key_2 not in nn_tree[tree_key])
						nn_tree[tree_key][tree_key_2] = Vector3(
							#f.force.x - linear_velocity.x,
							#f.force.y - linear_velocity.y,
							#f.moment - angular_velocity
							f.force.x,
							f.force.y,
							f.moment
						) # Store velocity or acceleration?
	#print(nn_tree)
	var data := AproxBoatModelParams.new()
	data.parameters = nn_tree

	var error := ResourceSaver.save(data, "nn_tree.res")
	if error:
		print("An error happened while saving data: ", error)

#var nn_linear_velocity := Vector2.ZERO
#var nn_angular_velocity := 0.0
func get_velocity(nn_linear_velocity:Vector2, nn_angular_velocity:float, rudder_angle: int, revs_per_second: int):
	var val_linear_velocity_x_float:float = remap(exponentiate(nn_linear_velocity.x), -lvx_mult, lvx_mult, 0, vel_step)
	var val_linear_velocity_y_float:float = remap(exponentiate(nn_linear_velocity.y), -lvy_mult, lvy_mult, 0, vel_step)
	var val_angular_velocity_float:float = remap(exponentiate(nn_angular_velocity), -av_mult, av_mult, 0, vel_step)
	
	var val_linear_velocity_x_floor := floori(val_linear_velocity_x_float)
	var val_linear_velocity_y_floor := floori(val_linear_velocity_y_float)
	var val_angular_velocity_floor := floori(val_angular_velocity_float)
	
	var val_linear_velocity_x_rest:float = val_linear_velocity_x_float - val_linear_velocity_x_floor
	var val_linear_velocity_y_rest:float = val_linear_velocity_y_float - val_linear_velocity_y_floor
	var val_angular_velocity_rest:float = val_angular_velocity_float - val_angular_velocity_floor
	
	var avg_rest = (val_linear_velocity_x_rest+val_linear_velocity_y_rest+val_angular_velocity_rest) / 3.0
	
	var val_linear_velocity_x_ceil := ceili(val_linear_velocity_x_float)
	var val_linear_velocity_y_ceil := ceili(val_linear_velocity_y_float)
	var val_angular_velocity_ceil := ceili(val_angular_velocity_float)
	
	var tree_key_2 := Vector2i(rudder_angle, revs_per_second)
	var tree_key_floor := Vector3i(val_linear_velocity_x_floor, val_linear_velocity_y_floor, val_angular_velocity_floor)
	tree_key_floor = tree_key_floor.clampi(0, vel_step)
	var velocity_floor:Vector3 = nn_tree[tree_key_floor][tree_key_2]
	var tree_key_ceil := Vector3i(val_linear_velocity_x_ceil, val_linear_velocity_y_ceil, val_angular_velocity_ceil)
	tree_key_ceil = tree_key_ceil.clampi(0, vel_step)
	var velocity_ceil:Vector3 = nn_tree[tree_key_ceil][tree_key_2]
	
	var velocity := velocity_floor.lerp(velocity_ceil, avg_rest)
	
	#prints(val_linear_velocity_x_floor, val_linear_velocity_y_floor, val_angular_velocity_floor, rudder_angle, revs_per_second)
	
	return velocity

func unexponentiate(val:float) -> float:
	#return val ** 2
	#return linear_to_db(absf(val)) * signf(val)
	return val

func exponentiate(val:float) -> float:
	#return sqrt(val)
	#return db_to_linear(absf(val)) * signf(val)
	return val

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
