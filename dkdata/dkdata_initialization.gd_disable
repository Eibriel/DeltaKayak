
var current_item: ItemResource
var current_action: ActionResource
var current_exchange: DialogueExchangeResource
var current_dialogue: DialogueResource
var dkdata: DKDataResource

enum Lang {
	EN,
	ES_LA,
	ES_ES,
	ES # Apply to both spanishs
}

func initialize_data(_dkdata: DKDataResource):
	dkdata = _dkdata
	dkdata.character_position = Vector3(80, 15, 50)
	dkdata.character_rotation = Vector3(0, 180, 0)
	
	add_item("capybara", "trigger_001_001")
	#set_logic(preload("res://interactives/capybara.gd"))
	set_label(Lang.EN, "Capybara")
	set_label(Lang.ES, "Carpincho")
	add_action("trigger_action")
	set_action_label(Lang.EN, "Pet")
	set_action_label(Lang.ES, "Acariciar")
	
	add_exchange("capybara1")
	add_dialogue("capybara")
	set_dl_text(Lang.EN, "Hi there!")
	set_dl_text(Lang.ES, "Hola!")
	
	
	

func set_dl_text(lang: Lang, label: String):
	current_dialogue.text = set_int_text(current_dialogue.text, lang, label)

func add_dialogue(character: String):
	var new_dialogue := DialogueResource.new()
	new_dialogue.character = character
	current_exchange.dialogues.append(new_dialogue)
	current_dialogue = new_dialogue

func add_exchange(id: String) -> DialogueExchangeResource:
	var new_exchange := DialogueExchangeResource.new()
	new_exchange.id = id
	dkdata.exchanges.append(new_exchange)
	current_exchange = new_exchange
	return new_exchange

func set_logic(script: Script):
	current_item.logic = script

func add_action(id: String) -> ActionResource:
	var new_action := ActionResource.new()
	new_action.action_id = id
	current_action = new_action
	current_item.actions.append(new_action)
	return new_action

func add_item(id: String, trigger: String) -> ItemResource:
	current_item = ItemResource.new()
	dkdata.items.append(current_item)
	current_item.id = id
	current_item.active = true
	current_item.trigger_name = trigger
	return current_item

func set_action_label(lang: Lang, label: String) -> void:
	current_action.label = set_int_text(current_action.label, lang, label)

func set_label(lang: Lang, label: String) -> void:
	current_item.label = set_int_text(current_item.label, lang, label)

func set_int_text(int_text: IntTextResource, lang: Lang, label: String) -> IntTextResource:
	if int_text == null:
		int_text = IntTextResource.new()
	match lang:
		Lang.EN:
			int_text.english = label
		Lang.ES_LA:
			int_text.spanish_latam = label
		Lang.ES_ES:
			int_text.spanish_spain = label
		Lang.ES:
			int_text.spanish_latam = label
			int_text.spanish_spain = label
	return int_text
