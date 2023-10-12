extends Weapon

func _ready():
	PROJECTILE = preload("res://weapons/fireball_projectile.tscn")
	DAMAGE = 2
	DISTANCE = 3*3 # Squared distance
	COOLDOWN = 0.5
	MODE = Weapon.MODES.PROJECTILE
	projectiles_node = $projectiles
