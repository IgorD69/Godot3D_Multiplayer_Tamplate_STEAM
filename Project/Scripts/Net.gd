extends Node

var is_host: bool = false
var lobby_id: int = 0
var max_players: int = 8

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# În Net.gd (Singleton)

func start_steam_client(p_lobby_id: int):
	var host_id = Steam.getLobbyOwner(p_lobby_id)
	var peer = SteamMultiplayerPeer.new()
	
	var res = peer.create_client(host_id, 0)
	if res == OK:
		multiplayer.multiplayer_peer = peer
		is_host = false
		get_tree().change_scene_to_file("res://Scene/Factory.tscn")
	else:
		print("Eroare Client Steam: ", res)
		
		
func host_spawn_sequence():
	# Aici get_tree() nu va fi NICIODATĂ null pentru că Net e Autoload
	await get_tree().process_frame
	
	# Verificăm dacă suntem server și dacă avem peer valid
	if multiplayer.multiplayer_peer and multiplayer.is_server():
		var my_id = multiplayer.get_unique_id()
		print("Singleton: Spawning host with ID: ", my_id)
		spawn_player(my_id) # Apelăm direct funcția locală
		
		
func _on_peer_connected(id: int):
	print("Peer connected în Singleton: ", id)
	if multiplayer.is_server():
		# Așteptăm să fim siguri că scena Factory s-a încărcat la client
		await get_tree().create_timer(1.5).timeout
		spawn_player.rpc(id)
		
		# Sincronizăm jucătorii deja existenți pentru noul peer
		for p in get_tree().get_nodes_in_group("Players"):
			var pid = str(p.name).to_int()
			if pid != id:
				spawn_player.rpc_id(id, pid)

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)
	var p = get_tree().current_scene.get_node_or_null("Map/Players/" + str(id))
	if p: p.queue_free()

func _on_server_disconnected():
	cleanup_network()
	get_tree().change_scene_to_file("res://Scene/MainScreen.tscn")

# ACEASTA ESTE FUNCȚIA CARE SPAWNEAZĂ
@rpc("any_peer", "call_local", "reliable")
func spawn_player(peer_id: int):
	var scene = get_tree().current_scene
	# IMPORTANT: Verifică dacă în Factory.tscn ierarhia este Map -> Players
	var container = scene.get_node_or_null("Map/Players")
	
	if not container:
		print("EROARE: Nu am găsit containerul Map/Players în scena curentă!")
		return
		
	if container.has_node(str(peer_id)):
		return
	
	var player_scene = load("res://Scene/Player.tscn")
	var p = player_scene.instantiate()
	p.name = str(peer_id)
	container.add_child(p)
	p.global_position = Vector3(0, 5, 0) # Ajustează în funcție de harta ta
	print("Player spawnat cu succes pentru ID: ", peer_id)

# FUNCȚII AJUTĂTOARE PENTRU STEAM
func start_steam_host():
	var peer = SteamMultiplayerPeer.new()
	var res = peer.create_host(0)
	if res == OK:
		multiplayer.multiplayer_peer = peer
		is_host = true
		return true
	return false

func cleanup_network():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if lobby_id != 0:
		Steam.leaveLobby(lobby_id)
		lobby_id = 0
	is_host = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
