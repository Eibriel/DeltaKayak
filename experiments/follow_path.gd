extends Node3D

@onready var enemy: Boat3D = $Enemy
@onready var path_3d: Path3D = $Path3D
@onready var character: RigidBody3D = $character


func _ready() -> void:
	Global.character = character
	Global.enemy = enemy
	#enemy.follow_path = path_3d
	enemy.home_position = $CSGBox3D.global_position #Vector3(50, 0, -50)
	enemy.target_position = $CSGBox3D.global_position #Vector3(50, 0, -50)
	#
	%ProportionalSlider.value = enemy.pid_proportional_par
	%IntegralSlider.value = enemy.pid_integral_par
	%DerivativeSlider.value = enemy.pid_derivative_par
	#
	#%ProportionalPathSlider.value = enemy.pid_path_proportional_par
	#%IntegralPathSlider.value = enemy.pid_path_integral_par
	#%DerivativePathSlider.value = enemy.pid_path_derivative_par
	
	var scenario := 1
	match scenario:
		0: # Stuck in narrow space
			character.position = Vector3(-25.4, 0, -61.5)
			character.rotation = Vector3(0,0,0)
			enemy.position = Vector3(-25.6,0,-40)
			enemy.rotation = Vector3(0,deg_to_rad(-148.3),0)
		1: # Circles
			character.position = Vector3(24.18, 0, -31.3)
			character.rotation = Vector3(0,0,0)
			enemy.position = Vector3(10.9,0,-31)
			enemy.rotation = Vector3(0,0,0)
		2: # Hit to the wall
			character.position = Vector3(-26.4, 0, -36.2)
			character.rotation = Vector3(0,0,0)
			enemy.position = Vector3(10.9,0,-37)
			enemy.rotation = Vector3(0,deg_to_rad(90),0)

func _process(delta: float) -> void:
	%LogLabel.text = Global.log_text
	Global.log_text = ""
	pass

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
	#enemy.pid_path_proportional_par = %ProportionalPathSlider.value
	#enemy.pid_path_integral_par = %IntegralPathSlider.value
	#enemy.pid_path_derivative_par = %DerivativePathSlider.value

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()

func _on_slider_value_changed(value: float) -> void:
	update_values()


func _on_slider_drag_ended(value_changed: bool) -> void:
	update_values()
