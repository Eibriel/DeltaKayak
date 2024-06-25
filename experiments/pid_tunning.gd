extends Node3D

@onready var generic_6dof_joint_3d: Generic6DOFJoint3D = $Generic6DOFJoint3D
@onready var proportional_slider: HSlider = %ProportionalSlider
@onready var integral_slider: HSlider = %IntegralSlider
@onready var derivative_slider: HSlider = %DerivativeSlider


var character: RigidBody3D

func _ready() -> void:
	Global.grab_joint = generic_6dof_joint_3d
	spawn()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		spawn()

func spawn():
	if character != null:
		character.free()
	character = preload("res://character/character.tscn").instantiate()
	add_child(character)
	character.pid_tunning = deg_to_rad(45)
	update_values()

func update_values()->void:
	print("P: %d I: %.1f D: %d" % [
		proportional_slider.value,
		integral_slider.value,
		derivative_slider.value])
	character.pid_proportional_par = proportional_slider.value
	character.pid_integral_par = integral_slider.value
	character.pid_derivative_par = derivative_slider.value

func _on_slider_value_changed(value: float) -> void:
	update_values()
