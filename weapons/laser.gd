extends Weapon

func _ready():
	DAMAGE = 2
	DISTANCE = 2*2 # Squared distance
	COOLDOWN = 0.5
	MODE = Weapon.MODES.ORBITING
