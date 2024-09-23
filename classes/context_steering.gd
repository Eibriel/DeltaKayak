class_name ContextSteering

var resolution := 4
var angles:Array[float] = []
var distances:Array[float] = []
var interests:Array[float] = []
var dangers:Array[float] = []
var debug_node:ImmediateMesh

var diffs:Array[float] = []

func _init() -> void:
	diffs.resize(360/resolution)
	diffs.fill(0.0)

func next():
	distances.resize(0)
	interests.resize(0)
	dangers.resize(0)

func get_angles() -> Array[float]:
	assert(resolution > 0)
	angles.resize(0)
	for angle in 360/resolution:
		angles.append(deg_to_rad(angle*resolution))
	return angles

func append(pos:float) -> void:
	distances.append(pos)

func get_direction(target_angle:float, delta:float) -> float:
	generate_dangers()
	generate_interests(target_angle)
	draw_interests()
	#var diffs:Array[float] = []
	
	for _n in angles.size():
		diffs[_n] = lerpf(diffs[_n], interests[_n] - dangers[_n], delta*0.5)
		#diffs[_n] = interests[_n] - dangers[_n]
	
	return angles[diffs.find(diffs.max())]

func generate_interests(target_angle) -> void:
	assert(interests.size() == 0)
	for a in angles:
		var interest:float = 1.0 - absf(angle_difference(a, target_angle)/PI)
		interest = clampf(remap(interest, 0.0, 1.0, -1.0, 1.0), 0.0, 1.0)
		interests.append(interest)

func generate_dangers() -> void:
	assert(dangers.size() == 0)
	var original_distances = distances
	for _n in distances.size():
		distances[_n] = \
			(original_distances[_n] / 3) + \
			(min(distances[_n], original_distances[wrapi(_n-1, 0, distances.size()-1)]) / 3) + \
			(min(distances[_n], original_distances[wrapi(_n+1, 0, distances.size()-1)]) / 3)
	
	var max_distance:float = distances.max()
	for d in distances:
		dangers.append(1.0 - (d/max_distance))

func set_debug_node(_debug_node:ImmediateMesh):
	debug_node = _debug_node


func draw_interests():
	if not debug_node: return
	var mat:= StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.RED
	var green_mat:= StandardMaterial3D.new()
	green_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green_mat.albedo_color = Color.GREEN
	
	debug_node.clear_surfaces()
	if distances.size() > 0:
		debug_node.surface_begin(Mesh.PRIMITIVE_POINTS, mat)
		for _n in distances.size():
			var d = distances[_n]
			debug_node.surface_add_vertex(Vector3(-d, 10, 0).rotated(Vector3.UP, angles[_n]))
		debug_node.surface_end()
	
	
	if dangers.size() > 0:
		debug_node.surface_begin(Mesh.PRIMITIVE_POINTS, mat)
		for _n in dangers.size():
			var d = dangers[_n]
			debug_node.surface_add_vertex(Vector3(-d*10, 10, 0).rotated(Vector3.UP, angles[_n]))
		debug_node.surface_end()
	
	if interests.size() > 0:
		debug_node.surface_begin(Mesh.PRIMITIVE_POINTS, green_mat)
		for _n in interests.size():
			var i = interests[_n]
			debug_node.surface_add_vertex(Vector3(-i*10, 10, 0).rotated(Vector3.UP, angles[_n]))
		debug_node.surface_end()
	
	debug_node.surface_begin(Mesh.PRIMITIVE_POINTS, green_mat)
	for _n in diffs.size():
		var d = diffs[_n]
		debug_node.surface_add_vertex(Vector3(0, 10, -min(0, d*10)).rotated(Vector3.UP, angles[_n]))
	debug_node.surface_end()
	#for c in debug_node.get_children():
		#c.queue_free()
	#var pos := Vector3(100, 0, 100)
	#for p in interests:
		#pos.y += 2
		#var b = CSGBox3D.new()
		#debug_node.add_child(b)
		#b.global_position = pos
		#b.global_position.z += p*10

#func get_direction(global_position:Vector3, target_position:Vector3):
	#if clos_dist < global_position.distance_squared_to(target_position):
			#var idx := positions.find(clos_pos)
			#if idx >= 0:
				#var pos_a:Vector3 = positions[wrapi(idx+1, 0, positions.size()-1)]
				#var pos_b:Vector3 = positions[wrapi(idx-1, 0, positions.size()-1)]
				#if is_equal_approx(global_position.distance_to(pos_a), max_dist_search):
					#clos_pos = pos_a
				#elif is_equal_approx(global_position.distance_to(pos_b), max_dist_search):
					#clos_pos = pos_b
			#subtarget_position = clos_pos
		#if not some_no_collision:
			#max_dist_search *= 0.5
			#time_all_collision += delta
		#else:
			#if time_all_collision > 2.0:
				#max_dist_search = 50
				#time_all_collision = 0.0
			#else:
				#time_all_collision += delta
	#print(time_all_collision)
	#for c in %BoatRayCast.get_children():
		#c.queue_free()
	#for p in positions:
		#var b = CSGBox3D.new()
		#%BoatRayCast.add_child(b)
		#b.global_position = p
