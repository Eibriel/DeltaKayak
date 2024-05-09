extends EditorProperty

func _init() -> void:
	var export_button := Button.new()
	export_button.text = "Export CSV"
	add_child(export_button)
	export_button.pressed.connect(_on_export_csv)

func _on_export_csv():
	var dkdata = get_edited_object() as DKDataResource
	var strings: Dictionary = {}
	get_items_strings(dkdata, strings)
	get_dialogue_strings(dkdata, strings)
	
	var csv_text = "key,es_AR,es_ES,en"
	for s in strings:
		csv_text += "\n%s,\"%s\",," % [s, strings[s].replace("\"", "\"\"")]
	
	var file = FileAccess.open("res://dkdata_strings.csv", FileAccess.WRITE)
	file.store_string(csv_text)
	print(csv_text)

func get_dialogue_strings(dkdata: DKDataResource, strings: Dictionary):
	for e in dkdata.exchanges:
		for d in e.dialogues:
			var key: String = d.resource_scene_unique_id
			if key == "" or key == null:
				push_error("Dialogue '%s' without unique id" % d.text)
				continue
			strings["%s_dialogue_text" % key] = d.text

func get_items_strings(dkdata: DKDataResource, strings: Dictionary):
	for i in dkdata.items:
		var key: String = i.resource_scene_unique_id
		if key == "" or key == null:
			push_error("Item '%s' without unique id" % i.label)
			continue
		strings["%s_item_label" % key] = i.label
		get_actions_strings(i, strings)

func get_actions_strings(item: ItemResource, strings: Dictionary):
	for a in item.actions:
		var key: String = a.resource_scene_unique_id
		if key == "" or key == null:
			push_error("Action '%s' without unique id, in item ''" % [a.label, item.label])
			continue
		strings["%s_action_label" % key] = a.label
