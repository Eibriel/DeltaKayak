extends Node3D

@onready var player = $Player
@onready var damage_texture = $DamageTexture
#@onready var enemies = $Enemies
@onready var camera := %Camera3D
@onready var pu_button_1 := %LevelUpButton1
@onready var pu_button_2 := %LevelUpButton2
@onready var pu_button_3 := %LevelUpButton3

const CLAIM_DISTANCE = 2*2*2 # Squared distanceg

var last_enemy_spawn := 9999.0

var needed_xp := 0

var wave_time := 0.0
var wave_quota := 15
var current_wave := -1
var boss_spawned := false

#var AgentClass = preload("res://agent_class.gd")

var agents : Array[Agent] = [
	Agent.new(),
	Agent.new(),
	Agent.new()
]

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
	for p in Global.powerups:
		#if used_powerups.has(p): continue
		if Global.powerups[p].requires != "":
			#if not used_powerups.has(Global.powerups[p].requires): continue
			if Global.powerups[p].type == "attack":
				if Global.powerups[p].current_level >= Global.powerups[p].levels -1:
					continue
			if Global.powerups[p].type == "powerup":
				if Global.powerups[p].current_rank >= Global.powerups[p].ranks -1:
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
		buttons[n].text = Global.powerups[select_powerup].name
		labels[n].text = Global.powerups[select_powerup].description
		buttons[n].set_meta("powerup", select_powerup)

func _ready():
	$PauseMenu.hide()
	$LevelUpMenu.hide()
	$StatsMenu.hide()
	%PaddleLeft.hide()
	%PaddleRight.hide()
	Global.player = player
	Global.camera = camera
	
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
	
	agents[0].set_multimesh(%MultiMesh1)
	agents[0].behavior = [
		{"name":"drone"},
		{"self_collision": 1},
		{"follow":{"target": Vector2.ZERO}},
		{"look_at":{"target": Vector2.ZERO}},
		{"scale": Vector3(0.5, 0.5, 0.5)},
		{"spawn_offscreen": 1},
		{"health": 5.0},
		{"power": 5.0},
		{"damages_player": 1}
	]
	agents[1].set_multimesh(%MultiMesh2)
	agents[1].collide_with(agents[0])
	agents[1].behavior = [
		{"name":"fireball"},
		{"forward": 1},
		{"scale": Vector3(0.2, 0.2, 0.2)},
		
		{"spawn_rotation": "random"},
		{"uses": 1},
		{"damage": 2.0},
	]
	agents[2].set_multimesh(%MultiMesh3)
	agents[2].behavior = [
		{"name":"xp_point"},
	]


func _process(delta):
	$Player/Node3D2.position = $Player.position
	update_time(delta)
	handle_wave(delta)
	#check_collisions()
	#agents[1].spawn(Vector2.ZERO+agents[1].shift, randf_range(-PI*2, PI*2), 0.25)
	for agent in agents:
		agent.set_shift(Vector2(Global.player.position.x, Global.player.position.z))
		agent.process(delta)


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		pause()

func handle_wave(delta):
	wave_time -= delta
	if wave_time < 0:
		current_wave += 1
		if current_wave >= Global.waves.size():
			current_wave = 0
		boss_spawned = false
		print(current_wave)
		wave_time = 60.0
		wave_quota = Global.waves[current_wave].min
		agents[0].SPAWN_AMOUNT = wave_quota
		agents[0].SPAWN_INTERVAL = Global.waves[current_wave].time

func start_level():
	if Global.player_level != 1:
		levelup()
		pass
	if Global.player_level == 1:
		#equip_weapon("snowplow")
		#equip_weapon("fireball")
		#equip_weapon("fireball")
		#equip_weapon("laser")
		#equip_weapon("lighthouse")
		#equip_weapon("peace_meteor")
		#equip_weapon("peace_meteor")
		#equip_weapon("peace_meteor")
		#equip_weapon("peace_meteor")
		#equip_weapon("peace_meteor")
		#equip_weapon("peace_meteor")
		pass
	needed_xp = Global.level_xp(Global.player_level)
	update_xp()


func update_time(delta):
	Global.player_time += delta
	var minutes = (Global.player_time/60) as int
	var seconds = Global.player_time - (minutes*60)
	%TimeLabel.text = "%02d:%02d" % [minutes, seconds]
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
	var random_enemy: String
	if Global.waves[current_wave].has("bosses") and not boss_spawned:
		random_enemy = Global.waves[current_wave].bosses.pick_random()
		boss_spawned = true
	else:
		random_enemy = Global.waves[current_wave].enemies.pick_random()
	
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
	var enemy_position: Vector3 = lerp(corner_intersections[p], corner_intersections[p+1], randf()) + Vector3(0, 1, 0)
	#agents[0].spawn(Vector2(enemy_position.x, enemy_position.z), 0.0, 0.7)

var weapon_nodes: = {}
func equip_weapon(_weapon: String):
	Global.powerups[_weapon].current_level += 1
	if Global.powerups[_weapon].current_level == 1:
		var weapon = load("res://weapons/%s.tscn" % _weapon)
		var w = weapon.instantiate()
		weapon_nodes[_weapon] = w
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
		#get_tree().quit()
		pass

#func update_damage(damage:float):
#	#damage_texture.material.set_shader_parameter("damage_level", damage)
#	pass

func _on_paddle_left(level:float):
	damage_texture.material.set_shader_parameter("paddle_left", level)
	if level > 0:
		%PaddleLeft.show()
	else:
		%PaddleLeft.hide()
	
func _on_paddle_right(level:float):
	damage_texture.material.set_shader_parameter("paddle_right", level)
	if level > 0:
		%PaddleRight.show()
	else:
		%PaddleRight.hide()


func _on_dropped_item(item_id: int, amount: float, pos: Vector3):
#	match item_id:
#		Global.ITEMS.XP:
#			var xp = preload("res://elements/xp_point.tscn").instantiate()
#			xp.position = pos
#			xp.XP = amount
#			$Items.add_child(xp)
	pass


func _on_claimed_item(item_id: int, amount: float):
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
	#get_tree().quit()
	#var main_scene := preload("res://main.tscn")
	get_tree().change_scene_to_file("res://main.tscn")


func _on_resume_button_button_up():
	unpause()

func _on_select_levelup(button):
	player.about_to_pause()
	get_tree().paused = false
	$LevelUpMenu.hide()
	$StatsMenu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var p = button.get_meta("powerup")
	if Global.powerups[p].type == "powerup":
		Global.player_modifiers[Global.powerups[p].stat] += Global.powerups[p].adds
	elif Global.powerups[p].type == "attack":
		#used_powerups.append(p)
		equip_weapon(p)
