extends Node3D
class_name DKWorld

@export var initial_camera: Camera3D
@export var initial_camera_path: Path3D
@export var interactive_items: Array = []

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

var camera_queue := []

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
	handle_intractive(delta)

func handle_intractive(delta):
	if Global.camera == null: return
	if Global.icon == null: return
	Global.icon.visible = false
	if interactive_items.size() > 0:
		if Global.camera.is_position_in_frustum(interactive_items[0]):
			var icon_position = Global.camera.unproject_position(interactive_items[0])
			Global.icon.position = icon_position
			Global.icon.visible = true

func handle_cameras(delta) -> void:
	# TODO Looks like process starts before world is fully initiated
	if Global.camera == null: return
	if Global.character == null: return
	if Global.camera_path == null: return
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
	if new_camera:
		camera_speed = 1.0
		
	var shifted_global_position_look = character.global_position + point_of_interest.rotated(Vector3.UP, character.rotation.y)
	lerped_shifted_global_position_look = lerp(lerped_shifted_global_position_look, shifted_global_position_look, camera_speed)
	var shifted_global_position_path = character.global_position + player_offset.rotated(Vector3.UP, character.rotation.y)
	lerped_shifted_global_position_path = lerp(lerped_shifted_global_position_path, shifted_global_position_path, camera_speed)
	
	position_look_sphere.position = lerped_shifted_global_position_look
	position_path_sphere.position = lerped_shifted_global_position_path
	
	current_camera.look_at(lerped_shifted_global_position_look)
	
	var local_character_pos = Global.camera_path.to_local(lerped_shifted_global_position_path)
	var local_closest_point = Global.camera_path.curve.get_closest_point(local_character_pos)
	target_camera_position = Global.camera_path.to_global(local_closest_point)
	current_camera.global_position = lerp(current_camera.global_position, target_camera_position, camera_speed)


func camera_entered(area_:Area3D, camera: Camera3D, path:Path3D) -> void:
	#if area_.has_meta("is_camera_sensor"): pass
	if not area_.has_meta("is_character_camera"): return
	camera_queue.append([camera, path])
	Global.camera = camera
	Global.camera_path = path
	#prints("Entering", camera.name)
	#for c in camera_queue:
	#	print(c[0].name)
	#print(camera_queue)

func camera_exited(area_:Area3D, camera_: Camera3D, path_:Path3D) -> void:
	if not area_.has_meta("is_character_camera"): return
	if camera_queue.size() < 1: return
	var previous_camera:=camera_queue.pop_back()
	var camera: Camera3D = previous_camera[0]
	var path: Path3D = previous_camera[1]
	Global.camera = camera
	Global.camera_path = path
	#prints("Leaving", camera.name)
	#for c in camera_queue:
	#	print(c[0].name)


func trigger_fired(area_:Area3D, trigger_name:String) -> void:
	if not area_.has_meta("is_character_interaction"): return
	prints("Trigger!", trigger_name)
