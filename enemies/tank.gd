extends AttackingComponent

var SPEED = 100
var LOOK_PLAYER = false
#var DAMAGE = 1

func _ready():
	POWER = 10
	HEALTH = 10

	$tank/AnimationPlayer.get_animation("TankIdle").set_loop_mode(Animation.LOOP_LINEAR)
	$tank/AnimationPlayer.play("TankIdle")
