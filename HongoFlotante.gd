extends RigidBody3D

var float_force := 100.0
var water_drag := 0.05
var water_angular_drag := 0.05

@onready var gravity :float = ProjectSettings.get_setting("physics/3d/default_gravity")

const water_height := 1.0
var submerged := false

func _process(delta: float) -> void:
	if position.y < -3:
		queue_free()

func _physics_process(_delta):
	submerged = false
	var depth = water_height - global_position.y
	if depth > 0:
		submerged = true
		apply_central_force(Vector3.UP * gravity * depth)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if submerged:
		state.linear_velocity *= 1 - water_drag
		state.angular_velocity *= 1 - water_angular_drag


func _on_body_entered(body: Node) -> void:
	var audios:AudioStreamPlayer3D = $AudioStreamPlayer3D as AudioStreamPlayer3D
	if not audios.playing:
		audios.play()
