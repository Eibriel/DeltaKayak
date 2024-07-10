extends Node

#App Ids:
# - Delta Kayak: 2632680
# - Delta Kayak Demo: 2960790
const APP_ID := 2632680
const APP_ID_DEMO := 2960790

# Steam variables
var initialized: bool = false
var is_on_steam_deck: bool = false
var is_online: bool = false
var is_owned: bool = false
#var steam_app_id: int = 480
var steam_id: int = 0
var steam_username: String = ""

var stats_ready := false

var _stats = {
	"distance_traveled": 0 #Kilometers
}

var _achievements = {}

var _demo_stats = {
	"distance_traveled": 0 #Kilometers
}

var _demo_achievements = {
	"demo_completed": false
}

var stats: Dictionary

func _init() -> void:
	var current_app_id:int
	if Global.is_demo():
		current_app_id = APP_ID_DEMO
	else:
		current_app_id = APP_ID
	# Set your game's Steam app ID here
	OS.set_environment("SteamAppId", str(current_app_id))
	OS.set_environment("SteamGameId", str(current_app_id))

func _ready() -> void:
	initialize_steam()

func set_stat(stat_name:String, value: Variant):
	if Global.is_demo():
		if not _demo_stats.has(stat_name): return
	else:
		if not _stats.has(stat_name): return
	Steam.setStatInt(stat_name, value)
	Steam.storeStats()

func get_stats() -> Dictionary:
	if Global.is_demo():
		return Dictionary(_demo_stats)
	else:
		return Dictionary(_stats)

func _process(_delta: float) -> void:
	Steam.run_callbacks()

func initialize_steam() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx()
	print("Did Steam initialize?: %s " % initialize_response)

	if initialize_response['status'] > 0:
		print("Failed to initialize Steam: %s" % initialize_response)
		return
	
	initialized = true
	is_on_steam_deck = Steam.isSteamRunningOnSteamDeck()
	is_online = Steam.loggedOn()
	is_owned = Steam.isSubscribed()
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()

	print(is_on_steam_deck)
	print(is_online)
	print(is_owned)
	print(steam_id)
	print(is_owned)
	print(steam_username)
	
	Steam.current_stats_received.connect(_on_steam_stats_ready)

func _on_steam_stats_ready(game: int, result: int, user: int) -> void:
	stats_ready = true
	print("This game's ID: %s" % game)
	print("Call result: %s" % result)
	print("This user's Steam ID: %s" % user)
	
	if Global.is_demo():
		_demo_stats["distance_traveled"] = Steam.getStatInt("distance_traveled")
		prints("demo stats", _demo_stats)
		_demo_achievements["demo_completed"] = get_achievement("demo_completed")
		prints("demo achievements", _demo_achievements)
	else:
		_stats["distance_traveled"] = Steam.getStatInt("distance_traveled")
		prints("stats", _stats)

func get_achievement(value: String) -> bool:
	var this_achievement: Dictionary = Steam.getAchievement(value)
	print(this_achievement)
	# Achievement exists
	if this_achievement['ret']:
		# Achievement is unlocked
		if this_achievement['achieved']:
			return true
		# Achievement is locked
		else:
			return false
	# Achievement does not exist
	else:
		return false

func _fire_Steam_Achievement(value: String) -> void:
	# Set the achievement to an in-game variable
	if Global.is_demo():
		if not _demo_achievements.has(value):
			print("Demo achievement %s don't exist" % value)
			return
		if _demo_achievements[value]: return
		_demo_achievements[value] = true
	else:
		if not _achievements.has(value):
			print("Achievement %s don't exist" % value)
			return
		if _achievements[value]: return
		_achievements[value] = true
	# Pass the value to Steam then fire it
	Steam.setAchievement(value)
	Steam.storeStats()

func set_rich_presence(token: String) -> void:
	# Set the token
	var setting_presence = Steam.setRichPresence("steam_display", token)
	
	# Tutorial
	# https://www.youtube.com/watch?v=VCwNxfYZ8Cw&t=4762s

	# Debug it
	print("Setting rich presence to "+str(token)+": "+str(setting_presence))

func open_url(url:String) -> void:
	if initialized:
		Steam.activateGameOverlayToWebPage(url) #, Steam.OVERLAY_TO_WEB_PAGE_MODE_MODAL)
	else:
		OS.shell_open(url)
