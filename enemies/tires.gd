extends AttackingComponent

var SPEED = 140
var LOOK_PLAYER = false
	
func _ready():
	POWER = 5
	HEALTH = 1

	#var anim = $tires001/AnimationPlayer
	#anim.get_animation("TiresIdle").set_loop_mode(Animation.LOOP_LINEAR)
	#anim.play("TiresIdle")

	$tires001.rotate_x(randf())
	$tires001.rotate_y(randf())
	$tires001.rotate_z(randf())
