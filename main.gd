extends Control

@export var game_preferences:PreferenceResource
@export var game_state:DKDataResource

@onready var dk_world: DKWorld = %DKWorld
@onready var label_demo: Label = $Control/LabelDemo
@onready var interactive_labels_control: Control = %InteractiveLabels
@onready var character: RigidBody3D = %character
@onready var dialogue_label: RichTextLabel = %DialogueLabel
@onready var log_label: RichTextLabel = %LogLabel
@onready var dialogue_control: Control = %DialogueControl

var interactive_labels:Dictionary
var in_trigger:Array[String]

var dialogue_queue: Array[DialogueResource]
var dialogue_time: float
var dialogue_tween: Tween
var write_speed: float

func _ready() -> void:
	Global.main_scene = self
	label_demo.visible = false
	if Global.is_demo():
		label_demo.visible = true
	
	dk_world.connect("trigger_entered", on_trigger_entered)
	dk_world.connect("trigger_exited", on_trigger_exited)
	
	dialogue_label.text = ""
	
	#var state_initializer = DkdataInitialization.new()
	#state_initializer.initialize_data(game_state)
	
	#Start
	character.position = Vector3(333.815, 0, 212.126)
	character.rotation = Vector3(0, 0, 0)
	
	#Skip start
	#character.position = Vector3(333.815, 0, 36)

func _process(delta: float) -> void:
	handle_triggers(delta)
	handle_dialogue(delta)
	handle_stats(delta)
	log_label.text = Global.log_text
	Global.log_text = ""

func handle_stats(_delta):
	#
	if GamePlatform.stats_support["last_player_position"] == null:
		GamePlatform.stats_support["last_player_position"] = Global.character.position
	var character_distance = Global.character.position.distance_to(GamePlatform.stats_support["last_player_position"])
	character_distance *= 0.001 # Meters to Kilometers
	GamePlatform.stats_support["last_player_position"] = Global.character.position
	
	GamePlatform.stats["distance_traveled"] += character_distance 
		

func handle_dialogue(delta:float) -> void:
	dialogue_time -= delta
	if dialogue_label.text == "":
		dialogue_control.visible = false
	else:
		dialogue_control.visible = true
	if dialogue_time > 0: return
	dialogue_label.text = ""
	if dialogue_queue.size() < 1: return
	var d: DialogueResource = dialogue_queue.pop_front() as DialogueResource
	var key: String = "%s_dialogue_text" % d.resource_scene_unique_id
	var character_string:String = d.Character.keys()[d.character]
	dialogue_label.text = "%s:\n\t%s" % [tr(character_string), tr(key)]
	dialogue_label.visible_ratio = 0
	if is_dialogue_animating():
		dialogue_tween.stop()
	dialogue_tween = create_tween()
	write_speed = dialogue_label.text.length() * 0.08
	dialogue_tween.tween_property(dialogue_label, "visible_ratio", 1., 1)
	dialogue_time = write_speed + (dialogue_label.text.length() * 0.08)
	# TODO
	# - Skip animation
	# - Skip text

func handle_triggers(_delta:float) -> void:
	if Global.camera == null: return
	
	for sector_id in dk_world.world_definition:
		var sector:Dictionary = dk_world.world_definition[sector_id] as Dictionary
		for trigger in sector.triggers:
			var trigger_position = Global.array_to_vector3(trigger.position)
			var primary_label := ""
			var secondary_label := ""
			var trigger_visible := true
			var always_visible := false
			for i in game_state.items:
				if i.trigger_name == trigger.id:
					if not i.visible:
						trigger_visible = false
						break
					if i.primary_action != "":
						var a = get_item_action(i.primary_action, i)
						if a != null:
							var key: String = "%s_action_label" % a.resource_scene_unique_id
							primary_label = tr(key)
					if i.secondary_action != "":
						var a = get_item_action(i.secondary_action, i)
						if a != null:
							var key: String = "%s_action_label" % a.resource_scene_unique_id
							secondary_label = tr(key)
					always_visible = i.always_visible
					break
			if is_in_trigger(trigger.id) and trigger_visible and \
					(Global.camera.is_position_in_frustum(trigger_position) or always_visible):
				var icon = get_interactive(trigger.id, primary_label, secondary_label, true)
				if Global.camera.is_position_in_frustum(trigger_position):
					icon.position = Global.camera.unproject_position(trigger_position)
				elif always_visible:
					icon.position = get_viewport_rect().size * 0.5
				icon.visible = true
				icon.set_active(false)
				if is_closest_trigger(trigger.id):
					icon.set_active(true)
			else:
				var icon = get_interactive(trigger.id, primary_label, secondary_label, false)
				if icon != null:
					icon.visible = false

func get_item_action(id:String, item:ItemResource) -> ActionResource:
	for a in item.actions:
		if a.id == id:
			return a
	return null

func get_interactive(id:String, primary_label:String, secondary_label:String, create:bool):
	if id not in interactive_labels:
		if create:
			var icon:Control = preload("res://ui/interactive_label.tscn").instantiate() as Control
			icon.primary_text = primary_label
			icon.secondary_text = secondary_label
			interactive_labels[id] = icon
			interactive_labels_control.add_child(icon)
		else:
			return null
		
	return interactive_labels[id]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("primary_action"):
		if is_saying_dialogue():
			skip_dialogue()
			return
		for id in in_trigger:
			execute_trigger("primary_action", id)
	elif event.is_action_pressed("secondary_action"):
		if is_saying_dialogue():
			skip_dialogue()
			return
		for id in in_trigger:
			execute_trigger("secondary_action", id)
	elif event.is_action_pressed("pepa"):
		say_dialogue("¡¡Pepa!!")
	elif event.is_action_pressed("compicactus"):
		on_compicactus()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func on_compicactus():
	say_dialogue("compi_im_here")

func on_trigger_entered(id:String):
	#prints("Entered", id)
	if id not in in_trigger:
		in_trigger.append(id)
	execute_trigger("trigger_entered", id)

func on_trigger_exited(id:String):
	#prints("Exited", id)
	if id in in_trigger:
		in_trigger.erase(id)
	execute_trigger("trigger_exited", id)

func execute_trigger(trigger_type:String, trigger_id:String):
	# var index := "%s:%s" % [type, trigger_id]
	if not is_closest_trigger(trigger_id): return
	for i in game_state.items:
		if not i.active: continue
		if i.trigger_name == trigger_id:
			if "primary_action" == trigger_type and i.primary_action != "":
				var a = get_item_action(i.primary_action, i)
				if a != null:
					if i.logic != null:
						var l_script = i.logic.new()
						l_script._on_trigger(self, game_state, a.id)
					else:
						push_error("Item '%s' has no logic" % i.id)
				else:
					push_error("Action '%s' not found in item '%s'" % [i.primary_action, i.id])
			elif "secondary_action" == trigger_type and i.secondary_action != "":
				var a = get_item_action(i.secondary_action, i)
				if a != null:
					if i.logic != null:
						var l_script = i.logic.new()
						l_script._on_trigger(self, game_state, a.id)
					else:
						push_error("Item '%s' has no logic" % i.id)
				else:
					push_error("Action '%s' not found in item '%s'" % [i.primary_action, i.id])
			else:
				if i.logic != null:
					var l_script = i.logic.new()
					l_script._on_trigger(self, game_state, trigger_type)

func is_in_trigger(id:String) -> bool:
	return id in in_trigger

func is_closest_trigger(id:String) -> bool:
	if in_trigger.size() < 1: return false
	if in_trigger.size() == 1: return true
	var min_dist:float = 9999.0
	var min_trigger:String = ""
	for t in in_trigger:
		for sector_id in dk_world.world_definition:
			var sector:Dictionary = dk_world.world_definition[sector_id] as Dictionary
			for trigger in sector.triggers:
				if trigger.id == t:
					var dist := character.position.distance_squared_to(Global.array_to_vector3(trigger.position))
					if min_trigger == "" or dist < min_dist:
						min_dist = dist
						min_trigger = trigger.id
	return id == min_trigger

func say_dialogue(text:String, force: bool = true) -> void:
	for e in game_state.exchanges:
		if e.id == text:
			if force:
				dialogue_queue.resize(0)
				skip_dialogue()
			for d in e.dialogues:
				dialogue_queue.append(d)
			return
	push_error("Cant find dialogue %s" % text)

func skip_dialogue() -> void:
	#dialogue_time = -1.0
	if is_dialogue_animating():
		dialogue_tween.stop()
		dialogue_label.visible_ratio = 1
		dialogue_time -= write_speed
	else:
		dialogue_label.text = ""
		dialogue_time = -1

func is_saying_dialogue() -> bool:
	var is_queue_full := dialogue_queue.size() > 0
	return is_dialogue_animating() or is_queue_full or dialogue_label.text != ""

func is_dialogue_animating() -> bool:
	return dialogue_tween != null and dialogue_tween.is_running()

func sync_misc_data() -> void:
	# NOTE
	# dots (.) in blender object names
	# are turned into lowscores (_) in godot node names
	var misc: MiscDataResource = game_state.misc_data
	node_visible("Muelle1_006", not misc.house_door_open)
	node_collide("Muelle1_006", not misc.house_door_open)
	item_active("character_house_door", not misc.house_door_open)
	item_visible("character_house_door", not misc.house_door_open)
	
	node_visible("Muelle1_007", not misc.next_door_open)
	node_collide("Muelle1_007", not misc.next_door_open)
	item_active("next_door", not misc.next_door_open)
	item_visible("next_door", not misc.next_door_open)
	
	item_active("next_door_key", not misc.has_next_door_key)
	item_visible("next_door_key", not misc.has_next_door_key)
	
	Global.character.pepa.visible = misc.pepa_visible

func node_collide(node_path: NodePath, active: bool):
	var node = dk_world.get_node(node_path)
	for static_body in node.get_children():
		if static_body is StaticBody3D:
			for collision_shape in static_body.get_children():
				if collision_shape is CollisionShape3D:
					collision_shape.disabled = not active

func node_visible(node_path: NodePath, active: bool):
	dk_world.get_node(node_path).visible = active

func item_active(item_id: String, active: bool):
	var item := get_item(item_id)
	if item == null: return
	item.active = active

func item_visible(item_id: String, _visible: bool):
	var item := get_item(item_id)
	if item == null: return
	item.visible = _visible

func get_item(item_id: String) -> ItemResource:
	for i in game_state.items:
		if i.id == item_id:
			return i
	return null
