extends RigidBody3D

@export var player: Node3D
@export var hearing_fallof: Curve
@export var hearing_distance: float

var alert_level := 0.0
var target_position := Vector3()

func _ready():
	player.connect("make_noise", _on_player_make_noise)
	target_position = global_position

func _physics_process(delta):
	alert_level -= delta
	if alert_level < 0:
		alert_level = 0.0
	if alert_level > 0.5:
		target_position = player.global_position+Vector3(0, 3, 0)
	
	var player_direction = target_position - global_position
	#apply_central_force(player_direction.normalized()*delta*100)
	apply_central_impulse(player_direction.normalized()*0.05)

func increase_alert(amount: float):
	alert_level += amount
	#print(alert_level)

func _on_player_make_noise(intensity: float):
	var distance = position.distance_to(player.position)
	var fallof_distance: float
	if hearing_distance == 0.0:
		fallof_distance = 1.0
	else:
		fallof_distance = distance / hearing_distance
	var fallof = hearing_fallof.sample(fallof_distance)
	increase_alert(intensity * fallof)
