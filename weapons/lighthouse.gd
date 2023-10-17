extends AttackingComponent

@onready var hitbox = $Hitbox

var DAMAGE = 1
var COOLDOWN = 0.5

func _ready():

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(hitbox, "scale", Vector3(1, 1, 1), 0.01)
	tween.tween_property(hitbox, "rotation:y", PI, 0.01)
	tween.tween_property(hitbox, "rotation:y", -PI, 1)
	# Hitbox scaled to 0 generates errors
	tween.tween_property(hitbox, "scale", Vector3(0.01, 0.01, 0.01), 0.01)
	tween.tween_interval(3)
