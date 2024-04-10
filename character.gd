extends Node3D

var soft_camera_rotation: float

func _ready():
	Global.character = self

func _process(delta: float) -> void:
	var input_dir:Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var movement_direction:Vector3 = Vector3(input_dir.x, 0, input_dir.y) * delta * 2.0
	var current_camera:Camera3D = get_viewport().get_camera_3d()
	var ration:float = 0.99-(0.1*delta)
	soft_camera_rotation = lerp_angle(current_camera.rotation.y, soft_camera_rotation, ration)
	var previous_position:Vector3 = position
	position += movement_direction.rotated(Vector3.UP, soft_camera_rotation)
	if position != previous_position:
		look_at(previous_position)
