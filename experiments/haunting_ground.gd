extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var char: CSGCylinder3D = $CSGCylinder3D
@onready var camera_3d: Camera3D = $Camera3D

@onready var marker_pairs = [
	[$Marker3D1, $Marker3D2],
	[$Marker3D3, $Marker3D4],
	[$Marker3D5, $Marker3D6],
]

var time := 0.0
var method := METHOD.CHECKPOINTS

enum METHOD {
	FRAME,
	CHECKPOINTS,
	DISTANCE
}

func _ready() -> void:
	match method:
		METHOD.FRAME:
			animation_player.queue("camera_animation")
		METHOD.CHECKPOINTS:
			animation_player.queue("camera_animation")
		METHOD.DISTANCE:
			animation_player.queue("camera_animation_2")
	animation_player.pause()

func _process(delta: float) -> void:
	if method == METHOD.FRAME:
		var screen_pos := camera_3d.unproject_position(char.global_position)
		var screen_size := get_viewport().get_visible_rect().size
		var screeen_center := screen_size.x*0.5
		time += (screen_pos.x-screeen_center)*0.001*delta
		time = clampf(time, 0.0, 1.0)
	elif method == METHOD.CHECKPOINTS:
		var char_position_2d := tri_to_bi(char.global_position)
		var path_pos:Array[Array]= []
		for p in marker_pairs:
			path_pos.append([
				tri_to_bi(p[0].global_position),
				tri_to_bi(p[1].global_position)
			])
		var ppos := get_path_position(char_position_2d, path_pos)
		print(ppos)
		time = lerpf(time, ppos, 0.1)
	elif method == METHOD.DISTANCE:
		var dist := char.global_position.distance_to(camera_3d.global_position)
		time += (dist - 3)*0.5*delta
		time = clampf(time, 0.0, 1.0)
	animation_player.seek(time, true)

func tri_to_bi(tri:Vector3) -> Vector2:
	return Vector2(tri.x, tri.z)
	

func get_path_position(point_pos: Vector2, path_def: Array[Array]) -> float:
	var c_dist := []
	var polygon_weight := []
	var total_weight := 0.0
	for line_id in range(path_def.size()-1):
		var pos_a:Vector2 = path_def[line_id][0]
		var pos_b:Vector2 = path_def[line_id+1][0]
		var dist := pos_a.distance_to(pos_b)
		polygon_weight.append(dist)
		total_weight += dist
	
	for n in range(polygon_weight.size()):
		polygon_weight[n] /= total_weight
	var added_weight := 0.0
	for line_id in range(path_def.size()-1):
		var pos_a:Vector2 = path_def[line_id][0]
		var pos_b:Vector2 = path_def[line_id][1]
		var pos_c:Vector2 = path_def[line_id+1][0]
		var pos_d:Vector2 = path_def[line_id+1][1]
		var polygon := PackedVector2Array([
			pos_a,
			pos_b,
			pos_d,
			pos_c
		])
		var in_polygon:=Geometry2D.is_point_in_polygon(point_pos, polygon)
		if not in_polygon:
			added_weight += polygon_weight[line_id]
			continue
		var dist_a:float = pos_a.distance_to(point_pos)
		var dist_b:float = pos_b.distance_to(point_pos)
		var dist_c:float = pos_c.distance_to(point_pos)
		var dist_d:float = pos_d.distance_to(point_pos)
		var lerp_a:float = remap(dist_a, 0.0, dist_a+dist_b, 0.0, 1.0)
		var lerp_b:float = remap(dist_c, 0.0, dist_c+dist_d, 0.0, 1.0)
		var proxy_a:Vector2 = lerp(pos_a, pos_b, lerp_a)
		var proxy_b:Vector2 = lerp(pos_c, pos_d, lerp_b)
		var total_dist := proxy_a.distance_to(proxy_b)
		var partial_dist := point_pos.distance_to(proxy_b)
		var val := remap(total_dist-partial_dist, 0.0, total_dist, 0.0, 1.0)
		return (val*polygon_weight[line_id]) + added_weight
	return 0

func _input(event: InputEvent) -> void:
	if event.is_action("ui_left"):
		char.position.x -= 0.1
	if event.is_action("ui_right"):
		char.position.x += 0.1
	if event.is_action("ui_up"):
		char.position.z -= 0.1
	if event.is_action("ui_down"):
		char.position.z += 0.1

