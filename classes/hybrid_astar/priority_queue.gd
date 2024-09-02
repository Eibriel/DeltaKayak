class_name PriorityQueue
"""
Priority Queue. Min heap priority queue that can take a Vector2 and its
corresponding cost and then always return the Vector2 in it with
the lowest cost value.
Based on: https://en.wikipedia.org/wiki/Binary_heap

Source: https://blog.bigturtleworks.com/posts/gdscript-priority-queue-benchmarks/
"""
var _data: Array = []

func insert(element: Vector2, cost: float) -> void:
	# Add the element to the bottom level of the heap at the leftmost open 
		# space
	self._data.push_back(Vector3(element.x, element.y, cost))
	var new_element_index: int = self._data.size() - 1
	self._up_heap(new_element_index)

func extract():
	if self.empty():
		return null
	var result: Vector3 = self._data.pop_front()
	# If the tree is not empty, replace the root of the heap with the last
	# element on the last level.
	if not self.empty():
		self._data.push_front(self._data.pop_back())
		self._down_heap(0)
	return Vector2(result.x, result.y)

func empty() -> bool:
	return self._data.is_empty()

func _get_parent(index: int) -> int:
	# warning-ignore:integer_division
	return (index - 1) / 2

func _left_child(index: int) -> int:
	return (2 * index) + 1

func _right_child(index: int) -> int:
	return (2 * index) +  2

func _swap(a_idx: int, b_idx: int) -> void:
	var a = self._data[a_idx]
	var b = self._data[b_idx]
	self._data[a_idx] = b
	self._data[b_idx] = a

func _up_heap(index: int) -> void:
	# Compare the added element with its parent; if they are in the correct 
		# order, stop.
	var parent_idx = self._get_parent(index)
	if self._data[index].z >= self._data[parent_idx].z:
		return
	self._swap(index, parent_idx)
	self._up_heap(parent_idx)

func _down_heap(index: int) -> void:
	var left_idx: int = self._left_child(index)
	var right_idx: int = self._right_child(index)
	var smallest: int = index
	var size: int = self._data.size()

	if right_idx < size and self._data[right_idx].z < self._data[smallest].z:
		smallest = right_idx

	if left_idx < size and self._data[left_idx].z < self._data[smallest].z:
		smallest = left_idx

	if smallest != index:
		self._swap(index, smallest)
		self._down_heap(smallest)
