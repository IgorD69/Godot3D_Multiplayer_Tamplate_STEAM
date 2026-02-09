extends Node3D

@export var PLAYER_SCENE: PackedScene = preload("res://Scene/Player.tscn")

@onready var players_container: Node3D = $Players
#@onready var players_container = $Players
@onready var spawner = $MultiplayerSpawner

func _ready():
	# Configurăm spawner-ul programatic (sau din Editor)
	spawner.spawn_path = players_container.get_path()
	spawner.add_spawnable_scene(PLAYER_SCENE.resource_path)
	
	# Dacă suntem serverul, spawnăm jucătorii care sunt deja conectați
	# (Inclusiv pe noi înșine)
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		# Spawn pentru Host
		_spawn_player(multiplayer.get_unique_id())
		
		# Spawn pentru clienții care s-au conectat în timp ce se încărca harta
		for id in multiplayer.get_peers():
			_spawn_player(id)

func _on_peer_connected(id: int):
	# Doar serverul spawnează, MultiplayerSpawner replică automat pe clienți
	_spawn_player.call_deferred(id)




func _spawn_player(id: int):
	if players_container.has_node(str(id)):
		return
		
	var p = PLAYER_SCENE.instantiate()
	p.name = str(id)
	players_container.add_child(p, true)
	
	# Setăm poziția (poți folosi SpawnPoints aici)
	p.global_position = Vector3(0, 5, 0) 
	
	print("Spawned player for ID: ", id)

func _on_peer_disconnected(id: int):
	if players_container.has_node(str(id)):
		players_container.get_node(str(id)).queue_free()
