extends GLTFDocumentExtension

func _import_post(gstate: GLTFState, node: Node) -> Error:
	#print(node.get_class())
	return OK

func _import_node(state: GLTFState, gltf_node: GLTFNode, json: Dictionary, node: Node) -> Error:
	#convert_meshinstance(node)
	#apply_lod(json, node)
	apply_material(json, node, state.filename)
	return OK

func apply_material(json, node, filename: String):
	if node is not ImporterMeshInstance3D: return
	var inode := node as ImporterMeshInstance3D
	var mat := inode.mesh.get_surface_material(0) as StandardMaterial3D
	if not inode.name.ends_with("_obj"): return
	var path := "res://models/world_textures/%s_diffuse.png" % filename
	prints(inode.name, path)
	if FileAccess.file_exists(path):
		prints(path, "exists!")
	#print(json)
	var texture := load(path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_texture = texture

# Unused:

func convert_meshinstance(node) -> void:
	if node is ImporterMeshInstance3D:
		pass

func apply_lod(json: Dictionary, node: Node) -> void:
	#print("apply_lod")
	print(node.get_class())
	if node is not ImporterMeshInstance3D: return
	#node = node as ImporterMeshInstance3D
	print("visibility_range_begin")
	node.visibility_range_begin = 20.0
	print("*")
	if false:
		#print("MeshInstance3D")
		if not json.has("extras"): return
		if not json.extras.has("DKT_DATA"): return
		
		var dkt_data_string: String = json.extras.DKT_DATA
		#print("dkt_data_string")
		var json_extra = JSON.new()
		var error = json_extra.parse(dkt_data_string)
		if error != OK: return
		#print("Set meta")
		node.set_meta("DKT_DATA", json_extra.data)
