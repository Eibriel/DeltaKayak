extends Node3D

var PROJECTILE = preload("res://weapons/fireball_projectile.tscn")
var DAMAGE = 2
var DISTANCE = 3*3 # Squared distance
var COOLDOWN = 0.5
var MODE = ProjectileDispenserComponent.MODES.PROJECTILE
var projectiles_node

func _ready():
	projectiles_node = $projectiles
