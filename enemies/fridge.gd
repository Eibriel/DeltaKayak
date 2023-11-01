extends AttackingComponent

var SPEED = 100
var LOOK_PLAYER = false
#var DAMAGE = 1

func _ready():
	POWER = 10
	HEALTH = 150
	XP = 2.5

	#$surface_bubbles/AnimationPlayer.get_animation("SurfaceBubbles").set_loop_mode(Animation.LOOP_LINEAR)
	#$surface_bubbles/AnimationPlayer.play("SurfaceBubbles")
