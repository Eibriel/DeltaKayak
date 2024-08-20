extends Node3D
class_name DKWorld

signal trigger_entered
signal trigger_exited
signal room_entered
signal room_exited

@export var initial_camera: Camera3D
@export var initial_camera_path: Path3D
@export var world_definition: Dictionary = {}
@export var nodes_dic: Dictionary = {}
#@export var camera_anim:Dictionary = {}

var target_movement_direction:Vector3
var target_camera_position:Vector3
var lerped_shifted_global_position_look:Vector3
var lerped_shifted_global_position_path:Vector3

var position_look_sphere
var position_path_sphere
var camera_sphere
var previous_camera: Camera3D
var next_camera:Camera3D
var initial_positioning:=true

#var camera_queue := []
var character_in_camera := {}
var camera_to_path := {}
var camera_switch_delta := 90.0
var camera_time := 0.0
var select_cameras := false

func _ready():
	Global.camera = initial_camera
	Global.camera_path = initial_camera_path
	initial_camera.current = true
	previous_camera = initial_camera
	
	position_look_sphere = CSGSphere3D.new()
	position_look_sphere.visible = false
	add_child(position_look_sphere)
	
	position_path_sphere = CSGSphere3D.new()
	position_path_sphere.visible = false
	add_child(position_path_sphere)
	
	camera_sphere = CSGSphere3D.new()
	camera_sphere.visible = false
	add_child(camera_sphere)
	
	select_best_camera()

func _process(delta: float) -> void:
	handle_cameras(delta)
	switch_camera(delta)

func switch_camera(delta):
	camera_switch_delta += delta
	if camera_switch_delta < 1: return
	camera_switch_delta = 0.0
	if next_camera == null: return
	Global.camera = next_camera
	#Global.camera_path = camera_to_path[next_camera]

func handle_cameras(delta)->void:
	if not select_cameras: return
	# TODO Looks like process starts before world is fully initiated
	if Global.camera == null: return
	if Global.character == null: return
	var current_camera:= Global.camera
	var character:= Global.character
	var new_camera = false
	if current_camera != previous_camera or initial_positioning:
		current_camera.current = true
		Global.character.hide_head_if_needed()
		Global.character.reset_camera_rotation()
		new_camera = true
		initial_positioning = false
		previous_camera = current_camera
	handle_camera_pathpoints(current_camera, character, new_camera, delta)
	handle_camera_framing(current_camera, character, new_camera, delta)

func set_select_cameras(value:bool) -> void:
	select_cameras = value
	if value == true:
		Global.camera.current = true

func handle_camera_framing(current_camera:Camera3D, character, new_camera:bool, delta:float):
	if not current_camera.has_meta("vertical_compensation"): return
	match current_camera.get_meta("vertical_compensation"):
		"rotation":
			var vertical_diff := get_camera_diff(current_camera, character).y
			current_camera.rotation.x -= vertical_diff*0.01*delta
			if new_camera:
				# TODO Optimize
				for _n in 100:
					vertical_diff = get_camera_diff(current_camera, character).y
					current_camera.rotation.x -= vertical_diff*0.001
		"translation":
			var crane_node := get_camera_parent(current_camera, "crane")
			var vertical_diff := get_camera_diff(current_camera, character).y
			crane_node.position.y -= vertical_diff*0.01*delta
			if new_camera:
				# TODO Optimize
				for _n in 100:
					vertical_diff = get_camera_diff(current_camera, character).y
					crane_node.position.y -= vertical_diff*0.001
	match current_camera.get_meta("horizontal_compensation"):
		"rotation":
			var horizontal_diff := get_camera_diff(current_camera, character).x
			current_camera.rotation.y += horizontal_diff*0.01*delta
			if new_camera:
				# TODO Optimize
				for _n in 100:
					horizontal_diff = get_camera_diff(current_camera, character).x
					current_camera.rotation.y += horizontal_diff*0.001
		"translation":
			var horizontal_diff := get_camera_diff(current_camera, character).x
			current_camera.position.x += horizontal_diff*0.01*delta
			if new_camera:
				# TODO Optimize
				for _n in 100:
					horizontal_diff = get_camera_diff(current_camera, character).x
					current_camera.position.x += horizontal_diff*0.001

func get_camera_parent(current_camera:Camera3D, _name:String) -> Node3D:
	var parents := {
		"rotz": 1,
		"rotx": 2,
		"roty": 3,
		"pos": 4,
		"crane": 5,
	}
	var parent = current_camera
	for _n in parents[_name]:
		parent = parent.get_parent_node_3d()
	return parent

func get_camera_diff(current_camera: Camera3D, character) -> Vector2:
	var screen_pos := current_camera.unproject_position(character.global_position)
	var screen_size := get_viewport().get_visible_rect().size
	var screen_center := screen_size*0.5
	#var vertical_diff := screen_pos.y-screen_center.y
	#var horizontal_diff := screen_pos.x-screen_center.x
	return screen_pos-screen_center

func handle_camera_pathpoints(current_camera:Camera3D, character, new_camera:bool, delta:float):
	#print(current_camera.name)
	if not current_camera.has_meta("pathpoints"): return
	var pathpoints:Array = current_camera.get_meta("pathpoints")
	#print(pathpoints)
	if pathpoints.size() == 0: return
	var path_pos_data := get_path_position(Global.tri_to_bi(character.global_position), pathpoints)
	var path_pos:float = path_pos_data[0]
	#var side_a:float = path_pos_data[1]
	#var side_b:float = path_pos_data[2]
	var camera_speed := 1.0
	if current_camera.has_meta("speed"):
		camera_speed = float(current_camera.get_meta("speed"))
	if new_camera:
		camera_time = path_pos
	else:
		camera_time = lerpf(camera_time, path_pos, camera_speed*delta)
	for c in get_children():
		if c.name.begins_with(current_camera.name.substr(0, current_camera.name.length()-4)):
			for cc in c.get_children():
				if cc is AnimationPlayer:
					cc.clear_queue()
					cc.queue(current_camera.name)
					cc.pause()
					cc.seek(camera_time*30.0, true)
					#print(time*30.0)

func handle_cameras_old(delta) -> void:
	# TODO Looks like process starts before world is fully initiated
	if Global.camera == null: return
	if Global.character == null: return
	#if Global.camera_path == null: return
	#
	var current_camera:= Global.camera
	var character:= Global.character
	var new_camera = false
	if current_camera != previous_camera or initial_positioning:
		current_camera.current = true
		new_camera = true
		initial_positioning = false
		previous_camera = current_camera
	
	var point_of_interest = Vector3(0,0,2)
	if current_camera.has_meta("point_of_interest"):
		var value = current_camera.get_meta("point_of_interest")
		point_of_interest = Vector3(value[0], value[1], value[2])
	
	var player_offset = Vector3(0,0,8)
	if current_camera.has_meta("player_offset"):
		var value = current_camera.get_meta("player_offset")
		player_offset = Vector3(value[0], value[1], value[2])
	
	var camera_speed := 0.03
	if current_camera.has_meta("speed"):
		camera_speed = float(current_camera.get_meta("speed")) / 10
	if new_camera:
		camera_speed = 1.0
	
	#TODO split rotation lock on XYZ
	var lock_rotation := false
	if current_camera.has_meta("lock_rotation_x"):
		lock_rotation = current_camera.get_meta("lock_rotation_x")
	
	var shifted_global_position_look = character.global_position + point_of_interest.rotated(Vector3.UP, character.rotation.y)
	lerped_shifted_global_position_look = lerp(lerped_shifted_global_position_look, shifted_global_position_look, camera_speed)
	var shifted_global_position_path = character.global_position + player_offset.rotated(Vector3.UP, character.rotation.y)
	lerped_shifted_global_position_path = lerp(lerped_shifted_global_position_path, shifted_global_position_path, camera_speed)
	
	position_look_sphere.position = lerped_shifted_global_position_look
	position_path_sphere.position = lerped_shifted_global_position_path
	
	if camera_speed != 0 and !new_camera:
		if not lock_rotation:
			current_camera.look_at(lerped_shifted_global_position_look)
	
	if Global.camera_path != null:
		var local_character_pos = Global.camera_path.to_local(lerped_shifted_global_position_path)
		var local_closest_point = Global.camera_path.curve.get_closest_point(local_character_pos)
		target_camera_position = Global.camera_path.to_global(local_closest_point)
		current_camera.global_position = lerp(current_camera.global_position, target_camera_position, camera_speed)

func select_best_camera():
	var area_amount := [null, null, null, null]
	var selected_camera
	for cam in character_in_camera:
		var camera_array := character_in_camera[cam] as Array
		if area_amount[camera_array.size()] == null or \
		 area_amount[camera_array.size()].get_meta("weight") < cam.get_meta("weight"):
			area_amount[camera_array.size()] = cam
	
	for n in range(3, -1, -1):
		if area_amount[n] != null and n == 3:
			selected_camera = area_amount[n]
			break
	
	if selected_camera != null:
		next_camera = selected_camera
	else:
		next_camera = Global.character.camera

func camera_entered(area:Area3D, camera: Camera3D, path:Path3D) -> void:
	if not area.has_meta("is_character_camera"): return
	if not character_in_camera.has(camera):
		character_in_camera[camera] = []
	if not character_in_camera[camera].has(area):
		character_in_camera[camera].append(area)
	camera_to_path[camera] = path
	select_best_camera()

func camera_exited(area:Area3D, camera: Camera3D, path_:Path3D) -> void:
	if not area.has_meta("is_character_camera"): return
	if not character_in_camera.has(camera): return
	var camera_array := character_in_camera[camera] as Array
	if not camera_array.has(area): return
	camera_array.erase(area)
	if camera_array.size() == 0:
		character_in_camera.erase(camera)
	select_best_camera()

func get_path_position(point_pos: Vector2, path_def: Array) -> Array:
	var c_dist := []
	var polygon_weight := []
	var total_weight := 0.0
	for line_id in range(path_def.size()-1):
		var pos_a:Vector2 = path_def[line_id][0]
		var pos_b:Vector2 = path_def[line_id+1][0]
		var dist := pos_a.distance_to(pos_b)
		polygon_weight.append(dist)
		total_weight += dist
	
	for n in range(polygon_weight.size()):
		polygon_weight[n] /= total_weight
	var added_weight := 0.0
	for line_id in range(path_def.size()-1):
		var pos_a:Vector2 = path_def[line_id][0]
		var pos_b:Vector2 = path_def[line_id][1]
		var pos_c:Vector2 = path_def[line_id+1][0]
		var pos_d:Vector2 = path_def[line_id+1][1]
		var polygon := PackedVector2Array([
			pos_a,
			pos_b,
			pos_d,
			pos_c
		])
		var in_polygon:=Geometry2D.is_point_in_polygon(point_pos, polygon)
		if not in_polygon:
			added_weight += polygon_weight[line_id]
			continue
		var dist_a:float = pos_a.distance_to(point_pos)
		var dist_b:float = pos_b.distance_to(point_pos)
		var dist_c:float = pos_c.distance_to(point_pos)
		var dist_d:float = pos_d.distance_to(point_pos)
		var lerp_a:float = remap(dist_a, 0.0, dist_a+dist_b, 0.0, 1.0)
		var lerp_b:float = remap(dist_c, 0.0, dist_c+dist_d, 0.0, 1.0)
		var proxy_a:Vector2 = lerp(pos_a, pos_b, lerp_a)
		var proxy_b:Vector2 = lerp(pos_c, pos_d, lerp_b)
		var total_dist := proxy_a.distance_to(proxy_b)
		var partial_dist := point_pos.distance_to(proxy_b)
		var val := remap(total_dist-partial_dist, 0.0, total_dist, 0.0, 1.0)
		var pos:float = (val*polygon_weight[line_id]) + added_weight
		return [pos, proxy_a, proxy_b]
	# If not in polygon
	var dist_first:float = path_def[0][0].distance_to(point_pos)
	var dist_last: float = path_def[path_def.size()-1][0].distance_to(point_pos)
	if dist_first > dist_last:
		return [1, path_def[0][0], path_def[0][1]]
	else:
		return [0, path_def[path_def.size()-1][0], path_def[path_def.size()-1][1]]

func on_trigger_entered(area_:Area3D, trigger_name:String) -> void:
	if not area_.has_meta("is_character_interaction"): return
	emit_signal("trigger_entered", trigger_name)
	#prints("Trigger!", trigger_name)

func on_trigger_exited(area_:Area3D, trigger_name:String) -> void:
	if not area_.has_meta("is_character_interaction"): return
	emit_signal("trigger_exited", trigger_name)
	#prints("Trigger!", trigger_name)

func on_room_entered(area_:Area3D, room:Room) -> void:
	if not area_.has_meta("is_character_interaction"): return
	emit_signal("room_entered", room)
	#prints("Room!", room_name)

func on_room_exited(area_:Area3D, room:Room) -> void:
	if not area_.has_meta("is_character_interaction"): return
	emit_signal("room_exited", room)
	#prints("Room!", room_name)
