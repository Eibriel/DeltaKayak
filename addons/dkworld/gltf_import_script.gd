@tool # Needed so it runs in editor.
extends EditorScenePostImport

# This sample changes all node names.
# Called right after the scene is imported and gets the root node.
func _post_import(scene):
	# Change all node names to "modified_[oldnodename]"
	print(scene.name)
	for c in scene.get_children():
		apply_material(c, scene.name)#c.name.split("_")[0])
	return scene # Remember to return the imported scene

func apply_material(node, filename: String):
	if node is not MeshInstance3D: return
	var inode := node as MeshInstance3D
	var mat := inode.mesh.surface_get_material(0) as StandardMaterial3D
	print(inode.name)
	if not inode.name.ends_with("_obj"): return
	var path := "res://models/world_textures/%s_diffuse.png" % filename
	prints(inode.name, path)
	if not FileAccess.file_exists(path):
		mat.albedo_color = Color.BLUE_VIOLET
		return
	#print(json)
	var texture := load(path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_texture = texture
	mat.metallic_specular = 0.0
	mat.roughness = 0.0
	# TODO not all materials need alpha
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
