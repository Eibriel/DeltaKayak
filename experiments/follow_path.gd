extends Node3D

@onready var enemy: Boat3D = $Enemy
@onready var path_3d: Path3D = $Path3D


func _ready() -> void:
	enemy.follow_path = path_3d
	enemy.home_position = Vector3(50, 0, -50)
	enemy.target_position = Vector3(50, 0, -50)
	#
	%ProportionalSlider.value = enemy.pid_proportional_par
	%IntegralSlider.value = enemy.pid_integral_par
	%DerivativeSlider.value = enemy.pid_derivative_par
	#
	%ProportionalPathSlider.value = enemy.pid_path_proportional_par
	%IntegralPathSlider.value = enemy.pid_path_integral_par
	%DerivativePathSlider.value = enemy.pid_path_derivative_par

func update_values()->void:
	print("Pa: %d Ia: %.1f Da: %d" % [
		%ProportionalSlider.value,
		%IntegralSlider.value,
		%DerivativeSlider.value])
	print("Pp: %d Ip: %.1f Dp: %d" % [
		%ProportionalPathSlider.value,
		%IntegralPathSlider.value,
		%DerivativePathSlider.value])
	enemy.pid_proportional_par = %ProportionalSlider.value
	enemy.pid_integral_par = %IntegralSlider.value
	enemy.pid_derivative_par = %DerivativeSlider.value
	#
	enemy.pid_path_proportional_par = %ProportionalPathSlider.value
	enemy.pid_path_integral_par = %IntegralPathSlider.value
	enemy.pid_path_derivative_par = %DerivativePathSlider.value

func _on_slider_value_changed(value: float) -> void:
	update_values()


func _on_slider_drag_ended(value_changed: bool) -> void:
	update_values()
