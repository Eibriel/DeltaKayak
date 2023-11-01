extends AttackingComponent

var COOLDOWN = 0.5

func _ready():
	POWER = 10

func _process(delta):
	# Move outside process
	scale = Vector3.ONE * (Global.player_modifiers.area * 0.01)
