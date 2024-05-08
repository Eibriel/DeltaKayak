extends Control

@export var game_preferences:PreferenceResource
@export var game_state:DKDataResource

@onready var dk_world: DKWorld = %DKWorld
@onready var label_demo: Label = $Control/LabelDemo
@onready var interactive_labels_control: Control = %InteractiveLabels
@onready var character: RigidBody3D = %character
@onready var dialogue_label: RichTextLabel = %DialogueLabel
@onready var log_label: RichTextLabel = %LogLabel

var interactive_labels:Dictionary
var in_trigger:Array[String]

var dialogue_queue: Array[DialogueResource]
var dialogue_time: float
var dialogue_tween: Tween

func _ready() -> void:
	label_demo.visible = false
	if Global.is_demo():
		label_demo.visible = true
	
	dk_world.connect("trigger_entered", on_trigger_entered)
	dk_world.connect("trigger_exited", on_trigger_exited)
	
	#var state_initializer = DkdataInitialization.new()
	#state_initializer.initialize_data(game_state)

func _process(delta: float) -> void:
	handle_triggers(delta)
	handle_dialogue(delta)
	log_label.text = Global.log_text
	Global.log_text = ""

func handle_dialogue(delta:float) -> void:
	dialogue_time -= delta
	if dialogue_time > 0: return
	dialogue_label.text = ""
	if dialogue_queue.size() < 1: return
	var d: DialogueResource = dialogue_queue.pop_front()
	var key: String = "%s_dialogue_text" % d.resource_scene_unique_id
	dialogue_label.text = tr(key)
	dialogue_label.visible_ratio = 0
	if dialogue_tween != null and dialogue_tween.is_running():
		dialogue_tween.stop()
	dialogue_tween = create_tween()
	dialogue_tween.tween_property(dialogue_label, "visible_ratio", 1., 1)
	dialogue_time = 5.

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
		for id in in_trigger:
			execute_trigger("primary_action", id)
	elif event.is_action_pressed("secondary_action"):
		for id in in_trigger:
			execute_trigger("secondary_action", id)
	elif event.is_action_pressed("pepa"):
		say_dialogue("¡¡Pepa!!")
	elif event.is_action_pressed("compicactus"):
		on_compicactus()

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
				dialogue_time = -1.0
			for d in e.dialogues:
				dialogue_queue.append(d)
			return
	push_error("Cant find dialogue %s" % text)

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
	
	item_active("next_door_key", not misc.has_next_door_key)
	item_visible("next_door_key", not misc.has_next_door_key)
	

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
