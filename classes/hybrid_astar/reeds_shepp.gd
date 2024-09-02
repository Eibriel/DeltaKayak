class_name ReedsShepp
# https://github.com/zhm-real/MotionPlanning/blob/master/CurvesGenerator/reeds_shepp.py

# parameters initiation
var STEP_SIZE := 0.2
var MAX_LENGTH := 1000.0
#PI = math.pi

# class for PATH element
class PATH:
	var lengths: Array[float]
	var ctypes: Array[String]
	var L: float
	var x: Array[float]
	var y: Array[float]
	var yaw: Array[float]
	var directions: Array[int]
	func _init(lengths:Array[float], ctypes:Array[String], L:float, x:Array[float], y:Array[float], yaw:Array[float], directions:Array[int]):
		self.lengths = lengths              # lengths of each part of path (+: forward, -: backward) [float]
		self.ctypes = ctypes                # type of each part of the path [string]
		self.L = L                          # total path length [float]
		self.x = x                          # final x positions [m]
		self.y = y                          # final y positions [m]
		self.yaw = yaw                      # final yaw angles [rad]
		self.directions = directions        # forward: 1, backward:-1


class FlagTUV:
	var flag: bool
	var t
	var u
	var v
	func _init(flag: bool, t, u, v) -> void:
		self.flag = flag
		self.t = t
		self.u = u
		self.v = v

func calc_optimal_path(sx, sy, syaw, gx, gy, gyaw, maxc, step_size:float=STEP_SIZE):
	var paths = calc_all_paths(sx, sy, syaw, gx, gy, gyaw, maxc, step_size)

	var minL = paths[0].L
	var mini := 0

	for i in range(len(paths)):
		if paths[i].L <= minL:
			minL = paths[i].L
			mini = i

	return paths[mini]

func calc_all_paths(sx, sy, syaw, gx, gy, gyaw, maxc, step_size=STEP_SIZE):
	var q0 := Vector3(sx, sy, syaw)
	var q1 := Vector3(gx, gy, gyaw)

	var paths = generate_path(q0, q1, maxc)

	for path in paths:
		var g_res = generate_local_course(path.L, path.lengths,
								  path.ctypes, maxc, step_size * maxc)
		var x = g_res[0]
		var y = g_res[1]
		var yaw = g_res[2]
		var directions = g_res[3]

		# convert global coordinate
		#path.x = [math.cos(-q0[2]) * ix + math.sin(-q0[2]) * iy + q0[0] for (ix, iy) in zip(x, y)]
		#path.y = [-math.sin(-q0[2]) * ix + math.cos(-q0[2]) * iy + q0[1] for (ix, iy) in zip(x, y)]
		path.x = Array([], TYPE_FLOAT, "", null)
		path.y = Array([], TYPE_FLOAT, "", null)
		for n in len(x):
			var ix = x[n]
			var iy = y[n]
			path.x.append(cos(-q0[2]) * ix + sin(-q0[2]) * iy + q0[0])
			path.y.append(-sin(-q0[2]) * ix + cos(-q0[2]) * iy + q0[1])
		
		#path.yaw = [pi_2_pi(iyaw + q0[2]) for iyaw in yaw]
		path.yaw = Array([], TYPE_FLOAT, "", null)
		for iyaw in yaw:
			path.yaw.append(pi_2_pi(iyaw + q0[2]))
		
		path.directions = directions
		#path.lengths = [l / maxc for l in path.lengths]
		# NOTE: optimize
		var p_lengths:Array[float] = []
		for l in path.lengths:
			p_lengths.append(l / maxc)
		path.lengths = p_lengths
		
		path.L = path.L / maxc

	return paths


func set_path(paths:Array[PATH], lengths:Array[float], ctypes:Array[String]):
	var path := PATH.new([], [], 0.0, [], [], [], [])
	path.ctypes = ctypes
	path.lengths = lengths

	# check same path exist
	for path_e in paths:
		if path_e.ctypes == path.ctypes:
			#if sum([x - y for x, y in zip(path_e.lengths, path.lengths)]) <= 0.01:
			var sum_array:Array[float]= []
			for i in len(path_e.lengths):
				var x = path_e.lengths[i]
				var y = path.lengths[i]
				sum_array.append(x-y)
			if sum_array.reduce(func(accum: float, element: float) -> float: return accum + element) <= 0.01:
				return paths  # not insert path

	#path.L = sum([abs(i) for i in lengths])
	path.L = 0.0
	for i in lengths:
		path.L += abs(i)

	if path.L >= MAX_LENGTH:
		return paths

	assert(path.L >= 0.01)
	paths.append(path)

	return paths

func LSL(x, y, phi) -> FlagTUV:
	var r_res := R(x - sin(phi), y - 1.0 + cos(phi))
	var u := r_res[0]
	var t := r_res[1]

	if t >= 0.0:
		var v = M(phi - t)
		if v >= 0.0:
			return FlagTUV.new(true, t, u, v)

	return FlagTUV.new(false, 0.0, 0.0, 0.0)

func LSR(x, y, phi) -> FlagTUV:
	var r_res := R(x + sin(phi), y - 1.0 - cos(phi))
	var u1 := r_res[0]
	var t1 := r_res[1]
	u1 = u1 ** 2

	if u1 >= 4.0:
		var u := sqrt(u1 - 4.0)
		var theta := atan2(2.0, u)
		var t := M(t1 + theta)
		var v := M(t - phi)

		if t >= 0.0 and v >= 0.0:
			return FlagTUV.new(true, t, u, v)

	return FlagTUV.new(false, 0.0, 0.0, 0.0)

func LRL(x, y, phi) -> FlagTUV:
	var r_res := R(x - sin(phi), y - 1.0 + cos(phi))
	var u1 := r_res[0]
	var t1 := r_res[1]

	if u1 <= 4.0:
		var u := -2.0 * asin(0.25 * u1)
		var t := M(t1 + 0.5 * u + PI)
		var v := M(phi - t + u)

		if t >= 0.0 and u <= 0.0:
			return FlagTUV.new(true, t, u, v)

	return FlagTUV.new(false, 0.0, 0.0, 0.0)

func generate_path(q0, q1, maxc):
	var dx = q1[0] - q0[0]
	var dy = q1[1] - q0[1]
	var dth = q1[2] - q0[2]
	var c := cos(q0[2])
	var s := sin(q0[2])
	var x = (c * dx + s * dy) * maxc
	var y = (-s * dx + c * dy) * maxc

	var paths:Array[PATH]= []
	paths = SCS(x, y, dth, paths)
	paths = CSC(x, y, dth, paths)
	paths = CCC(x, y, dth, paths)
	paths = CCCC(x, y, dth, paths)
	paths = CCSC(x, y, dth, paths)
	paths = CCSCC(x, y, dth, paths)

	return paths

func SCS(x, y, phi, paths:Array[PATH]) -> Array[PATH]:
	var res_flagtuv := SLS(x, y, phi)

	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, res_flagtuv.u, res_flagtuv.v], ["S", "WB", "S"])

	#flag, t, u, v = SLS(x, -y, -phi)
	res_flagtuv = SLS(x, -y, -phi)
	
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, res_flagtuv.u, res_flagtuv.v], ["S", "R", "S"])

	return paths

func SLS(x, y, phi) -> FlagTUV:
	phi = M(phi)

	if y > 0.0 and 0.0 < phi and phi < PI * 0.99:
		var xd = -y / tan(phi) + x
		var t = xd - tan(phi / 2.0)
		var u = phi
		var v = sqrt((x - xd) ** 2 + y ** 2) - tan(phi / 2.0)
		return FlagTUV.new(true, t, u, v)
	elif y < 0.0 and 0.0 < phi and phi < PI * 0.99:
		var xd = -y / tan(phi) + x
		var t = xd - tan(phi / 2.0)
		var u = phi
		var v = -sqrt((x - xd) ** 2 + y ** 2) - tan(phi / 2.0)
		return FlagTUV.new(true, t, u, v)

	return FlagTUV.new(false, 0.0, 0.0, 0.0)

func CSC(x, y, phi, paths):
	var res_flagtuv := LSL(x, y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, res_flagtuv.u, res_flagtuv.v], ["WB", "S", "WB"])

	res_flagtuv = LSL(-x, y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, -res_flagtuv.u, -res_flagtuv.v], ["WB", "S", "WB"])

	res_flagtuv = LSL(x, -y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, res_flagtuv.u, res_flagtuv.v], ["R", "S", "R"])

	res_flagtuv = LSL(-x, -y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, -res_flagtuv.u, -res_flagtuv.v], ["R", "S", "R"])

	res_flagtuv = LSR(x, y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, res_flagtuv.u, res_flagtuv.v], ["WB", "S", "R"])

	res_flagtuv = LSR(-x, y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, -res_flagtuv.u, -res_flagtuv.v], ["WB", "S", "R"])

	res_flagtuv = LSR(x, -y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, res_flagtuv.u, res_flagtuv.v], ["R", "S", "WB"])

	res_flagtuv = LSR(-x, -y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, -res_flagtuv.u, -res_flagtuv.v], ["R", "S", "WB"])

	return paths

func CCC(x, y, phi, paths):
	var res_flagtuv := LRL(x, y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, res_flagtuv.u, res_flagtuv.v], ["WB", "R", "WB"])

	res_flagtuv = LRL(-x, y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, -res_flagtuv.u, -res_flagtuv.v], ["WB", "R", "WB"])

	res_flagtuv = LRL(x, -y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, res_flagtuv.u, res_flagtuv.v], ["R", "WB", "R"])

	res_flagtuv = LRL(-x, -y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, -res_flagtuv.u, -res_flagtuv.v], ["R", "WB", "R"])

	# backwards
	var xb = x * cos(phi) + y * sin(phi)
	var yb = x * sin(phi) - y * cos(phi)

	res_flagtuv = LRL(xb, yb, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.v, res_flagtuv.u, res_flagtuv.t], ["WB", "R", "WB"])

	res_flagtuv = LRL(-xb, yb, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.v, -res_flagtuv.u, -res_flagtuv.t], ["WB", "R", "WB"])

	res_flagtuv = LRL(xb, -yb, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.v, res_flagtuv.u, res_flagtuv.t], ["R", "WB", "R"])

	res_flagtuv = LRL(-xb, -yb, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.v, -res_flagtuv.u, -res_flagtuv.t], ["R", "WB", "R"])

	return paths

func calc_tauOmega(u, v, xi, eta, phi)->Array[float]:
	var delta:float = M(u - v)
	var A:float = sin(u) - sin(delta)
	var B:float = cos(u) - cos(delta) - 1.0

	var t1:float = atan2(eta * A - xi * B, xi * A + eta * B)
	var t2:float = 2.0 * (cos(delta) - cos(v) - cos(u)) + 3.0

	var tau:float
	if t2 < 0:
		tau = M(t1 + PI)
	else:
		tau = M(t1)

	var omega:float = M(tau - u + v - phi)

	return [tau, omega]

func LRLRn(x, y, phi) -> FlagTUV:
	var xi:float = x + sin(phi)
	var eta:float = y - 1.0 - cos(phi)
	var rho:float  = 0.25 * (2.0 + sqrt(xi * xi + eta * eta))

	if rho <= 1.0:
		var u := acos(rho)
		var res_calc_tauOmega := calc_tauOmega(u, -u, xi, eta, phi)
		var t := res_calc_tauOmega[0]
		var v := res_calc_tauOmega[1]
		if t >= 0.0 and v <= 0.0:
			return FlagTUV.new(true, t, u, v)

	return FlagTUV.new(false, 0.0, 0.0, 0.0)

func LRLRp(x, y, phi) -> FlagTUV:
	var xi:float = x + sin(phi)
	var eta:float = y - 1.0 - cos(phi)
	var rho:float = (20.0 - xi * xi - eta * eta) / 16.0

	if 0.0 <= rho and rho <= 1.0:
		var u := -acos(rho)
		if u >= -0.5 * PI:
			var res_calc_tauOmega := calc_tauOmega(u, u, xi, eta, phi)
			var t := res_calc_tauOmega[0]
			var v := res_calc_tauOmega[1]
			if t >= 0.0 and v >= 0.0:
				return FlagTUV.new(true, t, u, v)

	return FlagTUV.new(false, 0.0, 0.0, 0.0)

func CCCC(x, y, phi, paths):
	var res_flagtuv = LRLRn(x, y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, res_flagtuv.u, -res_flagtuv.u, res_flagtuv.v], ["WB", "R", "WB", "R"])

	res_flagtuv = LRLRn(-x, y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, -res_flagtuv.u, res_flagtuv.u, -res_flagtuv.v], ["WB", "R", "WB", "R"])

	res_flagtuv = LRLRn(x, -y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, res_flagtuv.u, -res_flagtuv.u, res_flagtuv.v], ["R", "WB", "R", "WB"])

	res_flagtuv = LRLRn(-x, -y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, -res_flagtuv.u, res_flagtuv.u, -res_flagtuv.v], ["R", "WB", "R", "WB"])

	res_flagtuv = LRLRp(x, y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, res_flagtuv.u, res_flagtuv.u, res_flagtuv.v], ["WB", "R", "WB", "R"])

	res_flagtuv = LRLRp(-x, y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, -res_flagtuv.u, -res_flagtuv.u, -res_flagtuv.v], ["WB", "R", "WB", "R"])

	res_flagtuv = LRLRp(x, -y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, res_flagtuv.u, res_flagtuv.u, res_flagtuv.v], ["R", "WB", "R", "WB"])

	res_flagtuv = LRLRp(-x, -y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, -res_flagtuv.u, -res_flagtuv.u, -res_flagtuv.v], ["R", "WB", "R", "WB"])

	return paths

func LRSR(x, y, phi) -> FlagTUV:
	var xi:float = x + sin(phi)
	var eta:float = y - 1.0 - cos(phi)
	var r_res := R(-eta, xi)
	var rho := r_res[0]
	var theta := r_res[1]

	if rho >= 2.0:
		var t := theta
		var u := 2.0 - rho
		var v := M(t + 0.5 * PI - phi)
		if t >= 0.0 and u <= 0.0 and v <= 0.0:
			return FlagTUV.new(true, t, u, v)

	return FlagTUV.new(false, 0.0, 0.0, 0.0)

func LRSL(x, y, phi) -> FlagTUV:
	var xi = x - sin(phi)
	var eta = y - 1.0 + cos(phi)
	var r_res := R(xi, eta)
	var rho := r_res[0]
	var theta := r_res[1]

	if rho >= 2.0:
		var r := sqrt(rho * rho - 4.0)
		var u := 2.0 - r
		var t := M(theta + atan2(r, -2.0))
		var v := M(phi - 0.5 * PI - t)
		if t >= 0.0 and u <= 0.0 and v <= 0.0:
			return FlagTUV.new(true, t, u, v)

	return FlagTUV.new(false, 0.0, 0.0, 0.0)

func CCSC(x, y, phi, paths):
	var res_flagtuv = LRSL(x, y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, -0.5 * PI, res_flagtuv.u, res_flagtuv.v], ["WB", "R", "S", "WB"])

	res_flagtuv = LRSL(-x, y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, 0.5 * PI, -res_flagtuv.u, -res_flagtuv.v], ["WB", "R", "S", "WB"])

	res_flagtuv = LRSL(x, -y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, -0.5 * PI, res_flagtuv.u, res_flagtuv.v], ["R", "WB", "S", "R"])

	res_flagtuv = LRSL(-x, -y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, 0.5 * PI, -res_flagtuv.u, -res_flagtuv.v], ["R", "WB", "S", "R"])

	res_flagtuv = LRSR(x, y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, -0.5 * PI, res_flagtuv.u, res_flagtuv.v], ["WB", "R", "S", "R"])

	res_flagtuv = LRSR(-x, y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, 0.5 * PI, -res_flagtuv.u, -res_flagtuv.v], ["WB", "R", "S", "R"])

	res_flagtuv = LRSR(x, -y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, -0.5 * PI, res_flagtuv.u, res_flagtuv.v], ["R", "WB", "S", "WB"])

	res_flagtuv = LRSR(-x, -y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, 0.5 * PI, -res_flagtuv.u, -res_flagtuv.v], ["R", "WB", "S", "WB"])

	# backwards
	var xb:float = x * cos(phi) + y * sin(phi)
	var yb:float = x * sin(phi) - y * cos(phi)

	res_flagtuv = LRSL(xb, yb, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.v, res_flagtuv.u, -0.5 * PI, res_flagtuv.t], ["WB", "S", "R", "WB"])

	res_flagtuv = LRSL(-xb, yb, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.v, -res_flagtuv.u, 0.5 * PI, -res_flagtuv.t], ["WB", "S", "R", "WB"])

	res_flagtuv = LRSL(xb, -yb, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.v, res_flagtuv.u, -0.5 * PI, res_flagtuv.t], ["R", "S", "WB", "R"])

	res_flagtuv = LRSL(-xb, -yb, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.v, -res_flagtuv.u, 0.5 * PI, -res_flagtuv.t], ["R", "S", "WB", "R"])

	res_flagtuv = LRSR(xb, yb, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.v, res_flagtuv.u, -0.5 * PI, res_flagtuv.t], ["R", "S", "R", "WB"])

	res_flagtuv = LRSR(-xb, yb, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.v, -res_flagtuv.u, 0.5 * PI, -res_flagtuv.t], ["R", "S", "R", "WB"])

	res_flagtuv = LRSR(xb, -yb, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.v, res_flagtuv.u, -0.5 * PI, res_flagtuv.t], ["WB", "S", "WB", "R"])

	res_flagtuv = LRSR(-xb, -yb, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.v, -res_flagtuv.u, 0.5 * PI, -res_flagtuv.t], ["WB", "S", "WB", "R"])

	return paths

func LRSLR(x, y, phi) -> FlagTUV:
	# formula 8.11 *** TYPO IN PAPER ***
	var xi:float = x + sin(phi)
	var eta:float = y - 1.0 - cos(phi)
	var r_res := R(xi, eta)
	var rho := r_res[0]
	var theta := r_res[1]

	if rho >= 2.0:
		var u := 4.0 - sqrt(rho * rho - 4.0)
		if u <= 0.0:
			var t := M(atan2((4.0 - u) * xi - 2.0 * eta, -2.0 * xi + (u - 4.0) * eta))
			var v := M(t - phi)

			if t >= 0.0 and v >= 0.0:
				return FlagTUV.new(true, t, u, v)

	return FlagTUV.new(false, 0.0, 0.0, 0.0)

func CCSCC(x, y, phi, paths):
	var res_flagtuv = LRSLR(x, y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, -0.5 * PI, res_flagtuv.u, -0.5 * PI, res_flagtuv.v], ["WB", "R", "S", "WB", "R"])

	res_flagtuv = LRSLR(-x, y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, 0.5 * PI, -res_flagtuv.u, 0.5 * PI, -res_flagtuv.v], ["WB", "R", "S", "WB", "R"])

	res_flagtuv = LRSLR(x, -y, -phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [res_flagtuv.t, -0.5 * PI, res_flagtuv.u, -0.5 * PI, res_flagtuv.v], ["R", "WB", "S", "R", "WB"])

	res_flagtuv = LRSLR(-x, -y, phi)
	if res_flagtuv.flag:
		paths = set_path(paths, [-res_flagtuv.t, 0.5 * PI, -res_flagtuv.u, 0.5 * PI, -res_flagtuv.v], ["R", "WB", "S", "R", "WB"])

	return paths

func generate_local_course(L, lengths, mode, maxc, step_size):
	var point_num:int = int(L / step_size) + len(lengths) + 3

	#px = [0.0 for _ in range(point_num)]
	var px: Array[float]
	px.resize(point_num)
	px.fill(0.0)
	#py = [0.0 for _ in range(point_num)]
	var py: Array[float]
	py.resize(point_num)
	py.fill(0.0)
	#pyaw = [0.0 for _ in range(point_num)]
	var pyaw: Array[float]
	pyaw.resize(point_num)
	pyaw.fill(0.0)
	#directions = [0 for _ in range(point_num)]
	var directions: Array[int]
	directions.resize(point_num)
	directions.fill(0)
	
	var ind := 1

	if lengths[0] > 0.0:
		directions[0] = 1
	else:
		directions[0] = -1

	var d
	if lengths[0] > 0.0:
		d = step_size
	else:
		d = -step_size

	var ll = 0.0

	#for m, l, i in zip(mode, lengths, range(len(mode))):
	for i in range(len(mode)):
		var m = mode[i]
		var l = lengths[i]
		if l > 0.0:
			d = step_size
		else:
			d = -step_size

		var ox = px[ind] 
		var oy = py[ind]
		var oyaw = pyaw[ind]

		ind -= 1
		var pd
		if i >= 1 and (lengths[i - 1] * lengths[i]) > 0:
			pd = -d - ll
		else:
			pd = d - ll

		while abs(pd) <= abs(l):
			ind += 1
			var res_interpolate = \
				interpolate(ind, pd, m, maxc, ox, oy, oyaw, px, py, pyaw, directions)
			px = res_interpolate[0]
			py = res_interpolate[1]
			pyaw = res_interpolate[2]
			directions = res_interpolate[3]
			pd += d

		ll = l - pd - d  # calc remain length

		ind += 1
		var res_interpolate = \
			interpolate(ind, l, m, maxc, ox, oy, oyaw, px, py, pyaw, directions)
		px = res_interpolate[0]
		py = res_interpolate[1]
		pyaw = res_interpolate[2]
		directions = res_interpolate[3]

	if len(px) <= 1:
		return [[], [], [], []]

	# remove unused data
	while len(px) >= 1 and px[-1] == 0.0:
		px.pop_back()
		py.pop_back()
		pyaw.pop_back()
		directions.pop_back()

	return [px, py, pyaw, directions]


func interpolate(ind, l, m:String, maxc, ox, oy, oyaw, px:Array, py:Array, pyaw, directions:Array[int]) -> Array:
	var ldx:float
	var ldy:float
	if m == "S":
		px[ind] = ox + l / maxc * cos(oyaw)
		py[ind] = oy + l / maxc * sin(oyaw)
		pyaw[ind] = oyaw
	else:
		ldx = sin(l) / maxc
		if m == "WB":
			ldy = (1.0 - cos(l)) / maxc
		elif m == "R":
			ldy = (1.0 - cos(l)) / (-maxc)

		var gdx:float = cos(-oyaw) * ldx + sin(-oyaw) * ldy
		var gdy:float = -sin(-oyaw) * ldx + cos(-oyaw) * ldy
		px[ind] = ox + gdx
		py[ind] = oy + gdy

	if m == "WB":
		pyaw[ind] = oyaw + l
	elif m == "R":
		pyaw[ind] = oyaw - l

	if l > 0.0:
		directions[ind] = 1
	else:
		directions[ind] = -1

	return [px, py, pyaw, directions]
	

# utils
# TODO: check if it exists in Godot
func pi_2_pi(theta):
	while theta > PI:
		theta -= 2.0 * PI

	while theta < -PI:
		theta += 2.0 * PI

	return theta

func R(x:float, y:float) -> Array[float]:
	"""
	Return the polar coordinates (r, theta) of the point (x, y)
	"""
	#var r:float = hypot(x, y)
	var r:= Vector2(x,y).length()
	var theta:float = atan2(y, x)

	return [r, theta]


func M(theta:float) -> float:
	"""
	Regulate theta to -pi <= theta < pi
	"""
	var phi:float = fmod(theta, (2.0 * PI))

	if phi < -PI:
		phi += 2.0 * PI
	if phi > PI:
		phi -= 2.0 * PI

	return phi


func get_label(path) -> String:
	var label := ""

	#for m, l in zip(path.ctypes, path.lengths):
	for i in len(path.ctypes):
		var m = path.ctypes[i]
		var l = path.lengths[i]
		label = label + m
		if l > 0.0:
			label = label + "+"
		else:
			label = label + "-"

	return label


func calc_curvature(x, y, yaw, directions):
	var c := []
	var ds := []

	for i in range(1, len(x) - 1):
		var dxn = x[i] - x[i - 1]
		var dxp = x[i + 1] - x[i]
		var dyn = y[i] - y[i - 1]
		var dyp = y[i + 1] - y[i]
		var dn = Vector2(dxn, dyn).length()
		var dp = Vector2(dxp, dyp).length()
		var dx = 1.0 / (dn + dp) * (dp / dn * dxn + dn / dp * dxp)
		var ddx = 2.0 / (dn + dp) * (dxp / dp - dxn / dn)
		var dy = 1.0 / (dn + dp) * (dp / dn * dyn + dn / dp * dyp)
		var ddy = 2.0 / (dn + dp) * (dyp / dp - dyn / dn)
		var curvature = (ddy * dx - ddx * dy) / (dx ** 2 + dy ** 2)
		var d = (dn + dp) / 2.0

		if is_nan(curvature):
			curvature = 0.0

		if directions[i] <= 0.0:
			curvature = -curvature

		if len(c) == 0:
			ds.append(d)
			c.append(curvature)

		ds.append(d)
		c.append(curvature)

	ds.append(ds[-1])
	c.append(c[-1])

	return [c, ds]


func check_path(sx, sy, syaw, gx, gy, gyaw, maxc):
	var paths = calc_all_paths(sx, sy, syaw, gx, gy, gyaw, maxc)

	assert(len(paths) >= 1)

	for path in paths:
		assert(abs(path.x[0] - sx) <= 0.01)
		assert(abs(path.y[0] - sy) <= 0.01)
		assert(abs(path.yaw[0] - syaw) <= 0.01)
		assert(abs(path.x[-1] - gx) <= 0.01)
		assert(abs(path.y[-1] - gy) <= 0.01)
		assert(abs(path.yaw[-1] - gyaw) <= 0.01)

		# course distance check
		#d = [math.hypot(dx, dy)
		#	 for dx, dy in zip(np.diff(path.x[0:len(path.x) - 1]),
		#					   np.diff(path.y[0:len(path.y) - 1]))]

		#for i in range(len(d)):
		#	assert(abs(d[i] - STEP_SIZE) <= 0.001)
