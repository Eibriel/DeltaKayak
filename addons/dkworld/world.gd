extends Node3D
class_name DKWorld

@export var initial_camera: Camera3D
@export var initial_camera_path: Path3D

var target_movement_direction:Vector3
var target_camera_position:Vector3
var lerped_shifted_global_position_look:Vector3
var lerped_shifted_global_position_path:Vector3


var position_look_sphere
var position_path_sphere
var camera_sphere

func _ready():
	Global.camera = initial_camera
	Global.camera_path = initial_camera_path
	initial_camera.current = true
	
	position_look_sphere = CSGSphere3D.new()
	add_child(position_look_sphere)
	
	position_path_sphere = CSGSphere3D.new()
	add_child(position_path_sphere)
	
	camera_sphere = CSGSphere3D.new()
	add_child(camera_sphere)

func _process(delta: float) -> void:
	#var current_camera:Camera3D = get_viewport().get_camera_3d()
	if Global.camera == null:
		return
	if Global.character == null:
		return
	var current_camera:= Global.camera
	var character:= Global.character
	
	var shifted_global_position_look = character.global_position + Vector3(0,0,2).rotated(Vector3.UP, character.rotation.y)
	lerped_shifted_global_position_look = lerp(lerped_shifted_global_position_look, shifted_global_position_look, 0.01)
	var shifted_global_position_path = character.global_position + Vector3(0,0,8).rotated(Vector3.UP, character.rotation.y)
	lerped_shifted_global_position_path = lerp(lerped_shifted_global_position_path, shifted_global_position_path, 0.01)
	
	position_look_sphere.position = lerped_shifted_global_position_look
	position_path_sphere.position = lerped_shifted_global_position_path
	
	current_camera.look_at(lerped_shifted_global_position_look)
	
	var local_character_pos = Global.camera_path.to_local(lerped_shifted_global_position_path)
	var local_closest_point = Global.camera_path.curve.get_closest_point(local_character_pos)
	#var local_closest_point = Global.camera_curve.get_closest_point(lerped_shifted_global_position_path)
	target_camera_position = Global.camera_path.to_global(local_closest_point)
	current_camera.global_position = lerp(current_camera.global_position, target_camera_position, 0.1)
	
	#camera_sphere.position = current_camera.global_position


func camera_change(area_:Area3D, camera: Camera3D, path:Path3D) -> void:
	camera.current = true
	Global.camera = camera
	Global.camera_path = path
