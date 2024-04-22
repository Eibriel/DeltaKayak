extends Area3D
class_name Trigger

@export var world_node:DKWorld
@export var trigger_id:String
#@export var camera:Camera3D
#@export var path:Path3D

func _ready():
	connect("area_entered", world_node.trigger_fired.bind(trigger_id))
