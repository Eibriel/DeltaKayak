extends AttackingComponent

var SPEED = 140
var LOOK_PLAYER = true

func _ready():
	POWER = 5
	HEALTH = 5

	#$tires001/AnimationPlayer.play("TankIdle")
	$FollowPlayerComponent.LOOK_PLAYER = true
