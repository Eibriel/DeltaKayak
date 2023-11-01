extends AttackingComponent

var SPEED = 80
var LOOK_PLAYER = false
#var DAMAGE = 1

func _ready():
	POWER = 10
	HEALTH = 500
	XP = 3

	#$surface_bubbles/AnimationPlayer.get_animation("SurfaceBubbles").set_loop_mode(Animation.LOOP_LINEAR)
	#$surface_bubbles/AnimationPlayer.play("SurfaceBubbles")
