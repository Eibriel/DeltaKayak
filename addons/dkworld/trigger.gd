extends Area3D
class_name Trigger

@export var world_node:DKWorld
@export var trigger_id:String
#@export var camera:Camera3D
#@export var path:Path3D

func _ready():
	connect("area_entered", world_node.on_trigger_entered.bind(trigger_id))
	connect("area_exited", world_node.on_trigger_exited.bind(trigger_id))
