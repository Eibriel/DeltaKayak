extends AttackingComponent

@onready var hitbox = $Hitbox

var COOLDOWN = 3.0

func _ready():
	POWER = 10
	reposition()
	rebuild_tween()

func rebuild_tween():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CIRC)
	#tween.set_loops()
	tween.tween_callback(reposition)
	var modified_time: float = 0.2 * (Global.player_modifiers.speed * 0.01)
	tween.tween_property(hitbox, "position:y", -1, modified_time)
	tween.tween_callback(func():
		$Hitbox/GPUParticles3D.emitting = true
		$AudioStreamPlayer3D.play()
		)
	tween.tween_property(hitbox, "position:y", 0, 0.5)
	tween.tween_property(hitbox, "position:y", -60, 3)
	tween.set_parallel()
	tween.tween_property(hitbox, "scale", Vector3(0.01, 0.01, 0.01), 3)
	tween.set_parallel(false)
	var modified_cooldown = COOLDOWN * (Global.player_modifiers.cooldown * 0.01)
	tween.tween_interval(modified_cooldown)
	tween.tween_callback(rebuild_tween)

func reposition():
	hitbox.scale = Vector3.ONE * (Global.player_modifiers.area * 0.01)
	hitbox.global_position.x = Global.player.global_position.x + randf_range(-50, 50)
	hitbox.global_position.y = 50
	hitbox.global_position.z = Global.player.global_position.z + randf_range(-50, 50)
