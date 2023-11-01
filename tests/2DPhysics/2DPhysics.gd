extends Node3D

@onready var multimesh := $MultiMeshInstance3D
@onready var projectile = $MultiMeshInstance3D2
@onready var camera = $Camera3D

var positions: Array[Vector2]
var proj_pos: Array[Vector2]
var proj_dir: Array[Vector2]

var cells: Dictionary = {}
var proj_cells: Dictionary = {}

var remove_queue := []
var remove_proj_queue := []

var enemy_count := 0
var projectile_count := 0

func _ready():
	pass


func _physics_process(delta: float):
	move_enemies(delta)
	move_projectile(delta)
	for n in 10:
		spawn_enemy()
	for n in 1:
		add_projectile()
	prints("Projectile",projectile.multimesh.visible_instance_count)
	prints("Enemy",multimesh.multimesh.visible_instance_count)
	#prints("PROJ CELLS", proj_cells.keys().size())
	#remove_enemy(randi_range(0, multimesh.multimesh.visible_instance_count-1))
	#remove_projectile(randi_range(0, projectile.multimesh.visible_instance_count-1))

func _input(event):
	if event.is_action_pressed("ui_accept"):
		add_projectile()

func add_enemy(enemy_position: Vector2):
	if multimesh.multimesh.visible_instance_count == multimesh.multimesh.instance_count:
		return
	multimesh.multimesh.visible_instance_count += 1
	var id:int = multimesh.multimesh.visible_instance_count - 1
	if positions.size() <= id:
		positions.append(Vector2())
	positions[id] = enemy_position
	var cell := Vector2i(positions[id])
	if not cells.has(cell):
		cells[cell] = [id]
	else:
		cells[cell].append(id)


func remove_enemy(id: int):
	if multimesh.multimesh.visible_instance_count == 0:
		return
	var last_item_id = multimesh.multimesh.visible_instance_count - 1
	multimesh.multimesh.visible_instance_count -= 1
	# Clean cell
	var cell := Vector2i(positions[id])
	cells[cell].erase(id)
	if cells[cell].size() == 0:
		cells.erase(cell)
	# Move last enemy to this position
	# If the removed item is not the last one
	if id != last_item_id:
		positions[id] = positions[last_item_id]
		cell = Vector2i(positions[id])
		cells[cell].erase(last_item_id)
		cells[cell].append(id)


func add_projectile():
	if projectile.multimesh.visible_instance_count == projectile.multimesh.instance_count:
		return
	projectile.multimesh.visible_instance_count += 1
	var id:int = projectile.multimesh.visible_instance_count - 1
	
	if proj_pos.size() <= id:
		proj_pos.append(Vector2.ZERO)
	proj_pos[id] = Vector2.ZERO
	if proj_dir.size() <= id:
		proj_dir.append(Vector2.ZERO)
	proj_dir[id] = Vector2.UP.rotated(randf_range(-PI*2, PI*2))
	var cell := Vector2i(proj_pos[id])
	if not proj_cells.has(cell):
		proj_cells[cell] = [id]
	else:
		proj_cells[cell].append(id)


func remove_projectile(id: int):
	print("REMOVE PROJECTILE")
	if projectile.multimesh.visible_instance_count == 0:
		return
	var last_item_id: int = projectile.multimesh.visible_instance_count - 1
	projectile.multimesh.visible_instance_count -= 1
	# Clean cell
	projectile_count = projectile.multimesh.visible_instance_count # Debug
	var cell := Vector2i(proj_pos[id])
	proj_cells[cell].erase(id)
	if proj_cells[cell].size() == 0:
		proj_cells.erase(cell)
	# Move last enemy to this position
	# If the removed item is not the last one
	if id != last_item_id:
		proj_pos[id] = proj_pos[last_item_id]
		proj_dir[id] = proj_dir[last_item_id]
		cell = Vector2i(proj_pos[id])
		proj_cells[cell].erase(last_item_id)
		proj_cells[cell].append(id)


func compute_collision(id: int, cell:Vector2i):
	if proj_cells.has(cell):
		#positions[id] = Vector2(100, 100)
		if not remove_queue.has(id):
			remove_queue.append(id)
		if not remove_proj_queue.has(proj_cells[cell][0]):
			remove_proj_queue.append(proj_cells[cell][0])


func move_projectile(delta: float):
	for id in projectile.multimesh.visible_instance_count:
		var cell_prev := Vector2i(proj_pos[id])
		proj_pos[id] += proj_dir[id] * 2. * delta
		
		var cell := Vector2i(proj_pos[id])
		if cell_prev != cell:
			if proj_cells.has(cell_prev):
				proj_cells[cell_prev].erase(id)
				if proj_cells[cell_prev].size() == 0:
					proj_cells.erase(cell_prev)
		if not proj_cells.has(cell):
			proj_cells[cell] = [id]
		else:
			if not proj_cells[cell].has(id):
				proj_cells[cell].append(id)
		
		var v2d := proj_pos[id]
		var v: Vector3 = Vector3(v2d.x, 0.0, v2d.y)
		var t := Transform3D(Basis(), v)
		
		var angle:float = (-Vector2.ZERO.angle_to_point(proj_dir[id])) + deg_to_rad(90)
		t = t.rotated_local(Vector3.UP, angle)
		t = t.scaled_local(Vector3(0.2, 0.2, 0.2))
		projectile.multimesh.set_instance_transform(id, t)


func move_enemies(delta: float):
	for id in multimesh.multimesh.visible_instance_count:
		var cell_prev := Vector2i(positions[id])
		
		if cells[cell_prev].size()>1:
			var cell_center = Vector2(cell_prev) + Vector2(0.5, 0.5)
			positions[id] += cell_center.direction_to(positions[id]) * 0.8 * delta
		
		positions[id] += positions[id].direction_to(Vector2(0, 0)) * 1.1 * delta
		var v2d := positions[id]
		var cell := Vector2i(positions[id])
		
		if cell_prev != cell:
			#print( cells )
			if cells.has(cell_prev):
				cells[cell_prev].erase(id)
				if cells[cell_prev].size() == 0:
					cells.erase(cell_prev)
		if not cells.has(cell):
			cells[cell] = [id]
		else:
			if not cells[cell].has(id):
				cells[cell].append(id)
		
		var v: Vector3 = Vector3(v2d.x, 0.0, v2d.y)
		var t := Transform3D(Basis(), v)
		#var direction:Vector3 = v.direction_to(Vector3.ZERO)
		var angle:float = (-v2d.angle_to_point(Vector2.ZERO)) + deg_to_rad(-90)
		#print(angle)
		t = t.rotated_local(Vector3.UP, angle)
		multimesh.multimesh.set_instance_transform(id, t)
		compute_collision(id, cell)
	
	var count := 0
	while remove_queue.size() > 0:
		var id = remove_queue.pop_front()
		# Handle if last element will be moved
		var last_item_id = multimesh.multimesh.visible_instance_count - 1
		if id != last_item_id:
			if remove_queue.has(last_item_id):
				var last_array_index := remove_queue.find(last_item_id)
				remove_queue[last_array_index] -= 1
		remove_enemy(id)
		if count > 100:
			break
	remove_queue.resize(0)
	
	count = 0
	while remove_proj_queue.size() > 0:
		var id = remove_proj_queue.pop_front()
		# Handle if last element will be moved
		var last_item_id = projectile.multimesh.visible_instance_count - 1
		if id != last_item_id:
			if remove_proj_queue.has(last_item_id):
				var last_array_index := remove_proj_queue.find(last_item_id)
				remove_proj_queue[last_array_index] -= 1
		remove_projectile(id)
		if count > 100:
			break
	remove_proj_queue.resize(0)

func spawn_enemy():
	if multimesh.multimesh.visible_instance_count == multimesh.multimesh.instance_count-1:
		return
	
	var random_enemy: String
	
	var width := 640
	var height := 480
	var screen_corners = [
		Vector2i(0, 0),
		Vector2i(0, height),
		Vector2i(width, height),
		Vector2i(width, 0),
		Vector2i(0, 0)
	]
	var corner_intersections = []
	for c in screen_corners:
		var rayVector = camera.project_ray_normal(c)
		var rayPoint = camera.project_ray_origin(c)
		var intersection = planeRayIntersection(rayVector,rayPoint, Vector3.ZERO, Vector3.UP)
		corner_intersections.append(intersection)
	
	#var p = randi_range(0, screen_corners.size()-2)
	var p = [0, 0, 0, 1, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3].pick_random()
	var enemy_position: Vector3 = lerp(corner_intersections[p], corner_intersections[p+1], randf())
	add_enemy(Vector2(enemy_position.x, enemy_position.z))


func planeRayIntersection(rayVector: Vector3, rayPoint: Vector3, planePoint: Vector3, planeNormal: Vector3):
	var diff: Vector3 = rayPoint - planePoint
	var prod1 = diff.dot(planeNormal)
	var prod2 = rayVector.dot(planeNormal)
	var prod3 = prod1 / prod2
	var intersection: Vector3 = rayPoint - (rayVector * prod3)
	return intersection
