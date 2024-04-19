@tool
extends Node3D

const WATER_MATERIAL = preload("res://materials/water_material.tres")

func _ready() -> void:
	for x in 20:
		for z in 20:
			var c := CSGMesh3D.new()
			var q := PlaneMesh.new()
			q.size = Vector2i(20, 20)
			q.orientation = PlaneMesh.FACE_Y
			c.mesh = q
			add_child(c)
			c.position.x = (x-10) * 20
			c.position.z = (z-10) * 20
			c.visibility_range_end = 50
			c.visibility_range_end_margin = 5
			c.material_override = WATER_MATERIAL
