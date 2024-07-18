extends Node

var character: RigidBody3D
var camera: Camera3D
var enemy: Boat3D
var camera_path: Path3D
var main_scene
var grab_joint: Generic6DOFJoint3D
var grab_kayak: Generic6DOFJoint3D
var grab_kayak2: Generic6DOFJoint3D
var log_text: String = ""

var mouse_sensibility := 0.5

var is_near_carpincho:bool
var carpincho_near:Node3D

# NOTE Needed for datamosh_compositior
var refresh_frame: bool
var datamosh_mount: float = 0.0
var force_datamosh:float = 0.0
#

func is_demo():
	var _is_demo:bool = OS.has_feature("demo")
	# Editor counts as demo
	if OS.has_feature("editor"):
		_is_demo = true
	#if not is_demo:
	#	if not FileAccess.file_exists("res://not_demo.gd"):
	#		print("Not demo")
	#		quit_game()
	return _is_demo

func quit_game():
	# See https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html
	# get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()

func get_datamosh_amount() -> float:
	return max(datamosh_mount, force_datamosh)

func array_to_vector3(array: Array) -> Vector3:
	return Vector3(array[0], array[1], array[2])

func tri_to_bi(tri:Vector3) -> Vector2:
	return Vector2(tri.x, tri.z)

func bi_to_tri(bi:Vector2, z_value:float=0.0) -> Vector3:
	return Vector3(bi.x, z_value, bi.y)
