# import_plugin.gd
@tool
extends EditorImportPlugin
#extends EditorSceneFormatImporter

const gltf_document_extension_class = preload("./gltf_extension.gd")

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
	
	for sector_id in world_definition:
		var sector:Dictionary = world_definition[sector_id] as Dictionary
		for item_id in sector.items:
			var item:Dictionary = sector.items[item_id] as Dictionary
			add_item(item, item_id, main_node)
		for camera_id in sector.cameras:
			var camera:Dictionary = sector.cameras[camera_id] as Dictionary
			add_camera(camera, camera_id, main_node)
	
	packed_scenes = {}
	var result = scene.pack(main_node)
	if result == OK:
		#return scene
		#prints(save_path, _get_save_extension())
		return ResourceSaver.save(scene, "%s.%s" % [save_path, _get_save_extension()])
	else:
		return result
		#return null

func add_camera(camera:Dictionary, camera_id:String, main_node:Node3D):
	#print(camera)
	var camera_node = Node3D.new()
	camera_node.set_name(camera_id)
	main_node.add_child(camera_node)
	camera_node.set_owner(main_node)
	
	# Camera
	var camera3d := Camera3D.new()
	camera3d.set_name("%s_cam" % camera_id)
	camera_node.add_child(camera3d)
	camera3d.set_owner(main_node)
	
	camera3d.position.x = camera.camera.position[0]
	camera3d.position.y = camera.camera.position[1]
	camera3d.position.z = camera.camera.position[2]
	camera3d.rotation_order = EULER_ORDER_ZXY
	camera3d.rotation.x = camera.camera.rotation[0] - deg_to_rad(90)
	camera3d.rotation.y = camera.camera.rotation[1]
	camera3d.rotation.z = camera.camera.rotation[2]
	camera3d.fov = rad_to_deg(camera.camera.fov)
	
	# Sensor
	var sensor_area := CameraSensor.new()
	var sensor_collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	camera_node.add_child(sensor_area)
	sensor_area.set_owner(main_node)
	sensor_area.add_child(sensor_collision)
	sensor_collision.set_owner(main_node)
	sensor_collision.shape = box_shape
	
	box_shape.size = Vector3(
		camera.sensor.scale[0]*2,
		camera.sensor.scale[1]*2,
		camera.sensor.scale[2]*2
	)
	
	sensor_area.position.x = camera.sensor.position[0]
	sensor_area.position.y = camera.sensor.position[1]
	sensor_area.position.z = camera.sensor.position[2]
	
	# Curve
	var path3d := Path3D.new()
	var curve3d := Curve3D.new()
	path3d.curve = curve3d
	camera_node.add_child(path3d)
	path3d.set_owner(main_node)
	
	path3d.position.x = camera.curve.position[0]
	path3d.position.y = camera.curve.position[1]
	path3d.position.z = camera.curve.position[2]
	path3d.rotation_order = EULER_ORDER_ZXY
	path3d.rotation.x = camera.curve.rotation[0]
	path3d.rotation.y = camera.curve.rotation[1]
	path3d.rotation.z = camera.curve.rotation[2]
	
	for p in camera.curve.points:
		var p_position := Vector3(p[0][0], p[0][1], p[0][2])
		var p_in := Vector3(p[1][0], p[1][1], p[1][2]) - p_position
		var p_out := Vector3(p[2][0], p[2][1], p[2][2]) - p_position
		curve3d.add_point(p_position, p_in, p_out)
		
	if camera.default:
		#print("Default")
		main_node.initial_camera = camera3d
		main_node.initial_camera_path = path3d
	
	
	sensor_area.world_node = main_node
	sensor_area.camera = camera3d
	sensor_area.path = path3d
	#print(main_node.camera_change)
	#sensor_area.connect("area_entered", main_node.camera_change.bind(camera3d, curve3d))
	#print(sensor_area.is_connected("area_entered", main_node.camera_change.bind(camera3d)))
	#main_node.initial_camera_sensor = sensor_area

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
	#print(item)
	gltf_instance.position.x = item.position[0]
	gltf_instance.position.y = item.position[1]
	gltf_instance.position.z = item.position[2]
	gltf_instance.rotation_order = EULER_ORDER_ZXY
	gltf_instance.rotation.x = item.rotation[0]
	gltf_instance.rotation.y = item.rotation[1]
	gltf_instance.rotation.z = item.rotation[2]
	gltf_instance.scale.x = item.scale[0]
	gltf_instance.scale.y = item.scale[1]
	gltf_instance.scale.z = item.scale[2]
	gltf_instance.set_owner(main_node)
	#print("owner")
	#prints(gltf_instance.name, gltf_instance.owner.name)
	_recursively_set_owner(gltf_instance, main_node)
	#gltf_instance.propagate_call("set_owner", [main_node], true)

func scene_from_gltf(item:Dictionary, item_id:String) -> PackedScene:
	var gltf_loader := GLTFDocument.new()
	var convert_mesh_extension := GLTFDocumentExtensionConvertImporterMesh.new()
	var vrm_extension: GLTFDocumentExtension = gltf_document_extension_class.new()
	gltf_loader.register_gltf_document_extension(convert_mesh_extension, true)
	gltf_loader.register_gltf_document_extension(vrm_extension, false)
	var gltf_state := GLTFState.new()
	var gltf_path:String = "res://models/world/%s.glb" % item.instance
	gltf_state.base_path = "res://models/world/"
	var gltf_error = gltf_loader.append_from_file(gltf_path, gltf_state)
	var gltf_instance: Node3D
	if gltf_error == OK:
		print("OK")
		gltf_instance = gltf_loader.generate_scene(gltf_state) as Node3D
	gltf_loader.unregister_gltf_document_extension(vrm_extension)
	gltf_loader.unregister_gltf_document_extension(convert_mesh_extension)
	_recursively_set_owner(gltf_instance, gltf_instance)
	var scene = PackedScene.new()
	var result = scene.pack(gltf_instance)
	if result == OK:
		return scene
	else:
		return scene

func _recursively_set_owner(root: Node, owner: Node) -> void:
	for child in root.get_children():
		child.set_owner(owner)
		prints(child.name, child.owner.name)
		_recursively_set_owner(child, owner)

func _get_priority() -> float:
	return 1.0

func _get_import_order() -> int:
	return 1
