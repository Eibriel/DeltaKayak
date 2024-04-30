extends Node

#App Ids:
# - Delta Kayak: 2632680
# - Delta Kayak Demo: 2960790
const APP_ID := 2632680

# Steam variables
var is_on_steam_deck: bool = false
var is_online: bool = false
var is_owned: bool = false
#var steam_app_id: int = 480
var steam_id: int = 0
var steam_username: String = ""

var stats = {
	"distance_traveled": 0
}

func _init() -> void:
	# Set your game's Steam app ID here
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))

func _ready() -> void:
	initialize_steam()
	set_test_stats()

func set_test_stats():
	print("set_test_stats")
	Steam.setStatInt("distance_traveled", 10)
	Steam.storeStats()

func _process(_delta: float) -> void:
	Steam.run_callbacks()

func initialize_steam() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx()
	print("Did Steam initialize?: %s " % initialize_response)

	if initialize_response['status'] > 0:
		print("Failed to initialize Steam: %s" % initialize_response)
		return
	
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
	print("This game's ID: %s" % game)
	print("Call result: %s" % result)
	print("This user's Steam ID: %s" % user)
	
	# Get statistics (int) and pass them to variables
	stats["distance_traveled"] = Steam.getStatInt("distance_traveled")
	prints("stats", stats)

func set_rich_presence(token: String) -> void:
	# Set the token
	var setting_presence = Steam.setRichPresence("steam_display", token)
	
	# Tutorial
	# https://www.youtube.com/watch?v=VCwNxfYZ8Cw&t=4762s

	# Debug it
	print("Setting rich presence to "+str(token)+": "+str(setting_presence))
