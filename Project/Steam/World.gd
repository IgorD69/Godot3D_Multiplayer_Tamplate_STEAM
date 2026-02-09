extends Control

@export var PLAYER_SCENE: PackedScene

const FACTORY_SCENE_PATH = "res://Scene/Factory.tscn"

var settings_instance = null
@export var SETTINGS_SCENE: PackedScene = preload("uid://dsr4sx6v6qsiv")

@export var SETTINGS_MENU: PackedScene

var steam_id: int = 0
var lobby_id: int = 0
var max_players := 8
var is_host := false
var local_player_name := ""

@onready var control: Control = %Control
@onready var id_label: Label = %JoinInput
@onready var copy_button: Button = $UI/Multiplayer/Copy

func _ready():
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	multiplayer.peer_connected.connect(_on_network_peer_connected)
	multiplayer.peer_disconnected.connect(_on_network_peer_disconnected)
	
	var is_steam_running = Steam.steamInit()
	if not is_steam_running:
		printerr("Steam error!")
		return

	#multiplayer.peer_connected.connect(_on_network_peer_connected)
	#multiplayer.peer_disconnected.connect(_on_network_peer_disconnected)

	# ACESTA ESTE SEMNALUL CRITIC PENTRU CLIENT:
	#multiplayer.server_disconnected.connect(_on_server_disconnected)

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
	print("Conexiunea cu host-ul s-a pierdut! Revenire la meniu...")
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# 2. Resetăm stările locale
	is_host = false
	lobby_id = 0
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	get_tree().call_deferred("change_scene_to_file", "res://Scene/MainScreen.tscn")
	
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
	
	var host_ready = Steam.getLobbyData(lobby_id, "host_ready")
	if host_ready == "true":
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
		Net.host_spawn_sequence()
		
		
func _spawn_host_delayed():
	# Așteptăm ca scena Factory să devină 'current_scene'
	await get_tree().process_frame
	# Host-ul are mereu ID-ul 1 (sau ID-ul său de Steam)
	Net.spawn_player.rpc(multiplayer.get_unique_id())
	
	
func _start_game_as_client():
	Net.start_steam_client(lobby_id)

func _change_to_game_scene():
	get_tree().change_scene_to_file(FACTORY_SCENE_PATH)

func _on_network_peer_connected(id: int):
	if multiplayer.is_server():
		var timer = get_tree().create_timer(1.5)
		timer.timeout.connect(func(): 
			if multiplayer.multiplayer_peer:
				spawn_player_rpc.rpc(id)
				# Trimitem și ceilalți jucători
				for p in get_tree().get_nodes_in_group("Players"):
					var pid = str(p.name).to_int()
					if pid != id:
						spawn_player_rpc.rpc_id(id, pid)
		)

func _on_network_peer_disconnected(id: int):
	var p = get_node_or_null(str(id))
	if p: p.queue_free()

# ================= SPAWN PLAYER =================

@rpc("any_peer", "call_local", "reliable")
func spawn_player_rpc(peer_id: int):
	# Obținem scena curentă (Factory)
	var current_scene = get_tree().current_scene
	
	# Verificăm dacă suntem în scena corectă
	if current_scene.name != "Factory":
		print("Nu suntem în Factory, așteptăm...")
		return

	# Căutăm containerul 'Players'. 
	# Dacă în Factory ai un nod 'Map' și sub el 'Players', folosește "Map/Players"
	var container = current_scene.get_node_or_null("Players") 
	if not container:
		container = current_scene # Fallback pe rădăcina scenei
	
	if container.has_node(str(peer_id)):
		return
		
	var p = PLAYER_SCENE.instantiate()
	p.name = str(peer_id)
	container.add_child(p)
	
	p.global_position = Vector3(0, 5, 0)
# ================= UI & UTILS =================

func _on_host_pressed() -> void:
	host_lobby()

func _on_join_pressed():
	if %JoinInput.text != "":
		Steam.joinLobby(int(%JoinInput.text))

func _on_copy_pressed():
	if lobby_id != 0:
		DisplayServer.clipboard_set(str(lobby_id))

func _on_leave_room_pressed():
	# CURĂȚARE CORECTĂ:
	# 1. Ștergem jucătorii local mai întâi pentru a opri sincronizatorii
	for p in get_tree().get_nodes_in_group("Players"):
		p.queue_free()
	
	# 2. Oprim peer-ul
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# 3. Reset Steam
	if lobby_id != 0:
		Steam.leaveLobby(lobby_id)
		lobby_id = 0
	
	get_tree().change_scene_to_file("res://Scene/MainScreen.tscn")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_lan_button_pressed() -> void:
	Net.cleanup_network() # Curățăm totul prin Singleton
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(7777, 8)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		Net.is_host = true
		get_tree().change_scene_to_file("res://Scene/Factory.tscn")
		# Nu punem await aici! Singleton-ul va detecta schimbarea.
	else:
		var client_peer = ENetMultiplayerPeer.new()
		if client_peer.create_client("127.0.0.1", 7777) == OK:
			multiplayer.multiplayer_peer = client_peer
			Net.is_host = false
			get_tree().change_scene_to_file("res://Scene/Factory.tscn")
	


func _on_exit_button_pressed() -> void:
	get_tree().quit()



func _on_settings_pressed() -> void:
	if not is_instance_valid(settings_instance):
		settings_instance = SETTINGS_SCENE.instantiate()
		add_child(settings_instance)
		
		settings_instance.tree_exited.connect(func(): settings_instance = null)
