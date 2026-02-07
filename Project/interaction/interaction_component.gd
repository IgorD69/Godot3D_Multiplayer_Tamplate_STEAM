extends Node

enum InteractionType { DEFAULT, DOOR, SWITCH, LAPTOP }

@export var object_referance: Node3D
@export var interaction_type: InteractionType = InteractionType.DEFAULT
@export var maximum_rotation: float = 110
@export var pivit_point: Node3D
@export var nodes_to_affect: Array[Node]

# Parametri pentru throw
@export_group("Throw Settings")
@export var base_throw_force: float = 15.0  # Forța de bază pentru aruncarea obiectelor
@export var min_throw_strength: float = 5.0  # Puterea minimă de aruncare
@export var max_throw_strength: float = 30.0  # Puterea maximă de aruncare

# Parametri pentru greutate și handling
@export_group("Weight & Handling")
@export var light_object_mass: float = 1.0  # Sub această masă = obiect ușor
@export var heavy_object_mass: float = 5.0  # Peste această masă = obiect greu
@export var max_height_offset: float = 0.0  # Offset-ul Y pentru obiecte ușoare (0 = centru)
@export var min_height_offset: float = -0.5  # Offset-ul Y pentru obiecte grele (negativ = mai jos)
@export var light_object_speed: float = 25.0  # Viteza de răspuns pentru obiecte ușoare
@export var heavy_object_speed: float = 8.0  # Viteza de răspuns pentru obiecte grele
@export var lerp_smoothness: float = 10.0  # Cât de smooth e tranziția (mai mare = mai rapid)

var can_interact: bool = true
var is_interacting: bool = false
var lock_camera: bool = false
var starting_rotation: float
var is_front: bool
var player_hand: Marker3D
var was_opened: bool = false
var is_focused: bool = false

# Variabile pentru sistem de greutate
var current_weight_factor: float = 0.0  # 0 = ușor, 1 = greu
var current_height_offset: float = 0.0
var current_speed_multiplier: float = 1.0
var target_hand_position: Vector3 = Vector3.ZERO
var pickup_progress: float = 0.0  # Progres de la 0 la 1 pentru animația de ridicare
var is_picking_up: bool = false

func _ready() -> void:
	match interaction_type:
		InteractionType.DOOR:
			starting_rotation = pivit_point.rotation.y
		InteractionType.SWITCH:
			starting_rotation = object_referance.rotation.z
		InteractionType.LAPTOP:
			starting_rotation = pivit_point.rotation.z

func _physics_process(delta: float) -> void:
	if is_interacting and interaction_type == InteractionType.DEFAULT:
		# Animație de ridicare progresivă
		if is_picking_up and pickup_progress < 1.0:
			# Obiecte grele au o animație mai lentă de ridicare
			var pickup_speed = lerp(3.0, 1.0, current_weight_factor)  # 3.0 pentru ușoare, 1.0 pentru grele
			pickup_progress = min(pickup_progress + delta * pickup_speed, 1.0)
			
			if pickup_progress >= 1.0:
				is_picking_up = false
		
		if object_referance:
			# Dacă NU suntem serverul, trimitem poziția noastră către server constant
			if not multiplayer.is_server():
				update_remote_position.rpc(object_referance.global_position, object_referance.global_rotation)
			
			# Aplicăm mișcarea locală
			if object_referance.is_multiplayer_authority() or not multiplayer.is_server():
				_default_interact(delta)

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
			
			# Calculăm factorul de greutate bazat pe masa obiectului
			if object_referance and object_referance is RigidBody3D:
				var mass = (object_referance as RigidBody3D).mass
				
				# Normalizăm masa între 0 (ușor) și 1 (greu)
				current_weight_factor = clamp(
					(mass - light_object_mass) / (heavy_object_mass - light_object_mass),
					0.0,
					1.0
				)
				
				# Calculăm offset-ul de înălțime bazat pe greutate
				# Obiecte ușoare = sus (max_height_offset)
				# Obiecte grele = jos (min_height_offset)
				current_height_offset = lerp(max_height_offset, min_height_offset, current_weight_factor)
				
				# Calculăm viteza de răspuns
				current_speed_multiplier = lerp(light_object_speed, heavy_object_speed, current_weight_factor)
				
				# Inițializăm animația de ridicare
				pickup_progress = 0.0
				is_picking_up = true
				
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
	pickup_progress = 0.0
	is_picking_up = false

func set_direction(_normal: Vector3) -> void:
	for player in get_tree().get_nodes_in_group("Players"):
		if player.is_multiplayer_authority():
			if object_referance:
				var to_player = (player.global_position - object_referance.global_position).normalized()
				is_front = to_player.dot(_normal) > 0
			break

# --- LOGICA DEFAULT (CUBURI) ---

func _default_interact(delta: float) -> void:
	if player_hand == null or object_referance == null: return
	
	var rigid_body_3d: RigidBody3D = object_referance as RigidBody3D
	if rigid_body_3d:
		# Calculăm poziția țintă cu offset de greutate
		var hand_world_pos = player_hand.global_transform.origin
		
		# Aplicăm progresiv offset-ul în timpul ridicării
		var current_offset = current_height_offset * pickup_progress
		var adjusted_hand_pos = hand_world_pos + Vector3(0, current_offset, 0)
		
		# Smooth lerp către poziția țintă
		var current_pos = rigid_body_3d.global_transform.origin
		target_hand_position = adjusted_hand_pos
		
		# Calculăm diferența cu lerp pentru smooth transition
		var object_distance: Vector3 = target_hand_position - current_pos
		
		# Aplicăm viteza bazată pe greutate
		# Obiecte grele se mișcă mai încet, obiecte ușoare mai repede
		rigid_body_3d.linear_velocity = object_distance * current_speed_multiplier
		
		# Damping rotațional bazat pe greutate (obiecte grele se rotesc mai greu)
		var angular_damping = lerp(0.5, 2.0, current_weight_factor)
		rigid_body_3d.angular_velocity = rigid_body_3d.angular_velocity.lerp(Vector3.ZERO, angular_damping * delta)

func _default_throw() -> void:
	if player_hand == null or object_referance == null: return
	var rigid_body_3d = object_referance as RigidBody3D
	if rigid_body_3d:
		var throw_direction: Vector3 = -player_hand.global_transform.basis.z.normalized()
		
		# Calcul al puterii bazat pe masă folosind variabilele export
		var mass_factor: float = rigid_body_3d.mass
		
		# Obiectele mai grele sunt mai greu de aruncat (putere inversă proporțională cu masa)
		var throw_strength: float = max(base_throw_force / mass_factor, min_throw_strength)
		
		# Limităm puterea maximă pentru obiecte foarte ușoare
		throw_strength = min(throw_strength, max_throw_strength)
		
		# Trimitem poziția globală unde se află obiectul în mână
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
