extends RigidBody3D

@export var label_text:String
@export var target_position:Vector3

func _ready() -> void:
	$Label3D.text = label_text
