class_name Agent

var INITIAL_SPEED := 5.0
var CURRENT_SPEED := INITIAL_SPEED

var INITIAL_HEALTH := 5.0
var CURRENT_HEALTH := INITIAL_HEALTH

var INSTANCE_COUNT := 0
var MAX_INSTANCE_COUNT := 1000
#var MULTIMESH : MultiMesh

var SPAWN_AMOUNT := 0
var SPAWN_INTERVAL := 0.3

const FLAG := {
	"FROZEN": 0b1000000,
	"BURNING": 0b0100000,
	"MUDDED": 0b0010000,
	"ELECTROCUTED": 0b0001000,
	"FLAG_5": 0b0000100,
	"FLAG_6": 0b0000010,
	"FLAG_7": 0b0000001
}

var positions: Array[Vector2]
var rotations: Array[float]
var healths: Array[float]
var time: Array[float]
var flags: Array[int]
var scale: Vector3 = Vector3.ONE
var cells: Dictionary = {}
var shift: Vector2
var behavior: Dictionary

var s: Scripting

var last_spawn_time := 0.0
var collides_with: Array[Agent] = []
var remove_queue: Array[int] = []


const square: Array[Vector2i]= [
	Vector2i(0, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, -1),
	Vector2i(-1, 1),
]

func _init():
	pass

"""
func set_multimesh(multimesh: MultiMeshInstance3D):
	MULTIMESH = multimesh.multimesh
	INSTANCE_COUNT = multimesh.multimesh.instance_count
	# HACK: the number don't reset when the node is unloaded
	MULTIMESH.visible_instance_count = 0
	s = Scripting.new()
"""

func spawn(agent_position: Vector2, rotation: float, _scale: Vector3) -> int:
	if MAX_INSTANCE_COUNT == 0:
		return -1
	if INSTANCE_COUNT >= MAX_INSTANCE_COUNT:
		return -1
	INSTANCE_COUNT += 1
	var id:int = INSTANCE_COUNT - 1
	if positions.size() <= id:
		positions.append(Vector2())
	positions[id] = agent_position
	if rotations.size() <= id:
		rotations.append(0.0)
	rotations[id] = rotation
	if healths.size() <= id:
		healths.append(CURRENT_HEALTH)
	if time.size() <= id:
		time.append(0.0)
	scale = _scale
	refresh_agent_cell(id, positions[id])
	return id


func remove(id:int):
	if INSTANCE_COUNT <= 0:
		return
	var last_item_id: int = INSTANCE_COUNT - 1
	INSTANCE_COUNT -= 1
	# Clean cell
	remove_agent_from_cell(id, positions[id])
	# Move last enemy to this position
	# If the removed item is not the last one
	if id != last_item_id:
		positions[id] = positions[last_item_id]
		rotations[id] = rotations[last_item_id]
		healths[id] = healths[last_item_id]
		time[id] = time[last_item_id]
		switch_agent_from_cell(last_item_id, id, positions[id])
	positions.resize(positions.size()-1)
	rotations.resize(rotations.size()-1)
	healths.resize(healths.size()-1)
	time.resize(time.size()-1)


func process(delta: float):
	handle_wave(delta)
	move_agents(delta)
	remove_agents()


func handle_wave(delta: float):
	last_spawn_time += delta
	if last_spawn_time > SPAWN_INTERVAL:
		last_spawn_time = 0.0
		spawn_agent()


func spawn_agent():
	var position := Vector2.ZERO + shift
	var rotation := 0.0
	var scale := Vector3(1, 1, 1)
	spawn(position, rotation, scale)


func move_agents(delta: float):
	pass

"""
	for id in INSTANCE_COUNT:
		var from_position := positions[id]
		if behavior.has("step"):
			var rstate = behavior["step"].call({})
			#s.eval(behavior["step"])
			positions[id] += rstate.velocity
		if false:
			for action in behavior:
				if action.has("follow"):
					var target_position: Vector2= shift + action.follow.target
					positions[id] += positions[id].direction_to(target_position) * CURRENT_SPEED * delta
				if action.has("self_collision"):
					# Collide with other agents
					if agent_count_on_cell(from_position)>1:
						var cell_center = cell_center(from_position)
						positions[id] += cell_center.direction_to(positions[id]) * CURRENT_SPEED * 0.8 * delta
				if action.has("look_at"):
					var v2d := positions[id] - shift
					rotations[id] = (-v2d.angle_to_point(Vector2.ZERO)) + deg_to_rad(-90)
				if action.has("forward"):
					var target_position: Vector2= positions[id] + (Vector2.UP.rotated(-rotations[id] + deg_to_rad(180)))
					positions[id] -= positions[id].direction_to(target_position) * CURRENT_SPEED * delta
"""

func remove_agents():
	var count := 0
	while remove_queue.size() > 0:
		var id = remove_queue.pop_front()
		var last_item_id = INSTANCE_COUNT - 1
		if id != last_item_id:
			if remove_queue.has(last_item_id):
				var last_array_index := remove_queue.find(last_item_id)
				remove_queue[last_array_index] -= 1
		remove(id)
		if count > 100:
			break
	remove_queue.resize(0)

func queue_for_removal(id: int):
	if remove_queue.has(id): return
	remove_queue.append(id)

func damage_player(size:int):
	var agent_colliding := get_id_on_cirle(Vector2.ZERO + shift, size)
	if agent_colliding >= 0:
		Global.player.receive_attack(2.0)
		queue_for_removal(agent_colliding) # TODO kickback

"""
func collide_with_cells(id: int, collide_position: Vector2i, size: int):
	var agent_position := Vector2i(positions[id]-shift)
	if collide_position == agent_position:
		return true
	return false
"""

func collide(id:int, v2d: Vector2) -> bool:
	var cell := Vector2i(v2d)
	for c in collides_with:
		for square_cell in square:
			if c.cells.has(cell+square_cell):
				#print(c.cells[cell+square_cell])
				c.damage(c.cells[cell+square_cell][0], 10.0)
				return true
	return false


func collide2(radius:int) -> int:
	for c in collides_with:
		for cell in cells:
			var collide_id := c.get_id_on_cirle(cell, radius)
			if collide_id >= 0:
				c.damage(collide_id, 10.0)
				return cells[cell][0]
	return -1


func set_shift(_shift: Vector2):
	shift = _shift

func collide_with(c_agent: Agent):
	if not collides_with.has(c_agent):
		collides_with.append(c_agent)

func damage(id:int, amount:float):
	#prints("DAMAGE", id, amount)
	healths[id] -= amount
	if healths[id] < 0:
		on_die(id)
		queue_for_removal(id)

func on_die(id:int):
	pass

# Cell functions

func remove_agent_from_cell(id:int, position: Vector2):
	var cell := Vector2i(position)
	#if !cells.has(cell): return # TODO this check shouldn't be needed
	#if !cells[cell].has(id): return
	cells[cell].erase(id)
	if cells[cell].size() == 0:
		cells.erase(cell)

func switch_agent_from_cell(id_to_remove:int, id_to_add:int, position: Vector2):
	var cell := Vector2i(position)
	#if not cells.has(cell): return # TODO this check shouldn't be needed
	#if cells[cell].has(id_to_remove): # TODO this check shouldn't be needed
	cells[cell].erase(id_to_remove)
	#if not cells[cell].has(id_to_add): # TODO this check shouldn't be needed
	if not cells[cell].has(id_to_add):
		cells[cell].append(id_to_add)

func refresh_agent_cell(id:int, position: Vector2):
	var cell := Vector2i(position)
	if not cells.has(cell):
		cells[cell] = [id]
	else:
		if not cells[cell].has(id):
			cells[cell].append(id)

func move_from_to_cell(id:int, from_position: Vector2, to_position: Vector2):
	var from_cell := Vector2i(from_position)
	var to_cell := Vector2i(to_position)
	if from_cell == to_cell: return
	
	#if cells.has(from_cell):
	cells[from_cell].erase(id)
	if cells[from_cell].size() == 0:
		cells.erase(from_cell)
	if not cells.has(to_cell):
		cells[to_cell] = [id]
	else:
		if not cells[to_cell].has(id):
			cells[to_cell].append(id)

func agent_count_on_cell(position: Vector2) -> int:
	var cell := Vector2i(position)
	return cells[cell].size()

func get_agents_on_cell(position: Vector2) -> Array:
	var cell := Vector2i(position)
	if cells.has(cell):
		return cells[cell]
	else:
		return []

func cell_center(position: Vector2) -> Vector2:
	var cell := Vector2i(position)
	return Vector2(cell) + Vector2(0.5, 0.5)

func get_id_on_area(center:Vector2, size:int) -> int:
	for x in range(-size, size):
		for y in range(-size,size):
			var pp := center + Vector2(x, y)
			var colliding := get_agents_on_cell(pp)
			if colliding.size() > 0:
				return colliding[0]
	return -1

func get_id_on_cirle(center:Vector2, radius:int) -> int:
	for y in range(-radius, radius):
		for x in range(-radius, radius):
			# if(x*x+y*y > radius*radius - radius && x*x+y*y < radius*radius + radius)
			if x*x+y*y <= radius*radius:
				var pp := center + Vector2(x, y)
				var colliding := get_agents_on_cell(pp)
				if colliding.size() > 0:
					return colliding[0]
	return -1

# Misc

func generate_multimesh(mesh_res: Mesh) -> MultiMeshInstance3D:
	var m := MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_res
	mm.instance_count = 1000
	mm.visible_instance_count = 0
	m.multimesh = mm
	#m.position = Vector3(0, 0.458, 0)
	return m
	#(Global.player as Node3D).get_node("Node3D2").add_child(m)
