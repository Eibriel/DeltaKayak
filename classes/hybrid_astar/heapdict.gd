# https://github.com/DanielStutzbach/heapdict/blob/master/heapdict.py

class_name HeapDict

var heap := []
var d := {}

func _init() -> void:
	pass

func clear():
	heap.clear()
	d.clear()

func set_item(key, value):
	if key in d:
		del_item(key)
	var wrapper = [value, key, self.get_len()]
	d[key] = wrapper
	heap.append(wrapper)
	_decrease_key(len(self.heap)-1)

func _min_heapify(i):
		var n:int = len(self.heap)
		var h = self.heap
		while true:
			# calculate the offset of the left child
			var l:int = (i << 1) + 1
			# calculate the offset of the right child
			var r:int = (i + 1) << 1
			var low:int
			if l < n and h[l][0] < h[i][0]:
				low = l
			else:
				low = i
			if r < n and h[r][0] < h[low][0]:
				low = r

			if low == i:
				break

			self._swap(i, low)
			i = low

func _decrease_key(i):
	var parent
	while i:
		# calculate the offset of the parent
		parent = (i - 1) >> 1
		if self.heap[parent][0] < self.heap[i][0]:
			break
		self._swap(i, parent)
		i = parent

func _swap(i, j):
	var h = self.heap
	var h_i = h[i]
	h[i] = h[j]
	h[j] = h_i #h[i]
	h[i][2] = i
	h[j][2] = j

func del_item(key):
	var wrapper = self.d[key]
	while wrapper[2]:
		# calculate the offset of the parent
		var parentpos = (wrapper[2] - 1) >> 1
		var parent = self.heap[parentpos]
		self._swap(wrapper[2], parent[2])
	self.popitem()

func get_item(key):
	return self.d[key][0]

#func __iter__(self):
#	return iter(self.d)

func popitem():
	"""D.popitem() -> (k, v), remove and return the (key, value) pair with lowest\nvalue; but raise KeyError if D is empty."""
	var wrapper = self.heap[0]
	if len(self.heap) == 1:
		self.heap.pop_back()
	else:
		self.heap[0] = self.heap.pop_back()
		self.heap[0][2] = 0
		self._min_heapify(0)
	#del self.d[wrapper[1]]
	self.d.erase(wrapper[1])
	return [wrapper[1], wrapper[0]]

func get_len():
	return len(self.d)

func peekitem():
	"""D.peekitem() -> (k, v), return the (key, value) pair with lowest value;\n but raise KeyError if D is empty."""
	return [self.heap[0][1], self.heap[0][0]]
