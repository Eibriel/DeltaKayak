extends Control

@onready var dk_world: DKWorld = %DKWorld
@onready var label_demo: Label = $Control/LabelDemo

func _ready() -> void:
	Global.icon = $Control/Icon

	label_demo.visible = false
	if Global.is_demo():
		label_demo.visible = true
