extends Node

enum InteractionType { DEFAULT, DOOR, SWITCH, LAPTOP }

@export var object_referance: Node3D
@export var interaction_type: InteractionType = InteractionType.DEFAULT
@export var maximum_rotation: float = 110
@export var pivit_point: Node3D
@export var nodes_to_affect: Array[Node]

var can_interact: bool = true
var is_interacting: bool = false
var lock_camera: bool = false
var starting_rotation: float
var is_front: bool
var player_hand: Marker3D
var was_opened: bool = false
var is_focused: bool = false

func _ready() -> void:
	match interaction_type:
		InteractionType.DOOR:
			starting_rotation = pivit_point.rotation.y
		InteractionType.SWITCH:
			starting_rotation = object_referance.rotation.z
		InteractionType.LAPTOP:
			starting_rotation = pivit_point.rotation.z

func _physics_process(_delta: float) -> void:
	if is_interacting and interaction_type == InteractionType.DEFAULT:
		if object_referance:
			# Dacă NU suntem serverul, trimitem poziția noastră către server constant
			if not multiplayer.is_server():
				update_remote_position.rpc(object_referance.global_position, object_referance.global_rotation)
			
			# Aplicăm mișcarea locală
			if object_referance.is_multiplayer_authority() or not multiplayer.is_server():
				_default_interact()

@rpc("any_peer", "unreliable")
func update_remote_position(pos: Vector3, rot: Vector3) -> void:
	# Serverul primește poziția de la client și o forțează pe obiectul său local
	if multiplayer.is_server():
		object_referance.global_position = pos
		object_referance.global_rotation = rot

# --- FUNCȚII APELATE DE CONTROLLER ---

func preInteract() -> void:
	is_interacting = true
	match interaction_type:
		InteractionType.DEFAULT:
			# Gasim mana jucatorului LOCAL
			for player in get_tree().get_nodes_in_group("Players"):
				if player.is_multiplayer_authority():
					player_hand = player.find_child("hand", true, false)
					break
		InteractionType.DOOR, InteractionType.SWITCH, InteractionType.LAPTOP:
			lock_camera = true

func Interact() -> void:
	pass

func auxInteract() -> void:
	if not can_interact or not is_interacting:
		return
	match interaction_type:
		InteractionType.DEFAULT:
			_default_throw()

func postInteract() -> void:
	if is_interacting and interaction_type == InteractionType.DEFAULT:
		# Așteptăm un frame de fizică pentru a ne asigura că poziția finală a fost trimisă
		await get_tree().physics_frame
		release_authority.rpc()
		
	is_interacting = false
	lock_camera = false
	player_hand = null

func set_direction(_normal: Vector3) -> void:
	for player in get_tree().get_nodes_in_group("Players"):
		if player.is_multiplayer_authority():
			if object_referance:
				var to_player = (player.global_position - object_referance.global_position).normalized()
				is_front = to_player.dot(_normal) > 0
			break

# --- LOGICA DEFAULT (CUBURI) ---

func _default_interact() -> void:
	if player_hand == null or object_referance == null: return
	var object_distance: Vector3 = player_hand.global_transform.origin - object_referance.global_transform.origin
	var rigid_body_3d: RigidBody3D = object_referance as RigidBody3D
	if rigid_body_3d:
		# Seteaza viteza pentru a urmari mana
		rigid_body_3d.linear_velocity = object_distance * 25.0

func _default_throw() -> void:
	if player_hand == null or object_referance == null: return
	var rigid_body_3d = object_referance as RigidBody3D
	if rigid_body_3d:
		var throw_direction: Vector3 = -player_hand.global_transform.basis.z.normalized()
		var throw_strength: float = 90.0 / rigid_body_3d.mass
		
		# REPARAT: Trimitem și poziția globală unde se află obiectul în mână
		server_throw.rpc(throw_direction, throw_strength, object_referance.global_position)
	postInteract()

# --- MULTIPLAYER LOGIC ---

@rpc("any_peer", "call_local", "reliable")
func request_authority() -> void:
	if multiplayer.is_server():
		_set_node_authority(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_local", "reliable")
func release_authority() -> void:
	if multiplayer.is_server():
		_set_node_authority(1)
		
func _set_node_authority(id: int) -> void:
	if object_referance == null: return
	
	object_referance.set_multiplayer_authority(id)
	#var sync_node = object_referance.get_node_or_null("MultiplayerSynchronizer")
	#if sync_node:
		#sync_node.set_multiplayer_authority(id)
	
	if object_referance is RigidBody3D:
		if id != 1: # Un client îl ține
			object_referance.freeze = true 
			object_referance.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		else: # Serverul îl are înapoi
			object_referance.freeze = false

@rpc("any_peer", "call_local", "reliable")
func server_throw(direction: Vector3, strength: float, final_pos: Vector3) -> void:
	if multiplayer.is_server():
		_set_node_authority(1)
		
		var rigid_body_3d: RigidBody3D = object_referance as RigidBody3D
		if rigid_body_3d:
			rigid_body_3d.global_position = final_pos
			
			rigid_body_3d.linear_velocity = direction * strength


func open_or_close() -> void:
	sync_open_close.rpc(!was_opened)

@rpc("any_peer", "call_local", "reliable")
func sync_open_close(new_state: bool) -> void:
	was_opened = new_state
	if was_opened: pivit_point.rotation.y = starting_rotation + deg_to_rad(110)
	else: pivit_point.rotation.y = starting_rotation

func _focus() -> void: is_focused = true
func _unfocus() -> void: is_focused = false
