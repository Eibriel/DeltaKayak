extends Control

@export var game_preferences:PreferenceResource
@export var game_state:DKDataResource

@onready var dk_world: DKWorld = %DKWorld
@onready var label_demo: Label = $Control/LabelDemo
@onready var interactive_labels_control: Control = %InteractiveLabels
@onready var character: RigidBody3D = %character
@onready var dialogue_label: RichTextLabel = %DialogueLabel

var interactive_labels:Dictionary
var in_trigger:Array[String]

const DkdataInitialization = preload("res://dkdata/dkdata_initialization.gd")

func _ready() -> void:
	label_demo.visible = false
	if Global.is_demo():
		label_demo.visible = true
	
	dk_world.connect("trigger_entered", on_trigger_entered)
	dk_world.connect("trigger_exited", on_trigger_exited)
	
	var state_initializer = DkdataInitialization.new()
	state_initializer.initialize_data(game_state)

func _process(delta: float) -> void:
	handle_triggers(delta)

func handle_triggers(_delta:float) -> void:
	if Global.camera == null: return
	
	var visible_interactives := []
	
	for sector_id in dk_world.world_definition:
		var sector:Dictionary = dk_world.world_definition[sector_id] as Dictionary
		for trigger in sector.triggers:
			var trigger_position = Global.array_to_vector3(trigger.position)
			if Global.camera.is_position_in_frustum(trigger_position) and \
			is_in_trigger(trigger.id):
				visible_interactives.append(trigger)
				var icon = get_interactive(trigger.id, true)
				icon.position = Global.camera.unproject_position(trigger_position)
				icon.visible = true
				icon.set_active(false)
				if is_closest_trigger(trigger.id):
					icon.set_active(true)
			else:
				var icon = get_interactive(trigger.id, false)
				if icon != null:
					icon.visible = false

func get_interactive(id:String, create:bool):
	if id not in interactive_labels:
		if create:
			var icon:Control = preload("res://ui/interactive_label.tscn").instantiate() as Control
			icon.label_name = id
			interactive_labels[id] = icon
			interactive_labels_control.add_child(icon)
		else:
			return null
		
	return interactive_labels[id]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("action"):
		#print("Action")
		for id in in_trigger:
			execute_trigger("trigger_action", id)
	elif event.is_action_pressed("pepa"):
		say_dialogue("¡¡Pepa!!")
	elif event.is_action_pressed("compicactus"):
		say_dialogue("Compicactus...")

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

func execute_trigger(type:String, trigger_id:String):
	# var index := "%s:%s" % [type, trigger_id]
	# prints(type, id)
	for i in game_state.items:
		for a in i.actions:
			if a.action_id == type and i.trigger_name == trigger_id:
				var l_script = i.logic.new()
				l_script._on_trigger(self, game_state, type, trigger_id)

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

func say_dialogue(text:String) -> void:
	for e in game_state.exchanges:
		if e.id == text:
			for d in e.dialogues:
				dialogue_label.text = tr(d.text.english)
				var tween := create_tween()
				tween.tween_interval(5)
				tween.tween_callback(func():dialogue_label.text = "")
				return
