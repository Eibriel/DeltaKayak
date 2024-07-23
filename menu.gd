extends Control

const locale_names:=[
	"en",
	"es_AR",
	"es_ES"
]

const scene_name = "res://main.tscn"

var _progress := []
var _scene_load_status := 0
var _change_when_ready := false

var black_tween: Tween

func _ready() -> void:
	get_tree().paused = false
	%GameLoadProgressBar.value = 0
	var locale_id := locale_names.find(TranslationServer.get_locale())
	if locale_id != -1:
		%LocaleOption.select(locale_id)
	
	ResourceLoader.load_threaded_request.call_deferred(scene_name)
	
	%StartButton.grab_focus()
	%BlackColor.visible = true
	%BlackColor.modulate.a = 1.0
	black_tween = create_tween()
	black_tween.tween_property(%BlackColor, "modulate:a", 0.0, 1.0)
	

func _process(_delta: float) -> void:
	_scene_load_status = ResourceLoader.load_threaded_get_status(scene_name, _progress)
	var progress_val:float = _progress[0]*100.0
	%GameLoadProgressBar.value = progress_val
	if _scene_load_status == ResourceLoader.THREAD_LOAD_LOADED and _change_when_ready and not %StartButton.disabled:
		%StartButton.disabled = true
		if black_tween:
			black_tween.kill()
		%BlackColor.visible = true
		%BlackColor.modulate.a = 0.0
		black_tween = create_tween()
		black_tween.tween_property(%BlackColor, "modulate:a", 1.0, 1.0)
		black_tween.tween_callback(_change_scene)
		

func _change_scene():
	#print("change_scene")
	var new_scene = ResourceLoader.load_threaded_get(scene_name)
	get_tree().change_scene_to_packed(new_scene)

func _input(event: InputEvent) -> void:
	if event.is_action_released("primary_action"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button:
			focused.emit_signal("button_up")

func _on_start_button_button_up() -> void:
	_change_when_ready = true

func _on_quit_button_button_up() -> void:
	get_tree().quit()


func _on_wishlist_button_button_up() -> void:
	GlobalSteam.open_url("https://store.steampowered.com/app/2632680/Delta_Kayak/?utm_source=demo&utm_content=main_menu")


func _on_newsletter_button_up() -> void:
	GlobalSteam.open_url("https://v3.envialosimple.com/form/renderwidget/format/html/AdministratorID/188603/FormID/1/Lang/en")


func _on_feedback_button_up() -> void:
	GlobalSteam.open_url("https://docs.google.com/forms/d/e/1FAIpQLSeEH74iMRzZYncBLXYzjowi1LvMIpox-LChH5SloNu6NlyM8Q/viewform?usp=sf_link")


func _on_option_button_item_selected(index: int) -> void:
	TranslationServer.set_locale(locale_names[index])


func _on_follow_button_up() -> void:
	GlobalSteam.open_url("https://store.steampowered.com/developer/eibriel/?utm_source=demo&utm_content=main_menu")
