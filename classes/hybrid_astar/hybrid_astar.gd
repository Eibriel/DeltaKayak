class_name HybridAStar
# https://github.com/zhm-real/MotionPlanning/blob/master/HybridAstarPlanner/hybrid_astar.py

var rs = ReedsShepp.new()
var astar = AStar.new()
var config = C.new()

class C:  # Parameter config
	#var _PI := PI

	var XY_RESO := 1.0  # [m]
	var YAW_RESO := deg_to_rad(15.0)  # [rad]
	var MOVE_STEP := 0.2  # [m] path interporate resolution
	var N_STEER := 20.0  # steer command number
	var COLLISION_CHECK_STEP := 5  # skip number for collision check
	# var EXTEND_BOUND := 1  # collision check range extended
#
	var GEAR_COST := 1000.0 #100.0  # switch back penalty cost
	var BACKWARD_COST := 5000.0  # backward penalty cost
	var STEER_CHANGE_COST := 5.0  # steer angle change penalty cost
	var STEER_ANGLE_COST := 1.0  # steer angle penalty cost
	var H_COST := 15.0  # Heuristic cost penalty cost
#
	var RF := 4.5  # [m] distance from rear to vehicle front end of vehicle
	var RB := 1.0  # [m] distance from rear to vehicle back end of vehicle
	var W := 3.0  # [m] width of vehicle
	var WD := 0.7 * W  # [m] distance between left-right wheels
	var WB := 3.5  # [m] Wheel base
	var TR := 0.5  # [m] Tyre radius
	var TW := 1.0  # [m] Tyre width
	var MAX_STEER: = 0.8  # [rad] maximum steering angle

class HybridAStarNode:
	var xind:int
	var yind:int
	var yawind:int
	var direction:int
	var x:Array[float]
	var y:Array[float]
	var yaw:Array[float]
	var directions:Array
	var steer:float
	var cost:float
	var pind:int
				
	func _init(xind:int, yind:int, yawind:int, direction:int, x:Array[float], y:Array[float],
				 yaw:Array[float], directions:Array, steer:float, cost:float, pind:int):
		# HybridAStarNode.new(sxr, syr, syawr, 1, [sx], [sy], [syaw], [1], 0.0, 0.0, -1)
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
	var x
	var y
	var yaw
	var direction
	var cost
	func _init(x, y, yaw, direction, cost):
		self.x = x
		self.y = y
		self.yaw = yaw
		self.direction = direction
		self.cost = cost

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
		prints("item", item)
		return item[0]  # pop out element with smallest priority

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

const put_1 = [
	8004,
	8379,
	8754,
	9129,
	7629,
	7254,
	7255,
	6880,
	7931,
	7556,
	7181,
	7180,
	6805,
	8306,
	8681,
	9056,
	8053,
	8428,
	8803,
	9178
]
var put_1_count := 0

const put_2 = [
	8004,
	7931,
	8053
]
var put_2_count := 0

const EXPECTED_HMAP = [
	[INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF],
	[INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF],
	[INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF],
	[INF, INF, INF, 31.899494936611667, 30.899494936611667, 29.899494936611667, 28.899494936611667, 27.899494936611667, 26.899494936611667, 25.899494936611667, 25.48528137423857, 25.899494936611667, 26.313708498984763, INF, INF],
	[INF, INF, INF, 32.31370849898476, 31.313708498984763, 30.313708498984763, INF, INF, INF, INF, 24.48528137423857, 24.899494936611667, 25.313708498984763, INF, INF],
	[INF, INF, INF, 32.72792206135786, 31.72792206135786, 31.313708498984763, INF, INF, INF, INF, 23.48528137423857, 23.899494936611667, 24.313708498984763, INF, INF],
	[INF, INF, INF, 33.14213562373095, 32.72792206135786, 32.31370849898477, INF, INF, INF, INF, 22.48528137423857, 22.899494936611667, 23.313708498984763, INF, INF],
	[INF, INF, INF, 34.14213562373095, 33.72792206135786, 33.31370849898477, INF, INF, INF, INF, 21.48528137423857, 21.899494936611667, 22.313708498984763, INF, INF],
	[INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, 20.48528137423857, 20.899494936611667, 21.313708498984763, INF, INF],
	[INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, 19.48528137423857, 19.899494936611667, 20.313708498984763, INF, INF],
	[INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, 18.48528137423857, 18.899494936611667, 19.899494936611667, INF, INF],
	[INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, 17.48528137423857, 18.48528137423857, 19.48528137423857, INF, INF],
	[INF, INF, INF, INF, INF, INF, INF, INF, 15.071067811865477, 16.071067811865476, 17.071067811865476, 18.071067811865476, 19.071067811865476, INF, INF],
	[INF, INF, INF, 13.071067811865477, 12.656854249492381, 12.242640687119286, 12.656854249492381, 13.656854249492381, INF, INF, INF, INF, INF, INF, INF],
	[INF, INF, INF, 12.071067811865477, 11.656854249492381, 11.242640687119286, INF, INF, INF, INF, INF, INF, INF, INF, INF],
	[INF, INF, INF, 11.656854249492381, 10.656854249492381, 10.242640687119286, INF, INF, INF, INF, INF, INF, INF, INF, INF],
	[INF, INF, INF, 11.242640687119286, 10.242640687119286, 9.242640687119286, INF, INF, INF, INF, INF, INF, INF, INF, INF],
	[INF, INF, INF, 10.82842712474619, 9.82842712474619, 8.82842712474619, 7.82842712474619, 6.82842712474619, INF, INF, INF, INF, INF, INF, INF],
	[INF, INF, INF, INF, INF, INF, INF, INF, 5.414213562373095, 4.414213562373095, 4.0, 4.414213562373095, 4.82842712474619, INF, INF],
	[INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, 3.0, 3.414213562373095, 3.82842712474619, INF, INF],
	[INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, 2.0, 2.414213562373095, 2.8284271247461903, INF, INF],
	[INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, 1.0, 1.4142135623730951, 2.414213562373095, INF, INF],
	[INF, INF, INF, INF, INF, INF, INF, INF, 2.0, 1.0, 0.0, 1.0, 2.0, INF, INF],
	[INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF],
	[INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF, INF],
]

func python_round(num:float):
	# Python rounds 0.5 toward floor
	# Godot towards ceiling
	return round(num-0.001)

func hybrid_astar_planning(sx, sy, syaw, gx, gy, gyaw, ox, oy, xyreso, yawreso):
	var sxr:float = python_round(sx / xyreso)
	var syr:float = python_round(sy / xyreso)
	var gxr:float = python_round(gx / xyreso)
	var gyr:float = python_round(gy / xyreso)
	var syawr:float = python_round(rs.pi_2_pi(syaw) / yawreso)
	var gyawr:float = python_round(rs.pi_2_pi(gyaw) / yawreso)

	var nstart := HybridAStarNode.new(sxr, syr, syawr, 1, [sx], [sy], [syaw], [1], 0.0, 0.0, -1)
	var ngoal := HybridAStarNode.new(gxr, gyr, gyawr, 1, [gx], [gy], [gyaw], [1], 0.0, 0.0, -1)

	#kdtree = kd.KDTree([[x, y] for x, y in zip(ox, oy)])
	var kdt:Array[Vector2]
	for i in ox.size():
		kdt.append(Vector2(ox[i], oy[i]))
	var kdtree := KDTree.new(kdt)
	
	var P := calc_parameters(ox, oy, xyreso, yawreso, kdtree)
	
	var hmap = astar.calc_holonomic_heuristic_with_obstacle(ngoal, Array(P.ox, TYPE_FLOAT, "", null), Array(P.oy, TYPE_FLOAT, "", null), P.xyreso, 1.0)
	#print("HMAP")
	#for k in hmap.size():
		#for kk in hmap[k].size():
			#print(hmap[k][kk])
			#print(EXPECTED_HMAP[k][kk])
			#assert(is_equal_approx(hmap[k][kk], EXPECTED_HMAP[k][kk]))
			
	var res_calc_motion_set = calc_motion_set()
	var steer_set = res_calc_motion_set[0]
	var direc_set = res_calc_motion_set[1]
	var open_set := {calc_index(nstart, P): nstart}
	var closed_set := {}
	
	var qp := HybridAStarQueuePrior.new()
	qp.put_item(calc_index(nstart, P), calc_hybrid_cost(nstart, hmap, P))
	
	var fnode
	while true:
		if open_set.is_empty():
			return null
		
		var ind = qp.get_item()
		#prints("set ind", ind)
		assert(typeof(ind) == TYPE_INT)

		if not open_set.has(ind):
			push_error("%d not in open_set" % ind)
		var n_curr = open_set[ind]
		#if ind == 7980:
		#	breakpoint
		#if ind == 6805:
		#	breakpoint
		closed_set[ind] = n_curr
		open_set.erase(ind)

		# Is there a direct path to goal?
		var res_update := update_node_with_analystic_expantion(n_curr, ngoal, P)
		var update = res_update[0]
		var fpath = res_update[1]
		if update:
			fnode = fpath
			break
		
		for i in range(len(steer_set)):
			#prints(ind, i)
			var node := calc_next_node(n_curr, ind, steer_set[i], direc_set[i], P, i)
			
			if not node:
				continue
				
			var node_ind := calc_index(node, P)

			if node_ind in closed_set:
				continue

			if not open_set.has(node_ind):
				open_set[node_ind] = node
				qp.put_item(node_ind, calc_hybrid_cost(node, hmap, P))
				#prints("Put1:", node_ind)
				#assert(put_1[put_1_count] == node_ind, "Put1: is %d should be %d" % [node_ind, put_1[put_1_count]])
				#put_1_count += 1
				# 9056
			else:
				if open_set[node_ind].cost > node.cost:
					open_set[node_ind] = node
					qp.put_item(node_ind, calc_hybrid_cost(node, hmap, P))
					#prints("Put2:", node_ind)
					#assert(put_2[put_2_count] == node_ind, "Put2: is %d should be %d" % [node_ind, put_2[put_2_count]])
					#put_2_count += 1

	return extract_path(closed_set, fnode, nstart)

func extract_path(closed, ngoal:HybridAStarNode, nstart:HybridAStarNode) -> HybridAStarPath:
	var rx = []
	var ry = []
	var ryaw = []
	var direc = []
	var cost = 0.0
	var node := ngoal

	while true:
		#rx += node.x[::-1]
		var inv_node_x := node.x
		inv_node_x.reverse()
		rx.append_array(inv_node_x)
		#ry += node.y[::-1]
		var inv_node_y := node.y
		inv_node_y.reverse()
		ry.append_array(inv_node_y)
		#ryaw += node.yaw[::-1]
		var inv_node_yaw := node.yaw
		inv_node_yaw.reverse()
		ryaw.append_array(inv_node_yaw)
		#direc += node.directions[::-1]
		var inv_direc := node.directions
		inv_direc.reverse()
		direc.append_array(inv_direc)
		cost += node.cost

		if is_same_grid(node, nstart):
			break

		node = closed[node.pind]

	#rx = rx[::-1]
	#ry = ry[::-1]
	#ryaw = ryaw[::-1]
	#direc = direc[::-1]
	rx.reverse()
	ry.reverse()
	ryaw.reverse()
	direc.reverse()

	direc[0] = direc[1]
	return HybridAStarPath.new(rx, ry, ryaw, direc, cost)


func calc_next_node(n_curr:HybridAStarNode, c_id:int, u:float, d:int, P:HybridAStarPara, iii:int) -> HybridAStarNode:
	#if c_id == 9056:
		#breakpoint
	var step:float = config.XY_RESO * 2

	var nlist:int = ceil(step / config.MOVE_STEP)
	var xlist:Array[float] = [n_curr.x[-1] + d * config.MOVE_STEP * cos(n_curr.yaw[-1])]
	var ylist:Array[float] = [n_curr.y[-1] + d * config.MOVE_STEP * sin(n_curr.yaw[-1])]
	var yawlist:Array[float] = [rs.pi_2_pi(n_curr.yaw[-1] + d * config.MOVE_STEP / config.WB * tan(u))]

	for i in range(nlist - 1):
		xlist.append(xlist[i] + d * config.MOVE_STEP * cos(yawlist[i]))
		ylist.append(ylist[i] + d * config.MOVE_STEP * sin(yawlist[i]))
		yawlist.append(rs.pi_2_pi(yawlist[i] + d * config.MOVE_STEP / config.WB * tan(u)))

	var xind:int = python_round(xlist[-1] / P.xyreso)
	var yind:int = python_round(ylist[-1] / P.xyreso)
	var yawind:int = python_round(yawlist[-1] / P.yawreso)

	if not is_index_ok(xind, yind, xlist, ylist, yawlist, P):
		return null

	var cost := 0.0
	var direction:int
	if d > 0:
		direction = 1
		cost += abs(step)
	else:
		direction = -1
		cost += abs(step) * config.BACKWARD_COST

	if direction != n_curr.direction:  # switch back penalty
		cost += config.GEAR_COST

	cost += config.STEER_ANGLE_COST * abs(u)  # steer angle penalyty
	cost += config.STEER_CHANGE_COST * abs(n_curr.steer - u)  # steer change penalty
	cost = n_curr.cost + cost

	#directions = [direction for _ in range(len(xlist))]
	var directions:Array[int]=[]
	directions.resize(len(xlist))
	directions.fill(direction)

	#if c_id == 7980 and iii == 77:
		#print("DATA")
		#print(yawind)
		#print(yind)
		#print(xind)
		#print(P.minyaw)
		#print(P.xw)
		#print(P.yw)
		#print(P.miny)
		#print(P.minx)
		#breakpoint

	return HybridAStarNode.new(xind, yind, yawind, direction, xlist, ylist,
				yawlist, directions, u, cost, c_id)

#DATA
#11
#2
#6
#-13
#25
#15
#0
#0

#DATA
#6
#2
#11
#-1
#[10.2, 10.42481671667277, 10.673244304357157, 10.94395027615826, 11.235482650985098, 11.546277741517288, 11.87466854132856, 12.218893666181227, 12.577106801533347, 12.947386605585137]
#[6.653589838486225, 6.322746304614887, 6.0092439383123075, 5.7147642669745045, 5.440886786286836, 5.189080488309428, 4.960695982269037, 4.756958250318948, 4.578960077122693, 4.4276561885032395]
#[2.1676486511601847, 2.240902199927174, 2.3141557486941635, 2.387409297461153, 2.4606628462281424, 2.5339163949951318, 2.607169943762121, 2.6804234925291106, 2.7536770412961, 2.8269305900630894]
#[-1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
#-0.5700000000000001
#123.41999999999999


func is_index_ok(xind, yind, xlist, ylist, yawlist, P:HybridAStarPara) -> bool:
	if xind <= P.minx or \
			xind >= P.maxx or \
			yind <= P.miny or \
			yind >= P.maxy:
		return false

	var ind = range(0, len(xlist), config.COLLISION_CHECK_STEP)

	#nodex = [xlist[k] for k in ind]
	var nodex := []
	for k in ind:
		nodex.append(xlist[k])
	#nodey = [ylist[k] for k in ind]
	var nodey := []
	for k in ind:
		nodey.append(ylist[k])
	#nodeyaw = [yawlist[k] for k in ind]
	var nodeyaw := []
	for k in ind:
		nodeyaw.append(yawlist[k])

	if is_collision(nodex, nodey, nodeyaw, P):
		return false

	return true


func update_node_with_analystic_expantion(n_curr, ngoal, P:HybridAStarPara) -> Array:
	var path = analystic_expantion(n_curr, ngoal, P)  # rs path: n -> ngoal

	if not path:
		return [false, null]

	#fx = path.x[1:-1]
	var fx:Array[float] = path.x.slice(1,-1)
	#fy = path.y[1:-1]
	var fy:Array[float] = path.y.slice(1,-1)
	#fyaw = path.yaw[1:-1]
	var fyaw:Array[float] = path.yaw.slice(1,-1)
	#fd = path.directions[1:-1]
	var fd:Array[int] = path.directions.slice(1,-1)

	var fcost = n_curr.cost + calc_rs_path_cost(path)
	var fpind = calc_index(n_curr, P)
	var fsteer = 0.0

	var fpath := HybridAStarNode.new(n_curr.xind, n_curr.yind, n_curr.yawind, n_curr.direction,
				 fx, fy, fyaw, fd, fsteer, fcost, fpind)

	return [true, fpath]


func analystic_expantion(node, ngoal, P:HybridAStarPara):
	var sx = node.x[-1]
	var sy = node.y[-1]
	var syaw = node.yaw[-1]
	var gx = ngoal.x[-1]
	var gy = ngoal.y[-1]
	var gyaw = ngoal.yaw[-1]

	var maxc:float = tan(config.MAX_STEER) / config.WB
	var paths = rs.calc_all_paths(sx, sy, syaw, gx, gy, gyaw, maxc, config.MOVE_STEP)

	#print(paths.size())
	#for p in paths:
	#	prints("directions:", p.directions)
		
	if not paths:
		return null

	#p.L 146.30047599356556
	#p.L 44.20528454268698
	#p.L 46.81446146156151
	#p.L 46.59190357126159
	#p.L 46.74595374528852
	#p.L 44.67298325087312
	#p.L 46.74595374528852
	#p.L 44.66666618728221
	
	#p.x 368
	#p.x 112
	#p.x 119
	#p.x 119
	#p.x 119
	#p.x 114
	#p.x 119
	#p.x 115

	#pq = QueuePrior()
	var pq := HybridAStarQueuePrior.new()
	for path in paths:
		pq.put_item(path, calc_rs_path_cost(path))

	while not pq.empty():
		var path = pq.get_item()
		var ind = range(0, len(path.x), config.COLLISION_CHECK_STEP)

		#pathx = [path.x[k] for k in ind]
		var pathx := []
		for k in ind:
			pathx.append(path.x[k])
		#pathy = [path.y[k] for k in ind]
		var pathy := []
		for k in ind:
			pathy.append(path.y[k])
		#pathyaw = [path.yaw[k] for k in ind]
		var pathyaw := []
		for k in ind:
			pathyaw.append(path.yaw[k])

		if not is_collision(pathx, pathy, pathyaw, P):
			return path

	return null


func is_collision(x, y, yaw, P:HybridAStarPara) -> bool:
	#for ix, iy, iyaw in zip(x, y, yaw):
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

		if not ids:
			continue

		for i in ids:
			var xo = P.ox[i] - cx
			var yo = P.oy[i] - cy
			var dx = xo * cos(iyaw) + yo * sin(iyaw)
			var dy = -xo * sin(iyaw) + yo * cos(iyaw)

			if abs(dx) < r and abs(dy) < config.W / 2 + d:
				return true

	return false


func calc_rs_path_cost(rspath):
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


func calc_hybrid_cost(node:HybridAStarNode, hmap:Array[Array], P:HybridAStarPara) -> float:
	#assert(hmap[node.xind - P.minx][node.yind - P.miny] != INF)
	var cost:float = node.cost + \
		   config.H_COST * hmap[node.xind - P.minx][node.yind - P.miny]

	return cost


func calc_motion_set() -> Array:
	#var s = np.arange(config.MAX_STEER / config.N_STEER,
	#			  config.MAX_STEER, config.MAX_STEER / config.N_STEER)
	var s:Array[float] = []
	var curr_val:float = config.MAX_STEER / config.N_STEER
	s.append(curr_val)
	while curr_val < config.MAX_STEER:
		curr_val += config.MAX_STEER / config.N_STEER
		s.append(curr_val)
	#s.append(config.MAX_STEER)
	
	# Hardcoded for debug purposes
	#s = [0.03, 0.06, 0.09, 0.12, 0.15, 0.18, 0.21, 0.24, 0.27, 0.30000000000000004, 0.32999999999999996, 0.36, 0.39, 0.42000000000000004, 0.44999999999999996, 0.48, 0.51, 0.54, 0.5700000000000001]

	var steer:Array[float]
	steer.append_array(s)
	steer.append_array([0.0])
	for _s in s:
		steer.append(-_s)
	#print(steer.size())
	#direc = [1.0 for _ in range(len(steer))] + [-1.0 for _ in range(len(steer))]
	var direc:Array[int] = []
	for _n in len(steer):
		direc.append(1)
	for _n in len(steer):
		direc.append(-1)
	steer.append_array(steer)

	return [steer, direc]


func is_same_grid(node1, node2) -> bool:
	if node1.xind != node2.xind or \
			node1.yind != node2.yind or \
			node1.yawind != node2.yawind:
		return false

	return true


func calc_index(node:HybridAStarNode, P:HybridAStarPara) -> int:
	var p_yawind = 11
	var p_yind = 3
	var p_xind = 5
	var p_pminyaw = -13
	var p_Pxw = 25
	var p_Pyw = 15
	var p_Pminy = 0
	var p_Pminx = 0
	
	var test = (p_yawind - p_pminyaw) * p_Pxw * p_Pyw + \
		  (p_yind - p_Pminy) * p_Pxw + \
		  (p_xind - p_Pminx)
		
	var ind = (node.yawind - P.minyaw) * P.xw * P.yw + \
		  (node.yind - P.miny) * P.xw + \
		  (node.xind - P.minx)
	
	#if ind == 9080:
		#breakpoint
	
	return ind


func calc_parameters(ox:Array, oy:Array, xyreso, yawreso, kdtree:KDTree) -> HybridAStarPara:
	var minx = python_round(ox.min() / xyreso)
	var miny = python_round(oy.min() / xyreso)
	var maxx = python_round(ox.max() / xyreso)
	var maxy = python_round(oy.max() / xyreso)

	var xw = maxx - minx
	var yw = maxy - miny

	var minyaw = python_round(-PI / yawreso) - 1
	var maxyaw = python_round(PI / yawreso)
	var yaww = maxyaw - minyaw

	return HybridAStarPara.new(minx, miny, minyaw, maxx, maxy, maxyaw,
				xw, yw, yaww, xyreso, yawreso, ox, oy, kdtree)
