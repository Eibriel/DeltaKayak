class_name HeapDictTest

const N = 100

func check_invariants(h):
	# the 3rd entry of each heap entry is the position in the heap
	#for i, e in enumerate(h.heap):
	for i in h.heap.size():
		var e = h.heap[i]
		assert(e[2] == i)
	# the parent of each heap element must not be larger than the element
	for i in range(1, len(h.heap)):
		var parent = (i - 1) >> 1
		# assertLessEqual
		assert(h.heap[parent][0] <= h.heap[i][0])

func make_data():
	#pairs = [(random.random(), random.random()) for i in range(N)]
	var pairs := []
	for i in N:
		pairs.append([randf(), randf()])
	#pairs = [
		#["A", 0.1],
		#["B", 0.2],
		#["C", 0.4],
		#["D", 0.6],
	#]
	var h = HeapDict.new()
	var d = {}
	#for k, v in pairs:
	for p in pairs:
		var k = p[0]
		var v = p[1]
		h.set_item(k, v)
		d[k] = v

	var sort_descending = func(a, b):
		if a[1] > b[1]:
			return true
		return false
	pairs.sort_custom(sort_descending)
	#pairs.sort(key=lambda x: x[1], reverse=true)
	return [h, pairs, d]

func test_popitem():
	var d = self.make_data()
	var h = d[0]
	var pairs = d[1]
	while pairs:
		var v = h.popitem()
		var v2 = pairs.pop_at(-1)
		assert(v == v2)
	assert(h.get_len() == 0)

func test_popitem_ties():
	var h := HeapDict.new()
	for i in range(N):
		h.set_item(i, 0)
	for i in range(N):
		var r = h.popitem()
		var v = r[1]
		assert(v == 0)
		self.check_invariants(h)


func test_peek():
	var r = self.make_data()
	var h = r[0]
	var pairs = r[1]
	while not pairs.is_empty():
		var v = h.peekitem()[0]
		h.popitem()
		var v2 = pairs.pop_at(-1)
		assert(v == v2[0])
	assert(h.get_len() == 0)
"""
func test_iter():
	var md = self.make_data()
	var h = md[0]
	var d = md[2]
	
	self.assertEqual(list(h), list(d))

func test_keys(self):
	h, _, d = self.make_data()
	self.assertEqual(list(sorted(h.keys())), list(sorted(d.keys())))

func test_values(self):
	h, _, d = self.make_data()
	self.assertEqual(list(sorted(h.values())), list(sorted(d.values())))
"""

func test_del():
	var r = self.make_data()
	var h = r[0]
	var pairs = r[1]
	var pr = pairs.pop_at(int(N/2))
	var k = pr[0]
	var v = pr[1]
	h.del_item(k)
	while pairs:
		var v1 = h.popitem()
		var v2 = pairs.pop_at(-1)
		assert(v1 == v2)
	assert(h.get_len() == 0)


func test_change():
	var d = self.make_data()
	var h = d[0]
	var pairs = d[1]
	var p = pairs[int(N/2)]
	var k = p[0]
	var v = p[1]
	h.set_item(k, 0.5)
	pairs[int(N/2)] = [k, 0.5]
	#pairs.sort(key=lambda x: x[1], reverse=True)
	var sort_descending = func(a, b):
		if a[1] > b[1]:
			return true
		return false
	pairs.sort_custom(sort_descending)
	#print(pairs)
	#print(h.heap)
	#print()
	while not pairs.is_empty():
		var v1 = h.popitem()
		var v2 = pairs.pop_at(-1)
		#prints(v1, v2)
		assert(v1 == v2)
	assert(h.get_len() == 0)

# Expected print:
#[[0.1, 'A', 0]]
#[[0.1, 'A', 0], [0.2, 'B', 1]]
#[[0.1, 'A', 0], [0.2, 'B', 1]]
#[[0.1, 'A', 0], [0.2, 'B', 1], [0.4, 'C', 2]]
#[[0.1, 'A', 0], [0.2, 'B', 1], [0.4, 'C', 2]]
#[[0.1, 'A', 0], [0.2, 'B', 1], [0.4, 'C', 2], [0.6, 'D', 3]]
#[[0.1, 'A', 0], [0.2, 'B', 1], [0.4, 'C', 2], [0.6, 'D', 3]]
#[[0.1, 'A', 0], [0.6, 'D', 1], [0.4, 'C', 2], [0.5, 'B', 3]]
#[[0.1, 'A', 0], [0.5, 'B', 1], [0.4, 'C', 2], [0.6, 'D', 3]]
#('A', 0.1) ('A', 0.1)
#('C', 0.4) ('C', 0.4)
#('B', 0.5) ('B', 0.5)
#('D', 0.6) ('D', 0.6)


func test_clear():
	var d = self.make_data()
	d[0].clear()
	assert(d[0].get_len() == 0)

func test_main():
	test_popitem()
	test_popitem_ties()
	test_peek()
	test_del()
	test_change()
	test_clear()
