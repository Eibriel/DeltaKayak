@tool
extends Node3D

const WATER_MATERIAL = preload("res://materials/water_material.tres")

func _ready() -> void:
	var patch_size := Vector2i(60, 60)
	for x in 60:
		for z in 60:
			var c := CSGMesh3D.new()
			var q := PlaneMesh.new()
			q.size = patch_size #Vector2i(20, 20)
			q.orientation = PlaneMesh.FACE_Y
			c.mesh = q
			add_child(c)
			c.position.x = (x-(patch_size.x*0.5)) * patch_size.x
			c.position.z = (z-(patch_size.y*0.5)) * patch_size.y
			c.visibility_range_end = 200
			c.visibility_range_end_margin = 10
			c.material_override = WATER_MATERIAL
