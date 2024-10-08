# import_plugin.gd
@tool
extends EditorImportPlugin
#extends EditorSceneFormatImporter

const gltf_document_extension_class = preload("./gltf_extension.gd")

const WATER_PATCH = preload("res://scenes/water_patch.tscn")

enum Presets { DEFAULT }

var packed_scenes: Dictionary

func _get_importer_name():
	return "eibriel.dkworld"

func _get_visible_name():
	return "Delta Kayak World"

func _get_recognized_extensions() -> PackedStringArray:
	return ["dkworld"]

#func _get_extensions() -> PackedStringArray:
	#var exts: PackedStringArray
	#exts.push_back("dkworld")
	#return exts


#func _get_import_flags() -> int:
#	return IMPORT_SCENE
	
func _get_save_extension():
	return "scn"

func _get_resource_type():
	return "PackedScene"

func _get_preset_count():
	return Presets.size()

func _get_preset_name(preset_index):
	match preset_index:
		Presets.DEFAULT:
			return "Default"
		_:
			return "Unknown"

func _get_import_options(path, preset_index):
	match preset_index:
		Presets.DEFAULT:
			return [{
					   "name": "use_red_anyway",
					   "default_value": false
					}]
		_:
			return []

#func _get_import_options(path: String) -> void:
#	pass

func _get_option_visibility(path, option_name, options):
	return true

func _import(source_file, save_path, options, r_platform_variants, r_gen_files):
#func _import_scene(source_file: String, flags: int, options: Dictionary) -> Object:
	var file = FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
		#return null

	var json_string = file.get_as_text()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	var world_definition:Dictionary = {}
	if error == OK:
		world_definition = json.data
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
		
	var scene = PackedScene.new()
	var main_node = DKWorld.new()
	main_node.name = "DKWorld"
	main_node.world_definition = world_definition
	
	for sector_id in world_definition:
		var sector:Dictionary = world_definition[sector_id] as Dictionary
		for item_id in sector.items:
			var item:Dictionary = sector.items[item_id] as Dictionary
			add_item(item, item_id, main_node)
		for camera_id in sector.cameras:
			var camera:Dictionary = sector.cameras[camera_id] as Dictionary
			add_camera(camera, camera_id, main_node)
		for physicsitem_id in sector.physicsitems:
			var physicsitem:Dictionary = sector.physicsitems[physicsitem_id] as Dictionary
			add_physicsitem(physicsitem, physicsitem_id, main_node)
		add_trees(sector.trees, sector_id, main_node)
		add_triggers(sector.triggers, sector_id, main_node)
		add_colliders(sector.colliders, sector_id, main_node)
		add_lands(sector.lands, sector_id, main_node)
		add_navmesh(sector.navmesh, sector_id, main_node)
		add_rooms(sector.rooms, sector_id, main_node, sector)
		add_lights(sector.lights, sector_id, main_node)
		add_greyboxes(sector.greyboxes, sector_id, main_node)
	
	add_water(main_node)
	
	packed_scenes = {}
	var result = scene.pack(main_node)
	if result == OK:
		#return scene
		#prints(save_path, _get_save_extension())
		return ResourceSaver.save(scene, "%s.%s" % [save_path, _get_save_extension()])
	else:
		return result
		#return null

func add_lights(lights_array: Array, sector_id:String, main_node:Node3D):
	for light in lights_array:
		var light_node:Node3D
		var light_pos:Node3D = Node3D.new()
		match light.type:
			"SPOT":
				light_node = SpotLight3D.new()
				light_node.spot_angle = rad_to_deg(light.spot_size)
				light_node.spot_range = light.distance
			"POINT":
				light_node = OmniLight3D.new()
				light_node.omni_range = light.omni_radius
		light_node.name = light.name
		light_node.light_color = Color(light.color[0], light.color[1], light.color[2])
		light_node.light_volumetric_fog_energy = 2.61
		light_node.distance_fade_enabled = true
		light_node.distance_fade_begin = 200
		light_pos.position = array_to_vector3(light.position)
		light_pos.rotation = array_to_vector3(light.rotation)
		light_node.rotation.x = deg_to_rad(-90)
		main_node.add_child(light_pos)
		light_pos.add_child(light_node)
		light_node.set_owner(main_node)
		light_pos.set_owner(main_node)

func add_rooms(rooms_array: Array, sector_id:String, main_node:Node3D, sector:Dictionary):
	for room in rooms_array:
		var room_area := Room.new()
		var room_collision := CollisionPolygon3D.new()
		main_node.add_child(room_area)
		room_area.set_owner(main_node)
		room_area.add_child(room_collision)
		room_collision.set_owner(main_node)
		
		#Do not scale!
		room_area.position = array_to_vector3(room.position)
		room_area.quaternion = array_to_quaternion(room.quaternion)
		
		#Do not scale!
		room_collision.rotate_x(deg_to_rad(90))
		
		var points: PackedVector2Array
		for p in room.points:
			var p_position := Vector2(p[0][0], p[0][2])
			points.append(p_position)
		room_collision.polygon = points
		room_collision.depth = 6
		
		var enemy_points_positions:Array[Vector3]
		for ep in room.enemy_points:
			enemy_points_positions.append(array_to_vector3(sector.enemy_points[ep].position))
		
		room_area.room_id = room.id
		room_area.world_node = main_node
		room_area.enemy_points = enemy_points_positions

func add_navmesh(navmesh_array: Array, sector_id:String, main_node:Node3D):
	for navmesh in navmesh_array:
		#polygons, vertices
		var navigation_region := NavigationRegion3D.new()
		navigation_region.name = navmesh.name
		var navigation_mesh := NavigationMesh.new()
		main_node.add_child(navigation_region)
		navigation_region.set_owner(main_node)
		navigation_region.navigation_mesh = navigation_mesh
		navigation_region.position = array_to_vector3(navmesh.position)
		navigation_region.rotation = array_to_vector3(navmesh.rotation)
		var packed_vertices: PackedVector3Array
		for v in navmesh.vertices:
			packed_vertices.append(Vector3(v[0], v[1], v[2]))
		navigation_mesh.set_vertices(packed_vertices)
		for p in navmesh.polygons:
			navigation_mesh.add_polygon(PackedInt32Array(p))

func add_greyboxes(greybox_array: Array, sector_id:String, main_node:Node3D):
	var grey_mat := StandardMaterial3D.new()
	grey_mat.albedo_color = Color.DIM_GRAY
	grey_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for greybox in greybox_array:
		var navigation_region := MeshInstance3D.new()
		navigation_region.name = greybox.name
		var navigation_mesh := ArrayMesh.new()
		main_node.add_child(navigation_region)
		navigation_region.set_owner(main_node)
		navigation_region.mesh = navigation_mesh
		navigation_region.position = array_to_vector3(greybox.position)
		navigation_region.rotation = array_to_vector3(greybox.rotation)
		var packed_vertices: PackedVector3Array
		var packed_normals:PackedVector3Array
		var packed_polygons: PackedInt32Array
		#for v in greybox.vertices:
		#	packed_vertices.append(Vector3(v[0], v[1], v[2]))
		for p in greybox.polygons:
			#packed_polygons.append(p[2])
			#packed_polygons.append(p[1])
			#packed_polygons.append(p[0])
			var norm := get_normal_from_triangle(
				Vector3(greybox.vertices[p[0]][0], greybox.vertices[p[0]][1], greybox.vertices[p[0]][2]),
				Vector3(greybox.vertices[p[1]][0], greybox.vertices[p[1]][1], greybox.vertices[p[1]][2]),
				Vector3(greybox.vertices[p[2]][0], greybox.vertices[p[2]][1], greybox.vertices[p[2]][2]),
			)
			for v in 3:
				var ver = greybox.vertices[p[2-v]]
				packed_vertices.append(Vector3(ver[0], ver[1], ver[2]))
				packed_normals.append(norm)
		#for n in greybox.normals:
		#	packed_normals.append(Vector3(n[0], n[1], n[2]))
		var grey_mesh := []
		grey_mesh.resize(Mesh.ARRAY_MAX)
		grey_mesh.fill(null)
		grey_mesh[Mesh.ARRAY_VERTEX] = packed_vertices
		#grey_mesh[Mesh.ARRAY_INDEX] = packed_polygons
		grey_mesh[Mesh.ARRAY_NORMAL] = packed_normals
		navigation_mesh.add_surface_from_arrays(
			Mesh.PrimitiveType.PRIMITIVE_TRIANGLES,
			grey_mesh)
		#navigation_mesh.regen_normal_maps()
		navigation_mesh.surface_set_material(0, grey_mat)

func get_normal_from_triangle(p1:Vector3, p2:Vector3, p3:Vector3) -> Vector3:
	var A := p2 - p1
	var B := p3 - p1
	var N :Vector3
	N.x = A.y * B.z - A.z * B.y
	N.y = A.z * B.x - A.x * B.z
	N.z = A.x * B.y - A.y * B.x
	N = N.normalized()
	return N

func add_colliders(colliders: Array, sector_id:String, main_node:Node3D):
	# Collider
	for collider in colliders:
		var static_body := StaticBody3D.new()
		var collision_polygon := CollisionPolygon3D.new()
		main_node.add_child(static_body)
		static_body.set_owner(main_node)
		static_body.add_child(collision_polygon)
		collision_polygon.set_owner(main_node)
		
		var physics_material := PhysicsMaterial.new()
		physics_material.friction = 0
		static_body.physics_material_override = physics_material
		
		#static_body.set_collision_layer_value(2, true)
		static_body.set_collision_mask_value(1, true) # Walls
		static_body.set_collision_mask_value(2, true) # Character
		static_body.set_collision_mask_value(3, true) # Grabbable
		static_body.set_collision_mask_value(4, true) # Enemies
		
		#Do not scale!
		static_body.position = array_to_vector3(collider.position)
		static_body.quaternion = array_to_quaternion(collider.quaternion)
		
		#Do not scale!
		collision_polygon.rotate_x(deg_to_rad(90))
		
		var points: PackedVector2Array
		for p in collider.points:
			var p_position := Vector2(p[0][0], p[0][2])
			points.append(p_position)
		collision_polygon.polygon = points
		collision_polygon.depth = 6

func add_lands(lands: Array, sector_id:String, main_node:Node3D):
	# Lands
	var count := -1
	for land in lands:
		count += 1
		var static_body := Node3D.new()
		var land_polygon := CSGPolygon3D.new()
		main_node.add_child(static_body)
		static_body.set_owner(main_node)
		static_body.add_child(land_polygon)
		land_polygon.set_owner(main_node)
		
		static_body.name = "Land_%s" % str(count)
		
		#var material := StandardMaterial3D.new()
		#material.albedo_color = Color.GREEN
		#land_polygon.material = material
		land_polygon.material = preload("res://materials/land_material_2.tres")
		land_polygon.use_collision = true
		#land_polygon.smooth_faces = true
		land_polygon.set_collision_mask_value(1, true) # Walls
		land_polygon.set_collision_mask_value(2, true) # Character
		land_polygon.set_collision_mask_value(3, true) # Grabbable
		land_polygon.set_collision_mask_value(4, true) # Enemies
		land_polygon.set_collision_mask_value(5, true) # Transparent
		land_polygon.collision_priority = 20
		
		#Do not scale!
		static_body.position = array_to_vector3(land.position)
		static_body.position.y -= 0.05
		static_body.quaternion = array_to_quaternion(land.quaternion)
		
		#Do not scale!
		land_polygon.rotate_x(deg_to_rad(90))
		
		var points: PackedVector2Array
		for p in land.points:
			var p_position := Vector2(p[0][0], p[0][2])
			points.append(p_position)
		land_polygon.polygon = points
		land_polygon.depth = 0.55
		
		# Dress with grass
		var dressing_meshes :=[]
		match land["biome"]:
			"dry":
				dressing_meshes = [
					"BranchesTangled"
				]
			"concrete":
				dressing_meshes = []
			_:
				dressing_meshes = [
					"GrassCone",
					"BranchesTangled"
				]
			
		for dressing_mesh in dressing_meshes:
			var multimesh_instance := MultiMeshInstance3D.new()
			var multimesh := MultiMesh.new()
			multimesh_instance.set_name("LandDressing_%s_%s" % [str(count), dressing_mesh])
			static_body.add_child(multimesh_instance)
			multimesh_instance.set_owner(main_node)
			multimesh_instance.multimesh = multimesh
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = load_tree_meshes(dressing_mesh)
			var mm_points := []
			for pp_id in land.points.size()-1:
				var pp_a := array_to_vector3(land.points[pp_id][0])
				var pp_b := array_to_vector3(land.points[pp_id+1][0])
				var dist:float = pp_a.distance_to(pp_b)*randf_range(1, 3)
				for dist_amount in int(dist):
					var lerp_weight = float(dist_amount)/dist
					var pp_lerp = lerp(pp_a, pp_b, lerp_weight)
					#mm_points.append(pp)
					#var point := Vector3.ONE
					var t_point := Transform3D(Basis(), pp_lerp)
					var rand_rotation := randf_range(deg_to_rad(-180), deg_to_rad(180))
					var rand_scale := Vector3.ONE*randf_range(0.25, 1.0)
					t_point = t_point.rotated_local(Vector3.UP, rand_rotation)
					if dressing_mesh == "BranchesTangled":
						t_point = t_point.rotated_local(Vector3.FORWARD, randf_range(deg_to_rad(-180), deg_to_rad(180)))
						t_point = t_point.rotated_local(Vector3.RIGHT, randf_range(deg_to_rad(-180), deg_to_rad(180)))
					t_point = t_point.scaled_local(rand_scale)
					mm_points.append(t_point)
			
			multimesh.instance_count = mm_points.size()
			var tree_n := 0
			for p in mm_points:
				multimesh.set_instance_transform(tree_n, p)
				tree_n += 1

func add_triggers(triggers: Array, sector_id:String, main_node:Node3D):
	for trigger in triggers:
		# Trigger
		if trigger.id.begins_with("trigger_"):
			var trigger_area := Trigger.new()
			var trigger_collision := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			main_node.add_child(trigger_area)
			trigger_area.set_owner(main_node)
			trigger_area.add_child(trigger_collision)
			trigger_collision.set_owner(main_node)
			trigger_collision.shape = box_shape
			box_shape.size = array_to_vector3(trigger.scale)*2
			
			trigger_area.position = array_to_vector3(trigger.position)
			trigger_area.rotation = array_to_vector3(trigger.rotation)
			#trigger_area.scale = array_to_vector3(trigger.scale)
			
			trigger_area.trigger_id = trigger.id
			trigger_area.world_node = main_node
			#main_node.world_definition.append(trigger_area.position)
		elif trigger.id.begins_with("triggerpath_"):
			var trigger_area := Trigger.new()
			var trigger_collision := CollisionPolygon3D.new()
			main_node.add_child(trigger_area)
			trigger_area.set_owner(main_node)
			trigger_area.add_child(trigger_collision)
			trigger_collision.set_owner(main_node)
			
			#Do not scale!
			trigger_area.position = array_to_vector3(trigger.position)
			trigger_area.quaternion = array_to_quaternion(trigger.quaternion)
			
			#Do not scale!
			trigger_collision.rotate_x(deg_to_rad(90))
			
			var points: PackedVector2Array
			for p in trigger.points:
				var p_position := Vector2(p[0][0], p[0][2])
				points.append(p_position)
			trigger_collision.polygon = points
			trigger_collision.depth = 6
			
			trigger_area.trigger_id = trigger.id
			trigger_area.world_node = main_node

func add_water(main_node:Node3D):
	var water = WATER_PATCH.instantiate()
	main_node.add_child(water)
	water.set_owner(main_node)

func add_trees(trees: Dictionary, sector_id:String, main_node:Node3D):
	# TODO mix different types of trees in a better way
	for tree_id in trees:
		var selected_meshes = []
		if trees[tree_id]["biome"] == "dry":
			selected_meshes = [
				"TreeOld_003"
			]
		elif trees[tree_id]["biome"] == "camalote":
			selected_meshes = [
				"CamaloteField",
			]
		else:
			selected_meshes = [
				"Tree001",
				"Tree003",
				"Tree021"
			]
		#for tree_type in TREES:
		var tree_type:String = selected_meshes.pick_random()
		#var amount_trees: int = trees.keys().size()
		#if amount_trees < 1: return
		var multimesh_instance := MultiMeshInstance3D.new()
		var multimesh := MultiMesh.new()
		multimesh_instance.set_name("Trees_%s_%s" % [sector_id, tree_id])
		main_node.add_child(multimesh_instance)
		multimesh_instance.set_owner(main_node)
		multimesh_instance.multimesh = multimesh
		multimesh_instance.position = array_to_vector3(trees[tree_id].position)
		multimesh_instance.visibility_range_end = 100
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = load_tree_meshes(tree_type)
		var points := get_trees_positions(trees[tree_id], "%s%s" % [tree_id, tree_type])
		multimesh.instance_count = points.size()
		
		var tree_n := 0
		for p in points:
			multimesh.set_instance_transform(tree_n, p)
			tree_n += 1

func get_trees_positions(tree:Dictionary, my_seed:String) -> Array:
	#var tree_n := 0
	var points := []
	#for tree_id in trees:
	#var my_seed = tree_id.hash()
	seed(my_seed.hash())
	#print(tree_id)
	#var tree:Dictionary = trees[tree_id] as Dictionary
	#var set_position:= array_to_vector3(tree.position)
	var set_position:= Vector3.ZERO
	var set_rotation:= array_to_vector3(tree.rotation)
	var set_scale:= array_to_vector3(tree.scale)
	var t := Transform3D(Basis(), set_position)
	t = t.rotated_local(Vector3.RIGHT, set_rotation.x)
	t = t.rotated_local(Vector3.UP, set_rotation.y)
	t = t.rotated_local(Vector3.FORWARD, set_rotation.z)
	t = t.scaled_local(set_scale)
	
	# TODO allow rotation in any axis
	var corners: Array[Vector3] = [
		t * Vector3(-1, 0, -1),
		t * Vector3(1, 0, -1),
		t * Vector3(-1, 0, 1),
		t * Vector3(1, 0, 1)
	]
	var length_side1 := corners[0].distance_to(corners[1])
	var length_side2 := corners[1].distance_to(corners[2])
	var amount_side1:float = max(1., length_side1 * 0.5)
	var amount_side2:float = max(1., length_side2 * 0.5)
	for side1 in int(amount_side1):
		for side2 in int(amount_side2):
			var point_a: Vector3 = lerp(corners[0], corners[1], side1/amount_side1)
			var point_b: Vector3 = lerp(corners[2], corners[3], side1/amount_side1)
			var point:Vector3 = lerp(point_a, point_b, side2/amount_side2)
			point += Vector3(randf_range(-0.9, 0.9), 0, randf_range(-0.9, 0.9))
			var t_point := Transform3D(Basis(), point)
			var rand_rotation := randf_range(deg_to_rad(-180), deg_to_rad(180))
			var rand_scale := Vector3.ONE*randf_range(0.5, 1.0)
			t_point = t_point.rotated_local(Vector3.RIGHT, set_rotation.x)
			t_point = t_point.rotated_local(Vector3.UP, set_rotation.y+rand_rotation)
			t_point = t_point.rotated_local(Vector3.FORWARD, set_rotation.z)
			t_point = t_point.scaled_local(rand_scale)
			points.append(t_point)
	return points

var tree_mesh_cache := {}
# NOTE Works for any 3d model, not just trees
func load_tree_meshes(tree_id:String):
	#for tree_id in TREES:
	if tree_id not in tree_mesh_cache.keys():
		var gltf_loader := GLTFDocument.new()
		var convert_mesh_extension := GLTFDocumentExtensionConvertImporterMesh.new()
		gltf_loader.register_gltf_document_extension(convert_mesh_extension, true)
		var gltf_state := GLTFState.new()
		var gltf_path:String = "res://models/world/%s.glb" % tree_id
		gltf_state.base_path = "res://models/world/"
		var gltf_error = gltf_loader.append_from_file(gltf_path, gltf_state)
		var gltf_instance: Node3D
		if gltf_error == OK:
			gltf_instance = gltf_loader.generate_scene(gltf_state) as Node3D
		gltf_loader.unregister_gltf_document_extension(convert_mesh_extension)
		var TREE_001_DIFFUSE = load("res://models/world_textures/%s_diffuse.png" % tree_id)
		for c in gltf_instance.get_children():
			if c is MeshInstance3D:
				var mat := c.mesh.surface_get_material(0) as StandardMaterial3D
				mat.albedo_texture = TREE_001_DIFFUSE
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				tree_mesh_cache[tree_id] = c.mesh
	return tree_mesh_cache[tree_id]

func add_camera(camera:Dictionary, camera_id:String, main_node:Node3D):
	#print(camera)
	var camera_node = Node3D.new()
	camera_node.set_name(camera_id)
	main_node.add_child(camera_node)
	camera_node.set_owner(main_node)
	
	var camera_crane_node = Node3D.new()
	camera_crane_node.set_name("%s_crane" % camera_id)
	camera_node.add_child(camera_crane_node)
	camera_crane_node.set_owner(main_node)
	
	var camera_position_node = Node3D.new()
	camera_position_node.set_name("%s_pos" % camera_id)
	camera_crane_node.add_child(camera_position_node)
	camera_position_node.set_owner(main_node)
	
	var camera_rotation_y_node = Node3D.new()
	camera_rotation_y_node.set_name("%s_roty" % camera_id)
	camera_position_node.add_child(camera_rotation_y_node)
	camera_rotation_y_node.set_owner(main_node)
	
	var camera_rotation_x_node = Node3D.new()
	camera_rotation_x_node.set_name("%s_rotx" % camera_id)
	camera_rotation_y_node.add_child(camera_rotation_x_node)
	camera_rotation_x_node.set_owner(main_node)
	
	var camera_rotation_z_node = Node3D.new()
	camera_rotation_z_node.set_name("%s_rotz" % camera_id)
	camera_rotation_x_node.add_child(camera_rotation_z_node)
	camera_rotation_z_node.set_owner(main_node)
	
	# Camera
	var camera3d := Camera3D.new()
	camera3d.set_name("%s_cam" % camera_id)
	camera_rotation_z_node.add_child(camera3d)
	camera3d.set_owner(main_node)
	
	camera_position_node.position = array_to_vector3(camera.camera.position)
	#var camera_quaternion := array_to_quaternion(camera.camera.quaternion)
	#camera_position_node.quaternion = camera_quaternion
	#camera_position_node.rotation_edit_mode = Node3D.ROTATION_EDIT_MODE_QUATERNION
	camera_rotation_x_node.rotation.x = array_to_vector3(camera.camera.rotation).x
	camera_rotation_y_node.rotation.y = array_to_vector3(camera.camera.rotation).y
	camera_rotation_z_node.rotation.z = array_to_vector3(camera.camera.rotation).z
	camera_rotation_z_node.rotation.x = deg_to_rad(-90)
	camera3d.fov = rad_to_deg(camera.camera.fov)
	
	if camera.camera.animation != null:
		var animation_player := AnimationPlayer.new()
		camera_node.add_child(animation_player)
		animation_player.set_owner(main_node)
		var animation := Animation.new()
		animation.length = 30.0
		var reset_animation := Animation.new()
		# NOTE: https://github.com/godotengine/godot/pull/93818
		var animation_library:= AnimationLibrary.new()
		#var animation_library: AnimationLibrary
		#animation_library = animation_player.get_animation_library("")
		#if animation_library == null:
		#	animation_library = AnimationLibrary.new()
		#	animation_player.add_animation_library("", animation_library)
		#
		for t in camera.camera.animation:
			var track_path:String = camera_id+"_crane/"+camera_id+"_pos:"+t.path
			if t.path.begins_with("rotation:y"):
				track_path = camera_id+"_crane/"+camera_id+"_pos/"+camera_id+"_roty:"+t.path
			elif t.path.begins_with("rotation:x"):
				track_path = camera_id+"_crane/"+camera_id+"_pos/"+camera_id+"_roty/"+camera_id+"_rotx:"+t.path
			elif t.path.begins_with("rotation:z"):
				track_path = camera_id+"_crane/"+camera_id+"_pos/"+camera_id+"_roty/"+camera_id+"_rotx/"+camera_id+"_rotz:"+t.path
			var reset_track_idx = reset_animation.add_track(Animation.TYPE_BEZIER)
			reset_animation.track_set_path(reset_track_idx, track_path)
			var value := 0
			if t.path == "quaternion:w":
				value = 1
			reset_animation.bezier_track_insert_key(reset_track_idx, 0, value, Vector2.ZERO, Vector2.ZERO)
			var track_idx = animation.add_track(Animation.TYPE_BEZIER)
			animation.track_set_path(track_idx, track_path)
			for k in t.keys:
				animation.bezier_track_insert_key(track_idx, k[0], k[1], Vector2(k[2], k[3]), Vector2(k[4], k[5]))
				#animation.bezier_track_insert_key(track_idx, k[0], k[1], Vector2(0, 0), Vector2(0, 0))
		animation_library.add_animation("%s_cam" % camera_id, animation)
		animation_library.add_animation("RESET", reset_animation)
		#var error := animation_player.add_animation_library("%s_anims" % camera_id, animation_library)
		var error := animation_player.add_animation_library("", animation_library)
		#main_node.camera_anim[camera3d] = animation_player
	
	var pathpoints_data:Array[Array]
	var pathpoints=camera.pathpoints
	for p_id in range(0, pathpoints.size(), 2):
		pathpoints_data.append([
			Vector2(pathpoints[p_id][0], pathpoints[p_id][2]),
			Vector2(pathpoints[p_id+1][0], pathpoints[p_id+1][2]),
		])
	
	camera3d.set_meta("transition_type", camera.camera.transition_type)
	camera3d.set_meta("transition_speed", camera.camera.transition_speed)
	camera3d.set_meta("speed", camera.camera.speed)
	camera3d.set_meta("point_of_interest", camera.camera.point_of_interest)
	camera3d.set_meta("player_offset", camera.camera.player_offset)
	camera3d.set_meta("weight", camera.camera.weight)
	camera3d.set_meta("lock_rotation_x", camera.camera.lock_rotation_x)
	camera3d.set_meta("lock_rotation_y", camera.camera.lock_rotation_y)
	camera3d.set_meta("lock_rotation_z", camera.camera.lock_rotation_z)
	camera3d.set_meta("pathpoints", pathpoints_data)
	camera3d.set_meta("vertical_compensation", camera.camera.vertical_compensation)
	camera3d.set_meta("horizontal_compensation", camera.camera.horizontal_compensation)
	camera3d.set_meta("fog_density", camera.camera.fog_density)
	
	# Curve
	var path3d
	if camera.curve != null:
		path3d = Path3D.new()
		var curve3d := Curve3D.new()
		path3d.curve = curve3d
		camera_node.add_child(path3d)
		path3d.set_owner(main_node)
		
		path3d.position = array_to_vector3(camera.curve.position)
		path3d.rotation = array_to_vector3(camera.curve.rotation)
		
		for p in camera.curve.points:
			var p_position := Vector3(p[0][0], p[0][1], p[0][2])
			var p_in := Vector3(p[1][0], p[1][1], p[1][2]) - p_position
			var p_out := Vector3(p[2][0], p[2][1], p[2][2]) - p_position
			curve3d.add_point(p_position, p_in, p_out)
		
	if camera.default:
		#print("Default")
		main_node.initial_camera = camera3d
		main_node.initial_camera_path = path3d
	
	# Sensor
	for sensor in camera.sensor:
		var sensor_area := CameraSensor.new()
		var sensor_collision := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		camera_node.add_child(sensor_area)
		sensor_area.set_owner(main_node)
		sensor_area.add_child(sensor_collision)
		sensor_collision.set_owner(main_node)
		sensor_collision.shape = box_shape
		
		#Do not scale!
		box_shape.size = array_to_vector3(sensor.scale)*2
		sensor_area.position = array_to_vector3(sensor.position)
		sensor_area.quaternion = array_to_quaternion(sensor.quaternion)

		sensor_area.world_node = main_node
		sensor_area.camera = camera3d
		sensor_area.path = path3d
		sensor_area.set_meta("is_camera_sensor", true)
	
	# Sensorpath
	for sensorpath in camera.sensorpath:
		var sensorpath_area := CameraSensor.new()
		var sensorpath_collision := CollisionPolygon3D.new()
		camera_node.add_child(sensorpath_area)
		sensorpath_area.set_owner(main_node)
		sensorpath_area.add_child(sensorpath_collision)
		sensorpath_collision.set_owner(main_node)
		
		#Do not scale!
		sensorpath_area.position = array_to_vector3(sensorpath.position)
		sensorpath_area.quaternion = array_to_quaternion(sensorpath.quaternion)
		
		#Do not scale!
		sensorpath_collision.rotate_x(deg_to_rad(90))
		
		var points: PackedVector2Array
		for p in sensorpath.points:
			var p_position := Vector2(p[0][0], p[0][2])
			points.append(p_position)
		sensorpath_collision.polygon = points
		sensorpath_collision.depth = 6
		
		sensorpath_area.world_node = main_node
		sensorpath_area.camera = camera3d
		sensorpath_area.path = path3d
		sensorpath_area.set_meta("is_camera_sensor", true)
	
	#print(main_node.camera_change)
	#sensor_area.connect("area_entered", main_node.camera_change.bind(camera3d, curve3d))
	#print(sensor_area.is_connected("area_entered", main_node.camera_change.bind(camera3d)))
	#main_node.initial_camera_sensor = sensor_area

func add_physicsitem(item: Dictionary, item_id: String, main_node: Node3D):
	const PHYSICS_ITEMS = {
		"longbox1": preload("res://scenes/long_box.tscn"),
		"dogboat1": preload("res://scenes/enemy.tscn"),
		"box1": preload("res://scenes/box.tscn"),
		"smallbox1": preload("res://scenes/small_box.tscn"),
		"demobox1": preload("res://scenes/demo_box.tscn"),
		"demobox2": preload("res://scenes/demo_box.tscn"),
		"demobox3": preload("res://scenes/demo_box.tscn"),
		"kayakk1": preload("res://scenes/kayak_k1.tscn"),
		"football": preload("res://scenes/football.tscn"),
		"pistonbig": preload("res://scenes/piston_big.tscn"),
		"heavybox": preload("res://scenes/heavy_box.tscn"),
		"branchbox": preload("res://scenes/branch_box.tscn"),
	}
	if not PHYSICS_ITEMS.has(item.instance): return
	var gltf_instance = PHYSICS_ITEMS[item.instance].instantiate()
	match item.instance:
		"dogboat1":
			gltf_instance.home_position = array_to_vector3(item.position)
		"demobox1":
			#gltf_instance.label_text = "Cáliz"
			#gltf_instance.get_node("PuzzleCup").visible = true
			pass
		"demobox2":
			#gltf_instance.label_text = "Espada"
			#gltf_instance.get_node("PuzzleSword").visible = true
			pass
		"demobox3":
			#gltf_instance.label_text = "Sol"
			#gltf_instance.get_node("PuzzleSun").visible = true
			pass
	#gltf_instance.name = item_id
	main_node.add_child(gltf_instance)
	gltf_instance.position = array_to_vector3(item.position)
	# NOTE: Physics nodes should not be scaled
	#gltf_instance.scale = array_to_vector3(item.scale)
	gltf_instance.quaternion = array_to_quaternion(item.quaternion)
	gltf_instance.set_owner(main_node)
	#_recursively_set_owner(gltf_instance, main_node)

func add_item(item: Dictionary, item_id: String, main_node: Node3D):
	var gltf_scene: PackedScene
	if item.instance in packed_scenes:
		gltf_scene = packed_scenes[item.instance] as PackedScene
	else:
		gltf_scene = scene_from_gltf(item, item_id) as PackedScene
		packed_scenes[item.instance] = gltf_scene
	var gltf_instance = gltf_scene.instantiate()
	gltf_instance.name = item_id
	main_node.add_child(gltf_instance)
	gltf_instance.position = array_to_vector3(item.position)
	gltf_instance.scale = array_to_vector3(item.scale)
	gltf_instance.quaternion = array_to_quaternion(item.quaternion)
	gltf_instance.set_owner(main_node)
	_recursively_set_owner(gltf_instance, main_node)

func scene_from_gltf(item:Dictionary, item_id:String) -> PackedScene:
	var gltf_loader := GLTFDocument.new()
	var convert_mesh_extension := GLTFDocumentExtensionConvertImporterMesh.new()
	var vrm_extension: GLTFDocumentExtension = gltf_document_extension_class.new()
	# Order?
	gltf_loader.register_gltf_document_extension(convert_mesh_extension, true)
	gltf_loader.register_gltf_document_extension(vrm_extension, false)
	var gltf_state := GLTFState.new()
	var gltf_path:String = "res://models/world/%s.glb" % item.instance
	gltf_state.base_path = "res://models/world/"
	var gltf_error = gltf_loader.append_from_file(gltf_path, gltf_state)
	#print(gltf_state.json)
	var gltf_instance: Node3D
	if gltf_error == OK:
		#print("OK")
		gltf_instance = gltf_loader.generate_scene(gltf_state) as Node3D
	gltf_loader.unregister_gltf_document_extension(convert_mesh_extension)
	gltf_loader.unregister_gltf_document_extension(vrm_extension)
	_recursively_set_owner(gltf_instance, gltf_instance)
	_add_colliders(gltf_instance)
	_configure_lod(gltf_instance, gltf_state.json)
	# TODO remove unneded LODs (levels of details) from Mesh
	var scene = PackedScene.new()
	var result = scene.pack(gltf_instance)
	if result == OK:
		return scene
	else:
		return scene


func array_to_vector3(array: Array) -> Vector3:
	return Vector3(array[0], array[1], array[2])

func array_to_quaternion(array: Array) -> Quaternion:
	return Quaternion(array[0], array[1], array[2], array[3])

func _configure_lod(gltf_instance:Node, json:Dictionary) -> void:
	for node in gltf_instance.get_children():
		var extras:={}
		for gltf_node in json.nodes:
			if gltf_node.name == node.name:
				extras = gltf_node.extras
		#print(extras)
	
		if not extras.has("dkt_properties"): continue
		var dkt_data: Dictionary = extras.dkt_properties
		var mesh_instance: = node as MeshInstance3D
		if dkt_data.has("range_begin"):
			mesh_instance.visibility_range_begin= dkt_data.range_begin
			mesh_instance.visibility_range_begin_margin = 1.0
			mesh_instance.set_meta("visibility_range_begin", dkt_data.range_begin)
			# BUG objects not visible due to range still cast unwanted shadows
			if dkt_data.range_begin > 0:
				mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if dkt_data.has("range_end"):
			mesh_instance.visibility_range_end= dkt_data.range_end
			mesh_instance.visibility_range_end_margin = 1.0
			mesh_instance.set_meta("visibility_range_end", dkt_data.range_end)
		#if not dkt_data.is_last_lod:
			#mesh_instance.visibility_range_begin_margin = 1.0
			#mesh_instance.visibility_range_end = 10.0 * lod_distances[dkt_data.lod+1]
			#mesh_instance.visibility_range_end_margin = 1.0
	

func _add_colliders(gltf_instance:Node3D) -> void:
	for c in gltf_instance.get_children():
		if c.name.ends_with("-colonly"):
			c.visible = false
		if c.name.ends_with("_occluder"):
			c.visible = false
			var occluder := OccluderInstance3D.new()
			var array_occluder := ArrayOccluder3D.new()
			occluder.occluder = array_occluder
			var mesh = c.mesh as ArrayMesh
			var arrays := mesh.surface_get_arrays(0)
			#print(arrays.size())
			array_occluder.set_arrays(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_INDEX])
			gltf_instance.add_child(occluder)
			occluder.set_owner(gltf_instance)
			occluder.position = c.position
			occluder.rotation = c.rotation
			occluder.scale = c.scale
		if c.name.ends_with("_boxcollider"):
			c.visible = false
			var static_body := StaticBody3D.new()
			gltf_instance.add_child(static_body)
			static_body.set_owner(gltf_instance)
			var collider := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			collider.shape = box_shape
			box_shape.size = c.scale * 2
			static_body.add_child(collider)
			collider.set_owner(gltf_instance)
			collider.position = c.position
			collider.rotation = c.rotation
			#collider.scale = item.scale
			
			static_body.set_collision_layer_value(1, false)
			static_body.set_collision_layer_value(5, true)
			static_body.set_collision_mask_value(1, true) # Walls
			static_body.set_collision_mask_value(2, true) # Character
			static_body.set_collision_mask_value(3, true) # Grabbable
			static_body.set_collision_mask_value(4, true) # Enemies
			static_body.set_collision_mask_value(4, true) # Transparent

func _recursively_set_owner(root: Node, owner: Node) -> void:
	for child in root.get_children():
		child.set_owner(owner)
		#prints(child.name, child.owner.name)
		_recursively_set_owner(child, owner)

func _get_priority() -> float:
	return 1.0

func _get_import_order() -> int:
	return 1
