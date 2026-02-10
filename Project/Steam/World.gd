extends Control

@export var PLAYER_SCENE: PackedScene # Îl poți păstra dacă vrei referință aici, dar Net.gd se ocupă de spawn
const FACTORY_SCENE_PATH = "res://Scene/Factory.tscn"

var settings_instance = null
@export var SETTINGS_SCENE: PackedScene = preload("uid://dsr4sx6v6qsiv")

var steam_id: int = 0
var lobby_id: int = 0
var max_players := 8
var is_host := false
var local_player_name := ""

@onready var id_label: Label = %JoinInput

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Conectăm doar semnalele esențiale. Restul sunt în Net.gd
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	var is_steam_running = Steam.steamInit()
	if not is_steam_running:
		printerr("Steam error!")
		return

	# Steam Signals	
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.join_requested.connect(_on_join_requested)
	Steam.lobby_data_update.connect(_on_lobby_data_updated)

	steam_id = Steam.getSteamID()
	local_player_name = Steam.getPersonaName()
	if id_label: id_label.text = ""
	update_ui_steam_info()
		
func _process(_delta: float):
	Steam.run_callbacks()


func _on_server_disconnected():
	# Redirecționăm curățarea către Singleton
	Net.cleanup_network()
	get_tree().change_scene_to_file("res://Scene/MainScreen.tscn")
	
func update_ui_steam_info():
	var label = get_node_or_null("%SteamInfoLabel")
	if label: label.text = local_player_name + " (" + str(steam_id) + ")"

# ================= HOST & JOIN =================

func host_lobby():
	is_host = true
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, max_players)

func _on_lobby_created(success: int, new_lobby_id: int):
	if success != 1: return
	lobby_id = new_lobby_id
	if id_label: id_label.text = str(lobby_id)
	Steam.setLobbyData(lobby_id, "name", local_player_name)
	_start_game_as_host()

func _on_join_requested(lobby: int, _friend_id: int):
	Steam.joinLobby(lobby)

func _on_lobby_joined(new_lobby_id: int, _permissions: int, _locked: bool, response: int):
	if response != 1: return
	lobby_id = new_lobby_id
	is_host = false
	if id_label: id_label.text = str(lobby_id)
	
	if Steam.getLobbyData(lobby_id, "host_ready") == "true":
		_start_game_as_client()

func _on_lobby_data_updated(updated_lobby_id: int, _member_id: int, _key: int):
	if updated_lobby_id == lobby_id and not is_host and multiplayer.multiplayer_peer == null:
		if Steam.getLobbyData(lobby_id, "host_ready") == "true":
			_start_game_as_client()

# ============== NETWORKING CORE =================

func _start_game_as_host():
	if Net.start_steam_host():
		Steam.setLobbyData(lobby_id, "host_ready", "true")
		get_tree().change_scene_to_file(FACTORY_SCENE_PATH)
		# Singleton-ul se ocupă de restul
		Net.host_spawn_sequence()

func _start_game_as_client():
	Net.start_steam_client(lobby_id)

# ================= UI BUTTONS =================

func _on_host_pressed() -> void:
	host_lobby()

func _on_join_pressed():
	if %JoinInput.text != "":
		Steam.joinLobby(int(%JoinInput.text))

func _on_copy_pressed():
	if lobby_id != 0:
		DisplayServer.clipboard_set(str(lobby_id))

func _on_leave_room_pressed():
	# Totul se curăță prin Singleton
	Net.cleanup_network()
	if lobby_id != 0:
		Steam.leaveLobby(lobby_id)
		lobby_id = 0
	get_tree().change_scene_to_file("res://Scene/MainScreen.tscn")

func _on_lan_button_pressed() -> void:
	Net.cleanup_network()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(7777, 8)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		Net.is_host = true
		get_tree().change_scene_to_file(FACTORY_SCENE_PATH)
		Net.host_spawn_sequence() # Adăugat și aici pentru LAN
	else:
		var client_peer = ENetMultiplayerPeer.new()
		if client_peer.create_client("127.0.0.1", 7777) == OK:
			multiplayer.multiplayer_peer = client_peer
			Net.is_host = false
			get_tree().change_scene_to_file(FACTORY_SCENE_PATH)

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_settings_pressed() -> void:
	if not is_instance_valid(settings_instance):
		settings_instance = SETTINGS_SCENE.instantiate()
		add_child(settings_instance)

func _on_friends_pressed() -> void:
	Steam.activateGameOverlay("friends")
