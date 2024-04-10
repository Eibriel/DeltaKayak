extends GLTFDocumentExtension

func _import_post(gstate: GLTFState, node: Node) -> Error:
	#print("Node")
	#prints(node.name, node.get_class().get_basename())
	#for c in node.get_children():
	#	prints(c.name, c.get_class().get_basename())
	return OK
