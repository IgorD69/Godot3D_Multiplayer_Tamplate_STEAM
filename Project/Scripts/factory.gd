extends Node3D

@onready var players_container: Node = $Players

func _ready():
	print("FACTORY: _ready() apelat")
	
	# 1. Ne asigurăm că grupul este setat imediat
	if not players_container.is_in_group("SpawnContainer"):
		players_container.add_to_group("SpawnContainer")
		print("FACTORY: Players adăugat în grupul SpawnContainer")
	
	# 2. Logica separată pentru Server și Client
	if multiplayer.is_server():
		_setup_server()
	else:
		_setup_client()

func _setup_server():
	print("FACTORY: Sunt server (ID 1)")
	# Așteptăm un frame pentru a ne asigura că arborele de noduri este gata
	await get_tree().process_frame
	
	if not 1 in Net.spawned_peers:
		print("FACTORY: Host-ul nu este spawnat, pornesc secvența")
		Net.host_spawn_sequence()
	else:
		print("FACTORY: Host-ul este deja în listă")

func _setup_client():
	print("FACTORY: Sunt client (ID: ", multiplayer.get_unique_id(), ")")
	
	# Așteptăm stabilizarea conexiunii Steam Relay
	var connected = false
	for i in range(10): # Încercăm timp de 10 secunde
		var status = multiplayer.multiplayer_peer.get_connection_status()
		
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			print("FACTORY: Conexiune stabilă stabilită!")
			connected = true
			break
			
		print("FACTORY: Status conexiune: ", status, " (se așteaptă CONNECTION_CONNECTED/2)...")
		await get_tree().create_timer(1.0).timeout
	
	if connected:
		print("FACTORY: Trimit notify_client_ready către server")
		Net.notify_client_ready.rpc_id(1)
	else:
		print("FACTORY: EROARE - Conexiunea nu s-a stabilizat în timp util!")
