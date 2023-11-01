extends AttackingComponent

const INITIAL_POWER = 10.0

func _ready():
	POWER = INITIAL_POWER
	$Hitbox/snowplow2.hide()
	$Hitbox/CollisionShape3D2.disabled = true

func _process(delta):
	# Todo remove from _process
	var level: int = Global.powerups.snowplow.current_level
	if level > 1:
		POWER = INITIAL_POWER + 5.0
	if level > 2:
		$Hitbox/snowplow2.show()
		$Hitbox/CollisionShape3D2.disabled = false
	scale = Vector3.ONE * (Global.player_modifiers.area * 0.01)
