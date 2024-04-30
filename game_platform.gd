extends Node

var stats = {
	"distance_traveled": 0
}

func _init() -> void:
	if OS.has_feature("steam"):
		print("steam")

func set_stat():
	pass

func get_stats():
	pass

func set_achievement():
	pass

func get_achievements():
	pass

func set_rich_presence():
	pass
