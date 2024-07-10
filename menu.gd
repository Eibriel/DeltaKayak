extends Control

const locale_names:=[
	"en",
	"es_AR",
	"es_ES"
]

func _ready() -> void:
	get_tree().paused = false
	var locale_id := locale_names.find(TranslationServer.get_locale())
	if locale_id != -1:
		%LocaleOption.select(locale_id)

func _on_start_button_button_up() -> void:
	get_tree().change_scene_to_packed(load("res://main.tscn"))


func _on_quit_button_button_up() -> void:
	get_tree().quit()


func _on_wishlist_button_button_up() -> void:
	GlobalSteam.open_url("https://store.steampowered.com/app/2632680/Delta_Kayak/")


func _on_newsletter_button_up() -> void:
	GlobalSteam.open_url("https://v3.envialosimple.com/form/renderwidget/format/html/AdministratorID/188603/FormID/1/Lang/en")


func _on_feedback_button_up() -> void:
	GlobalSteam.open_url("https://docs.google.com/forms/d/e/1FAIpQLSeEH74iMRzZYncBLXYzjowi1LvMIpox-LChH5SloNu6NlyM8Q/viewform?usp=sf_link")


func _on_option_button_item_selected(index: int) -> void:
	TranslationServer.set_locale(locale_names[index])
