extends Node3D
class_name Enemy

var target_position := Vector3()

# Set this parameters on the Enemy!
var DAMAGE: int = 2
var DISTANCE: float = 3*3*3 # Squared distance
var HEALTH: int = 5
var SPEED := 0.5

var current_healt: int = HEALTH
var alive:bool = true

var on_attack_cooldown:bool = false

func _ready():
	target_position = global_position

func _physics_process(delta):
	if not alive: return
	if on_attack_cooldown: return
	
	target_position = Global.player.global_position + Vector3(0, 1, 0)
	var player_direction = target_position - global_position
	position += player_direction.normalized()*delta*SPEED
	
	var distance = global_position.distance_squared_to(target_position)
	if distance < DISTANCE:
		on_attack_cooldown = true
		Global.player.add_damage(DAMAGE)
		damage_push(player_direction)
	
	var target_rotation = Vector3(
		target_position.x,
		global_position.y,
		target_position.z
	)
	look_at(target_rotation)


func damage_push(player_direction: Vector3):
	var new_position = position - player_direction.normalized() * 2.0
	var tween = create_tween()
	tween.tween_property(self, "position", new_position, 0.1)
	tween.tween_callback(func (): on_attack_cooldown = false)


func add_damage(value:int):
	current_healt -= value
	if current_healt < 0:
		#print("DEAD")
		alive = false
		visible = false
		Global.drop_item(Global.ITEMS.XP, 1, global_position)
	target_position = Global.player.global_position + Vector3(0, 1, 0)
	var player_direction = target_position - global_position
	damage_push(player_direction)
