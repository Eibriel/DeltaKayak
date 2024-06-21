extends Node3D

signal change_state

@export var state := false
@onready var lever: RigidBody3D = $RigidBody3D

func _ready() -> void:
	set_state(state)

func _process(_delta: float) -> void:
	var new_state := get_state()
	if new_state != state:
		state = new_state
		emit_signal("change_state", state)

func get_state() -> bool:
	if rad_to_deg(lever.rotation.y) < 40:
		return true
	elif rad_to_deg(lever.rotation.y) > 130:
		return false
	return state

func set_state(_state: bool):
	state = _state
	if state:
		lever.rotation.y = deg_to_rad(36.3)
	else:
		lever.rotation.y = deg_to_rad(137)
