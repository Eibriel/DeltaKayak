extends Node


var stats_ready := false
var stats = {
	"distance_traveled": 0 #Kilometers
}
var stats_support = {
	"last_player_position": null
}

var stats_time: float = 0.0

func _process(delta: float) -> void:
	stats_time += delta
	if not stats_ready and GlobalSteam.stats_ready:
		stats = GlobalSteam.stats
		stats_ready = true
	if not stats_ready: return
	if stats_time > 10:
		stats_time = 0.0
		GlobalSteam.set_stat("distance_traveled", int(stats["distance_traveled"]))

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
