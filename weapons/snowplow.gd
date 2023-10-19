extends AttackingComponent

var DAMAGE = 2
var COOLDOWN = 0.5

func _ready():
	pass

func _process(delta):
	# Todo remove from _process
	scale = Vector3.ONE * (Global.player_modifiers.area * 0.01)
	#COOLDOWN = 0.5 * (Global.player_modifiers.cooldown * 0.01)
