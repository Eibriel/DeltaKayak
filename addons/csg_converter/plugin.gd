@tool
extends EditorPlugin
## Adds a button to the 3D editor to convert CSGs


enum ButtonId {
	CONVERT_AUTO,
	CONVERT_MESH,
	CONVERT_STATIC,
	CONVERT_ALL_AUTO,
	CONVERT_ALL_MESH,
	CONVERT_ALL_STATIC,
}

var _button: MenuButton
var _menu: PopupMenu

var _selected_csgs: Array[CSGShape3D]


func _enter_tree():
	# create button
	_button = MenuButton.new()
	_button.text = "CSG"
	
	
	# create menu
	_menu = _button.get_popup()
	
	# 0
	_menu.add_item("Convert selected", ButtonId.CONVERT_AUTO)
	_menu.set_item_tooltip(0, "Convert selected CSG root shapes into mesh instances or solid bodies.\nDepends on the Use Collision flag.")
	
	# 1
	var sub_menu_selected := PopupMenu.new()
	sub_menu_selected.add_item("..mesh instances", ButtonId.CONVERT_MESH)
	sub_menu_selected.set_item_tooltip(0, "Convert selected CSG root shapes into mesh instances.\nIgnores Use Collision flag.")
	sub_menu_selected.add_item("..static bodies", ButtonId.CONVERT_STATIC)
	sub_menu_selected.set_item_tooltip(1, "Convert selected CSG root shapes into static bodies.\nIgnores Use Collision flag.")
	_menu.add_submenu_node_item("Convert selected to..", sub_menu_selected)
	
	# 2
	_menu.add_separator()
	
	# 3
	_menu.add_item("Convert all in scene", ButtonId.CONVERT_ALL_AUTO)
	_menu.set_item_tooltip(3, "Convert all CSG root shapes in the scene into mesh instances or solid bodies.\nDepends on the Use Collision flag.")
	
	# 4
	var sub_menu_all := PopupMenu.new()
	sub_menu_all.add_item("..mesh instances", ButtonId.CONVERT_ALL_MESH)
	sub_menu_all.set_item_tooltip(0, "Convert all CSG root shapes in the scene into mesh instances.\nIgnores Use Collision flag.")
	sub_menu_all.add_item("..static bodies", ButtonId.CONVERT_ALL_STATIC)
	sub_menu_all.set_item_tooltip(1, "Convert all CSG root shapes in the scene into static bodies.\nIgnores Use Collision flag.")
	_menu.add_submenu_node_item("Convert all in scene to..", sub_menu_all)
	
	
	# connect signals
	_menu.id_pressed.connect(on_item_selected)
	sub_menu_selected.id_pressed.connect(on_item_selected)
	sub_menu_all.id_pressed.connect(on_item_selected)
	
	
	# add button
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _button)
	_button.hide()
	
	# listen for node selection in scene tree
	EditorInterface.get_selection().selection_changed.connect(on_editor_selection_changed)


func _exit_tree() -> void:
	if is_instance_valid(_button):
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _button)
		_button.queue_free()


func on_item_selected(id: int) -> void:
	match id:
		ButtonId.CONVERT_AUTO, ButtonId.CONVERT_MESH, ButtonId.CONVERT_STATIC:
			for csg in _selected_csgs:
				convert_csg(csg, id)
		
		ButtonId.CONVERT_ALL_AUTO, ButtonId.CONVERT_ALL_MESH, ButtonId.CONVERT_ALL_STATIC:
			var tried_csgs: Array[CSGShape3D] = []
			while true:
				var csg := get_first_root_csg_in_scene()
				if csg:
					# break out of loop on error
					if csg in tried_csgs:
						push_error("One conversion failed. Aborted")
						break
					tried_csgs.append(csg)
					
					convert_csg(csg, id - 3)
					
				else:
					break


func get_first_root_csg_in_scene() -> CSGShape3D:
	var root := EditorInterface.get_edited_scene_root()
	for csg: CSGShape3D in root.find_children("*", "CSGShape3D"):
		if csg.is_root_shape():
			return csg
	return null


func convert_csg(csg: CSGShape3D, to: ButtonId) -> void:
	# keep node name and position in tree
	var csg_name := csg.name
	var csg_index := csg.get_index()
	var csg_parent := csg.get_parent()
	var csg_owner := csg.owner
	
	# create mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	
	# extract mesh
	mesh_instance.mesh = csg.get_meshes()[1]
	if not mesh_instance.mesh or mesh_instance.mesh.get_surface_count() == 0:
		push_error("Failed to extract mesh. CSG (", csg.name, ") appears to have no mesh")
		return
	
	# copy settings
	# VisualInstance3D
	mesh_instance.layers = csg.layers
	mesh_instance.sorting_offset = csg.sorting_offset
	mesh_instance.sorting_use_aabb_center = csg.sorting_use_aabb_center
	
	# GeometryInstance3D
	mesh_instance.material_override = csg.material_override
	mesh_instance.material_overlay = csg.material_overlay
	mesh_instance.transparency = csg.transparency
	mesh_instance.cast_shadow = csg.cast_shadow
	mesh_instance.extra_cull_margin = csg.extra_cull_margin
	mesh_instance.custom_aabb = csg.custom_aabb
	mesh_instance.lod_bias = csg.lod_bias
	mesh_instance.ignore_occlusion_culling = csg.ignore_occlusion_culling
	
	mesh_instance.gi_mode = csg.gi_mode
	mesh_instance.gi_lightmap_scale = csg.gi_lightmap_scale
	
	mesh_instance.visibility_range_begin = csg.visibility_range_begin
	mesh_instance.visibility_range_begin_margin = csg.visibility_range_begin_margin
	mesh_instance.visibility_range_end = csg.visibility_range_end
	mesh_instance.visibility_range_end_margin = csg.visibility_range_end_margin
	mesh_instance.visibility_range_fade_mode = csg.visibility_range_fade_mode
	
	
	# new root node
	var new_node: Node3D = mesh_instance
	
	
	# create collision, if forced or csg has it
	if to == ButtonId.CONVERT_STATIC or (to == ButtonId.CONVERT_AUTO and csg.use_collision):
		# create static body
		#TODO: method configurable
		mesh_instance.create_trimesh_collision()
		
		# get created static body
		var static_body := mesh_instance.get_child(0) as StaticBody3D
		
		# check
		if not static_body:
			push_error("Failed to create collision shape for CSG (", csg_name, "). Check Godot error log")
			static_body = StaticBody3D.new()
		
		# reorder nodes to have the static body as root
		mesh_instance.remove_child(static_body)
		static_body.add_child(mesh_instance)
		
		# copy collision settings
		static_body.collision_layer = csg.collision_layer
		static_body.collision_mask = csg.collision_mask
		static_body.collision_priority = csg.collision_priority
		
		# use the static body as root
		new_node = static_body
	
	
	# check if csg has an attached script
	var csg_script = csg.get_script()
	if csg_script:
		# inform user, can't attach script to other type
		push_warning("Can't reattach scripts due to type mismatch. Script from CSG (", csg_name, ") detached: ", csg_script.get_path())
	
	# copy remaining settings
	# Node
	new_node.editor_description = csg.editor_description
	new_node.auto_translate_mode = csg.auto_translate_mode
	new_node.physics_interpolation_mode = csg.physics_interpolation_mode
	new_node.process_mode = csg.process_mode
	new_node.process_priority = csg.process_priority
	new_node.process_physics_priority = csg.process_physics_priority
	new_node.process_thread_group = csg.process_thread_group
	
	# Node3D
	new_node.transform = csg.transform
	new_node.top_level = csg.top_level
	new_node.visible = csg.visible
	new_node.visibility_parent = csg.visibility_parent
	
	
	# build undo-redo action
	get_undo_redo().create_action("Convert CSG (" + csg.name + ")")
	
	# DO - add new node
	get_undo_redo().add_do_method(csg_parent, "add_child", new_node)
	get_undo_redo().add_do_method(csg_parent, "move_child", new_node, csg_index)
	get_undo_redo().add_do_method(new_node, "propagate_call", "set_owner", [csg_owner], true)
	
	# UNDO - add csg back
	get_undo_redo().add_undo_method(csg_parent, "add_child", csg)
	get_undo_redo().add_undo_method(csg_parent, "move_child", csg, csg_index)
	get_undo_redo().add_undo_method(csg, "propagate_call", "set_owner", [csg_owner], true)
	
	# move non-csg children over, do-undo done in function
	reparent_non_csg_nodes_recursive(csg, new_node)
	
	# rename
	get_undo_redo().add_do_property(csg, "name", csg_name + "_")
	get_undo_redo().add_do_property(new_node, "name", csg_name)
	
	get_undo_redo().add_undo_property(new_node, "name", csg_name + "_")
	get_undo_redo().add_undo_property(csg, "name", csg_name)
	
	# remove old node
	get_undo_redo().add_undo_reference(csg) # keep reference as long as in history
	get_undo_redo().add_do_method(csg_parent, "remove_child", csg)
	
	get_undo_redo().add_do_reference(new_node)
	get_undo_redo().add_undo_method(csg_parent, "remove_child", new_node)
	
	# do it
	get_undo_redo().commit_action()


func reparent_non_csg_nodes_recursive(node: Node, new_parent: Node) -> void:
	if node is CSGShape3D:
		# check children
		for child in node.get_children():
			reparent_non_csg_nodes_recursive(child, new_parent)
		
	else:
		get_undo_redo().add_do_method(node, "reparent", new_parent)
		get_undo_redo().add_undo_method(node, "reparent", node.get_parent())
		# restore original name in case it got changed
		get_undo_redo().add_undo_property(node, "name", node.name)


func on_editor_selection_changed() -> void:
	# get current selection
	var selected_nodes := EditorInterface.get_selection().get_selected_nodes()
	
	# hide if nothing is selected
	if selected_nodes.size() == 0:
		_button.hide()
		return
	
	# get root csg nodes and store them
	_selected_csgs.clear()
	for node: Node in selected_nodes:
		if node is CSGShape3D:
			var root_csg := get_csg_root_node(node)
			if not root_csg in _selected_csgs:
				_selected_csgs.append(root_csg)
	
	# update button
	match _selected_csgs.size():
		0:
			# hide when no csgs are selected
			_button.hide()
			return
		
		1:
			_button.text = "CSG"
		
		_:
			_button.text = "(" + str(_selected_csgs.size()) + ") CSGs"
	
	_button.icon = ResourceLoader.load("res://addons/csg_converter/icons/" + _selected_csgs[0].get_class() + ".svg", "CompressedTexture2D", ResourceLoader.CACHE_MODE_REUSE)
	_button.show()

func get_csg_root_node(csg: CSGShape3D) -> CSGShape3D:
	if csg.is_root_shape():
		return csg
	
	return get_csg_root_node(csg.get_parent())
