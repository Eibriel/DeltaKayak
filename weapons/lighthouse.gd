extends AttackingComponent

@onready var hitbox = $Hitbox

var DAMAGE = 1
var COOLDOWN = 0.5

func _ready():
	rebuild_tween()

func rebuild_tween():
	var tween = create_tween()
	#tween.set_loops()
	tween.tween_property(hitbox, "scale", Vector3.ONE * (Global.player_modifiers.area * 0.01), 0.01)
	tween.tween_property(hitbox, "rotation:y", PI, 0.01)
	var modified_time: float = 1.0 * (100.0 / Global.player_modifiers.speed)
	tween.tween_property(hitbox, "rotation:y", -PI, modified_time)
	# Hitbox scaled to 0 generates errors
	tween.tween_property(hitbox, "scale", Vector3(0.01, 0.01, 0.01), 0.01)
	tween.tween_interval(3)
	tween.tween_callback(rebuild_tween)
