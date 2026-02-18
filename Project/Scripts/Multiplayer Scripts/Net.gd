extends Node

var is_host: bool = false
var lobby_id: int = 0
var max_players: int = 8
var spawned_peers: Array = [] # Listă ca să nu spawnăm același om de două ori

func _ready():
	# Conectarea semnalelor esențiale de rețea
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _process(_delta: float):
	Steam.run_callbacks() 
	
# --- LOGICA DE CONECTARE ---

func start_steam_host():
	var peer = SteamMultiplayerPeer.new()
	# Optional: peer.set_allow_p2p_connections(true) pentru a ajuta trecerea de firewall-uri
	
	var res = peer.create_host(0) # Portul virtual Steam este 0
	if res == OK:
		multiplayer.multiplayer_peer = peer
		is_host = true
		spawned_peers.clear()
		print("HOST: Steam host pornit cu succes")
		return true
	print("HOST: Eroare la pornirea host-ului: ", res)
	return false

	Steam.setRichPresence("connect", "--connect-lobby=" + str(lobby_id))
	print("Rich Presence setat pentru Join direct.")

func start_steam_client(p_lobby_id: int):
	var host_id = Steam.getLobbyOwner(p_lobby_id)
	print("CLIENT: Încerc să mă conectez la host_id: ", host_id)
	
	var peer = SteamMultiplayerPeer.new()
	# Optional: peer.set_allow_p2p_connections(true)
	
	var res = peer.create_client(host_id, 0)
	if res == OK:
		multiplayer.multiplayer_peer = peer
		is_host = false
		spawned_peers.clear()
		print("CLIENT: Peer creat cu succes, schimb scena")
		get_tree().change_scene_to_packed(Global.FACTORY_SCENE_PATH)
	else:
		print("CLIENT: Eroare Steam: ", res)

# --- LOGICA DE SPAWN ---

func host_spawn_sequence():
	print("HOST_SPAWN: Începe secvența de spawn pentru host")
	# Așteptăm un frame pentru ca scena să fie complet în arborele de noduri
	await get_tree().process_frame
	if multiplayer.is_server():
		print("HOST_SPAWN: Sunt server, spawn-ez peer 1")
		spawn_player(1) # Host-ul are întotdeauna ID-ul de rețea 1
		if not 1 in spawned_peers:
			spawned_peers.append(1)
		print("HOST_SPAWN: Terminat. spawned_peers = ", spawned_peers)

@rpc("any_peer", "call_local", "reliable")
func notify_client_ready():
	print("NOTIFY: Apel primit. is_server=", multiplayer.is_server())
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1
	
	if sender_id in spawned_peers:
		print("NOTIFY: Peer-ul ", sender_id, " deja spawnat, ignor")
		return
	
	print("SERVER: Peer-ul ", sender_id, " este gata. Trimit comanda de spawn.")
	spawned_peers.append(sender_id)
	
	# 1. Comandă de spawn pentru toți jucătorii conectați
	spawn_player.rpc(sender_id)
	
	# 2. Trimite noului jucător datele despre jucătorii care erau deja prezenți
	for old_peer_id in spawned_peers:
		if old_peer_id != sender_id:
			print("SERVER: Trimit către ", sender_id, " info despre peer ", old_peer_id)
			spawn_player.rpc_id(sender_id, old_peer_id)

@rpc("any_peer", "call_local", "reliable")
func spawn_player(peer_id: int):
	print("SPAWN_PLAYER: Apel pentru peer_id=", peer_id) 
	var container = get_tree().get_first_node_in_group("SpawnContainer")
	
	if not container:
		print("SPAWN_PLAYER: Container nu găsit, aștept 0.1s ")
		await get_tree().create_timer(0.1).timeout
		container = get_tree().get_first_node_in_group("SpawnContainer")
	
	if not container:
		print("SPAWN_PLAYER: EROARE - Containerul Players nu a fost găsit! ")
		return
	
	if container.has_node(str(peer_id)):
		return 
	
	var player_scene = load("res://Scene/Player Scene/Player.tscn")
	var p = player_scene.instantiate()
	p.name = str(peer_id) # Nodul trebuie să poarte numele ID-ului pentru sincronizare 
	
	container.add_child(p)
	p.set_multiplayer_authority(peer_id) 
	
	# Poziționare inițială 
	p.global_position = Vector3(randf_range(-1, 1), 10, randf_range(-1, 1))
	print("SPAWN_PLAYER: Jucător ", peer_id, " spawnat cu succes ")

# --- SEMNALE REȚEA ---

func _on_peer_connected(id: int):
	print("SIGNAL: Peer conectat la nivel de rețea: ", id) 

func _on_connected_to_server():
	print("SIGNAL: CLIENT conectat la server cu succes! ")

func _on_peer_disconnected(id: int):
	print("SIGNAL: Peer deconectat: ", id) 
	if id in spawned_peers:
		spawned_peers.erase(id) 
	
	var container = get_tree().get_first_node_in_group("SpawnContainer")
	if container and container.has_node(str(id)):
		container.get_node(str(id)).queue_free() 

func _on_server_disconnected():
	cleanup_network() 
	get_tree().change_scene_to_packed(Global.MAIN_SCREEN)

func cleanup_network():
	print("CLEANUP: Curăț rețeaua ")
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null 
	
	spawned_peers.clear() 
	is_host = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE 
	
	# Elimină eventualele meniuri rămase active 
	for child in get_tree().root.get_children():
		if child.name == "EscMenu":
			child.queue_free()
