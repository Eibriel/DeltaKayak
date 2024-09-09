class_name SimpleBoatModel

var linear_velocity: Vector2
var angular_velocity:float

var linear_force: Vector2
var angular_force: float

var mass: float
var inv_mass: float
var inertia: float
var inverse_inertia: float

var position:Vector2 = Vector2.ZERO
var rotation:float = 0.0

var p_surge_multiplier := 200.0
var p_rudder_multiplier := 10.0
var p_rudder_profile_coef := 1.0
var p_vel_rudder_rel := 0.01
var p_longitudinal_damp_coef := 0.99
var p_lateral_damp_coef := 0.99
var p_vel_damp_rel := 0.01
var p_angular_damp_coef := 0.99
var p_hull_torque_coef := 0.01

func configure(mass:float) -> void:
	self.mass = mass

func calculate_boat_forces(revs_per_second: float, rudder_angle: float)->void:
	var local_velocity := linear_velocity.rotated(rotation)
	
	# More rudder_angle, the less effect revs_per_second has on longitudinal force
	var rudder_profile_coef:float= clampf(1.0 - absf(rudder_angle) * p_rudder_profile_coef, 0.0, 1.0)
	var surge_force := revs_per_second * p_surge_multiplier * rudder_profile_coef
	var surge_force_v := Vector2(surge_force, 0.0).rotated(rotation)
	add_force(surge_force_v)
	# More longirudinal velocity, more rudder angular_force
	# More revs_per_second, more rudder angular_force
	var rudder_force := rudder_angle * p_rudder_multiplier + (local_velocity.x * p_vel_rudder_rel)
	# More velocity, the more the boat rotates towards direction of motion
	# (hull is acting as a rudder)
	var direction_of_motion := local_velocity.normalized()
	var angle_to_motion := direction_of_motion.angle_to(Vector2.RIGHT.rotated(rotation))
	#rudder_force += angle_to_motion * p_hull_torque_coef
	add_torque(rudder_force)

func damping():
	# Damping
	var local_velocity_b := linear_velocity.rotated(-rotation)
	var longitudinal_damp := clampf(p_longitudinal_damp_coef * (1.0 - (local_velocity_b.x * p_vel_damp_rel)), 0.0, 1.0)
	local_velocity_b.x *= longitudinal_damp
	local_velocity_b.y *= p_lateral_damp_coef
	linear_velocity = local_velocity_b.rotated(rotation)
	
	angular_velocity *= p_angular_damp_coef


func get_torque() -> float:
	return angular_force

func step(delta:float) -> void:
	assert(mass > 0)
	# Symplectic Euler
	linear_velocity += (1.0/mass * linear_force) * delta
	angular_velocity += (1.0/mass * angular_force) * delta
	
	damping()
	
	position += linear_velocity * delta
	rotation += angular_velocity * delta
	
	reset_forces()

func add_force(force:Vector2) -> void:
	linear_force += force

func add_torque(torque:float) -> void:
	angular_force += torque

func add_force_at_pos(force: Vector2, pos: Vector2) -> void:
	add_force(force)
	add_torque(pos.cross(force))

func reset_forces() -> void:
	linear_force = Vector2.ZERO
	angular_force = 0.0

func get_local_velocity() -> Vector2:
	return linear_velocity.rotated(rotation)
