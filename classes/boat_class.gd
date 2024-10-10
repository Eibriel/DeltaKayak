extends RigidBody3D
class_name Boat3D

var simple_boat_model := SimpleBoatModel.new()
var context_steering := ContextSteering.new()

var time := 999999999999.0
var time_horizon := 1.0
var recalc_time := 0.1
var p0 :Vector2
var p1 :Vector2
var p2 :Vector2
var p3 :Vector2

var speed := 0.0
var force_limit_mult := 1.0
var force_limit := 5.0

var boat_speed_multiplyer := 10.0
var torque_speed := 10.0
var torque_multiplier := 1.0
var waiting := false

var last_position:Vector3
var real_velocity_integral:Vector3
var real_velocity:Vector3
var last_rotationb:float
var last_angle_to_target:float
var real_angular_velocity:float
var about_to_collide:=false

var torque := 0.0
var last_applied_torque := 0.0

var target_position := Vector3.ZERO
var target_velocity := Vector3.ZERO
var current := Vector3.ZERO
var subtarget_position := Vector3.ZERO
var direct_target := false

var last_rotation := 0.0
var angle_to_target := 0.0
var pid_proportional_par := 1.0
var pid_integral_par := 1.0
var pid_derivative_par := 10.0

var path_visualization:Path3D
var boat_pathfinding_debug:Node3D

var last_applied_force: Vector3

var inside_turn_radius:=false

var nav_regions: Array[NavigationRegion3D]

var manual_control := Vector2.ZERO

var rudder_angle:float
var revs_per_second:float = 20.0

var boat_ray_cast:RayCast3D

func _ready():
	last_rotation = rotation.y
	last_position = position
	set_physics_process(false)
	#call_deferred("setup_physics")
	#path_target_indicator = CSGBox3D.new()
	#add_child(path_target_indicator)
	path_visualization = Path3D.new()
	path_visualization.name = "PathVisualization"
	path_visualization.top_level = true
	path_visualization.curve = Curve3D.new()
	path_visualization.curve.add_point(Vector3.ZERO, Vector3.ONE, Vector3.ONE)
	path_visualization.curve.add_point(Vector3.ONE, Vector3.ONE, Vector3.ONE)
	add_child(path_visualization)
	boat_pathfinding_debug = MeshInstance3D.new()
	add_child(boat_pathfinding_debug)
	boat_pathfinding_debug.name = "PathfindingDebug"
	boat_pathfinding_debug.mesh = ImmediateMesh.new()
	context_steering = ContextSteering.new()
	context_steering.set_debug_node(boat_pathfinding_debug.mesh)
	context_steering.resolution = 4
	
	simple_boat_model.configure(10.0)
	
	boat_ray_cast = RayCast3D.new()
	boat_ray_cast.position = Vector3(0,0,-6)
	add_child(boat_ray_cast)
	


func _manual_control(delta: float):
	if true:
		manual_control = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
		manual_control *= -1.0
	if manual_control == Vector2.ZERO: return
	simple_boat_model.position = Global.tri_to_bi(global_position)
	simple_boat_model.rotation = -rotation.y + deg_to_rad(90)
	simple_boat_model.linear_velocity = Global.tri_to_bi(linear_velocity)
	simple_boat_model.angular_velocity = angular_velocity.y
	var sbm_forces := simple_boat_model.calculate_boat_forces(
		remap(manual_control.y, -1, 1, 20*4.0, -20*4.0),
		remap(manual_control.x, -1, 1, deg_to_rad(45), deg_to_rad(-45))
	)
	var linear_to_apply := Vector3(sbm_forces.x, 0, sbm_forces.y)
	#print(linear_to_apply, sbm_forces.z*10)
	%EnemyNavigationVelocityIndicator.global_position = global_position + linear_to_apply*2
	apply_central_force(linear_to_apply)
	apply_torque(Vector3(0, sbm_forces.z, 0))
	simple_boat_model.step(delta)
	# Godot BUG ? when inertia.z is > 0, but .x and .y == 0
	# erratic behaviour

var local_data:Dictionary
var linear_force_to_apply: Vector3
var angular_force_to_apply: float
var old_target_position: Vector3
var previous_linear_velocity := Vector2.ZERO
var previous_angular_velocity := 0.0
func _physics_process(delta: float):
	context_steering.next()
	
	_get_target(delta)
	if direct_target:
		subtarget_position = target_position
	else:
		get_subtarget_position(delta)
	move_boat(delta)
	get_rudder_angle(
		subtarget_position
	)
	#_manual_control(delta)
	boat_pathfinding_debug.rotation.y = -rotation.y


var max_dist_search := 50
func get_subtarget_position(delta: float):
	boat_ray_cast.rotation.y = -rotation.y
	boat_ray_cast.target_position = Vector3(max_dist_search, 0, 0)
	for rad in context_steering.get_angles():
		var vect := Vector3.LEFT.rotated(Vector3.UP, rad) * max_dist_search
		boat_ray_cast.target_position = vect
		boat_ray_cast.force_raycast_update()
		if boat_ray_cast.is_colliding():
			context_steering.append(
				global_position.distance_to(boat_ray_cast.get_collision_point())
			)
		else:
			context_steering.append(max_dist_search)

	var angle_to_target := Global.tri_to_bi(global_position).angle_to_point(Global.tri_to_bi(target_position))
	angle_to_target = Global.pi_2_pi(-angle_to_target+deg_to_rad(180))
	var angle := context_steering.get_direction(angle_to_target, delta)
	#angle += deg_to_rad(-90)
	subtarget_position = Vector3.LEFT.rotated(Vector3.UP, angle)*10 + global_position
	#subtarget_position = Vector3.FORWARD.rotated(Vector3.UP, rotation.y+deg_to_rad(-4))*15 + global_position
	%EnemyNavigationVelocityIndicator.global_position = subtarget_position
	%EnemyNavigationVelocityIndicator.global_position.y = 5

## Simulates and applies forces to the boat
func move_boat(delta: float) -> void:
	setup_boat_model(
			simple_boat_model,
			linear_velocity,
			angular_velocity.y,
			global_position,
			rotation.y)
	#print(revs_per_second)
	#revs_per_second = 20.0
	#rudder_angle = deg_to_rad(5)
	#print(rudder_angle)
	%Rudder.rotation.y = -rudder_angle
	var forces_to_apply := simple_boat_model.calculate_boat_forces(
		revs_per_second*5.0,
		rudder_angle
	)
	simple_boat_model.step(delta)
	
	var torque_to_apply := forces_to_apply.z
	var force_to_apply := Vector3(forces_to_apply.x, 0.0, forces_to_apply.y)
	#%EnemyNavigationVelocityIndicator.global_position = global_position + force_to_apply*20
	#%EnemyNavigationVelocityIndicator.global_position.y = 10.0
	apply_torque(Vector3(0, torque_to_apply, 0))
	apply_central_force(force_to_apply)


func setup_boat_model(
		boat_model:SimpleBoatModel,
		_linear_velocity:Vector3,
		_angular_velocity:float,
		_position:Vector3,
		_rotation:float):
	boat_model.linear_velocity = Global.tri_to_bi(_linear_velocity)
	boat_model.angular_velocity = _angular_velocity
	boat_model.position = Global.tri_to_bi(_position)
	boat_model.rotation = -(_rotation+deg_to_rad(90))
	#boat_model.rotation = -_rotation


## Determine rudder angle from sub target position
func get_rudder_angle(target_position: Vector3):
	# TODO switch from Vector3 to Vector2
	var rotation_vector := global_position.direction_to(target_position)
	var angle_to_target := Vector3.RIGHT.signed_angle_to(-rotation_vector.rotated(Vector3.UP, deg_to_rad(90)), Vector3.UP)
	var forward_direction := Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	var direction_error := rotation_vector.dot(forward_direction)
	var rotation_y:float = rotation.y
	var error := angle_difference(angle_to_target, rotation_y)
	#prints(error, angle_to_target, rotation_y)
	error *= -1.0
	var poportional := get_proportional(error)
	var integral := get_proportional(error)
	var derivative := get_derivative(error)
	#prints(poportional, integral, derivative)
	rudder_angle = 0.0
	rudder_angle += poportional
	rudder_angle += integral
	rudder_angle += derivative
	rudder_angle = Global.pi_2_pi(rudder_angle)
	rudder_angle = clampf(rudder_angle, deg_to_rad(-45), deg_to_rad(45))
	#print(rudder_angle)
	last_rotation = rotation.y
	
	#print(error)
	if abs(direction_error) > 0.5:
		revs_per_second = 20
	else:
		revs_per_second = 10
	if direction_error < 0:
		%RearRayCast.force_raycast_update()
		if not %RearRayCast.is_colliding():
			revs_per_second *= -1.0
		rudder_angle *= -1.0
	#prints(error, direction_error, revs_per_second)
	#print(revs_per_second)

# PID control Torque
func get_proportional(error) -> float:
	# Minimizes error
	# Adds
	return error * pid_proportional_par

func get_integral(_error) -> float:
	# External perturvations (inertia)
	# Compensates
	var integral = angular_velocity.y * pid_integral_par
	return -integral

func get_derivative(_error) -> float:
	# Error change speed
	# Substracts
	var derivative = last_rotation - rotation.y
	if absf(derivative) > PI:
		if rotation.y > last_rotation:
			derivative = -(last_rotation + rotation.y)
		else:
			derivative = -(rotation.y + last_rotation)
	return derivative * pid_derivative_par


func _integrate_forces(state:PhysicsDirectBodyState3D):
	_handle_contacts(state)
	var dvel := simple_boat_model.damped_velocity(
		Global.tri_to_bi(state.linear_velocity),
		state.angular_velocity.y,
		Engine.physics_ticks_per_second,
		-(rotation.y+deg_to_rad(90))
	)
	state.linear_velocity = Global.bi_to_tri(dvel[0])
	state.angular_velocity = Vector3(0, dvel[1], 0)


## Virtual method
func _get_target(_delta: float):
	pass

## Virtual method
func _handle_contacts(_state: PhysicsDirectBodyState3D):
	pass

## Virtual method
func _get_sensor_data() -> Dictionary:
	return {}
