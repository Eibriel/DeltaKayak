extends Area3D
class_name Room

@export var world_node:DKWorld
@export var room_id:String
@export var enemy_points:Array[Vector3]
#@export var camera:Camera3D
#@export var path:Path3D

func _ready():
	connect("area_entered", world_node.on_room_entered.bind(self))
	connect("area_exited", world_node.on_room_exited.bind(self))
