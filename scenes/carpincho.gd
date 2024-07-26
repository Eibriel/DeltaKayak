extends Node3D

var is_character_near:=false
var previous_camera:Camera3D

func _ready() -> void:
	$character.visible = false

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.name == "character":
		is_character_near = true
		Global.is_near_carpincho = true
		Global.carpincho_near = self

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.name == "character":
		is_character_near = false
		Global.is_near_carpincho = false

func is_petting() -> bool:
	return petting

var petting:=false
func pet():
	petting = true
	previous_camera = get_viewport().get_camera_3d()
	#Global.character.visible = false
	$Camera3D.current = true
	$AnimationPlayer.play("pet_carpincho")

func end_pet():
	petting = false
	#Global.character.visible = true
	previous_camera.current = true
