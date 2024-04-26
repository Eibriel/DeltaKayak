extends Control

@onready var dk_world: DKWorld = %DKWorld

func _ready() -> void:
	Global.icon = $Control/Icon
