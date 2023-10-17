extends AttackingComponent

@onready var hitbox = $Hitbox

var DAMAGE = 10
var COOLDOWN = 0.5

func _ready():
	reposition()
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_loops()
	tween.tween_callback(reposition)
	tween.tween_property(hitbox, "position:y", -1, 0.2)
	tween.tween_property(hitbox, "position:y", 0, 0.5)
	tween.tween_property(hitbox, "position:y", -20, 1)
	tween.tween_interval(3)

func reposition():
	hitbox.global_position.x = Global.player.global_position.x + randf_range(-50, 50)
	hitbox.global_position.y = 50
	hitbox.global_position.z = Global.player.global_position.z + randf_range(-50, 50)
