extends Boat3D

@export var home_position:Vector3

@export var engine_curve_1:Curve
@export var engine_curve_2:Curve
@export var engine_curve_3:Curve
@export var engine_curve_4:Curve
@export var engine_curve_5:Curve
@export var engine_curve_6:Curve
@export var engine_curve_7:Curve

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var ray_cast_3d: RayCast3D = $RayCast3D

var current_state := STATE.SLEEPING
var attack_state := ATTACK_STATE.START

var on_alert_time := 0.0
var attack_start_time := 0.0
var attack_charge_time := 0.0
var attack_intimidate_time := 0.0
var path_blocked_time := 0.0
var avoid_collision_time := 0.0

var forward_force := 0.0
#var attack_position:Vector3

enum STATE {
	SLEEPING,
	ALERT,
	ATTACK,
	SEARCHING_FOOD,
	EATING,
	STUCK,
	AVOID_COLLISION
}

enum ATTACK_STATE {
	START,
	INTIMIDATE,
	CHARGE
}

func _process(delta: float) -> void:
	Global.log_text += "\nState: %s" % STATE.find_key(current_state)
	#Global.log_text += "\nAttack: %s" % ATTACK_STATE.find_key(attack_state)
	#%AttackPositionindicator.global_position = attack_position
	is_stuck(delta)
	inside_turn_radius = is_target_inside_rotation_radius()
	handle_sounds()
	handle_music()
	
	%PhantomArea1.position = global_position - (real_velocity * 1)
	%PhantomArea1.rotation.y = rotation.y

func handle_music():
	var dist := global_position.distance_to(Global.character.global_position)
	%MusicPlayer.volume_db = remap(dist, 0, 50, -10, -30)

func handle_sounds():
	var new_forward_force = lerpf(forward_force, -last_applied_force.rotated(Vector3.UP, -rotation.y).z, 0.1)
	if new_forward_force > 0.0 and forward_force < 0.0:
		#print("Shift forward")
		%ShiftAudio.play()
	elif new_forward_force < 0.0 and forward_force > 0.0:
		#print("Shift backward")
		%ShiftAudio.play()
	forward_force = new_forward_force
	#print(forward_force)
	#var pitch := remap(abs(forward_force), 0, 15, 0.2, 1.0)
	#Global.log_text += "\nforward_force: %f" % forward_force
	#%MotorAudio.pitch_scale = pitch
	#var volume := remap(abs(forward_force), 0, 15, -20.0, 0.0)
	#%MotorAudio.volume_db = volume
	
	var engine_speed := remap(abs(forward_force), 0, 15, 0.0, 1.0)
	var samples := [
		engine_curve_1.sample(engine_speed),
		engine_curve_2.sample(engine_speed),
		engine_curve_3.sample(engine_speed),
		engine_curve_4.sample(engine_speed),
		engine_curve_5.sample(engine_speed),
		engine_curve_6.sample(engine_speed),
		engine_curve_7.sample(engine_speed)
	]
	for n in range(samples.size()):
		var vol:float = (samples[n]*20) - 20
		#prints(n, vol)
		%EngineAudio.stream["stream_%s/volume" % n] = vol
	
	# TODO move outside this function
	var particle_vel := remap(abs(forward_force), 0, 15, 0, 2)
	var particle_amount := remap(abs(forward_force), 0, 15, 0, 1)
	%SmokeParticles.process_material.initial_velocity_min = particle_vel*0.9
	%SmokeParticles.process_material.initial_velocity_max = particle_vel
	%SmokeParticles.amount_ratio = particle_amount
	

func _get_target(delta: float) -> void:
	change_state()
	
	if current_state == STATE.ATTACK:
		%AttackIndicator.visible = true
		%SpotLightEnemy.visible = true
		%OmniLightEnemy.visible = true
		change_attack_state()
		#is_trail_visible() # TODO line may not be needed
		#target_position = attack_position
		boat_speed = 0.5
		if attack_state == ATTACK_STATE.START:
			attack_start_time += delta
			boat_speed = 0.8
			
		if attack_state == ATTACK_STATE.CHARGE:
			attack_charge_time += delta
			boat_speed = 0.4
			if global_position.distance_to(Global.character.global_position) > 4.0:
				waiting = false
			else:
				waiting = true
		if attack_state == ATTACK_STATE.INTIMIDATE:
			attack_intimidate_time += delta
			boat_speed = 0.1
	if current_state == STATE.ALERT:
		on_alert_time += delta
		boat_speed = 0.4
	if current_state == STATE.SLEEPING:
		%AttackIndicator.visible = false
		%SpotLightEnemy.visible = false
		%OmniLightEnemy.visible = false
		#nav.target_position = home_position
		#if nav.is_target_reachable():
		#	target_position = nav.get_next_path_position()
		target_position = global_position
		boat_speed = 0.2
		if global_position.distance_to(home_position) > 2.0:
			waiting = false
		else:
			waiting = true
	if current_state == STATE.AVOID_COLLISION:
		if avoid_collision_time == 0:
			#var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
			var prev_target_position = target_position
			target_position = global_position + (real_velocity * 50)
			#target_velocity = real_velocity * 5
			target_velocity = target_position.direction_to(prev_target_position) * 5
			#prints(target_position, target_velocity)
		avoid_collision_time += delta
	
	#path_blocked_time -= delta
	#if path_blocked_time < 0:
		#path_blocked_time = 0.0
	#if path_blocked_time > 0.0:
		#boat_speed = -1.0
	#%RayAhead.force_raycast_update()
	#if %RayAhead.is_colliding():
		#path_blocked_time = 5
		##print("path_blocked")

func change_attack_state():
	match attack_state:
		ATTACK_STATE.START:
			check_attack_start_exit()
		ATTACK_STATE.INTIMIDATE:
			check_attack_intimidate_exit()
		ATTACK_STATE.CHARGE:
			check_attack_charge_exit()

func check_attack_start_exit():
	if attack_start_time > 1.0:
		attack_start_time = 0.0
		if randf() > 0.5:
			attack_state = ATTACK_STATE.CHARGE
		else:
			attack_state = ATTACK_STATE.INTIMIDATE

func check_attack_intimidate_exit():
	if attack_intimidate_time > 4.0:
		attack_intimidate_time = 0.0
		attack_state = ATTACK_STATE.CHARGE

func check_attack_charge_exit():
	if attack_charge_time > 10.0:
		attack_charge_time = 0.0
		attack_state = ATTACK_STATE.INTIMIDATE

func change_state():
	if current_state != STATE.AVOID_COLLISION and about_to_collide:
		#prints(real_velocity.length())
		if real_velocity.length() > 5:
			about_to_collide = false
			current_state = STATE.AVOID_COLLISION
			#print("AVOID_COLLISION")
	match current_state:
		STATE.SLEEPING:
			check_sleeping_exit()
		STATE.ATTACK:
			check_attack_exit()
		STATE.ALERT:
			check_alert_exit()
		STATE.AVOID_COLLISION:
			check_avoid_collision_exit()

func check_sleeping_exit():
	if is_character_visible():
		current_state = STATE.ATTACK
		attack_state = ATTACK_STATE.START
		waiting = false

func check_attack_exit():
	if not is_character_visible():
		current_state = STATE.ALERT
		on_alert_time = 0.0

func check_alert_exit():
	if is_character_visible():
		current_state = STATE.ATTACK
		attack_state = ATTACK_STATE.START
		waiting = false
	elif on_alert_time > 10.0:
		current_state = STATE.SLEEPING
		#waiting = true
		waiting = false

func check_avoid_collision_exit():
	if avoid_collision_time > 5.0:
		current_state = STATE.SLEEPING
		avoid_collision_time = 0.0

func is_target_inside_rotation_radius() -> bool:
	if target_position.distance_to(%RotRadiusRight.global_position) < 20.0:
		return true
	if target_position.distance_to(%RotRadiusLeft.global_position) < 20.0:
		return true
	return false

func is_stuck(delta:float):
	#Global.log_text += "\nreal_velocity: %.2f" % real_velocity.length()
	#Global.log_text += "\nlast_applied_force: %.2f" % last_applied_force.length()
	#Global.log_text += "\nreal_velocity_integral: %.2f" % last_applied_force.normalized().dot(real_velocity_integral.normalized())
	var is_moving_towards_force:float = last_applied_force.normalized().dot(real_velocity_integral.normalized())
	if (last_applied_force.length() - real_velocity.length()) > last_applied_force.length() * 0.5:
		if is_moving_towards_force < 0.5:
			Global.log_text += "\nStuck Linear"
	# Angular
	# If the angle to target is large
	# but real angular velocity is not
	#Global.log_text += "\nreal_angular_velocity: %.2f" % real_angular_velocity
	#Global.log_text += "\nlast_applied_torque: %.2f" % last_applied_torque
	#Global.log_text += "\nlast_angle_to_target: %.2f" % last_angle_to_target
	#Global.log_text += "\nrotation.y: %.2f" % (last_angle_to_target - rotation.y)
	if abs(last_angle_to_target - rotation.y) > deg_to_rad(40):
		if abs(real_angular_velocity) < 0.1:
			Global.log_text += "\nStuck Angular"
	#current_state = STATE.STUCK

func is_character_visible() -> bool:
	if direct_sight_character():
		return true
	if is_trail_visible():
		return true
	return false

func direct_sight_character() -> bool:
	if Global.character == null:
		return false
	var target := to_local(Global.character.global_position)
	target = target.normalized() * 40
	
	var target_vector := global_position.direction_to(Global.character.global_position) # Direction vector to target
	#var target_vector := to_local(Global.character.global_position).normalized() # Vector to target
	var rotation_vector := Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	#print(rotation_vector, target_vector)
	var dot_product := target_vector.dot(rotation_vector)
	#Global.log_text += "\ndot_product: %f" % dot_product
	#if dot_product < 0.7: return false
	ray_cast_3d.target_position = target
	ray_cast_3d.force_raycast_update()
	if not ray_cast_3d.is_colliding(): return false
	var collider = ray_cast_3d.get_collider()
	#Global.log_text += "\ncollider: %s" % collider.name
	if not collider.name == "character": return false
	var char_pos = Vector3(Global.character.global_position)
	var char_vel := Vector3(Global.character.linear_velocity)
	var predicted_pos: Vector3= char_pos+(char_vel*time_horizon)
	var char_rotation_vector := Vector3.FORWARD.rotated(Vector3.UP, Global.character.rotation.y)
	var dist := global_position.distance_to(Global.character.global_position)
	target_velocity = char_vel
	if dist < 20:
		var dire := Global.tri_to_bi(Global.character.global_position.direction_to(Global.enemy.global_position))
		dire = dire.rotated(Global.character.global_rotation.y)
		var angle := rad_to_deg(Vector2.DOWN.angle_to(dire))
		#Global.log_text += "\nangle: %.2f" % angle
		if abs(angle) > 150:
			# Is in front
			char_rotation_vector = char_rotation_vector.rotated(Vector3.UP, deg_to_rad(180))
		elif abs(angle) < 30:
			# Is behind
			pass
		else:
			if angle < 0:
				char_rotation_vector = char_rotation_vector.rotated(Vector3.UP, deg_to_rad(90))
			else:
				char_rotation_vector = char_rotation_vector.rotated(Vector3.UP, deg_to_rad(-90))
			
			
		target_velocity = char_rotation_vector * 10.0
		target_position = predicted_pos #char_pos
	else:
		target_velocity = char_vel
		target_position = predicted_pos
	#Global.log_text += "\nDirect sight"
	return true

func is_trail_visible() -> bool:
	var trail_position := Vector3.ZERO
	var trail_velocity := Vector3.ZERO
	var id:=0
	for t in Global.character.trail_position:
		id+=1
		var target := to_local(t)
		if target.length() > 20: continue
		ray_cast_3d.target_position = target
		ray_cast_3d.force_raycast_update()
		if ray_cast_3d.is_colliding(): continue
		trail_position = to_global(target)
		break
	if trail_position != Vector3.ZERO:
		target_position = trail_position
		target_velocity = Global.character.trail_velocity[id-1]
		#Global.log_text += "\nTrail"
		return true
	return false

#func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
#	handle_contacts(state)

func _handle_contacts(state: PhysicsDirectBodyState3D):
	if state.get_contact_count() > 0:
		var collision_impulse:float = state.get_contact_impulse(0).length()
		if collision_impulse > 0.5:
			# TODO mode out of this function
			%CollisionAudio.global_position = state.get_contact_collider_position(0)
			var vol := remap(collision_impulse, 0.5, 40, -40, -20)
			vol = clamp(vol, -40, -20)
			#prints(collision_impulse, vol)
			%CollisionAudio.volume_db = vol
			#print(%CollisionAudio.volume_db)
			if not %CollisionAudio.playing:
				%CollisionAudio.play()
		var body = state.get_contact_collider_object(0)
		if body.name == "character":
			Global.character.set_damage()

func _get_sensor_data() -> Dictionary:
	%RayAhead.force_raycast_update()
	%RayBehind.force_raycast_update()
	%RayLeftBack.force_raycast_update()
	%RayLeftFront.force_raycast_update()
	%RayRightBack.force_raycast_update()
	%RayRightFront.force_raycast_update()
	return {
		"ahead": %RayAhead.is_colliding(),
		"behind": %RayBehind.is_colliding(),
		"left_back": %RayLeftBack.is_colliding(),
		"left_front": %RayLeftFront.is_colliding(),
		"right_back": %RayRightBack.is_colliding(),
		"right_front": %RayRightFront.is_colliding(),
	}


func _on_phantom_area_1_body_entered(_body: Node3D) -> void:
	return
	if current_state == STATE.AVOID_COLLISION: return
	about_to_collide = true
	#prints("about_to_collide", body.name, body.get_path())
