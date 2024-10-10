extends Control

var in_room := []

func _ready() -> void:
	Global.main_scene = self
	Global.character = $EnemyCollision/character
	Global.enemy = $EnemyCollision/Enemy

func set_player_state(_v:String):
	pass
