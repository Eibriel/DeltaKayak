class_name BoatModel

# https://link.springer.com/article/10.1007/s00773-014-0293-y
# https://github.com/nikpau/mmgdynamics

# Parameters
class Parameters:
	# derivatives
	var R_0_dash:float
	var X_vv_dash:float
	var X_vr_dash:float
	var X_rr_dash:float
	var X_vvvv_dash:float
	var Y_v_dash:float
	var Y_r_dash:float
	var Y_vvv_dash:float
	var Y_vvr_dash:float
	var Y_vrr_dash:float
	var Y_rrr_dash:float
	var N_v_dash:float
	var N_r_dash:float
	var N_vvv_dash:float
	var N_vvr_dash:float
	var N_vrr_dash:float
	var N_rrr_dash:float
	# experimental
	var kappa:float = 0.5
	# propeller
	var J_slo:float = -0.5
	var J_int:float = 0.4
	# Masses and added masses
	var displ: float # Displacement in [m³]
	var m_x_dash: float # Non dimensionalized added masses coefficient in x direction
	var m_y_dash: float # Non dimensionalized added masses coefficient in y direction
	# Moment of inertia and added moment of inertia
	var J_z_dash: float # Added moment of inertia coefficient
	var x_G: float # X-Coordinate of the center of gravity (m)
	#
	var C_1: float
	var C_2_plus: float
	var C_2_minus: float
	var k_0: float
	var k_1: float
	var k_2: float
	# rho
	var water_density := 1.0 
	#
	var rudder_aspect_ratio := 1.0
	#A_R
	var rudder_surface_area := 0.0
	var distance_rudder_mass_center := 2.0 #
	# a_H: the factor of lateral force acting on ship hull by steering
	# (lateral component of F_N)
	var rudder_force_increase_factor := 1.0
	#H_R
	# Rudder span length
	var rudder_span_length := 1.0
	# L_pp
	var ship_length_between_perpendiculars := 1.0
	#xH': The longitudinal acting point of the additional lateral force component.
	var position_of_additional_lateral_force := 1.0
	#xR
	#var longitudinal_coordinate_of_rudder_position:= -0.5*ship_length_between_perpendiculars
	#xP
	var longitudinal_coordinate_of_propeller_position:= 1.0
	#gamma_R
	var flow_straightening_coefficient := 0.0
	var flow_straightening_coefficient_plus := 0.0
	var flow_straightening_coefficient_minus := 0.0
	# d: Ship draft (Tiefgang)
	var ship_draft:float = 1.0
	# t_R
	var steering_resistance_deduction_factor:float = 1.0
	#t_P
	var thrust_deduction_factor:float = 0.1
	# D_P
	# Propeller diameter
	var propeller_diameter := 0.7
	#r
	var yaw_rate := 0.0
	#l_R
	# Effective longitudinal coordinate of rudder position
	# BUG this is not l_R
	var effective_longitudinal_coordinate_of_rudder_position := 1.0
	#l_R
	# correction of flow straightening factor to yaw-rate
	var correction_of_flow_straightening_factor_to_yaw_rate := 1.0
	#R'
	# Ship resistance coefficient in straight moving
	var resistance_coefficient_straight_moving := 1.0
	# epsilon
	# Ratio of wake fraction at propeller and rudder positions
	var ratio_of_wake_fraction_at_propeller_and_rudder_positions := 1.0
	# eta
	# Ratio of propeller diameter to rudder span
	var ratio_of_propeller_diameter_to_rudder_span := 1.0
	#w_P0
	# Wake coefficient at propeller position in straight moving
	var wake_coefficient_at_propeller_position_in_straight := 1.0
	#w_R
	# Wake coefficient at rudder position
	var wake_coefficient_at_rudder_position := 1.0
	#beta
	# Hull drift angle at midship
	#var hull_drift_angle_at_midship := 1.0
	# f_alpha
	#Rudder lift gradient coefficient
	var rudder_lift_gradient_coefficient := 1.0

#var coefficient_hull_influence_on_rudder_force := 1.0 #
var rudder_angle := 0.0 #delta  >0 portside, <0 starboard
var revs_per_second := 0.0

# x: longitudinal velocity - u
# y: latera velocity - v
var linear_velocity:Vector2
var angular_velocity:float


var p:= Parameters.new()

class BoatForces:
	var force:Vector2
	var moment:float
	
	func _init(force:Vector2, moment:float) -> void:
		self.force = force
		self.moment = moment

## J_P
## Propeller advanced ratio
func propeller_advanced_ratio() -> float:
	var w_P := pre_wake_coefficient_at_propeller_position_in_maneuvering
	var res: float
	if revs_per_second == 0.0:
		res = 0.0
	else:
		res = (1.0 - w_P) * linear_velocity.x / (revs_per_second * p.propeller_diameter)
	
	return res

## beta_P
var pre_beta_P:float
func beta_P() -> float:
	#var tt := drift_angle_at_midship_position()
	#var pp := nondimensionalized_yaw_rate()
	return drift_angle_at_midship_position() - \
		(p.longitudinal_coordinate_of_propeller_position/ \
		p.ship_length_between_perpendiculars) * \
		pre_nondimensionalized_yaw_rate

## w_P
## Wake coefficient at propeller position in maneuvering motions
var pre_wake_coefficient_at_propeller_position_in_maneuvering: float
func wake_coefficient_at_propeller_position_in_maneuvering() -> float:
	var w_P:float
	var w_P0 := p.wake_coefficient_at_propeller_position_in_straight
	var _beta_P := pre_beta_P
	
	if true: # TODO check if C_1 and C_2 parameters are set
		var C_2:float
		if _beta_P >= 0:
			C_2 = p.C_2_plus
		else:
			C_2 = p.C_2_minus
		var tmp = 1.0-exp(-p.C_1*abs(_beta_P))*(C_2-1.0)
		w_P = 1.0-(1.0-w_P0)*(1.0+tmp)
	else:
		w_P = w_P0 * exp(-4.0 * _beta_P**2) 
	return w_P

## K_T
## Propeller thrust open water characteristic
var pre_propeller_thrust_open_water_characteristic:float
func propeller_thrust_open_water_characteristic() -> float:
	var K_T:float
	var J_P := propeller_advanced_ratio()
	if true: # TODO check if k parameters are set
		K_T = p.k_0 + (p.k_1 * J_P) + (p.k_2 * J_P**2)
	else:
		K_T = p.J_slo * J_P * p.J_int
	return K_T

## u_R
func longitudinal_inflow_velocity_component_to_rudder() -> float:
	var J_P := propeller_advanced_ratio()
	if J_P == 0.0:
		return 0.0
	
	#var w_R := p.wake_coefficient_at_rudder_position
	#var h_R := p.rudder_span_length
	var w_P := pre_wake_coefficient_at_propeller_position_in_maneuvering
	var K_T := pre_propeller_thrust_open_water_characteristic
	
	# epsilon
	#p.ratio_of_wake_fraction_at_propeller_and_rudder_positions = (1.0-w_R) / (1.0-w_P)
	p.ratio_of_wake_fraction_at_propeller_and_rudder_positions = 1.09
	# eta
	#p.ratio_of_propeller_diameter_to_rudder_span = p.propeller_diameter/h_R
	p.ratio_of_propeller_diameter_to_rudder_span = 0.626
	
	# Experimental constant
	var kappa := p.kappa
	
	var u_R := linear_velocity.x * (1.0 - w_P) * \
		p.ratio_of_wake_fraction_at_propeller_and_rudder_positions * \
		sqrt(p.ratio_of_propeller_diameter_to_rudder_span * (1.0 + kappa * \
		(sqrt(1.0+8.0*K_T/(PI * J_P**2))-1.0))**2 + \
		(1.0 - p.ratio_of_propeller_diameter_to_rudder_span))
	return u_R

## U_R
func resultant_inflow_velocity_to_rudder() -> float:
	var U_R:= pre_inflow_velocity_component_to_rudder.length()
	return U_R

## A_R
func rubber_profile_area():
	return 6.13*p.rudder_aspect_ratio / p.rudder_aspect_ratio + 2.25

## beta
func drift_angle_at_midship_position() -> float:
	if linear_velocity.x == 0.0:
		return 0.0
	else:
		return atan(-linear_velocity.y/linear_velocity.x)

## v'
## Non-dimensionalized lateral velocity
var pre_nondimensionalized_lateral_velocity:float
func nondimensionalized_lateral_velocity() -> float:
	if overall_vessel_speed() == 0:
		return 0.0
	else:
		return linear_velocity.y / overall_vessel_speed()

## r'
## non-dimensionalized yaw rate
var pre_nondimensionalized_yaw_rate:float
func nondimensionalized_yaw_rate() -> float:
	if overall_vessel_speed() == 0:
		return 0.0
	else:
		var nyr := angular_velocity * p.ship_length_between_perpendiculars / overall_vessel_speed()
		return nyr

"""
# x_H'
func position_of_additional_lateral_force() -> float:
	if true:
		return -0.464
	return -0.45*p.ship_length_between_perpendiculars 
"""

## x_H
## Redimensionalize x_H'
func redimensionalized_x_H_dash() -> float:
	return p.position_of_additional_lateral_force * p.ship_length_between_perpendiculars

## beta_R
## Effective inflow angle to rudder in maneuvering motions
var pre_effective_inflow_angle_to_rudder:float
func effective_inflow_angle_to_rudder() -> float:
	return drift_angle_at_midship_position() - \
		p.correction_of_flow_straightening_factor_to_yaw_rate * \
		pre_nondimensionalized_yaw_rate

## gamma_R
## Flow straightening coefficient
func flow_straightening_coefficient() -> float:
	var beta_R:= pre_effective_inflow_angle_to_rudder
	if p.flow_straightening_coefficient != 0:
		return p.flow_straightening_coefficient
	else:
		if beta_R < 0:
			return p.flow_straightening_coefficient_minus
		else:
			return p.flow_straightening_coefficient_plus

## Longitudinal and lateral inflow velocity component to rudder
## u_R v_R
var pre_inflow_velocity_component_to_rudder:Vector2
func inflow_velocity_component_to_rudder() -> Vector2:
	var resistance_coefficient_straight_moving := pre_effective_inflow_angle_to_rudder
	
	var gamma_R := flow_straightening_coefficient()
	
	var u_R = longitudinal_inflow_velocity_component_to_rudder()
	var v_R = overall_vessel_speed() * \
		gamma_R * \
		resistance_coefficient_straight_moving
	return Vector2(u_R, v_R)

## alpha_R
func effective_rudder_angle_of_attack() -> float:
	var u_Rv_R := pre_inflow_velocity_component_to_rudder
	return rudder_angle - \
		atan2(u_Rv_R.y, u_Rv_R.x)

## F_N
var pre_rudder_normal_force:float
func rudder_normal_force() -> float:
	var U_R := resultant_inflow_velocity_to_rudder()
	var f:float
	if p.rudder_surface_area != 0:
		f = 0.5 * p.rudder_surface_area * \
			p.water_density * p.rudder_lift_gradient_coefficient * \
			(U_R**2) * \
			sin(effective_rudder_angle_of_attack())
	else:
		f = 0.5 * rubber_profile_area() * \
			(p.ship_length_between_perpendiculars * p.shift_draft *p.water_density) * \
			p.rudder_lift_gradient_coefficient * \
			(U_R**2) * \
			sin(effective_rudder_angle_of_attack())
	return f

# U
func overall_vessel_speed() -> float:
	return linear_velocity.length()

func hull_moment_derivatives() -> float:
	var v_dash:float = pre_nondimensionalized_lateral_velocity
	var r_dash:float = pre_nondimensionalized_yaw_rate
	
	var N_H_der:float = p.N_v_dash * v_dash \
		+ p.N_r_dash * r_dash \
		+ p.N_vvv_dash * (v_dash**3) \
		+ p.N_vvr_dash * (v_dash**2) * r_dash \
		+ p.N_vrr_dash * v_dash * (r_dash**2) \
		+ p.N_rrr_dash * (r_dash**3)
	
	return N_H_der

func surge_force_hull_derivatives() -> float:
	var v_dash:float = pre_nondimensionalized_lateral_velocity
	var r_dash:float = pre_nondimensionalized_yaw_rate
	
	var W_H_der:float = - p.R_0_dash \
		+ p.X_vv_dash * (v_dash**2) \
		+ p.X_vr_dash * v_dash * r_dash \
		+ p.X_rr_dash * (r_dash**2) \
		+ p.X_vvvv_dash * (v_dash**4)
	return W_H_der

func lateral_force_hull_derivatives() -> float:
	var v_dash:float = pre_nondimensionalized_lateral_velocity
	var r_dash:float = pre_nondimensionalized_yaw_rate
	
	var Y_H_der:float = p.Y_v_dash * v_dash \
		+ p.Y_r_dash * r_dash \
		+ p.Y_vvv_dash * (v_dash**3) \
		+ p.Y_vvr_dash * (v_dash**2) * r_dash \
		+ p.Y_vrr_dash * v_dash * (r_dash**2) \
		+ p.Y_rrr_dash * (r_dash**3)
	return Y_H_der

# Hull

## X_H
func surge_force_ship_hull() -> float:
	var X_H:float = (0.5 * \
		p.water_density * \
		p.ship_length_between_perpendiculars * \
		p.ship_draft * \
		(overall_vessel_speed()**2)) * \
		surge_force_hull_derivatives()
	return X_H

## N_H
func hull_moment() -> float:
	var os := overall_vessel_speed()
	var hmd := hull_moment_derivatives()
	var N_H:float = 0.5 *\
		p.water_density *\
		(p.ship_length_between_perpendiculars**2) *\
		p.ship_draft *\
		(overall_vessel_speed()**2) *\
		hull_moment_derivatives()
	#if N_H > 162256263179:
	#	breakpoint
	return N_H

## Y_H
func lateral_force_on_ship_hull() -> float:
	var Y_H:float = 0.5 * p.water_density * p.ship_length_between_perpendiculars * \
		p.ship_draft * \
		(overall_vessel_speed()**2) * \
		lateral_force_hull_derivatives()
	
	return Y_H

# Rudder

## X_R
func surge_force_by_steering() -> float:
	var X_R:float = -(1.0-p.steering_resistance_deduction_factor) * \
		pre_rudder_normal_force * \
		sin(rudder_angle)
	return X_R

## Y_R
func lateral_force_by_steering() -> float:
	var Y_R:float = -(1.0+p.rudder_force_increase_factor) * \
		pre_rudder_normal_force * \
		cos(rudder_angle)
	return Y_R

func longitudinal_coordinate_of_rudder_position() -> float:
	return -0.5 * p.ship_length_between_perpendiculars

## N_R
func rudder_moment() -> float:
	var tt := longitudinal_coordinate_of_rudder_position()
	var x_H := redimensionalized_x_H_dash()
	var N_R: float= -(tt + \
		p.rudder_force_increase_factor * \
		x_H) * \
		pre_rudder_normal_force * \
		cos(rudder_angle)
	
	# NOTE Model can't go backwards!
	#if linear_velocity.x < 0:
	#	N_R *= -1.0
	
	return N_R

# Propeller

## X_P
func surge_force_by_propeller() -> float:
	var K_T:float = pre_propeller_thrust_open_water_characteristic
	
	var X_P:float = (1.0-p.thrust_deduction_factor) * p.water_density * K_T * \
		(revs_per_second**2) * \
		(p.propeller_diameter**4)
	
	# NOTE Model can't go backwards!
	#if revs_per_second < 0:
	#	X_P *= -1.0
	
	return X_P

## Hacks the model to allow the boat to go backwards
func extended_boat_model(
		linear_velocity:Vector2,
		angular_velocity:float,
		revs_per_second:float,
		rudder_angle:float) -> BoatForces:
	if revs_per_second <0:
		linear_velocity = linear_velocity.rotated(deg_to_rad(180))
		rudder_angle *= -1.0
	var rforces := get_boat_forces(linear_velocity, angular_velocity, abs(revs_per_second), rudder_angle)
	if revs_per_second <0:
		rforces.force = rforces.force.rotated(deg_to_rad(180))
	return rforces

func get_boat_forces(
		linear_velocity:Vector2,
		angular_velocity:float,
		revs_per_second:float,
		rudder_angle:float) -> BoatForces:
	self.linear_velocity = linear_velocity
	self.angular_velocity = angular_velocity
	self.rudder_angle = rudder_angle
	self.revs_per_second = revs_per_second
	
	# Precompute variables:
	pre_nondimensionalized_lateral_velocity = nondimensionalized_lateral_velocity()
	pre_nondimensionalized_yaw_rate = nondimensionalized_yaw_rate()
	pre_beta_P = beta_P()
	pre_wake_coefficient_at_propeller_position_in_maneuvering = wake_coefficient_at_propeller_position_in_maneuvering()
	pre_propeller_thrust_open_water_characteristic = propeller_thrust_open_water_characteristic()
	pre_effective_inflow_angle_to_rudder = effective_inflow_angle_to_rudder()
	pre_inflow_velocity_component_to_rudder = inflow_velocity_component_to_rudder()
	pre_rudder_normal_force = rudder_normal_force()
	
	# Wind is not computed
	var X_H:float = surge_force_ship_hull() #X_H
	var X_R:float = surge_force_by_steering() #X_R
	var X_P:float = surge_force_by_propeller() #X_P
	
	var FX:float = X_H + X_R + X_P
	
	var Y_H:float = lateral_force_on_ship_hull() #Y_H
	var Y_R:float = lateral_force_by_steering() #Y_R
	
	var FY:float = Y_H + Y_R #+ Y_W
	
	var N_H:float = hull_moment() #N_H
	var N_R:float = rudder_moment() #N_R
	
	var FN:float = N_H + N_R #+ N_W
	
	# Added masses and added moment of inertia
	var rho := p.water_density
	var Lpp := p.ship_length_between_perpendiculars
	var d := p.ship_draft
	
	var m_x = p.m_x_dash * (0.5 * rho * (Lpp**2) * d)
	var m_y = p.m_y_dash * (0.5 * rho * (Lpp**2) * d)
	var J_z = p.J_z_dash * (0.5 * rho * (Lpp**4) * d)
	var m = p.displ*rho
	var I_zG = m*(0.25*Lpp)**2
	
	# Mass matrices
	var M_RB = [Vector3(m, 0.0, 0.0),
				Vector3(0.0, m, m * p.x_G),
				Vector3(0.0, m * p.x_G, I_zG)]
	var M_A = [Vector3(m_x, 0.0, 0.0),
				Vector3(0.0, m_y, 0.0),
				Vector3(0.0, 0.0, J_z + (p.x_G**2) * m)]
	var M_sum := Basis(
		M_RB[0] + M_A[0],
		M_RB[1] + M_A[1],
		M_RB[2] + M_A[2],
	)
	#print(M_sum)
	var M_inv := M_sum.inverse()
	
	#print(M_inv)
	#var M_inv = np.linalg.inv(M_RB + M_A)
	var M_inv_array:Array[Vector3] = [
		M_inv.x,
		M_inv.y,
		M_inv.z,
	]
	
	var F := Vector3(FX, FY, FN)
	
	var r:= angular_velocity
	var u := linear_velocity.x
	var v_m := linear_velocity.y
	#
	var _C_RB_res := _C_RB(m,p.x_G,r)
	var _C_A_res := _C_A(m_x, m_y, u, v_m)
	var added:Array[Vector3]= [
		_C_RB_res[0] + _C_A_res[0],
		_C_RB_res[1] + _C_A_res[1],
		_C_RB_res[2] + _C_A_res[2],
	]
	# TODO use Basis for matrix math, not Arrays[Vector3)
	var mult_1 := multiply_matrix_by_vector(added, Vector3(u, v_m, r))
	var rest_1 := F - mult_1
	var final_res = multiply_matrix_by_vector(M_inv_array, rest_1)
	
	#if final_res.z > 10.0:
	#	breakpoint
	
	return BoatForces.new(Vector2(final_res.x, final_res.y), final_res.z)


func _C_RB(m:float,x_G:float, r:float)->Array[Vector3]:
	return [
		Vector3(0.0, -m * r, -m * x_G * r),
		Vector3(m * r, 0.0, 0.0),
		Vector3(m * x_G * r, 0.0, 0.0)]

func _C_A(m_x:float,m_y:float,u:float, vm:float)->Array[Vector3]:
	return [
		Vector3(0.0, 0.0, -m_y * vm),
		Vector3(0.0, 0.0, m_x * u),
		Vector3(0.0, 0.0, 0.0)]

func tests():
	# Test
	var t_linear_velocity := Vector2(0.08599999999569, 0.0170000000071)
	var t_angular_velocity := -0.04300000000512
	var t_rudder_angle := -0.63999999999942
	var t_r := -20.0
	var new_local_forces = extended_boat_model(
		t_linear_velocity,
		t_angular_velocity,
		t_r,
		t_rudder_angle)
	if new_local_forces.moment > 10.0:
		breakpoint
	
	
	var test_C_RB := _C_RB(0.5,1.1, 2.0)
	var res:Array[Vector3]= [Vector3(0.,  -1.,  -1.1),
		Vector3(1.,   0.,   0.),
		Vector3(1.1,  0.,   0.)]
	assert(test_C_RB == res)
	var test_C_A := _C_A(0.6,1.0,0.4,0.3)
	res = [Vector3(0.,    0.,   -0.3),
		Vector3(0.,    0.,    0.24),
		Vector3(0.,    0.,    0.)]
	assert(test_C_A == res)
	#
	var M_RBt:Array[Vector3] = [Vector3(0.2, 0.0, 0.0),
				Vector3(0.0, 0.4, 0.6),
				Vector3(0.0, 0.8, 10.0)]
	var M_At:Array[Vector3] = [Vector3(0.1, 0.0, 0.0),
				Vector3(0.0, 0.3, 0.0),
				Vector3(0.0, 0.0, 0.5)]
	var M_sumt := Basis(
		M_RBt[0] + M_At[0],
		M_RBt[1] + M_At[1],
		M_RBt[2] + M_At[2],
	)
	var M_invt := M_sumt.inverse()
	var res_b := Basis(Vector3(3.33333333, 0., 0.),
		Vector3(0., 1.52838428, -0.08733624),
		Vector3(-0., -0.11644833,  0.10189229))
	assert(M_invt.is_equal_approx(res_b))
	
	# Dot M_RBt, M_At
	var dot_ = multiply_matrix_by_vector(M_RBt, Vector3(0.1, 0.2, 0.3))
	assert(dot_.is_equal_approx(Vector3(0.02, 0.26, 3.16)))

# Generated by ChatGPT

# Function to multiply two 3x3 matrices stored as Array[Vector3]
func multiply_matrices(matrix_a: Array, matrix_b: Array) -> Array:
	var result = []
	
	for i in range(3):
		var result_row = Vector3()
		for j in range(3):
			result_row[j] = matrix_a[i].dot(Vector3(matrix_b[0][j], matrix_b[1][j], matrix_b[2][j]))
		result.append(result_row)
	
	return result

# Function to multiply a 3x3 matrix (Array[Vector3]) by a Vector3
func multiply_matrix_by_vector(matrix: Array, vector: Vector3) -> Vector3:
	return vector * Basis(matrix[0], matrix[1], matrix[2])
	
	var result = Vector3()
	
	for i in range(3):
		result[i] = matrix[i].dot(vector)
	
	return result
#

func load_parameters():
	var boat_preset := kvlcc2_l64_dump
	p.R_0_dash = boat_preset.R_0_dash
	p.X_vv_dash = boat_preset.X_vv_dash
	p.X_vr_dash = boat_preset.X_vr_dash
	p.X_rr_dash = boat_preset.X_rr_dash
	p.X_vvvv_dash = boat_preset.X_vvvv_dash
	p.Y_v_dash = boat_preset.Y_v_dash
	p.Y_r_dash = boat_preset.Y_r_dash
	p.Y_vvv_dash = boat_preset.Y_vvv_dash
	p.Y_vvr_dash = boat_preset.Y_vvr_dash
	p.Y_vrr_dash = boat_preset.Y_vrr_dash
	p.Y_rrr_dash = boat_preset.Y_rrr_dash
	p.N_v_dash = boat_preset.N_v_dash
	p.N_r_dash = boat_preset.N_r_dash
	p.N_vvv_dash = boat_preset.N_vvv_dash
	p.N_vvr_dash = boat_preset.N_vvr_dash
	p.N_vrr_dash = boat_preset.N_vrr_dash
	p.N_rrr_dash = boat_preset.N_rrr_dash
	p.displ = boat_preset.displ
	p.m_x_dash = boat_preset.m_x_dash
	p.m_y_dash = boat_preset.m_y_dash
	p.J_z_dash = boat_preset.J_z_dash
	p.x_G = boat_preset.x_G
	p.C_1 = boat_preset.C_1
	p.C_2_minus = boat_preset.C_2_minus
	p.C_2_plus = boat_preset.C_2_plus
	p.k_0 = boat_preset.k_0
	p.k_1 = boat_preset.k_1
	p.k_2 = boat_preset.k_2
	#
	p.water_density = boat_preset.rho
	p.rudder_aspect_ratio = 2.0
	#p.rudder_surface_area = 
	p.distance_rudder_mass_center = boat_preset.x_P
	p.rudder_force_increase_factor = boat_preset.a_H
	p.ship_length_between_perpendiculars = boat_preset.Lpp
	#p.position_of_additional_lateral_force = boat_preset.x_H_dash
	#p.longitudinal_coordinate_of_rudder_position = boat_preset.
	p.flow_straightening_coefficient_plus = boat_preset.gamma_R_plus # TODO should be gamma_R
	p.flow_straightening_coefficient_minus = boat_preset.gamma_R_minus # TODO should be gamma_R
	p.ship_draft = boat_preset.d
	p.steering_resistance_deduction_factor = boat_preset.t_R
	p.thrust_deduction_factor = boat_preset.t_P
	p.propeller_diameter = boat_preset.D_p
	#p.yaw_rate = boat_preset
	p.correction_of_flow_straightening_factor_to_yaw_rate = boat_preset.l_R
	p.resistance_coefficient_straight_moving = boat_preset.R_0_dash
	
	p.ratio_of_propeller_diameter_to_rudder_span = boat_preset.eta
	p.wake_coefficient_at_propeller_position_in_straight = boat_preset.w_P0
	#p.hull_drift_angle_at_midship = boat_preset.
	p.rudder_surface_area = boat_preset.A_R
	p.rudder_lift_gradient_coefficient = boat_preset.f_alpha
	p.longitudinal_coordinate_of_propeller_position = boat_preset.x_P
	p.position_of_additional_lateral_force = boat_preset.x_H_dash

const kvlcc2_l7 = {
	"C_b":          0.810, # Block Coeffiient
	"Lpp":          7.0, # Length over pependiculars (m)
	"B":            1.27, # Overall width
	"displ":        3.2724, # Displacement in [m³]
	"w_P0":         0.40, # Assumed wake fraction coefficient
	"J_int":        0.4, # Intercept for the calculation of K_T (https://doi.org/10.1615/ICHMT.2012.ProcSevIntSympTurbHeatTransfPal.500)
	"J_slo":       -0.5, # Slope for the calculation of K_T
	"x_G":          0.244, # X-Coordinate of the center of gravity (m)
	"x_P":         -3.36, # X-Coordinate of the propeller (-0.5*Lpp)
	"D_p":          0.204, # Diameter of propeller (m)
	"k_0":          0.2931, # Same value as "J_int" | Propeller open water coefficients. 
	"k_1":         -0.2753,
	"k_2":         -0.1385,    
	"C_1":          2.0,
	"C_2_plus":     1.6,
	"C_2_minus":    1.1,
	"l_R":         -0.710, # correction of flow straightening factor to yaw-rate
	"gamma_R_plus": 0.640, # Flow straightening coefficient for positive rudder angles
	"gamma_R_minus":0.395, # Flow straightening coefficient for negative rudder angles
	"eta":          0.626, # Ratio of propeller diameter to rudder span
	"kappa":        0.50, # An experimental constant for expressing "u_R"
	"A_R":          0.0654, # Moveable rudder area
	"epsilon":      1.09, # Ratio of wake fraction at propeller and rudder positions ((1 - w_R) / (1 - w_P))
	"A_R_Ld_em":    1/46.8, # Fraction of moveable Rudder area to length*draft
	"f_alpha":      2.747, # Rudder lift gradient coefficient (assumed rudder aspect ratio = 2)
	"rho":          1030, # Water density of freshwater
	"rho_air":      1.225, # Air density
	
	# From _16
	"A_Fw":         24.0,   # Frontal wind area [m²]
	"A_Lw":         72.0,   # Lateral wind area [m²]
	
	"t_R":          0.387, # Steering resistance deduction factor
	"t_P":          0.220, # Thrust deduction factor. TODO give this more than an arbitrary value
	"x_H_dash":    -0.464, # Longitudinal coordinate of acting point of the additional lateral force
	"d":            0.455, # Ship draft (Tiefgang)
	"m_x_dash":     0.022, # Non dimensionalized added masses coefficient in x direction
	"m_y_dash":     0.223, # Non dimensionalized added masses coefficient in y direction
	"R_0_dash":     0.022, # frictional resistance coefficient TODO Estimate this via Schoenherr's formula
	"X_vv_dash":   -0.040, # Hull derivatives
	"X_vr_dash":    0.002, # Hull derivatives
	"X_rr_dash":    0.011, # Hull derivatives
	"X_vvvv_dash":  0.771, # Hull derivatives
	"Y_v_dash":    -0.315, # Hull derivatives
	"Y_r_dash":     0.083, # Hull derivatives
	"Y_vvv_dash":  -1.607, # Hull derivatives
	"Y_vvr_dash":   0.379, # Hull derivatives
	"Y_vrr_dash":  -0.391, # Hull derivatives
	"Y_rrr_dash":   0.008, # Hull derivatives
	"N_v_dash":    -0.137, # Hull derivatives
	"N_r_dash":    -0.049, # Hull derivatives
	"N_vvv_dash":  -0.030, # Hull derivatives
	"N_vvr_dash":  -0.294, # Hull derivatives
	"N_vrr_dash":   0.055, # Hull derivatives
	"N_rrr_dash":  -0.013, # Hull derivatives
	"J_z_dash":     0.011, # Added moment of inertia coefficient
	"a_H":          0.312 # Rudder force increase factor
}

const kvlcc2_l64_dump = {
	"rho":1000,
	"rho_air":1.225,
	"C_b":0.81,
	"Lpp":64,
	"B":11.6,
	"d":4.16,
	"w_P0":0.35,
	"x_G":2.24,
	"x_P":-32.0,
	"D_p":1.972,
	"l_R":-0.71,
	"eta":0.626,
	"kappa":0.5,
	"A_R":4.5,
	"epsilon":1.09,
	"t_R":0.387,
	"t_P":0.22,
	"x_H_dash":-0.464,
	"a_H":0.312,
	"A_Fw":240,
	"A_Lw":720,
	"R_0_dash":0.022,
	"X_vv_dash":-0.04,
	"X_vr_dash":0.002,
	"X_rr_dash":0.011,
	"X_vvvv_dash":0.771,
	"Y_v_dash":-0.315,
	"Y_r_dash":0.083,
	"Y_vvv_dash":-1.607,
	"Y_vvr_dash":0.379,
	"Y_vrr_dash":-0.391,
	"Y_rrr_dash":0.008,
	"N_v_dash":-0.137,
	"N_r_dash":-0.049,
	"N_vvv_dash":-0.03,
	"N_vvr_dash":-0.294,
	"N_vrr_dash":0.055,
	"N_rrr_dash":-0.013,
	"displ":2500.8,
	"m_x_dash":0.022,
	"m_y_dash":0.223,
	"J_z_dash":0.011,
	"k_0":0.2931,
	"k_1":-0.2753,
	"k_2":-0.1359,
	"C_1":2.0,
	"C_2_plus":1.6,
	"C_2_minus":1.1,
	"J_slo":-0.5,
	"J_int":0.4,
	"gamma_R_plus":0.64,
	"gamma_R_minus":0.395,
	"gamma_R":null,
	"A_R_Ld_em":null,
	"f_alpha":2.747,
	"delta_prop":null
}

#3.85 0 0
#X_H -534.8854761250001
#X_R -17.783163761851533
#X_P -66.19577697296013
#Y_H 0.0
#Y_R -215.8557476986778
#N_H 0.0
#N_R 742.5595664064539
#FX -618.8644168598117
#FY -215.8557476986778
#FN 742.5595664064539
#
#3.6791927583170785 -0.042847903865440955 0.04654186277153924
#X_H -486.79443253320215
#X_R -12.24230045771634
#X_P -65.9137206008467
#Y_H 245.73181268125805
#Y_R -148.59959421399876
#N_H -429.1539628963152
#N_R 511.19347723719585
#FX -564.9504535917652
#FY 97.13221846725929
#FN 82.03951434088066
#
#3.5204930307757847 -0.13119155353348175 0.047371625038629524
#X_H -447.12471444801764
#X_R -9.735673172176373
#X_P -63.07566113720098
#Y_H 403.3040522052357
#Y_R -118.17362984860051
#N_H 60.38858581325368
#N_R 406.5259335301503
#FX -519.9360487573949
#FY 285.13042235663517
#FN 466.914519343404
#
#3.3673261091398152 -0.18811980234470765 0.06990523567019923
#X_H -408.6168704191772
#X_R -6.0643426891159296
#X_P -61.17047889337288
#Y_H 569.9082791007039
#Y_R -73.6102553510893
#N_H 39.232141469263794
#N_R 253.22466452399237
#FX -475.851692001666
#FY 496.29802374961463
#FN 292.4568059932562
#
#3.2155726477885924 -0.24947887000806707 0.07884067386961013
#X_H -373.94124498162205
#X_R -3.5071650517798534
#X_P -58.29736496101733
#Y_H 693.1741519025207
#Y_R -42.57070028105006
#N_H 207.31868460851103
#N_R 146.44632389610103
#FX -435.7457749944192
#FY 650.6034516214706
#FN 353.76500850461207
#
#3.064519504202022 -0.29617810041415343 0.08983130468647138
#X_H -340.26508369108444
#X_R -1.1049167183994963
#X_P -55.219913146477126
#Y_H 793.5634447158776
#Y_R -13.41170938922178
#N_H 251.5224477328063
#N_R 46.137261643512375
#FX -396.58991355596106
#FY 780.1517353266559
#FN 297.6597093763187
#
#2.91333855556895 -0.3336579800484206 0.09593957314268438
#X_H -308.37816402409663
#X_R 0.6526282284193221
#X_P -51.67776776771005
#Y_H 857.1502673026985
#Y_R 7.921737442294626
#N_H 301.56854114684774
#N_R -27.25135644081856
#FX -359.4033035633874
#FY 865.0720047449931
#FN 274.3171847060292
#
#2.763830980656774 -0.3590899414607556 0.09985076008245945
#X_H -278.0677689366873
#X_R 1.9384408351269256
#X_P -47.92211021835991
#Y_H 888.1853509480894
#Y_R 23.529198821953987
#N_H 316.8239565471119
#N_R -80.942165596216
#FX -324.0514383199203
#FY 911.7145497700434
#FN 235.8817909508959
#
#2.6179611992235254 -0.37413331406780004 0.10112471665588856
#X_H -249.8435859165931
#X_R 2.7565710896180735
#X_P -44.079257919562686
#Y_H 888.7958395860372
#Y_R 33.45983434682807
#N_H 318.711875661951
#N_R -115.10427843365052
#FX -291.16627274653774
#FY 922.2556739328653
#FN 203.6075972283005
#
#2.4779867599224983 -0.38028734448764123 0.10058264205523657
#X_H -224.01634524408698
#X_R 3.217351053914729
#X_P -40.313991281937945
#Y_H 866.0354897374019
#Y_R 39.052877578606136
#N_H 308.7881734766234
#N_R -134.3447563980328
#FX -261.11298547211015
#FY 905.0883673160081
#FN 174.44341707859058
