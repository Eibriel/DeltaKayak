extends AttackingComponent

var COOLDOWN = 0.5

func _ready():
	POWER = 10.0
	DIE_ON_ATTACK = true

	scale = Vector3.ONE * (Global.player_modifiers.area * 0.01)
