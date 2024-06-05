extends Node3D
class_name DKWorld

signal trigger_entered
signal trigger_exited

@export var initial_camera: Camera3D
@export var initial_camera_path: Path3D
@export var world_definition: Dictionary = {}
@export var nodes_dic: Dictionary = {}

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

func _process(delta: float) -> void:
	handle_cameras(delta)
	switch_camera(delta)
	#Global.character.camera.current = true

func switch_camera(delta):
	camera_switch_delta += delta
	if camera_switch_delta < 1: return
	camera_switch_delta = 0.0
	
	Global.camera = next_camera
	Global.camera_path = camera_to_path[next_camera]

func handle_cameras(delta) -> void:
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
		
	var shifted_global_position_look = character.global_position + point_of_interest.rotated(Vector3.UP, character.rotation.y)
	lerped_shifted_global_position_look = lerp(lerped_shifted_global_position_look, shifted_global_position_look, camera_speed)
	var shifted_global_position_path = character.global_position + player_offset.rotated(Vector3.UP, character.rotation.y)
	lerped_shifted_global_position_path = lerp(lerped_shifted_global_position_path, shifted_global_position_path, camera_speed)
	
	position_look_sphere.position = lerped_shifted_global_position_look
	position_path_sphere.position = lerped_shifted_global_position_path
	
	if camera_speed != 0 and ! new_camera:
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
		if area_amount[n] != null:
			selected_camera = area_amount[n]
	
	if selected_camera != null:
		#Global.camera = selected_camera
		#Global.camera_path = camera_to_path[selected_camera]
		next_camera = selected_camera

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

func on_trigger_entered(area_:Area3D, trigger_name:String) -> void:
	if not area_.has_meta("is_character_interaction"): return
	emit_signal("trigger_entered", trigger_name)
	#prints("Trigger!", trigger_name)

func on_trigger_exited(area_:Area3D, trigger_name:String) -> void:
	if not area_.has_meta("is_character_interaction"): return
	emit_signal("trigger_exited", trigger_name)
	#prints("Trigger!", trigger_name)
