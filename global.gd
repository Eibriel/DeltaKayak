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

const voice_files = [
	preload("res://sounds/voice/character/Resource_4iing_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_5ayvc_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_5tv27_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_6ksbf_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_6ynwi_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_8sirj_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_51f2c_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_ai67n_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_b2qif_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_d66k7_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_e63sy_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_es55d_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_f5cul_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_g28fn_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_gkviw_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_hesgk_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_hog5x_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_hql8m_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_hw8d6_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_ijug1_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_iybrk_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_kctts_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_kx7gw_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_l0nb5_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_l1nq4_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_mccnv_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_mgkwo_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_niw0c_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_ofr0y_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_ooev8_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_p85l1_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_qtmnn_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_r4nqs_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_rtasq_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_rvwc4_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_rx17p_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_sl1rs_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_tnkfu_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_wayrf_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_weff2_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_x06et_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_xpsea_dialogue_text.ogg"),
	preload("res://sounds/voice/character/Resource_yfiv7_dialogue_text.ogg"),
]

const voice_id = [
	"Resource_4iing_dialogue_text",
	"Resource_5ayvc_dialogue_text",
	"Resource_5tv27_dialogue_text",
	"Resource_6ksbf_dialogue_text",
	"Resource_6ynwi_dialogue_text",
	"Resource_8sirj_dialogue_text",
	"Resource_51f2c_dialogue_text",
	"Resource_ai67n_dialogue_text",
	"Resource_b2qif_dialogue_text",
	"Resource_d66k7_dialogue_text",
	"Resource_e63sy_dialogue_text",
	"Resource_es55d_dialogue_text",
	"Resource_f5cul_dialogue_text",
	"Resource_g28fn_dialogue_text",
	"Resource_gkviw_dialogue_text",
	"Resource_hesgk_dialogue_text",
	"Resource_hog5x_dialogue_text",
	"Resource_hql8m_dialogue_text",
	"Resource_hw8d6_dialogue_text",
	"Resource_ijug1_dialogue_text",
	"Resource_iybrk_dialogue_text",
	"Resource_kctts_dialogue_text",
	"Resource_kx7gw_dialogue_text",
	"Resource_l0nb5_dialogue_text",
	"Resource_l1nq4_dialogue_text",
	"Resource_mccnv_dialogue_text",
	"Resource_mgkwo_dialogue_text",
	"Resource_niw0c_dialogue_text",
	"Resource_ofr0y_dialogue_text",
	"Resource_ooev8_dialogue_text",
	"Resource_p85l1_dialogue_text",
	"Resource_qtmnn_dialogue_text",
	"Resource_r4nqs_dialogue_text",
	"Resource_rtasq_dialogue_text",
	"Resource_rvwc4_dialogue_text",
	"Resource_rx17p_dialogue_text",
	"Resource_sl1rs_dialogue_text",
	"Resource_tnkfu_dialogue_text",
	"Resource_wayrf_dialogue_text",
	"Resource_weff2_dialogue_text",
	"Resource_x06et_dialogue_text",
	"Resource_xpsea_dialogue_text",
	"Resource_yfiv7_dialogue_text",
]
