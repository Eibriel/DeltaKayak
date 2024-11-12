extends Path3D

const TRACK_SLEEPERS_CUBE = preload("res://meshes/track_sleeper_rollercoaster.res")

func _ready() -> void:
	var cable_mesh := MeshInstance3D.new()
	var st = SurfaceTool.new()
	var offsets := [
		Vector3(0.2,0,0),
		Vector3(-0.2,0,0),
		Vector3(0,-0.1,0)
	]
	var mesh := ArrayMesh.new()
	for offset in offsets:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var shape := [
			Vector3(1, 1, 0),
			Vector3(-1, 1, 0),
			Vector3(-1, -1, 0),
			Vector3(1, -1, 0),
		]
		var patterns := [
			[[0,0], [1,0], [0,1]],
			[[1,0], [1,1], [0,1]],
			[[1,1], [1,0], [2,0]],
			[[2,1], [1,1], [2,0]],
			[[0,0], [0,1], [3,0]],
			[[0,0], [0,1], [3,0]],
			[[3,0], [0,1], [3,1]],
			[[3,0], [0,1], [3,1]],
			[[3,0], [3,1], [2,1]],
			[[2,0], [3,0], [2,1]],
		]
		var curve_length := curve.get_baked_length()
		
		for cp in 100:
			for pa in patterns:
				for po in pa:
					var ccp:int = cp + po[1]
					var p_transform := get_point_transform(ccp*0.01)
					st.add_vertex(p_transform * ((shape[po[0]] * 0.025)+offset))
		st.generate_normals()
		mesh = st.commit(mesh)
	for cp in 100:
		var p_transform := get_point_transform(cp*0.01)
		p_transform = p_transform.scaled_local(Vector3.ONE * 0.25)
		st.append_from(TRACK_SLEEPERS_CUBE, 0, p_transform)
	mesh = st.commit(mesh)
	cable_mesh.mesh = mesh
	add_child(cable_mesh)


func get_point_transform(offset:float) -> Transform3D:
	return curve.sample_baked_with_rotation(
			offset*curve.get_baked_length(),
			false,
			true
		)

func exit_test():
	get_tree().quit()
