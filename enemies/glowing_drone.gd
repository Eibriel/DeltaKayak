extends AttackingComponent

var SPEED = 140
var LOOK_PLAYER = true

func _ready():
	POWER = 10
	HEALTH = 50
	XP = 30

	#$tires001/AnimationPlayer.play("TankIdle")
	$FollowPlayerComponent.LOOK_PLAYER = true
