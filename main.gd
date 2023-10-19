extends Node3D

@onready var player = $Player
@onready var damage_texture = $DamageTexture
@onready var enemies = $Enemies
@onready var camera := %Camera3D
@onready var pu_button_1 := %LevelUpButton1
@onready var pu_button_2 := %LevelUpButton2
@onready var pu_button_3 := %LevelUpButton3

const CLAIM_DISTANCE = 2*2*2 # Squared distance

var last_enemy_spawn := 9999.0

var needed_xp := 0

var wave_time := 60.0
var wave_quota := 15
var used_powerups = ["laser"]
var powerups = {
	# Attacks
	"snowplow": {
		"type": "attack",
		"name": "Snowplow",
		"description": "Push enemies around",
		"requires": "",
	},
	"fireball": {
		"type": "attack",
		"name": "Fireball",
		"description": "Fireballs hitting a random enemy",
		"requires": "",
	},
	"laser": {
		"type": "attack",
		"name": "Laser",
		"description": "A laser rotating around the character",
		"requires": "",
	},
	"lighthouse": {
		"type": "attack",
		"name": "Lighthouse",
		"description": "A rotating light",
		"requires": "",
	},
	"peace_meteor": {
		"type": "attack",
		"name": "Peace Meteor",
		"description": "Meteors falling from the sky",
		"requires": "",
	},
	
	# PowerUps
	"might": {
		"type": "powerup",
		"name": "Might",
		"description": "Increases inflicted damage by 5%",
		"requires": "",
		"stat": "might",
		"adds": 5,
		"ranks": 5,
		"current_rank": 0
	},
	"armor": {
		"type": "powerup",
		"name": "Armor",
		"description": "Increases Armor by 1",
		"requires": "",
		"stat": "armor",
		"adds": 1,
		"ranks": 3,
		"current_rank": 0
	},
	"max_health": {
		"type": "powerup",
		"name": "Max Health",
		"description": "Increases Max Health by 10%",
		"requires": "",
		"stat": "max_health",
		"adds": 10,
		"ranks": 3,
		"current_rank": 0
	},
	"recovery": {
		"type": "powerup",
		"name": "Recovery",
		"description": "Recovers additional 0.1 per second",
		"requires": "",
		"stat": "recovery",
		"adds": 0.1,
		"ranks": 3,
		"current_rank": 0
	},
	"cooldown": {
		"type": "powerup",
		"name": "Colldown",
		"description": "Colldown reduced by 2.5%",
		"requires": "",
		"stat": "cooldown",
		"adds": -2.5,
		"ranks": 2,
		"current_rank": 0
	},
	"area": {
		"type": "powerup",
		"name": "Area",
		"description": "Increases area by 5%",
		"requires": "",
		"stat": "area",
		"adds": 5,
		"ranks": 2,
		"current_rank": 0
	},
	"speed": {
		"type": "powerup",
		"name": "Speed",
		"description": "Projectile speed increased by 10%",
		"requires": "",
		"stat": "area",
		"adds": 10,
		"ranks": 2,
		"current_rank": 0
	},
	# Duration
	# Amount
	"move_speed": {
		"type": "powerup",
		"name": "Move Speed",
		"description": "Character speed increased by 5%",
		"requires": "",
		"stat": "move_speed",
		"adds": 5,
		"ranks": 2,
		"current_rank": 0
	},
	"magnet": {
		"type": "powerup",
		"name": "Magnet",
		"description": "Item pickup area increased by 25%",
		"requires": "",
		"stat": "magnet",
		"adds": 25,
		"ranks": 2,
		"current_rank": 0
	},
	# Luck
	"growth": {
		"type": "powerup",
		"name": "Growth",
		"description": "XP drops value increase by 3%",
		"requires": "",
		"stat": "growth",
		"adds": 3,
		"ranks": 5,
		"current_rank": 0
	}
}



func pause():
	player.about_to_pause()
	get_tree().paused = true
	$PauseMenu.show()
	$StatsMenu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func unpause():
	$PauseMenu.hide()
	$StatsMenu.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func levelup():
	get_tree().paused = true
	$LevelUpMenu.show()
	$StatsMenu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var available_powerups := []
	for p in powerups:
		if used_powerups.has(p): continue
		if powerups[p].requires != "":
			if not used_powerups.has(powerups[p].requires): continue
			if powerups[p].type == "powerup":
				if powerups[p].current_rank >= powerups[p].ranks -1:
					continue
		available_powerups.append(p)
	available_powerups.shuffle()
	var buttons = [
		%LevelUpButton1,
		%LevelUpButton2,
		%LevelUpButton3
	]
	var labels = [
		%LevelUpLabel1,
		%LevelUpLabel2,
		%LevelUpLabel3
	]
	for n in range(min(3, available_powerups.size()+1)):
		var select_powerup = available_powerups.pop_back()
		buttons[n].text = powerups[select_powerup].name
		labels[n].text = powerups[select_powerup].description
		buttons[n].set_meta("powerup", select_powerup)

func _ready():
	$PauseMenu.hide()
	$LevelUpMenu.hide()
	$StatsMenu.hide()
	Global.player = player
	Global.enemies_node = enemies
	player.connect("damage_update", _on_damage_update)
	player.connect("paddle_left", _on_paddle_left)
	player.connect("paddle_right", _on_paddle_right)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
	Global.connect("dropped_item", _on_dropped_item)
	Global.connect("claimed_item", _on_claimed_item)
	player.set_kayak(Player.KAYAKS.NORMAL_PINK)
	start_level()
	
	pu_button_1.connect("button_up", _on_select_levelup.bind(pu_button_1))
	pu_button_2.connect("button_up", _on_select_levelup.bind(pu_button_2))
	pu_button_3.connect("button_up", _on_select_levelup.bind(pu_button_3))


func _process(delta):
	$Player/Node3D2.position = $Player.position
	update_time(delta)
	#
	last_enemy_spawn += delta
	wave_time -= delta
	if wave_time < 0:
		wave_time = 60.0
		wave_quota = randi_range(20, 150)
	if enemies.get_children().size() >= wave_quota: return
	if last_enemy_spawn > 0.1:
		last_enemy_spawn = 0.0
		spawn_enemy()
	#check_collisions()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		pause()

func start_level():
	if Global.player_level != 1:
		levelup()
	if Global.player_level == 1:
		equip_weapon("laser")
	needed_xp = Global.level_xp(Global.player_level)
	update_xp()


func update_time(delta):
	Global.player_time += delta
	var minutes = (Global.player_time/60) as int
	var seconds = Global.player_time - (minutes*60)
	%TimeLabel.text = "%d:%d" % [minutes, seconds]
	# TODO move to other place
	%KillsLabel.text = "%d K" % Global.player_kills

func update_xp():
	%XPProgressBar.value = (Global.player_xp * 100) / needed_xp
	#%XPLabel.text = "%d" % Global.player_xp
	%LevelLabel.text = "LV %d" % Global.player_level
	var mm = ""
	for pm in Global.player_modifiers:
		mm += "%s: %d\n" % [pm, Global.player_modifiers[pm]]
	%StatsTextLabel.text = mm

func update_damage():
	%DamageLabel.text = "%f" % Global.player_damage
	%DamageProgressBar.value = (1.0 - Global.player_damage) * 100

#func check_collisions():
#	for i in $Items.get_children():
#		if player.global_position.distance_squared_to(i.global_position) < CLAIM_DISTANCE:
#			i.claim()


func load_enemies():
	for e in Global.enemies:
		var enemy = load("res://enemies/%s.tscn" % e)

func spawn_enemy():
	var enemy_list = Global.enemies.pick_random()
	var enemy = load("res://enemies/%s.tscn" % enemy_list)
	var e = enemy.instantiate()
	enemies.add_child(e)
	
	var width := 640
	var height := 480
	var screen_corners = [
		Vector2i(0, 0),
		Vector2i(0, height),
		Vector2i(width, height),
		Vector2i(width, 0),
		Vector2i(0, 0)
	]
	var corner_intersections = []
	for c in screen_corners:
		var rayVector = camera.project_ray_normal(c)
		var rayPoint = camera.project_ray_origin(c)
		var intersection = planeRayIntersection(rayVector,rayPoint, Vector3.ZERO, Vector3.UP)
		corner_intersections.append(intersection)
	
	#var p = randi_range(0, screen_corners.size()-2)
	var p = [0, 0, 0, 1, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3].pick_random()
	e.global_position = lerp(corner_intersections[p], corner_intersections[p+1], randf()) + Vector3(0, 1, 0)

func equip_weapon(_weapon: String):
	var weapon = load("res://weapons/%s.tscn" % _weapon)
	var w = weapon.instantiate()
	Global.player.add_weapon(w)

func _exit_tree():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_damage_update(damage:float):
	#var tween = create_tween()
	#tween.tween_method(update_damage, current_damage, 1.0, 0.1)
	#tween.tween_method(update_damage, 1.0, damage, 0.3)
	Global.player_damage = damage
	update_damage()
	if Global.player_damage == 1:
		get_tree().quit()

#func update_damage(damage:float):
#	#damage_texture.material.set_shader_parameter("damage_level", damage)
#	pass

func _on_paddle_left(level:float):
	damage_texture.material.set_shader_parameter("paddle_left", level)
	
func _on_paddle_right(level:float):
	damage_texture.material.set_shader_parameter("paddle_right", level)


func _on_dropped_item(item_id: int, amount: int, pos: Vector3):
	match item_id:
		Global.ITEMS.XP:
			var xp = preload("res://elements/xp_point.tscn").instantiate()
			xp.position = pos
			$Items.add_child(xp)


func _on_claimed_item(item_id: int, amount: int):
	match item_id:
		Global.ITEMS.XP:
			Global.player_xp += amount
			update_xp()
			if Global.player_xp >= needed_xp:
				Global.player_xp -= needed_xp
				Global.player_level += 1
				start_level()





func planeRayIntersection(rayVector: Vector3, rayPoint: Vector3, planePoint: Vector3, planeNormal: Vector3):
	var diff: Vector3 = rayPoint - planePoint
	var prod1 = diff.dot(planeNormal)
	var prod2 = rayVector.dot(planeNormal)
	var prod3 = prod1 / prod2
	var intersection: Vector3 = rayPoint - (rayVector * prod3)
	return intersection


func _on_quit_button_button_up():
	get_tree().quit()


func _on_resume_button_button_up():
	unpause()

func _on_select_levelup(button):
	player.about_to_pause()
	get_tree().paused = false
	$LevelUpMenu.hide()
	$StatsMenu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var p = button.get_meta("powerup")
	if powerups[p].type == "powerup":
		Global.player_modifiers[powerups[p].stat] += powerups[p].adds
	elif powerups[p].type == "attack":
		used_powerups.append(p)
		equip_weapon(p)
