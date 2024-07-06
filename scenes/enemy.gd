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

var forward_force := 0.0
#var attack_position:Vector3

enum STATE {
	SLEEPING,
	ALERT,
	ATTACK,
	SEARCHING_FOOD,
	EATING
}

enum ATTACK_STATE {
	START,
	INTIMIDATE,
	CHARGE
}

func _process(_delta: float) -> void:
	Global.log_text += "\nState: %s" % STATE.find_key(current_state)
	Global.log_text += "\nAttack: %s" % ATTACK_STATE.find_key(attack_state)
	#%AttackPositionindicator.global_position = attack_position
	handle_sounds()

func handle_sounds():
	var new_forward_force = lerpf(forward_force, -last_applied_force.rotated(Vector3.UP, -rotation.y).z, 0.1)
	if new_forward_force > 0.0 and forward_force < 0.0:
		print("Shift forward")
		%ShiftAudio.play()
	elif new_forward_force < 0.0 and forward_force > 0.0:
		print("Shift backward")
		%ShiftAudio.play()
	forward_force = new_forward_force
	#print(forward_force)
	var pitch := remap(abs(forward_force), 0, 15, 0.2, 1.0)
	Global.log_text += "\nforward_force: %f" % forward_force
	%MotorAudio.pitch_scale = pitch
	var volume := remap(abs(forward_force), 0, 15, -20.0, 0.0)
	%MotorAudio.volume_db = volume
	
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
		prints(n, vol)
		%EngineAudio.stream["stream_%s/volume" % n] = vol
	

func _get_target(delta: float) -> void:
	change_state()
	
	if current_state == STATE.ATTACK:
		%AttackIndicator.visible = true
		%SpotLight3D.visible = true
		change_attack_state()
		is_trail_visible() # TODO line may not be needed
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
		%SpotLight3D.visible = false
		nav.target_position = home_position
		if nav.is_target_reachable():
			target_position = nav.get_next_path_position()
		boat_speed = 0.2
		if global_position.distance_to(home_position) > 2.0:
			waiting = false
		else:
			waiting = true
	
	path_blocked_time -= delta
	if path_blocked_time < 0:
		path_blocked_time = 0.0
	if path_blocked_time > 0.0:
		boat_speed *= -1
	%RayAhead.force_raycast_update()
	if %RayAhead.is_colliding():
		path_blocked_time = 5
		#print("path_blocked")

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
	match current_state:
		STATE.SLEEPING:
			check_sleeping_exit()
		STATE.ATTACK:
			check_attack_exit()
		STATE.ALERT:
			check_alert_exit()

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
	target = target.normalized() * 20
	
	var target_vector := global_position.direction_to(Global.character.global_position) # Direction vector to target
	#var target_vector := to_local(Global.character.global_position).normalized() # Vector to target
	var rotation_vector := Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	#print(rotation_vector, target_vector)
	var dot_product := target_vector.dot(rotation_vector)
	#Global.log_text += "\ndot_product: %f" % dot_product
	if dot_product < 0.7: return false
	ray_cast_3d.target_position = target
	ray_cast_3d.force_raycast_update()
	if not ray_cast_3d.is_colliding(): return false
	var collider = ray_cast_3d.get_collider()
	Global.log_text += "\ncollider: %s" % collider.name
	if not collider.name == "character": return false
	target_position = Vector3(Global.character.global_position)
	target_velocity = Vector3(Global.character.linear_velocity)
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
		return true
	return false

#func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
#	handle_contacts(state)

func _handle_contacts(state: PhysicsDirectBodyState3D):
	if state.get_contact_count() > 0:
		var collision_impulse:float = state.get_contact_impulse(0).length()
		if collision_impulse > 0.5:
			%CollisionAudio.global_position = state.get_contact_collider_position(0)
			%CollisionAudio.volume_db = ((collision_impulse-15) * 15) - 15
			if not %CollisionAudio.playing:
				%CollisionAudio.play()
		var body = state.get_contact_collider_object(0)
		if body.name == "character":
			Global.character.set_damage()
