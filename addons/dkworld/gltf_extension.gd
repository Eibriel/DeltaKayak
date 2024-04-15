extends GLTFDocumentExtension

func _import_post(gstate: GLTFState, node: Node) -> Error:
	#print(node.get_class())
	return OK

func _import_node(state: GLTFState, gltf_node: GLTFNode, json: Dictionary, node: Node) -> Error:
	#convert_meshinstance(node)
	#apply_lod(json, node)
	return OK



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
