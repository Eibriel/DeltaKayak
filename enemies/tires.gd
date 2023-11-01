extends AttackingComponent

var SPEED = 100
var LOOK_PLAYER = false

func _ready():
	POWER = 10
	HEALTH = 15
	XP = 2

	#var anim = $tires001/AnimationPlayer
	#anim.get_animation("TiresIdle").set_loop_mode(Animation.LOOP_LINEAR)
	#anim.play("TiresIdle")

	$tires001.rotate_x(randf())
	$tires001.rotate_y(randf())
	$tires001.rotate_z(randf())
