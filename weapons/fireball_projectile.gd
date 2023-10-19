extends AttackingComponent

var DAMAGE = 2
var COOLDOWN = 0.5

func _ready():
	DIE_ON_ATTACK = true

	scale = Vector3.ONE * (Global.player_modifiers.area * 0.01)
