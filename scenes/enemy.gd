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
@onready var enemy_camera: Camera3D = %EnemyCamera

#@onready var ray_cast_3d: RayCast3D = $RayCast3D

var current_state := STATE.SEARCHING
var attack_state := ATTACK_STATE.START

var previous_room: String
var previous_enemy_point: int

var following_trail_time := 0.0
var on_sleeping_time := 0.0
var on_alert_time := 0.0
var on_ambush_time := 0.0
var attack_start_time := 0.0
var attack_charge_time := 0.0
var attack_intimidate_time := 0.0
var path_blocked_time := 0.0
var avoid_collision_time := 0.0
var is_moving_time := 0.0
var delay_next_state_change := 0.0

var is_character_visible:=false
var is_trail_visible:=false
var clear_path_to_character:=false

var force_new_enemy_point:=false

var buoyancy_time:=0.0
var buoyancy_instability:=1.0

var forward_force := 0.0
#var attack_position:Vector3

enum STATE {
	SLEEPING,
	ALERT,
	ATTACK,
	SEARCHING_FOOD,
	EATING,
	STUCK,
	AVOID_COLLISION,
	GO_HOME,
	AMBUSH,
	FACE_POINT,
	SEARCHING
}

enum ATTACK_STATE {
	START,
	INTIMIDATE,
	CHARGE,
	FOLLOW_TRAIL
}

func _ready() -> void:
	set_physics_process(false)
	#call_deferred("setup_physics")
	NavigationServer3D.connect("map_changed", _on_map_changed)
	super._ready()

func _on_map_changed(map: RID):
	#prints("MAP:", map)
	setup_physics()

func setup_physics():
	set_physics_process(true)

func _process(delta: float) -> void:
	Global.log_text += "\nState: %s" % STATE.find_key(current_state)
	Global.log_text += "\nAttack: %s" % ATTACK_STATE.find_key(attack_state)
	Global.log_text += "\nforce_limit_mult: %s" % force_limit_mult
	%AttackPositionindicator.global_position = target_position
	#is_stuck(delta)
	inside_turn_radius = is_target_inside_rotation_radius()
	handle_sounds()
	handle_music()
	handle_buoyancy(delta)
	handle_is_moving(delta)
	
	%PhantomArea1.position = global_position - (real_velocity * 1)
	%PhantomArea1.rotation.y = rotation.y
	
	buoyancy_instability += abs(torque) * 0.001 * delta
	#Global.log_text += "\nbuoyancy_instability: %f" % buoyancy_instability
	
var is_moving_array: Array[Vector3] = []
var is_moving := true
func handle_is_moving(delta:float):
	is_moving_time += delta
	if is_moving_time < 0.1: return
	is_moving_time = 0.0
	is_moving_array.append(global_position)
	is_moving = true
	if is_moving_array.size() > 30:
		var old_position:Vector3 = is_moving_array.pop_front()
		var moving_distance:float = old_position.distance_to(global_position)
		if moving_distance < 1.5:
			is_moving = false
	# NOTE Hack to prevent enemy getting stuck
	if is_moving:
		torque_multiplier = 1.0
	else:
		torque_multiplier = 5.0

func reset_is_moving():
	is_moving_array.resize(0)

func handle_buoyancy(delta:float):
	buoyancy_time += delta
	if buoyancy_time > PI*2:
		buoyancy_time = 0.0
	buoyancy_instability -= delta
	buoyancy_instability = clamp(buoyancy_instability, 1.0, 5.0)
	var rotation_amount = sin(buoyancy_time)
	%EnemyVisual.rotation.z = deg_to_rad(5*buoyancy_instability) * rotation_amount


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
	delay_next_state_change -= delta
	delay_next_state_change = max(delay_next_state_change, 0)
	if delay_next_state_change <= 0:
		change_state()
	check_character_visible(delta)
	direct_target = false
	if current_state == STATE.ATTACK:
		direct_target = true
		%AttackIndicator.visible = true
		#%SpotLightEnemy.visible = true
		%OmniLightEnemy.visible = true
		if delay_next_state_change <= 0:
			change_attack_state()
		#is_trail_visible() # TODO line may not be needed
		#target_position = attack_position
		
		#boat_speed = 0.5
		if attack_state == ATTACK_STATE.START:
			attack_start_time += delta
			target_velocity = direct_target_velocity
			target_position = direct_target_position
			force_limit_mult = 1.2
		elif attack_state == ATTACK_STATE.CHARGE:
			attack_charge_time += delta
			target_velocity = direct_target_velocity
			target_position = direct_target_position
			force_limit_mult = 1.0
			#if global_position.distance_to(Global.character.global_position) > 4.0:
			#	waiting = false
			#else:
			#	waiting = true
		elif attack_state == ATTACK_STATE.FOLLOW_TRAIL:
			following_trail_time += delta
			target_position = trail_target_position
			target_velocity = trail_target_velocity
			force_limit_mult = 1.3
		elif attack_state == ATTACK_STATE.INTIMIDATE:
			attack_intimidate_time += delta
			target_velocity = direct_target_velocity
			target_position = direct_target_position
			force_limit_mult = 0.2
		%SpotBaseEnemy.look_at(target_position)
	elif current_state == STATE.ALERT:
		on_alert_time += delta
		force_limit_mult = 1.4
	elif current_state == STATE.AMBUSH:
		on_ambush_time += delta
		force_limit_mult = 1.1
		#target_position = Global.character.estimated_target
		nav.target_position = Global.character.estimated_target
		#if nav.is_target_reachable():
			#print("Reachable")
		target_position = nav.get_next_path_position()
		%SpotBaseEnemy.look_at(nav.target_position)
	elif current_state == STATE.SEARCHING:
		force_limit_mult = 1.8
		var current_room: Room
		if Global.main_scene.in_room.size() > 0:
			current_room = Global.main_scene.in_room[0]
		if current_room:
			if current_room.room_id != previous_room or force_new_enemy_point:
				force_new_enemy_point = false
				previous_room = current_room.room_id
				if force_new_enemy_point and current_room.enemy_points.size() > 1:
					if previous_enemy_point == 0:
						previous_enemy_point = 1
					else:
						previous_enemy_point = 0
				else:
					previous_enemy_point = randi_range(0, current_room.enemy_points.size()-1)
			# BUG Out of bounds get index '-1' on base Array[Vector3]
			if global_position.distance_to(current_room.enemy_points[previous_enemy_point]) < 4.0:
				previous_enemy_point = randi_range(0, current_room.enemy_points.size()-1)
			#nav.target_position = current_room.to_global(current_room.enemy_points[0])
			nav.target_position = current_room.enemy_points[previous_enemy_point]
			#print(nav.target_position)
			target_position = nav.get_next_path_position()
			if nav.get_current_navigation_path().size() > 2:
				target_velocity =nav.get_current_navigation_path()[2] - nav.get_current_navigation_path()[1]
				var nav_dist := nav.get_current_navigation_path()[2].distance_to(nav.get_current_navigation_path()[1])
				target_velocity = target_velocity.normalized() * nav_dist * -2.0
			else:
				target_velocity = Vector3.ZERO
			#position.y = target_position.y
			if not is_zero_approx(target_position.y):
				var teleportation := false
				var teleport_position: Vector3
				var teleport_facing:Vector3
				for path_point in nav.get_current_navigation_path():
					if not teleportation and not is_zero_approx(path_point.y):
						teleportation = true
						prints("Teleportation!", path_point)
					elif teleportation and is_zero_approx(path_point.y) and not teleport_position:
						prints("Teleport to", path_point)
						teleport_position = path_point
					elif teleportation and teleport_position:
						prints("Teleport facing", path_point)
						teleport_facing = path_point
						break
				if teleportation and teleport_position:
					global_position.x = teleport_position.x
					global_position.z = teleport_position.z
					if teleport_facing:
						# TODO fix rotation
						rotation.y = deg_to_rad(180) + Global.tri_to_bi(teleport_position).angle_to_point(Global.tri_to_bi(teleport_facing))
			%SpotBaseEnemy.look_at(target_position)
	elif current_state == STATE.SLEEPING or current_state == STATE.GO_HOME:
		force_limit_mult = 0.8
		if current_state == STATE.SLEEPING:
			on_sleeping_time += delta
		%AttackIndicator.visible = false
		#%SpotLightEnemy.visible = false
		%OmniLightEnemy.visible = false
		nav.target_position = home_position
		#NavigationServer3D.map_get_iteration_id()
		if nav.is_target_reachable():
			target_position = nav.get_next_path_position()
		#target_position = global_position
		#boat_speed = 0.2
		if global_position.distance_to(home_position) > 4.0:
			waiting = false
		else:
			waiting = true
	elif current_state == STATE.AVOID_COLLISION:
		force_limit_mult = 0.5
		if avoid_collision_time == 0:
			#var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
			var prev_target_position = target_position
			target_position = global_position + (real_velocity * 50)
			#target_velocity = real_velocity * 5
			target_velocity = target_position.direction_to(prev_target_position) * 5
			#prints(target_position, target_velocity)
		avoid_collision_time += delta
	
	
	#%EnemyNavigationVelocityIndicator.global_position = target_position + target_velocity
	
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
		ATTACK_STATE.FOLLOW_TRAIL:
			check_attack_follow_trail_exit()

func set_attack_state(_attack_state:ATTACK_STATE):
	attack_state = _attack_state
	reset_is_moving()
	match attack_state:
		ATTACK_STATE.START:
			attack_start_time = 0.0
		ATTACK_STATE.FOLLOW_TRAIL:
			following_trail_time = 0.0
		ATTACK_STATE.INTIMIDATE:
			attack_intimidate_time = 0.0
		ATTACK_STATE.CHARGE:
			attack_charge_time = 0.0

func check_attack_start_exit():
	if attack_start_time > 1.0:
		if randf() > 0.5:
			set_attack_state(ATTACK_STATE.CHARGE)
		else:
			set_attack_state(ATTACK_STATE.INTIMIDATE)

func check_attack_intimidate_exit():
	if attack_intimidate_time > 4.0:
		set_attack_state(ATTACK_STATE.CHARGE)

func check_attack_charge_exit():
	if not is_character_visible and is_trail_visible:
		set_attack_state(ATTACK_STATE.FOLLOW_TRAIL)
	if attack_charge_time > 10.0:
		set_attack_state(ATTACK_STATE.INTIMIDATE)
	if not is_moving:
		set_attack_state(ATTACK_STATE.FOLLOW_TRAIL)

func check_attack_follow_trail_exit():
	if is_character_visible:
		set_attack_state(ATTACK_STATE.CHARGE)

func change_state():
	if current_state != STATE.AVOID_COLLISION and about_to_collide:
		#prints(real_velocity.length())
		if real_velocity.length() > 5:
			about_to_collide = false
			set_state(STATE.AVOID_COLLISION)
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
		STATE.GO_HOME:
			check_go_home_exit()
		STATE.AMBUSH:
			check_ambush_exit()
		STATE.SEARCHING:
			check_searching_exit()

func set_state(state_to_set:STATE):
	prints("Set", STATE.find_key(state_to_set))
	current_state = state_to_set
	reset_is_moving()
	match state_to_set:
		STATE.ATTACK:
			attack_state = ATTACK_STATE.START
			waiting = false
			play_howl()
		STATE.ALERT:
			on_alert_time = 0.0
		STATE.SLEEPING:
			on_sleeping_time = 0.0
			waiting = false
		STATE.AVOID_COLLISION:
			avoid_collision_time = 0.0
		STATE.AMBUSH:
			waiting = false
			on_ambush_time = 0.0
		STATE.SEARCHING:
			waiting = false

func check_sleeping_exit():
	if is_character_visible:
		#set_state(STATE.ATTACK)
		set_state(STATE.AMBUSH)

func check_attack_exit():
	if following_trail_time > 60.0:
		set_state(STATE.ALERT)
	if not is_character_visible:
		set_state(STATE.ALERT)
	if not is_moving:
		delay_next_state_change = 60.0
		set_state(STATE.SEARCHING)

func check_alert_exit():
	if is_character_visible:
		set_state(STATE.ATTACK)
	elif on_alert_time > 30.0:
		set_state(STATE.SEARCHING)
	elif following_trail_time > 60.0:
		set_state(STATE.SEARCHING)
	if not is_moving:
		delay_next_state_change = 60.0
		set_state(STATE.SEARCHING)

func check_avoid_collision_exit():
	if avoid_collision_time > 5.0:
		set_state(STATE.SLEEPING)

func check_go_home_exit():
	# NOTE can only exit manually
	pass

func check_ambush_exit():
	if global_position.distance_to(Global.character.estimated_target) < 4.0 or on_ambush_time > 180:
		if is_character_visible:
			set_state(STATE.ATTACK)
		else:
			set_state(STATE.SLEEPING)

func check_searching_exit():
	if is_character_visible:
		set_state(STATE.ATTACK)
	if not is_moving:
		force_new_enemy_point = true
		reset_is_moving()
	#	delay_next_state_change = 20.0
	#	set_state(STATE.SLEEPING)

func is_target_inside_rotation_radius() -> bool:
	if target_position.distance_to(%RotRadiusRight.global_position) < 20.0:
		return true
	if target_position.distance_to(%RotRadiusLeft.global_position) < 20.0:
		return true
	return false

var linear_stuck_time := 0.0
func is_stuck(delta:float):
	linear_stuck_time -= delta * 0.5
	linear_stuck_time = max(linear_stuck_time, 0.0)
	#Global.log_text += "\nlinear_stuck_time: %.2f" % linear_stuck_time
	#Global.log_text += "\nreal_velocity: %.2f" % real_velocity.length()
	#Global.log_text += "\nlast_applied_force: %.2f" % last_applied_force.length()
	#Global.log_text += "\nreal_velocity_integral: %.2f" % last_applied_force.normalized().dot(real_velocity_integral.normalized())
	var is_moving_towards_force:float = last_applied_force.normalized().dot(real_velocity_integral.normalized())
	if (last_applied_force.length() - real_velocity.length()) > last_applied_force.length() * 0.5:
		if is_moving_towards_force < 0.5:
			#Global.log_text += "\nStuck Linear"
			pass
	# Angular
	# If the angle to target is large
	# but real angular velocity is not
	#Global.log_text += "\nreal_angular_velocity: %.2f" % real_angular_velocity
	#Global.log_text += "\nlast_applied_torque: %.2f" % last_applied_torque
	#Global.log_text += "\nlast_angle_to_target: %.2f" % last_angle_to_target
	#Global.log_text += "\nrotation.y: %.2f" % (last_angle_to_target - rotation.y)
	if abs(last_angle_to_target - rotation.y) > deg_to_rad(40):
		if abs(real_angular_velocity) < 0.1:
			#Global.log_text += "\nStuck Angular"
			linear_stuck_time += delta
	#current_state = STATE.STUCK

func check_character_visible(delta: float) -> void:
	is_character_visible = false
	is_trail_visible = false
	if direct_sight_character():
		is_character_visible = true
	if direct_sight_trail():
		is_trail_visible = true

var direct_target_velocity:Vector3
var direct_target_position:Vector3
func direct_sight_character() -> bool:
	if Global.character == null:
		return false
	var target := to_local(Global.character.global_position)
	target = target.normalized() * 20
	
	if false:
		var target_vector := global_position.direction_to(Global.character.global_position) # Direction vector to target
		#var target_vector := to_local(Global.character.global_position).normalized() # Vector to target
		var rotation_vector := Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
		#print(rotation_vector, target_vector)
		var dot_product := target_vector.dot(rotation_vector)
		#Global.log_text += "\ndot_product: %f" % dot_product
		#if dot_product < 0.7: return false
		%EnemyEyeRayCast.target_position = target
	%EnemyEyeRayCast.look_at(Global.character.global_position)
	%EnemyEyeRayCast.force_raycast_update()
	if not %EnemyEyeRayCast.is_colliding(): return false
	var collider = %EnemyEyeRayCast.get_collider()
	#Global.log_text += "\ncollider: %s" % collider.name
	if not collider.name == "character": return false
	
	%EnemyReachRayCast.look_at(Global.character.global_position)
	%EnemyReachRayCast.force_raycast_update()
	clear_path_to_character = false
	if %EnemyReachRayCast.is_colliding():
		if collider.name == "character":
			clear_path_to_character = true
	
	var char_pos = Vector3(Global.character.global_position)
	var char_vel := Vector3(Global.character.linear_velocity)
	var predicted_pos: Vector3= char_pos+(char_vel*time_horizon)
	var char_rotation_vector := Vector3.FORWARD.rotated(Vector3.UP, Global.character.rotation.y)
	var dist := global_position.distance_to(Global.character.global_position)
	direct_target_velocity = char_vel
	if dist < 10:
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
			
			
		direct_target_velocity = char_rotation_vector * 10.0
		direct_target_position = predicted_pos #char_pos
	else:
		direct_target_velocity = char_vel
		direct_target_position = predicted_pos
	#Global.log_text += "\nDirect sight"
	return true

var trail_target_position:Vector3
var trail_target_velocity:Vector3
func direct_sight_trail() -> bool:
	var trail_position := Vector3.ZERO
	var trail_velocity := Vector3.ZERO
	var id:=0
	for t in Global.character.trail_position:
		id+=1
		var target := to_local(t)
		if target.length() > 20: continue
		#%EnemyReachRayCast.target_position = target
		%EnemyReachRayCast.look_at(t)
		%EnemyReachRayCast.force_raycast_update()
		if %EnemyReachRayCast.is_colliding(): continue
		trail_position = to_global(target)
		break
	if trail_position != Vector3.ZERO:
		trail_target_position = trail_position
		trail_target_velocity = Global.character.trail_velocity[id-1]
		#Global.log_text += "\nTrail"
		return true
	return false

#func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
#	handle_contacts(state)

func play_howl():
	if %Vocalizations.playing: return
	const vocalization_sounds = [
		preload("res://sounds/enemy/howl_01.mp3"),
		preload("res://sounds/enemy/howl_02.mp3"),
		preload("res://sounds/enemy/howl_03.mp3"),
		preload("res://sounds/enemy/howl_05.mp3"),
	]
	%Vocalizations.stream = vocalization_sounds.pick_random()
	%Vocalizations.play()


func _handle_contacts(state: PhysicsDirectBodyState3D):
	if state.get_contact_count() > 0:
		var body = state.get_contact_collider_object(0)
		var collision_impulse:float = state.get_contact_impulse(0).length()
		if collision_impulse > 0.5:
			# TODO mode out of this function
			%CollisionAudio.global_position = state.get_contact_collider_position(0)
			var vol := remap(collision_impulse, 0.5, 40, -20, -10)
			vol = clamp(vol, -20, -10)
			#prints(collision_impulse, vol)
			%CollisionAudio.volume_db = vol
			#print(%CollisionAudio.volume_db)
			if not %CollisionAudio.playing:
				%CollisionAudio.play()
				buoyancy_instability += 1
		if body.name == "character":
			Global.character.set_damage()

func _on_phantom_area_1_body_entered(_body: Node3D) -> void:
	return
	if current_state == STATE.AVOID_COLLISION: return
	about_to_collide = true
	#prints("about_to_collide", body.name, body.get_path())
