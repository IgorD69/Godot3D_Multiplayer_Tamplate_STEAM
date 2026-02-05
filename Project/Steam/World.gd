extends Node3D

@export var PLAYER_SCENE: PackedScene

var steam_id: int = 0
var lobby_id: int = 0
var max_players := 8
var is_host := false
var local_player_name := ""

@onready var host_button: Button = $UI/Control/Host
@onready var join_button: Button = $UI/Control/Join
@onready var copy_button: Button = $UI/Control/Copy
@onready var control: Control = %Control
@onready var leave_room: Button = %LeaveRoom
@onready var id_label: Label = %JoinInput
@onready var lan_button: Button = $UI/Control/LanButton

func _ready():
	#var init_dict: Dictionary = Steam.steamInit()
	var is_steam_running = Steam.steamInit()
	
	if not is_steam_running:
		printerr("Steam nu a putut fi inițializat! Asigură-te că Steam este deschis.")
		return

	print("Steam inițializat cu succes!")

	print("Steam este activ și rulează!")

	print("Steam inițializat cu succes!")
	var copy_btn = get_node_or_null("%Copy")
	if copy_btn:
		copy_btn.pressed.connect(_on_copy_pressed)

	multiplayer.peer_connected.connect(_on_network_peer_connected)
	multiplayer.peer_disconnected.connect(_on_network_peer_disconnected)

	
	if not is_steam_running:
		print("ATENȚIE: Steam nu rulează. Modul Online (Steam) va fi inactiv, dar LAN va funcționa.")
	else:
		if not Steam.lobby_created.is_connected(_on_lobby_created):
			Steam.lobby_created.connect(_on_lobby_created)
		if not Steam.lobby_joined.is_connected(_on_lobby_joined):
			Steam.lobby_joined.connect(_on_lobby_joined)
		if not Steam.join_requested.is_connected(_on_join_requested):
			Steam.join_requested.connect(_on_join_requested)
		if not Steam.lobby_data_update.is_connected(_on_lobby_data_updated):
			Steam.lobby_data_update.connect(_on_lobby_data_updated)

		steam_id = Steam.getSteamID()
		local_player_name = Steam.getPersonaName()
		# Curățăm label-ul de orice placeholder text
		if id_label:
			id_label.text = ""
			#id_label.placeholder_text = "Lobby ID va apărea aici"
		print("Steam Login succes: ", local_player_name, " (", steam_id, ")")
		update_ui_steam_info()
		
func _process(_delta: float):
	Steam.run_callbacks()

func update_ui_steam_info():
	var label = get_node_or_null("%SteamInfoLabel")
	if label:
		label.text = local_player_name + " (" + str(steam_id) + ")"

# ================= HOST =================

func host_lobby():
	is_host = true
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, max_players)
	#Steam.createLobby()
	print("Sent request to Steam to create lobby...")

func _on_lobby_created(success: int, new_lobby_id: int):
	if success != 1:
		print("Lobby creation failed with code: ", success)
		return
	
	lobby_id = new_lobby_id
	print("✓ Lobby creat cu succes!")
	print("✓ Lobby ID: ", lobby_id)
	print("✓ Copiază acest ID și trimite-l prietenilor:")
	print("   ", lobby_id)
	
	# Afișăm Lobby ID-ul în label
	if id_label:
		id_label.text = str(lobby_id)
	
	Steam.setLobbyData(lobby_id, "name", local_player_name)
	_start_game_as_host()

# ================= JOIN =================

func join_via_overlay():
	Steam.activateGameOverlay("Friends")

func _on_join_requested(lobby: int, friend_id: int):
	print("Join requested from: ", friend_id, " lobby: ", lobby)
	
	# Verificăm dacă suntem deja conectați la acest lobby
	if lobby_id == lobby and multiplayer.multiplayer_peer != null:
		print("⚠️ Deja conectat la acest lobby, ignorăm cererea")
		return
	
	# Verificăm dacă suntem deja în alt lobby
	if multiplayer.multiplayer_peer != null:
		print("⚠️ Deja conectat la un alt lobby, părăsim mai întâi...")
		Steam.leaveLobby(lobby_id)
		multiplayer.multiplayer_peer = null
		await get_tree().create_timer(0.5).timeout
	
	Steam.joinLobby(lobby)

func _on_lobby_joined(new_lobby_id: int, _permissions: int, _locked: bool, response: int):
	print("=== LOBBY_JOINED CALLBACK ===")
	print("Lobby ID: ", new_lobby_id)
	print("Response code: ", response)
	
	if response != 1:
		var error_msg = ""
		match response:
			2: error_msg = "Lobby nu există sau s-a închis"
			3: error_msg = "Nu ai permisiune să intri"
			4: error_msg = "Lobby-ul este plin"
			5: error_msg = "Eroare internă Steam"
			6: error_msg = "Lobby-ul este blocat"
			7: error_msg = "Comunitate banată"
			_: error_msg = "Eroare necunoscută: " + str(response)
		print("❌ Eroare la intrare: ", error_msg)
		return
	
	# Prevenim intrări duble în același lobby
	if lobby_id == new_lobby_id and multiplayer.multiplayer_peer != null:
		print("⚠️ Deja conectat la acest lobby, ignorăm!")
		return
		
	lobby_id = new_lobby_id
	is_host = false
	print("✓ Am intrat în lobby: ", lobby_id)
	
	# Afișăm Lobby ID-ul în label
	if id_label:
		id_label.text = str(lobby_id)
	
	# Verificăm dacă host-ul este gata
	var host_ready = Steam.getLobbyData(lobby_id, "host_ready")
	if host_ready == "true":
		print("✓ Host-ul este deja gata, conectare...")
		_start_game_as_client()
	else:
		print("⏳ Așteptăm ca host-ul să fie gata...")

func _on_lobby_data_updated(updated_lobby_id: int, member_id: int, key: int):
	print("Lobby data updated for lobby: ", updated_lobby_id)
	
	# Verificăm dacă update-ul este pentru lobby-ul nostru și nu suntem deja conectați
	if updated_lobby_id == lobby_id and not is_host and multiplayer.multiplayer_peer == null:
		var host_ready = Steam.getLobbyData(lobby_id, "host_ready")
		if host_ready == "true":
			print("Host-ul este gata! Începem conectarea...")
			_start_game_as_client()

# ============== START GAME =================

func _start_game_as_host():
	print("Starting as HOST")
	
	# Așteptăm un frame pentru ca Steam să finalizeze setup-ul lobby-ului
	await get_tree().process_frame
	
	var peer = SteamMultiplayerPeer.new()
	
	# Încercăm de mai multe ori să creăm host-ul
	var res = ERR_CANT_CREATE
	for attempt in range(5):
		res = peer.create_host(0)
		if res == OK:
			break
		print("Încercare host ", attempt + 1, " eșuată, reîncerc...")
		await get_tree().create_timer(0.2).timeout
	
	if res != OK:
		print("EROARE CRITICĂ: Nu s-a putut crea host-ul Steam după 5 încercări: ", res)
		print("Verifică: 1) Steam rulează? 2) Ai steam_appid.txt? 3) Versiune GodotSteam compatibilă?")
		return
	
	multiplayer.multiplayer_peer = peer
	print("SteamMultiplayerPeer HOST ready")
	print("My multiplayer ID (host): ", multiplayer.get_unique_id())
	
	# IMPORTANT: Semnalizăm că host-ul este gata
	Steam.setLobbyData(lobby_id, "host_ready", "true")
	
	# HOST spawneză propriul player
	await get_tree().process_frame
	spawn_player_rpc.rpc(multiplayer.get_unique_id())

func _start_game_as_client():
	var host_id = Steam.getLobbyOwner(lobby_id)
	if host_id == 0:
		print("Eroare: Host-ul nu a fost găsit încă!")
		return
	
	print("Încercare de conectare la host: ", host_id)
	
	# Așteptăm puțin pentru ca host-ul să fie complet gata
	await get_tree().create_timer(0.3).timeout
	
	var peer = SteamMultiplayerPeer.new()
	var err = peer.create_client(host_id, 0)
	if err != OK:
		print("Eroare la creare client: ", err)
		return
	multiplayer.multiplayer_peer = peer
	print("Client conectat cu succes!")
	print("My multiplayer ID: ", multiplayer.get_unique_id())
	
	# CLIENT NU spawneză propriul player!
	# Host-ul va primi signal peer_connected și va spawneza playerul clientului

# ================= SPAWN PLAYER =================

@rpc("any_peer", "call_local", "reliable")
func spawn_player_rpc(peer_id: int):
	print("=== SPAWNING PLAYER (RPC) ===")
	print("Spawning for peer ID: ", peer_id)
	print("My ID: ", multiplayer.get_unique_id())
	
	# Verificăm dacă playerul există deja
	if has_node(str(peer_id)):
		print("⚠️ Player ", peer_id, " already exists, skipping spawn")
		return
	
	var p = PLAYER_SCENE.instantiate()
	p.name = str(peer_id)
	add_child(p, true)
	p.global_position = Vector3(0, 2, 0)
	
	# Setăm authority
	p.set_multiplayer_authority(peer_id)
	
	print("✓ Player ", peer_id, " spawned with authority: ", p.get_multiplayer_authority())

# Funcție helper pentru a obține numele jucătorului local
func get_player_name() -> String:
	return local_player_name

# ================= UI CALLBACKS =================

func _on_host_pressed() -> void:
	host_lobby()

func _on_join_pressed():
	var input_field = %JoinInput
	if input_field and input_field.text != "":
		var input_text = input_field.text.strip_edges()
		
		print("=== DEBUG JOIN ===")
		print("Text introdus: '", input_text, "'")
		print("Lungime: ", input_text.length())
		
		# Verificăm dacă textul conține doar cifre
		if not input_text.is_valid_int():
			print("❌ ID invalid! Introdu doar cifre (fără text, fără spații)")
			print("   Exemplu corect: 109775240999419806")
			print("   Ai introdus: '", input_text, "'")
			return
		
		# Verificăm dacă este un ID valid de lobby (mai lung de 15 caractere)
		if input_text.length() > 15:
			var target_lobby_id = int(input_text)
			print("✓ Lobby ID convertit: ", target_lobby_id)
			print("✓ Trimit cerere joinLobby...")
			Steam.joinLobby(target_lobby_id)
		else:
			print("❌ ID prea scurt! Lobby ID-ul trebuie să aibă peste 15 caractere.")
			print("   Steam ID (greșit): ~17 caractere")
			print("   Lobby ID (corect): ~18 caractere")
			print("   Ai introdus doar: ", input_text.length(), " caractere")
	else:
		print("Câmp gol - deschid overlay-ul Steam pentru invitații...")
		Steam.activateGameOverlay("Friends")
		
func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_copy_pressed():
	if lobby_id != 0:
		DisplayServer.clipboard_set(str(lobby_id))
		print("Lobby ID copiat în clipboard: ", lobby_id)
		if copy_button:
			var old_text = copy_button.text
			copy_button.text = "Copiat!"
			await get_tree().create_timer(1.5).timeout
			copy_button.text = old_text
	else:
		print("Nu există un ID de lobby pentru a fi copiat!")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		control.visible = !control.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if control.visible else Input.MOUSE_MODE_CAPTURED

func _on_leave_room_pressed():
	Steam.leaveLobby(lobby_id)
	multiplayer.multiplayer_peer = null
	get_tree().reload_current_scene()

func _on_friends_pressed() -> void:
	Steam.activateGameOverlay("Friends")

func _on_lan_button_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	var port = 7777 # Make sure this matches in both calls
	Global.LAN = true
	
	# Try to host first
	var error = peer.create_server(port, max_players)
	if error == OK:
		print("LAN: Server pornit pe portul: ", port)
		multiplayer.multiplayer_peer = peer
		is_host = true
		# Host spawns themselves
		spawn_player_rpc(multiplayer.get_unique_id()) 
		lan_button.text = "LAN (Host Active)"
	else:
		# If hosting fails, try to join
		print("LAN: Port ocupat, încercăm conectarea ca client...")
		error = peer.create_client("127.0.0.1", port)
		if error == OK:
			multiplayer.multiplayer_peer = peer
			is_host = false
			lan_button.text = "LAN (Connected)"
		else:
			print("LAN Error: ", error)

func _on_network_peer_connected(id: int):
	print("=== PEER_CONNECTED SIGNAL ===")
	print("Peer conectat: ", id)
	print("Is server: ", multiplayer.is_server())
	print("My ID: ", multiplayer.get_unique_id())
	print("is_host flag: ", is_host)
	
	if multiplayer.is_server():
		print("✓ Server spawning player for peer: ", id)
		await get_tree().process_frame
		# Spawnăm playerul pentru TOȚI clienții (inclusiv noi)
		spawn_player_rpc.rpc(id)
		
		# IMPORTANT: Trimitem lista cu toți playerii existenți către noul client
		print("Sending existing players to new peer: ", id)
		var existing_players = get_tree().get_nodes_in_group("Players")
		for player in existing_players:
			var player_id = str(player.name).to_int()
			if player_id > 0 and player_id != id:
				print("  - Telling ", id, " about player ", player_id)
				spawn_player_rpc.rpc_id(id, player_id)
	else:
		print("⚠️ Client detected peer connection, ignoring (server will handle)")

func _on_network_peer_disconnected(id: int):
	print("Peer deconectat: ", id)
	var player_to_remove = get_node_or_null(str(id))
	if player_to_remove:
		player_to_remove.queue_free()
