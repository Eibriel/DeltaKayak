extends AttackingComponent

var SPEED = 300
var LOOK_PLAYER = true
var DAMAGE = 1

func _ready():
	POWER = 5
	HEALTH = 4

	#$tires001/AnimationPlayer.play("TankIdle")
	$FollowPlayerComponent.LOOK_PLAYER = true
