@tool
extends MeshInstance3D
#class_name EibrielTerrain

@export var resolution:int:
	get:
		return resolution
	set(value):
		if value == resolution:
			return
		resolution = value
		update_mesh()

@export var camera:Camera3D

var array_mesh:ArrayMesh = ArrayMesh.new()

var is_ready = false

func _ready():
	mesh = array_mesh
	is_ready = true
	update_mesh()

func in_frustum(point:Vector3, frustum:Array[Plane]):
	for p in frustum:
		if (point.dot(p.normal) + p.d) <= 0:
			return false
	return true
	

func update_mesh():
	if not is_ready: return
	var frustum := camera.get_frustum()
	#visible = in_frustum(position, frustum)
	#visible = camera.is_position_in_frustum(position)
	
	# Generate mesh
	var corners := get_corners()
	
	build_triangle(corners[0], corners[1], corners[3])
	
	#var output := PackedFloat32Array([0, 0, 0, 1, 0, 0, 0, 0, 1])
	var vertices = PackedVector3Array()
	vertices.append(corners[0])
	vertices.append(corners[1])
	vertices.append(corners[2])
	vertices.append(corners[1])
	vertices.append(corners[3])
	vertices.append(corners[2])
	#print(vertices)
	
	# TODO remove for loop
	#for n in range(0, output.size(), 3):
		#vertices.push_back(Vector3(output[n], output[n+1], output[n+2]))
	#print(vertices)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	
	array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func build_triangle(v1, v2, v3):
	var points := []
	points += []
	return [0, 0, 0, 1, 0, 0, 0, 0, 1]
	

func generate_mesh_shader():
	var rd := RenderingServer.create_local_rendering_device()
	
	# Load GLSL shader
	var shader_file := load("res://addons/eibriel_terrain/terrain.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)

	# Prepare our data. We use floats in the shader, so we need 32 bit.
	var input := PackedFloat32Array([0, 0, 0, 1, 0, 0, 0, 0, 1])
	var input_bytes := input.to_byte_array()

	

	# Create a storage buffer that can hold our float values.
	# Each float has 4 bytes (32 bit) so 10 x 4 = 40 bytes
	var buffer := rd.storage_buffer_create(input_bytes.size(), input_bytes)
	
	# Create a uniform to assign the buffer to the rendering device
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0 # this needs to match the "binding" in our shader file
	uniform.add_id(buffer)
	var uniform_set := rd.uniform_set_create([uniform], shader, 0) # the last parameter (the 0) needs to match the "set" in our shader file

	# Create a compute pipeline
	var pipeline := rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, 5, 1, 1)
	rd.compute_list_end()
	
	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()
	
	# Read back the data from the buffer
	var output_bytes := rd.buffer_get_data(buffer)
	var output := output_bytes.to_float32_array()
	#print("Input: ", input)
	#print("Output: ", output)


func get_corners() -> Array[Vector3]:
	#var rect_size := DisplayServer.window_get_size()
	#var rect_size: Vector2 = get_viewport().size
	#print(rect_size)
	#var width := rect_size.y
	#var height := rect_size.x
	var width:int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height:int = ProjectSettings.get_setting("display/window/size/viewport_height")
	var screen_corners = [
		Vector2i(50, 50),
		Vector2i(width, 0),
		Vector2i(0, height),
		Vector2i(width-50, height-50)
	]
	#print(screen_corners)
	var corner_intersections:Array[Vector3] = []
	for c in screen_corners:
		var rayVector = camera.project_ray_normal(c)
		var rayPoint = camera.project_ray_origin(c)
		var intersection = planeRayIntersection(rayVector,rayPoint, Vector3.ZERO, Vector3.UP)
		if intersection == Vector3.ZERO:
			var far_plane := camera.get_frustum()[1]
			var far_intersection = planeRayIntersection(rayVector,rayPoint, far_plane.get_center(), far_plane.normal)
			intersection = planeRayIntersection(Vector3.DOWN,far_intersection, Vector3.ZERO, Vector3.UP)
		corner_intersections.append(intersection)
	return corner_intersections


func planeRayIntersection(rayVector: Vector3, rayPoint: Vector3, planePoint: Vector3, planeNormal: Vector3) -> Vector3:
	var diff: Vector3 = rayPoint - planePoint
	var prod1 = diff.dot(planeNormal)
	var prod2 = rayVector.dot(planeNormal)
	var prod3 = prod1 / prod2
	if prod3 > 0:
		return Vector3.ZERO
	var intersection: Vector3 = rayPoint - (rayVector * prod3)
	return intersection
