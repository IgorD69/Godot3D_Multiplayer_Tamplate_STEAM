extends Node3D

#@export var PLAYER_SCENE = preload("uid://bb3qcv0kbqbo6")
@export var PLAYER_SCENE = preload("uid://bb3qcv0kbqbo6")

#signal Send_Name_to_Label(str)

var showCanvas = true

@onready var ui: CanvasLayer = $UI
@onready var control: Control = %Control
@onready var id_label: Label = %IDLabel

var peer: NodeTunnelPeer

func _ready() -> void:
	
	peer = NodeTunnelPeer.new()
	#peer.debug_enabled = true # Enable debugging if needed
	
	# Always set the global peer *before* attempting to connect
	multiplayer.multiplayer_peer = peer
	
	# Connect to the public relay
	peer.connect_to_relay("relay.nodetunnel.io", 9998)
	
	# Wait until we have connected to the relay
	await peer.relay_connected
	
	# Attach peer_connected signal
	peer.peer_connected.connect(_add_player)
	
	# Attach peer_disconnected signal
	peer.peer_disconnected.connect(_remove_player)
	
	# Attach room_left signal
	peer.room_left.connect(_show_main_menu)
	
	# At this point, we can access the online ID that the server generated for us
	%IDLabel.text = peer.online_id

func _on_host_pressed() -> void:
	print("Online ID: ", peer.online_id)
	
	# Host a game, must be done *after* relay connection is made
	peer.host()
	
	# Copy online id to clipboard
	DisplayServer.clipboard_set(peer.online_id)
	
	# Wait until peer has started hosting
	await peer.hosting
	
	# Spawn the host player
	_add_player()
	
	# Hide the UI
	%Control.hide()
	
func _on_join_pressed() -> void:
	peer.join(%HostID.text)
	
	# Wait until peer has finished joining
	await peer.joined
	
	# Hide the UI
	%Control.hide()
	
	# Show leave room button
	#%LeaveRoom.show()

func _add_player(peer_id: int = 1) -> void:
	if !multiplayer.is_server(): return
	
	print("Player Joined: ", peer_id)
	var player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	#Send_Name_to_Label.emit("peer_id")
	# IMPORTANT: Set authority BEFORE adding to tree
	player.set_multiplayer_authority(peer_id)
	
	var spawn_position = Vector3(randf_range(-5, 5), 2, randf_range(-5, 5))
	player.position = spawn_position
	
	add_child(player)
	
	print("Player spawned at: ", spawn_position, " with authority: ", peer_id)
	

func _remove_player(peer_id: int) -> void:
	if !multiplayer.is_server(): return
	
	var player = get_node(str(peer_id))
	player.queue_free()

func _on_leave_room_pressed() -> void:
	peer.leave_room()
	
func _show_main_menu() -> void:
	showCanvas = !showCanvas
	
	if showCanvas:
		%Control.show()
		# Eliberăm mouse-ul pentru a putea da click pe butoane
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		%Control.hide()
		# Blocăm mouse-ul în centrul ecranului pentru a roti camera
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	

func _on_button_pressed() -> void:
	DisplayServer.clipboard_set(id_label.text.replace("Your ID: ", ""))
	print("Copied ID to clipboard:", DisplayServer.clipboard_get())

func _on_exit_button_pressed() -> void:
	get_tree().quit()


#func _ready() -> void:
	#control.visible = false
	
	
func _input(event: InputEvent) -> void:
	
	if event.is_action_pressed("force_close"):
		get_tree().quit()
		
	if event.is_action_pressed("esc"):
		_show_main_menu()
		
func _on_menu_pressed() -> void:
	ui.visible = true
	_on_leave_room_pressed()
