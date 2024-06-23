extends Area3D

var area_status := []
var body_status := []

func _on_area_exited(area: Area3D) -> void:
	var area_position := to_local(area.global_position)
	if area_position.z < 0:
		if not area_status.has(area):
			area_status.append(area)
	else:
		area_status.erase(area)
	print(area_status)


func _on_body_exited(body: Node3D) -> void:
	var body_position := to_local(body.global_position)
	if body_position.z < 0:
		if not body_status.has(body):
			body_status.append(body)
	else:
		body_status.erase(body)
	print(area_status)
