extends Node3D

@onready var character: Node3D = $character
@onready var camera_1_area: Area3D = $camera1/camera1_area
@onready var camera_1_camera: Camera3D = $camera1/camera1_camera
@onready var camera_2_area: Area3D = $camera2/camera2_area
@onready var camera_2_camera: Camera3D = $camera2/camera2_camera
@onready var camera_2_path: Path3D = $camera2/camera2_path

var soft_camera_rotation: float

var target_movement_direction:Vector3
var target_camera_position:Vector3
var lerped_shifted_global_position_look:Vector3
var lerped_shifted_global_position_path:Vector3

func _ready() -> void:
	camera_1_area.connect("area_entered", camera_change.bind(camera_1_camera))
	camera_2_area.connect("area_entered", camera_change.bind(camera_2_camera))

func _process(delta: float) -> void:
	var input_dir:Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	#var target_movement_direction = Vector3(input_dir.x, 0, input_dir.y) * delta * 2.0
	#movement_direction = lerp(movement_direction, target_movement_direction, 0.01)
	var movement_direction:Vector3 = Vector3(input_dir.x, 0, input_dir.y) * delta * 2.0
	var current_camera:Camera3D = get_viewport().get_camera_3d()
	var ration:float = 0.99-(0.1*delta)
	#soft_camera_rotation = (soft_camera_rotation*ration) + (current_camera.rotation*(1.0-ration))
	soft_camera_rotation = lerp_angle(current_camera.rotation.y, soft_camera_rotation, ration)
	#soft_camera_rotation = current_camera.rotation
	var previous_position:Vector3 = character.position
	character.position += movement_direction.rotated(Vector3.UP, soft_camera_rotation)
	if character.position != previous_position:
		character.look_at(previous_position)
	
	var shifted_global_position_look = character.global_position + Vector3(0,0,2).rotated(Vector3.UP, character.rotation.y)
	lerped_shifted_global_position_look = lerp(lerped_shifted_global_position_look, shifted_global_position_look, 0.01)
	var shifted_global_position_path = character.global_position + Vector3(0,0,8).rotated(Vector3.UP, character.rotation.y)
	lerped_shifted_global_position_path = lerp(lerped_shifted_global_position_path, shifted_global_position_path, 0.01)
	
	#var previous_rotation = current_camera.rotation
	current_camera.look_at(lerped_shifted_global_position_look)
	#target_camera_rotation = current_camera.rotation
	#current_camera.rotation = lerp(previous_rotation, target_camera_rotation, 0.01)
	
	var local_character_pos = camera_2_path.to_local(lerped_shifted_global_position_path)
	var local_closest_point = camera_2_path.curve.get_closest_point(local_character_pos)
	#camera_2_camera.global_position = camera_2_path.to_global(local_closest_point)
	target_camera_position = camera_2_path.to_global(local_closest_point)
	camera_2_camera.global_position = lerp(camera_2_camera.global_position, target_camera_position, 0.1)

func camera_change(area_:Area3D, camera: Camera3D) -> void:
	camera.current = true
	
