extends Control

func _ready() -> void:
	get_tree().paused = false

func _on_start_button_button_up() -> void:
	get_tree().change_scene_to_packed(load("res://main.tscn"))


func _on_quit_button_button_up() -> void:
	get_tree().quit()


func _on_wishlist_button_button_up() -> void:
	GlobalSteam.open_url("https://store.steampowered.com/app/2632680/Delta_Kayak/")


func _on_newsletter_button_up() -> void:
	GlobalSteam.open_url("https://v3.envialosimple.com/form/renderwidget/format/html/AdministratorID/188603/FormID/1/Lang/en")
