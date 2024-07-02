extends Node

var character: Node3D
var camera: Camera3D
var camera_path: Path3D
var main_scene
var grab_joint: Generic6DOFJoint3D
var grab_kayak: Generic6DOFJoint3D
var log_text: String = ""

func is_demo():
	var _is_demo:bool = OS.has_feature("demo")
	#if not is_demo:
	#	if not FileAccess.file_exists("res://not_demo.gd"):
	#		print("Not demo")
	#		quit_game()
	return _is_demo

func quit_game():
	# See https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html
	# get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()

func array_to_vector3(array: Array) -> Vector3:
	return Vector3(array[0], array[1], array[2])

func tri_to_bi(tri:Vector3) -> Vector2:
	return Vector2(tri.x, tri.z)
