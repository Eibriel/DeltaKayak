extends Boat3D

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var ray_cast_3d: RayCast3D = $RayCast3D

var current_state := STATE.SLEEPING

enum STATE {
	SLEEPING,
	ALERT,
	ATTACK,
	SEARCHING_FOOD,
	EATING
}

#func _ready():
#	set_physics_process(false)
#	call_deferred('setup')

#func setup():
#	await get_tree().physics_frame
#	set_physics_process(true)

func _process(delta: float) -> void:
	Global.log_text += "\nState: %s" % STATE.find_key(current_state)

func _get_target(delta: float) -> void:
	change_state()
	
	if current_state == STATE.ATTACK:
		nav.target_position = Global.character.global_position
	
	var direction := Vector3.ZERO
	direction = nav.get_next_path_position() - global_position
	direction = direction.normalized()

func change_state():
	match current_state:
		STATE.SLEEPING:
			check_sleeping_exit()
		STATE.ATTACK:
			check_attack_exit()

func check_sleeping_exit():
	#if Global.character.global_position.distance_to(global_position) < 10:
	if is_character_visible():
		current_state = STATE.ATTACK

func check_attack_exit():
	#if Global.character.global_position.distance_to(global_position) < 10:
	if not is_character_visible():
		current_state = STATE.SLEEPING

func is_character_visible() -> bool:
	var target := to_local(Global.character.global_position)
	target = target.normalized() * 20
	ray_cast_3d.target_position = target
	ray_cast_3d.force_raycast_update()
	if not ray_cast_3d.is_colliding(): return false
	var collider = ray_cast_3d.get_collider()
	if not collider.name == "character": return false
	return true
