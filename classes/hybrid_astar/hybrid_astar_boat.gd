class_name HybridAStarBoat
# https://github.com/zhm-real/MotionPlanning/blob/master/HybridAstarPlanner/hybrid_astar.py

var rs = ReedsShepp.new()
var astar = AStar.new()
var config = C.new()

var boat_sim = BoatModel.new()
var aprox_boat_model #:= AproxBoatModel.new()

class C:  # Parameter config
	#var _PI := PI

	var XY_RESO := 1.0  # [m]
	var YAW_RESO := deg_to_rad(15.0)  # [rad]
	var MOVE_STEP := 1.0  # [m] path interporate resolution
	var N_STEER := 5.0 #20.0  # steer command number
	var COLLISION_CHECK_STEP := 5  # skip number for collision check
	# var EXTEND_BOUND := 1  # collision check range extended
#
	var GEAR_COST := 10.0 # 10.0  # switch back penalty cost
	var BACKWARD_COST := 5.0  # 5.0 backward penalty cost
	var STEER_CHANGE_COST := 5.0  # steer angle change penalty cost
	var STEER_ANGLE_COST := 1.0  # steer angle penalty cost
	var H_COST := 15.0  # Heuristic cost penalty cost
#
	var RF := 3.0  # 4.5 [m] distance from rear to vehicle front end of vehicle
	var RB := 3.0  # 1.0 [m] distance from rear to vehicle back end of vehicle
	var W := 1.0  # 3.0 [m] width of vehicle
	var WD := 0.7 * W  # [m] distance between left-right wheels
	var WB := 3.5  # [m] Wheel base
	var TR := 0.5  # [m] Tyre radius
	var TW := 1.0  # [m] Tyre width
	var MAX_STEER: = deg_to_rad(60)  # [rad] maximum steering angle

class HybridAStarNode:
	var xind:int # TODO merge into Vector2i
	var yind:int
	var yawind:int
	var direction:int # NOTE direction becomes revs_per_second
	var x:Array[float] # TODO merge into Array[Vector2]
	var y:Array[float]
	var yaw:Array[float]
	var directions:Array[int] # NOTE direction becomes revs_per_second
	var steer:float # NOTE steer becomes rudder_angle
	var cost:float
	var pind:int
	# Added for boat
	var linear_velocity:Array[Vector2]
	var angular_velocity:Array[float]
	var xvelind:int
	var yvelind:int
	var steers:Array[float]
	var ticks:Array[int]
	
				
	func _init(xind:int, yind:int, yawind:int, direction:int, x:Array[float], y:Array[float],
				yaw:Array[float], directions:Array[int], steer:float, cost:float, pind:int,
				linear_velocity:Array[Vector2], angular_velocity:Array[float],
				xvelind:int, yvelind:int, steers:Array[float], ticks:Array[int]):
		self.xind = xind
		self.yind = yind
		self.yawind = yawind
		self.direction = direction
		self.x = x
		self.y = y
		self.yaw = yaw
		self.directions = directions
		self.steer = steer
		self.cost = cost
		self.pind = pind
		#
		self.linear_velocity = linear_velocity
		self.angular_velocity = angular_velocity
		self.xvelind = xvelind
		self.yvelind = yvelind
		self.steers = steers
		self.ticks = ticks
	
	func clone() -> HybridAStarNode :
		return HybridAStarNode.new(
			xind,
			yind,
			yawind,
			direction,
			Array(x, TYPE_FLOAT, "", null),
			Array(y, TYPE_FLOAT, "", null),
			Array(yaw, TYPE_FLOAT, "", null),
			Array(directions, TYPE_INT, "", null),
			steer,
			cost,
			pind,
			Array(linear_velocity, TYPE_VECTOR2, "", null),
			Array(angular_velocity, TYPE_FLOAT, "", null),
			xvelind,
			yvelind,
			Array(steers, TYPE_FLOAT, "", null),
			Array(ticks, TYPE_INT, "", null)
		)

class HybridAStarPara:
	var minx
	var miny
	var minyaw
	var maxx
	var maxy
	var maxyaw
	var xw
	var yw
	var yaww
	var xyreso
	var yawreso
	var ox
	var oy
	var kdtree:KDTree
	func _init(minx, miny, minyaw, maxx, maxy, maxyaw,
				 xw, yw, yaww, xyreso, yawreso, ox, oy, kdtree:KDTree):
		self.minx = minx
		self.miny = miny
		self.minyaw = minyaw
		self.maxx = maxx
		self.maxy = maxy
		self.maxyaw = maxyaw
		self.xw = xw
		self.yw = yw
		self.yaww = yaww
		self.xyreso = xyreso
		self.yawreso = yawreso
		self.ox = ox
		self.oy = oy
		self.kdtree = kdtree

class HybridAStarPath:
	var x:Array[float]
	var y:Array[float]
	var yaw:Array[float]
	var direction:Array[int]
	var cost:float
	var steer:Array[float]
	var ticks:Array[int]
	var linear_velocity: Array[Vector2]
	var angular_velocity: Array[float]
	func _init(x:Array[float],
			y:Array[float],
			yaw:Array[float],
			direction:Array[int],
			cost:float,
			steer:Array[float],
			ticks:Array[int],
			linear_velocity: Array[Vector2],
			angular_velocity: Array[float]):
		self.x = x
		self.y = y
		self.yaw = yaw
		self.direction = direction
		self.cost = cost
		self.steer = steer
		self.ticks = ticks
		self.linear_velocity = linear_velocity
		self.angular_velocity = angular_velocity

class HybridAStarQueuePrior:
	var queue:HeapDict
	
	func _init():
		self.queue = HeapDict.new()

	func empty():
		return self.queue.get_len() == 0  # if Q is empty

	func put_item(item, priority):
		self.queue.set_item(item, priority)

	func get_item():
		var item = queue.popitem()
		#prints("item", item)
		return item[0]  # pop out element with smallest priority
	
	func peek_item():
		return queue.peekitem()[0]

class KDTree:
	var tree:Array[Vector2]
	func _init(tree:Array[Vector2]):
		self.tree = tree
	
	func query_ball_point(point:Vector2, r:float) -> Array[int]:
		var res:Array[int]
		for k in tree.size():
			if tree[k].distance_to(point) < r:
				res.append(k)
		return res

func _init() -> void:
	#boat_sim.load_parameters()
	#boat_sim.tests()
	tests()

func tests()->void:
	var test_node := HybridAStarNode.new(
		0, 0, 0, 1, [0.0, 1.0], [0.0], [0.0], [1], 0.0, 0.0, -1,
		[Vector2.ZERO], [0.0], 0, 0, [0.0], [0])
	var clone_node := test_node.clone()
	clone_node.x.reverse()
	#print(test_node.x)
	assert(test_node.x == [0.0, 1.0])

func python_round(num:float):
	# Python rounds 0.5 toward floor
	# Godot towards ceiling
	return round(num-0.001)

var open_set: Dictionary
var closed_set: Dictionary
var qp := HybridAStarQueuePrior.new()
var fnode
var nstart: HybridAStarNode
var ngoal: HybridAStarNode
var P: HybridAStarPara
var steer_set
var direc_set
var hmap: Array
var state:STATES
enum STATES {
	ITERATING,
	OK,
	ERROR
}
var final_path
var area_size:Vector2i
func hybrid_astar_planning(
		initial_linear_velocity:Vector2,
		initial_angular_velocity:float,
		area_size:Vector2i,
		sx:float,
		sy:float,
		syaw:float,
		gx:float,
		gy:float,
		gyaw:float,
		ox:Array,
		oy:Array,
		xyreso:float,
		yawreso:float):
	self.area_size = area_size
	
	var sxr:float = python_round(sx / xyreso)
	var syr:float = python_round(sy / xyreso)
	var gxr:float = python_round(gx / xyreso)
	var gyr:float = python_round(gy / xyreso)
	var syawr:float = python_round(rs.pi_2_pi(syaw) / yawreso)
	var gyawr:float = python_round(rs.pi_2_pi(gyaw) / yawreso)

	nstart = HybridAStarNode.new(
		sxr, syr, syawr, 1, [sx], [sy], [syaw], [1], 0.0, 0.0, -1,
		[initial_linear_velocity], [initial_angular_velocity], 0, 0, [0.0], [0])
	ngoal = HybridAStarNode.new(
		gxr, gyr, gyawr, 1, [gx], [gy], [gyaw], [1], 0.0, 0.0, -1,
		[Vector2.ZERO], [0.0], 0, 0, [0.0], [0])

	var kdt:Array[Vector2]
	for i in ox.size():
		kdt.append(Vector2(ox[i], oy[i]))
	var kdtree := KDTree.new(kdt)
	
	P = calc_parameters(ox, oy, xyreso, yawreso, kdtree)
	
	hmap = astar.calc_holonomic_heuristic_with_obstacle(ngoal, area_size, Array(P.ox, TYPE_FLOAT, "", null), Array(P.oy, TYPE_FLOAT, "", null), P.xyreso, 1.0)
			
	var res_calc_motion_set = calc_motion_set()

	steer_set = res_calc_motion_set[0]
	direc_set = res_calc_motion_set[1]
	open_set = {calc_index(nstart): nstart}
	closed_set = {}
	
	qp.put_item(calc_index(nstart), calc_hybrid_cost(nstart, hmap))
	state = STATES.ITERATING

var res_update: Array
func iterate() -> void:
	if open_set.is_empty():
		state = STATES.ERROR
		return
	
	var ind = qp.get_item()
	assert(typeof(ind) == TYPE_INT)

	if not open_set.has(ind):
		push_error("%d not in open_set" % ind)
	var n_curr = open_set[ind]
	#assert(Vector2(n_curr.x[0], n_curr.y[0]) == Vector2(15,15))
	closed_set[ind] = n_curr
	open_set.erase(ind)

	# Is there a direct path to goal?
	var use_analystic_expantion:=false
	var stop_on_found:=false
	if use_analystic_expantion:
		res_update = update_node_with_analystic_expantion(n_curr.clone(), ngoal.clone(), true)
		var update = res_update[0]
		var fpath = res_update[1]
		if update:
			fnode = fpath.clone()
			final_path = extract_path(closed_set, fnode, nstart.clone())
			if stop_on_found:
				if final_path:
					state = STATES.OK
				else:
					state = STATES.ERROR
				return
	
	# TODO remove this for loop
	# takes to much time
	for i in range(len(steer_set)):
		var node := calc_next_node(n_curr, ind, steer_set[i], direc_set[i], i)
		
		if not node:
			continue
			
		var node_ind := calc_index(node)

		if node_ind in closed_set:
			continue

		if not open_set.has(node_ind):
			open_set[node_ind] = node
			qp.put_item(node_ind, calc_hybrid_cost(node, hmap))
		else:
			if open_set[node_ind].cost > node.cost:
				open_set[node_ind] = node
				qp.put_item(node_ind, calc_hybrid_cost(node, hmap))

func extract_any_path(closed, ngoal:HybridAStarNode, nstart:HybridAStarNode) -> HybridAStarPath:
	var rx:Array[float] = []
	var ry:Array[float] = []
	var ryaw:Array[float] = []
	var direc:Array[int] = []
	var steer:Array[float] = []
	var ticks:Array[int] = []
	var angular_velocity:Array[float] = []
	var linear_velocity:Array[Vector2] = []
	var cost := 0.0
	var node := ngoal.clone()

	while true:
		# NOTE, use "duplicate()" to copy an Array
		# otherwise will create a reference, and modify
		# the original as well
		
		#if node.pind <= 0: break
		#rx += node.x[::-1]
		var inv_node_x := node.x.duplicate()
		#inv_node_x = inv_node_x.slice(1)
		inv_node_x.reverse()
		rx.append_array(inv_node_x)
		#ry += node.y[::-1]
		var inv_node_y := node.y.duplicate()
		#inv_node_y = inv_node_y.slice(1)
		inv_node_y.reverse()
		ry.append_array(inv_node_y)
		#ryaw += node.yaw[::-1]
		var inv_node_yaw := node.yaw.duplicate()
		#inv_node_yaw = inv_node_yaw.slice(1)
		inv_node_yaw.reverse()
		ryaw.append_array(inv_node_yaw)
		#direc += node.directions[::-1]
		var inv_direc := node.directions.duplicate()
		#inv_direc = inv_direc.slice(1)
		inv_direc.reverse()
		direc.append_array(inv_direc)
		cost += node.cost
		# Added for boat:
		var inv_steer := node.steers.duplicate()
		#inv_steer = inv_steer.slice(1)
		inv_steer.reverse()
		steer.append_array(inv_steer)
		var inv_ticks := node.ticks.duplicate()
		inv_ticks.reverse()
		ticks.append_array(inv_ticks)
		var inv_linear_velocity := node.linear_velocity.duplicate()
		inv_linear_velocity.reverse()
		linear_velocity.append_array(inv_linear_velocity)
		var inv_angular_velocity := node.angular_velocity.duplicate()
		inv_angular_velocity.reverse()
		angular_velocity.append_array(inv_angular_velocity)

		if is_same_grid(node, nstart):
			break
		if node.pind < 0: break
		
		node = closed[node.pind]

	rx.reverse()
	ry.reverse()
	ryaw.reverse()
	direc.reverse()
	steer.reverse()
	ticks.reverse()
	linear_velocity.reverse()
	angular_velocity.reverse()

	if direc.size() > 1:
		direc[0] = direc[1]
	return HybridAStarPath.new(rx, ry, ryaw, direc, cost, steer, ticks, linear_velocity, angular_velocity)

func extract_path(closed, ngoal:HybridAStarNode, nstart:HybridAStarNode) -> HybridAStarPath:
	var rx:Array[float] = []
	var ry:Array[float] = []
	var ryaw:Array[float] = []
	var direc:Array[int] = []
	var steer:Array[float] = []
	var ticks:Array[int] = []
	var angular_velocity:Array[float] = []
	var linear_velocity:Array[Vector2] = []
	var cost := 0.0
	var node := ngoal.clone()

	while true:
		# NOTE, use "duplicate()" to copy an Array
		# otherwise will create a reference, and modify
		# the original as well
		
		#rx += node.x[::-1]
		var inv_node_x := node.x.duplicate()
		inv_node_x.reverse()
		rx.append_array(inv_node_x)
		#ry += node.y[::-1]
		var inv_node_y := node.y.duplicate()
		inv_node_y.reverse()
		ry.append_array(inv_node_y)
		#ryaw += node.yaw[::-1]
		var inv_node_yaw := node.yaw.duplicate()
		inv_node_yaw.reverse()
		ryaw.append_array(inv_node_yaw)
		#direc += node.directions[::-1]
		var inv_direc := node.directions.duplicate()
		inv_direc.reverse()
		direc.append_array(inv_direc)
		cost += node.cost
		# Added for boat:
		var inv_steer := node.steers.duplicate()
		inv_steer.reverse()
		steer.append_array(inv_steer)
		var inv_ticks := node.ticks.duplicate()
		inv_ticks.reverse()
		ticks.append_array(inv_ticks)
		var inv_linear_velocity := node.linear_velocity.duplicate()
		inv_linear_velocity.reverse()
		linear_velocity.append_array(inv_linear_velocity)
		var inv_angular_velocity := node.angular_velocity.duplicate()
		inv_angular_velocity.reverse()
		angular_velocity.append_array(inv_angular_velocity)

		if is_same_grid(node, nstart):
			break

		node = closed[node.pind]

	rx.reverse()
	ry.reverse()
	ryaw.reverse()
	direc.reverse()
	steer.reverse()
	ticks.reverse()
	linear_velocity.reverse()
	angular_velocity.reverse()

	direc[0] = direc[1]
	return HybridAStarPath.new(rx, ry, ryaw, direc, cost, steer, ticks, linear_velocity, angular_velocity)

func get_next_boat_state(linear_velocity:Vector2,
		angular_velocity:float,
		revs_per_second:int,
		rudder_angle:float,
		position: Vector2,
		yaw: float) -> Dictionary:
	
	var simple_boat_model := SimpleBoatModel.new()
	var _delta := 0.1
	simple_boat_model.configure(10.0)
	simple_boat_model.ticks_per_second = int(1.0 / _delta)
	
	var local_data := {
		"force": Vector2(linear_velocity),
		"moment": float(angular_velocity),
		"position": Vector2(position),
		"yaw": yaw,
		"ticks": 0
	}
	# Initialize simple_boat_model
	simple_boat_model.rotation = yaw
	simple_boat_model.position = Vector2(position)
	simple_boat_model.linear_velocity = linear_velocity
	simple_boat_model.angular_velocity = angular_velocity
	
	#var global_pos := 
	#var global_yaw := yaw
	# TODO should look until min distance is reached?
	var r := float(revs_per_second)# * 10.0
	var size_scale := 0.01
	for _n in range(10000):
		var _linear_velocity:Vector2 = local_data.force
		var _angular_velocity:float = local_data.moment
		#print(local_data.moment)
		var new_local_forces
		if false:
			new_local_forces = boat_sim.extended_boat_model(
				_linear_velocity,
				_angular_velocity,
				r,
				rudder_angle)
			#if new_local_forces.moment > 10.0:
			#	breakpoint
			local_data.force += new_local_forces.force * size_scale
			local_data.moment += new_local_forces.moment
		elif false:
			new_local_forces = aprox_boat_model.get_velocity(
				_linear_velocity,
				_angular_velocity,
				aprox_boat_model.get_rudder_angle_key(rudder_angle),
				aprox_boat_model.get_revs_per_second_key(revs_per_second)
			)
			local_data.force += Vector2(new_local_forces.x, new_local_forces.y) * size_scale
			local_data.moment += new_local_forces.z
		else:
			new_local_forces = simple_boat_model.calculate_boat_forces(
				r,#revs_per_second,
				rudder_angle
			)
			#simple_boat_model.linear_force *= size_scale
			simple_boat_model._update_forces(_delta)
			# Save last velocity
			local_data.force = simple_boat_model.linear_velocity
			local_data.moment = simple_boat_model.angular_velocity
			simple_boat_model._update_transform(_delta)
			simple_boat_model._reset_forces()
		if false:
			local_data.yaw -= local_data.moment
			local_data.position += local_data.force.rotated(local_data.yaw)
		else:
			local_data.yaw = simple_boat_model.rotation
			local_data.position = simple_boat_model.position
		local_data.ticks += 1
		var new_x:int = python_round(local_data.position.x / P.xyreso)
		var new_y:int = python_round(local_data.position.y / P.xyreso)
		var old_x:int = python_round(position.x / P.xyreso)
		var old_y:int = python_round(position.y / P.xyreso)
		if new_x != old_x or new_y != old_y: break
		#if position.distance_to(local_data.position) > 1.415: break
	
	return local_data
	

const IS_CAR = false
## Looks like it takes a node and applies steer and direction to te list of x,y positions
func calc_next_node(n_curr:HybridAStarNode, c_id:int, u:float, d:int, iii:int) -> HybridAStarNode:
	var step:float = config.XY_RESO * 2
	var boat_state := {
		"force": Vector2.ZERO,
		"moment": 0.0,
		"position": Vector2.ZERO,
		"yaw": n_curr.yaw[-1],
		"ticks": 0
	}
	if not IS_CAR:
		boat_state = get_next_boat_state(
			n_curr.linear_velocity[-1],
			n_curr.angular_velocity[-1],
			d,
			u,
			Vector2(n_curr.x[-1], n_curr.y[-1]),
			n_curr.yaw[-1]
		)
	var nlist:int = ceil(step / config.MOVE_STEP)
	var xlist:Array[float]
	var ylist:Array[float]
	var yawlist:Array[float]
	
	if IS_CAR:
		xlist = [n_curr.x[-1] + d * config.MOVE_STEP * cos(n_curr.yaw[-1])]
		ylist = [n_curr.y[-1] + d * config.MOVE_STEP * sin(n_curr.yaw[-1])]
		yawlist = [rs.pi_2_pi(n_curr.yaw[-1] + d * config.MOVE_STEP / config.WB * tan(u))]
	else:
		xlist = [boat_state.position.x * config.MOVE_STEP]
		ylist = [boat_state.position.y * config.MOVE_STEP]
		yawlist = [boat_state.yaw * config.MOVE_STEP]
	#
	var linear_velocity_list:Array[Vector2] = [boat_state.force]
	var angular_velocity_list:Array[float] = [boat_state.moment]
	var ticks_list:Array[int] = [boat_state.ticks]
	
	for i in range(nlist - 1):
		if IS_CAR:
			xlist.append(xlist[i] + d * config.MOVE_STEP * cos(yawlist[i]))
			ylist.append(ylist[i] + d * config.MOVE_STEP * sin(yawlist[i]))
			yawlist.append(rs.pi_2_pi(yawlist[i] + d * config.MOVE_STEP / config.WB * tan(u)))
		else:
			boat_state = get_next_boat_state(
				linear_velocity_list[i],
				angular_velocity_list[i],
				d,
				u,
				Vector2(xlist[i], ylist[i]),
				yawlist[i]
			)
			xlist.append(boat_state.position.x * config.MOVE_STEP)
			ylist.append(boat_state.position.y * config.MOVE_STEP)
			yawlist.append(boat_state.yaw * config.MOVE_STEP)
		#
		linear_velocity_list.append(boat_state.force)
		angular_velocity_list.append(boat_state.moment)
		ticks_list.append(boat_state.ticks)
		#prints(n_curr.linear_velocity[i], boat_state.force, linear_velocity_list[-1])
	
	#prints(xlist[-1], ylist[-1], yawlist[-1], linear_velocity_list[-1], angular_velocity_list[-1])

	var xind:int = python_round(xlist[-1] / P.xyreso)
	var yind:int = python_round(ylist[-1] / P.xyreso)
	var yawind:int = python_round(yawlist[-1] / P.yawreso)
	# TODO add velocity?
	var xvelind:int = python_round((linear_velocity_list[-1].x*1) / P.xyreso)
	var yvelind:int = python_round((linear_velocity_list[-1].y*1) / P.xyreso)
	if IS_CAR:
		xvelind = 0
		yvelind = 0

	if not is_index_ok(xind, yind, xlist, ylist, yawlist):
		return null

	var cost := 0.0
	#var direction:int = d
	if d > 0:
		#direction = 1
		cost += abs(step)
	else:
		#direction = -1
		cost += abs(step) * config.BACKWARD_COST
	
	if d != n_curr.direction:
		cost += config.GEAR_COST * 0.0 # penalty for changing gear
	
	if (d>0) != (n_curr.direction>0):  # switch back penalty
		cost += config.GEAR_COST

	cost += config.STEER_ANGLE_COST * abs(u)  # steer angle penalyty
	cost += config.STEER_CHANGE_COST * abs(n_curr.steer - u)  # steer change penalty
	cost = n_curr.cost + cost

	#directions = [direction for _ in range(len(xlist))]
	var directions:Array[int]=[]
	directions.resize(len(xlist))
	directions.fill(d)

	var steers:Array[float]=[]
	steers.resize(len(xlist))
	steers.fill(u)

	#prints("xlist", xlist)
	#prints("yind", yind)
	return HybridAStarNode.new(xind, yind, yawind, d, xlist, ylist,
				yawlist, directions, u, cost, c_id,
				linear_velocity_list, angular_velocity_list, xvelind, yvelind, steers, ticks_list)

func is_index_ok(xind:int, yind:int, xlist:Array[float], ylist:Array[float], yawlist:Array[float]) -> bool:
	if xind <= P.minx or \
			xind >= P.maxx or \
			yind <= P.miny or \
			yind >= P.maxy:
		return false

	var ind = range(0, len(xlist), config.COLLISION_CHECK_STEP)

	#nodex = [xlist[k] for k in ind]
	var nodex:Array[float] = []
	for k in ind:
		nodex.append(xlist[k])
	#nodey = [ylist[k] for k in ind]
	var nodey:Array[float] = []
	for k in ind:
		nodey.append(ylist[k])
	#nodeyaw = [yawlist[k] for k in ind]
	var nodeyaw:Array[float] = []
	for k in ind:
		nodeyaw.append(yawlist[k])

	if is_collision(nodex, nodey, nodeyaw):
		return false

	return true


func update_node_with_analystic_expantion(n_curr:HybridAStarNode, ngoal:HybridAStarNode, ignore_collisions:=false) -> Array:
	var path = analystic_expantion(n_curr, ngoal, ignore_collisions)  # rs path: n -> ngoal

	if not path:
		return [false, null]

	var fx:Array[float] = path.x.slice(1,-1)
	var fy:Array[float] = path.y.slice(1,-1)
	var fyaw:Array[float] = path.yaw.slice(1,-1)
	var fd:Array[int] = path.directions.slice(1,-1)
	var fu:Array[float] = []
	fu.resize(fd.size())
	fu.fill(0.0) # RS dont return steering angle
	var fticks:Array[int] = []
	fticks.resize(fd.size())
	fticks.fill(0) # RS dont return tick count

	var fcost := n_curr.cost + calc_rs_path_cost(path)
	var fpind = calc_index(n_curr)
	var fsteer := 0.0
	
	var linear_velocity:Array[Vector2]
	linear_velocity.resize(len(path.x)-2)
	linear_velocity.fill(Vector2.ZERO)
	var angular_velocity:Array[float]
	angular_velocity.resize(len(path.x)-2)
	angular_velocity.fill(0.0)

	var fpath := HybridAStarNode.new(n_curr.xind, n_curr.yind, n_curr.yawind, n_curr.direction,
				fx, fy, fyaw, fd, fsteer, fcost, fpind,
				linear_velocity, angular_velocity, n_curr.xvelind, n_curr.yvelind, fu, fticks)

	return [true, fpath]

var analystic_expantion_paths
func analystic_expantion(node:HybridAStarNode, ngoal:HybridAStarNode, ignore_collisions:=false):
	var sx = node.x[-1]
	var sy = node.y[-1]
	var syaw = node.yaw[-1]
	var gx = ngoal.x[-1]
	var gy = ngoal.y[-1]
	var gyaw = ngoal.yaw[-1]

	var maxc:float = tan(config.MAX_STEER) / config.WB
	var paths = rs.calc_all_paths(sx, sy, syaw, gx, gy, gyaw, maxc, config.MOVE_STEP)
	
	analystic_expantion_paths = paths
	
	if not paths:
		return null

	#pq = QueuePrior()
	var pq := HybridAStarQueuePrior.new()
	for path in paths:
		pq.put_item(path, calc_rs_path_cost(path))

	if ignore_collisions:
		return pq.get_item() 

	while not pq.empty():
		var path = pq.get_item()
		var ind = range(0, len(path.x), config.COLLISION_CHECK_STEP)

		#pathx = [path.x[k] for k in ind]
		var pathx:Array[float]= []
		for k in ind:
			pathx.append(path.x[k])
		#pathy = [path.y[k] for k in ind]
		var pathy:Array[float]= []
		for k in ind:
			pathy.append(path.y[k])
		#pathyaw = [path.yaw[k] for k in ind]
		var pathyaw:Array[float]= []
		for k in ind:
			pathyaw.append(path.yaw[k])

		if not is_collision(pathx, pathy, pathyaw):
			return path

	return null


func is_collision(x:Array[float], y:Array[float], yaw:Array[float]) -> bool:
	var ids:Array[int]
	for k in len(x):
		var ix = x[k]
		var iy = y[k]
		var iyaw = yaw[k]
		var d = 1
		var dl = (config.RF - config.RB) / 2.0
		var r = (config.RF + config.RB) / 2.0 + d

		var cx = ix + dl * cos(iyaw)
		var cy = iy + dl * sin(iyaw)

		ids = P.kdtree.query_ball_point(Vector2(cx, cy), r)

		if ids.is_empty():
			continue

		for i in ids:
			var xo = P.ox[i] - cx
			var yo = P.oy[i] - cy
			var dx = xo * cos(iyaw) + yo * sin(iyaw)
			var dy = -xo * sin(iyaw) + yo * cos(iyaw)

			if abs(dx) < r and abs(dy) < config.W / 2 + d:
				return true

	return false

## Returns the cells taken by the boat
func get_shape(pos:Vector2, yaw:float) -> Array[Vector2i]:
	var volume_cells:Array[Vector2i] = []
	#var ids:Array[int]
	
	var ix = pos.x
	var iy = pos.y
	var iyaw = yaw
	var d = 1
	var dl = (config.RF - config.RB) / 2.0
	var r = (config.RF + config.RB) / 2.0 + d

	var cx = ix + dl * cos(iyaw)
	var cy = iy + dl * sin(iyaw)
	
	var points:Array[Vector2i]=[]
	for x in range(int(pos.x)-5, int(pos.x)+5):
		for y in range(int(pos.y)-5, int(pos.y)+5):
			points.append(Vector2i(x, y))
	for i in points:
		var xo = i.x - cx
		var yo = i.y - cy
		var dx = xo * cos(iyaw) + yo * sin(iyaw)
		var dy = -xo * sin(iyaw) + yo * cos(iyaw)

		if abs(dx) < r and abs(dy) < config.W / 2 + d:
			volume_cells.append(Vector2i(i.x, i.y))

	return volume_cells


func calc_rs_path_cost(rspath) -> float:
	var cost := 0.0

	for lr in rspath.lengths:
		if lr >= 0:
			cost += 1
		else:
			cost += abs(lr) * config.BACKWARD_COST

	for i in range(len(rspath.lengths) - 1):
		if rspath.lengths[i] * rspath.lengths[i + 1] < 0.0:
			cost += config.GEAR_COST

	for ctype in rspath.ctypes:
		if ctype != "S":
			cost += config.STEER_ANGLE_COST * abs(config.MAX_STEER)

	var nctypes = len(rspath.ctypes)
	#ulist = [0.0 for _ in range(nctypes)]
	var ulist:Array[float] = []
	ulist.resize(nctypes)
	ulist.fill(0.0)

	for i in range(nctypes):
		if rspath.ctypes[i] == "R":
			ulist[i] = -config.MAX_STEER
		elif rspath.ctypes[i] == "WB":
			ulist[i] = config.MAX_STEER

	for i in range(nctypes - 1):
		cost += config.STEER_CHANGE_COST * abs(ulist[i + 1] - ulist[i])

	return cost


func calc_hybrid_cost(node:HybridAStarNode, hmap:Array[Array]) -> float:
	#assert(hmap[node.xind - P.minx][node.yind - P.miny] != INF)
	var cost:float = node.cost + \
		   config.H_COST * hmap[node.xind - P.minx][node.yind - P.miny]

	return cost


func calc_motion_set() -> Array:
	var s:Array[float] = []
	var curr_val:float = config.MAX_STEER / config.N_STEER
	s.append(curr_val)
	while curr_val < config.MAX_STEER:
		curr_val += config.MAX_STEER / config.N_STEER
		s.append(curr_val)

	var steer_s:Array[float]
	steer_s.append_array(s)
	steer_s.append_array([0.0])
	for _s in s:
		steer_s.append(-_s)
	
	var direc:Array[int] = []
	for _n in len(steer_s):
		direc.append(20)
	for _n in len(steer_s):
		direc.append(10)
	for _n in len(steer_s):
		direc.append(5)
	for _n in len(steer_s):
		direc.append(-5)
	for _n in len(steer_s):
		direc.append(-10)
	for _n in len(steer_s):
		direc.append(-20)
	
	var steer:Array[float] = []
	for _n in 6:
		steer.append_array(steer_s)

	return [steer, direc]


func is_same_grid(node1, node2) -> bool:
	if node1.xind != node2.xind or \
			node1.yind != node2.yind or \
			node1.yawind != node2.yawind:
		return false

	return true


func calc_index(node:HybridAStarNode) -> int:
		
	var ind = (node.yawind - P.minyaw) * P.xw * P.yw + \
		  (node.yind - P.miny) * P.xw + \
		  (node.xind - P.minx) + \
		  (node.xvelind + node.yvelind)
	
	return ind


func calc_parameters(ox:Array, oy:Array, xyreso, yawreso, kdtree:KDTree) -> HybridAStarPara:
	var minx:int = python_round(ox.min() / xyreso)
	var miny:int = python_round(oy.min() / xyreso)
	var maxx:int = python_round(ox.max() / xyreso)
	var maxy:int = python_round(oy.max() / xyreso)
	#var minx:int = 0
	#var miny:int = 0
	#var maxx:int = area_size.x-1
	#var maxy:int = area_size.y-1

	var xw:int = maxx - minx
	var yw:int = maxy - miny

	var minyaw:float = python_round(-PI / yawreso) - 1
	var maxyaw:float = python_round(PI / yawreso)
	var yaww:float = maxyaw - minyaw

	return HybridAStarPara.new(minx, miny, minyaw, maxx, maxy, maxyaw,
				xw, yw, yaww, xyreso, yawreso, ox, oy, kdtree)
