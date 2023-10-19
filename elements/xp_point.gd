extends Node3D

var claimed := false

var SPEED = 5.0
var DISTANCE_B = 1*1*1

func _ready():
	var tween = create_tween()
	tween.tween_property(self, "position:y", 0.2, 1)
	$GPUParticles3D.set_emitting(true)

func _physics_process(delta):
	# Todo remove from _process
	$Hitbox.scale = Vector3.ONE * (Global.player_modifiers.magnet * 0.01)
	if claimed:
		move_to_player(delta)

func move_to_player(delta:float):
	var target_position = Global.player.global_position + Vector3(0, 1, 0)
	var player_direction = target_position - global_position
	position += player_direction.normalized()*delta*SPEED
	
	var distance = global_position.distance_squared_to(target_position)
	if distance < DISTANCE_B:
		queue_free()
	SPEED += delta

func claim():
	if claimed: return
	claimed = true
	var modified_xp = Global.ITEMS.XP * (Global.player_modifiers.growth * 0.01)
	Global.claim_item(modified_xp, 1)
