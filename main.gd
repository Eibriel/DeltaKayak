extends Node3D

func _process(delta):
	var camera := get_viewport().get_camera_3d()
	
	$"Eibriel Terrain".camera = camera
	$"Eibriel Terrain".resolution = randi()
