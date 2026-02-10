class_name Player


extends CharacterBody3D

const SPEED = 5.0
const SPRINT_SPEED = 10.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002


var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_moving_state: bool = false 
var camera_v_rot: float = 0.0
var current_anim: String = ""
var player_name: String = ""
var hand: Marker3D
var accumulated_mouse_input: Vector2 = Vector2.ZERO
var ik_base_position: Vector3
var ik_initialized: bool = false
var esc_menu_instance = null
var is_frozen: bool = false

@export var camera_rotation = 0.05

@onready var Transition_anim: AnimationPlayer = $Transition/AnimationPlayer
@onready var transition: ColorRect = $Transition

@onready var crosshair: TextureRect = $Character/Camera3D/Crosshair
@onready var Animation_Player: AnimationPlayer = $Character/metarig/Skeleton3D/AnimationPlayer
@export var camera: Camera3D


@export var ESC_MENU_SCENE = preload("uid://b84p0jqodhcxg") 



#IK
@onready var r_hand_marker: Marker3D = $Character/metarig/Skeleton3D/R_HandMarker
@onready var l_two_bone_ik_3d_2: TwoBoneIK3D = $Character/metarig/Skeleton3D/L_TwoBoneIK3D2
@onready var r_two_bone_ik_3d: TwoBoneIK3D = $Character/metarig/Skeleton3D/R_TwoBoneIK3D
@onready var ik_target: Marker3D = $Character/metarig/Skeleton3D/R_HandMarker

@onready var Flash: Node3D = $Character/metarig/Skeleton3D/CameraBoneAtachment/RemoteTransform3D/BoneAttachment3D/FlashLight
@onready var Flash_Light: SpotLight3D = $Character/metarig/Skeleton3D/CameraBoneAtachment/RemoteTransform3D/BoneAttachment3D/FlashLight/SpotLight3D
@onready var radiation_device: Node3D = $Character/metarig/Skeleton3D/BoneAttachment3D/RadiationDevice


#@onready var PortalAnim: AnimationPlayer = $Character/metarig/Skeleton3D/CameraBoneAtachment/RemoteTransform3D/BoneAttachment3D/Portal_Gun_Meshes/AnimationPlayer


#Tab UI
@onready var tab_canvas: CanvasLayer = $TAB
@onready var box_container: BoxContainer = $TAB/BoxContainer


#HEAD MESHES
@onready var head: MeshInstance3D = $Character/metarig/Skeleton3D/HEAD/head
@onready var helmet: MeshInstance3D = $Character/metarig/Skeleton3D/HEAD/helmet
@onready var ochelari: MeshInstance3D = $Character/metarig/Skeleton3D/HEAD/ochelari
@onready var mask: MeshInstance3D = $Character/metarig/Skeleton3D/HEAD/mask



func _enter_tree():
	var peer_id = str(name).to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)

func _ready():
	
	await get_tree().create_timer(0.5).timeout # Așteptăm să se termine spawn-ul complet
	if is_multiplayer_authority():
		camera.make_current()
		print("CAMERA: Forțată pe peer ", multiplayer.get_unique_id())
	
	Net.notify_client_ready.rpc_id(1)
	
	var peer_id = str(name).to_int()
	set_multiplayer_authority(peer_id)
	
	# 2. Controlăm camera
	if is_multiplayer_authority():
		camera.make_current()
		Transition_anim.play("FadeOut")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		camera.current = false
		
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		esc_menu_instance = null
	
	# DEBUG: Verifică authority-ul
	print("=== PLAYER DEBUG ===")
	print("Player name in scene: ", name)
	print("Multiplayer unique ID: ", multiplayer.get_unique_id())
	print("Player authority ID: ", get_multiplayer_authority())
	print("Is multiplayer authority: ", is_multiplayer_authority())
	
	#if Global.LAN == true:
	player_name = Steam.getPersonaName()
	
	add_to_group("Players")
	
	if player_name == "":
		player_name = "Guest_" + str(multiplayer.get_unique_id())
		
	# Ascunde TAB-ul la început
	if tab_canvas:
		tab_canvas.visible = false
	
	# Caută sau creează nodul "hand"
	if camera:
		hand = camera.get_node_or_null("hand")
		if hand == null:
			hand = Marker3D.new()
			hand.name = "hand"
			hand.position = Vector3(0, 0, -1.5)
			camera.add_child(hand)
			print("Hand marker created for player: ", name)
		else:
			print("Hand marker found for player: ", name)
	else:
		print("ERROR: Camera not found for player: ", name)
	
	# Așteptăm un frame pentru ca multiplayer să fie complet inițializat
	await get_tree().process_frame
	
	print("After wait - Is authority: ", is_multiplayer_authority())
	
	if is_multiplayer_authority():
		transition.visible = true 
		
		Transition_anim.play("FadeOut") 
		
		print("Pornesc animația de FadeOut pentru jucătorul local.")
	else:
		transition.visible = false
	
	if is_multiplayer_authority():
		print("✓ Setting up LOCAL player controls")
		if camera:
			camera.make_current()
			Transition_anim.play("FadeOut")
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		helmet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		ochelari.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		mask.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		
		# Amână capturarea mouse-ului până când fereastra este în focus
		call_deferred("_setup_mouse_capture")
		
		# Trimitem numele jucătorului după ce totul este gata
		call_deferred("_send_player_name")
	else:
		print("✓ Setting up REMOTE player (no controls)")
		if camera:
			camera.current = false
			
	if ik_target:
		ik_base_position = ik_target.position
	
	radiation_device.visible = false
	Flash.visible = false

func _send_player_name():
	await get_tree().process_frame
	
	var world = get_parent()
	if world and world.has_method("get_player_name"):
		var my_name = world.get_player_name()
		set_player_name.rpc(my_name)
		print("Sending player name: ", my_name, " for peer: ", name)
		
		if multiplayer.get_unique_id() != 1:
			request_all_player_names.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func set_player_name(new_name: String) -> void:
	player_name = new_name
	print("Player name set to: ", player_name, " for peer: ", name)
	update_all_player_lists.rpc()

@rpc("any_peer", "reliable")
func request_all_player_names() -> void:
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		print("Host received request from peer: ", sender_id)
		
		var all_players = get_tree().get_nodes_in_group("Players")
		for player in all_players:
			if player.has_method("get_player_name"):
				var p_name = player.get_player_name()
				var p_id = player.name.to_int()
				if p_name != "" and p_id > 0:
					receive_player_name.rpc_id(sender_id, p_id, p_name)

@rpc("any_peer", "call_local", "reliable")
func receive_player_name(peer_id: int, p_name: String) -> void:
	print("Received player name: ", p_name, " for peer: ", peer_id)
	
	var player = get_parent().get_node_or_null(str(peer_id))
	if player and player.has_method("set_player_name_direct"):
		player.set_player_name_direct(p_name)
	
	call_deferred("update_all_player_lists")

func set_player_name_direct(new_name: String) -> void:
	player_name = new_name
	print("Player name set directly to: ", player_name, " for peer: ", name)

@rpc("any_peer", "call_local", "reliable")
func update_all_player_lists() -> void:
	if !is_multiplayer_authority():
		return
	
	if box_container:
		for child in box_container.get_children():
			child.queue_free()
		
		await get_tree().process_frame
		
		var all_players = get_tree().get_nodes_in_group("Players")
		for player in all_players:
			if player.has_method("get_player_name"):
				var p_name = player.get_player_name()
				if p_name != "":
					add_player_to_list(p_name, player.name)

func add_player_to_list(p_name: String, peer_id: String) -> void:
	if !box_container:
		return
	
	var label = Label.new()
	label.name = "Player_" + peer_id
	
	if peer_id == str(multiplayer.get_unique_id()):
		label.text = p_name + " (You)"
	else:
		label.text = p_name
	
	label.add_theme_font_size_override("font_size", 16)
	box_container.add_child(label)

func get_player_name() -> String:
	return player_name

func _setup_mouse_capture():
	await get_tree().process_frame
	if DisplayServer.window_is_focused():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		get_viewport().gui_focus_changed.connect(_on_focus_gained, CONNECT_ONE_SHOT)

func _on_focus_gained(_node = null): # Adăugăm un argument opțional
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	if multiplayer.multiplayer_peer == null or not is_multiplayer_authority() or not is_inside_tree():
		return

	# GRAVITAȚIA (Esențială!)
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0:
		velocity.y = 0

	# GESTIONARE BLOCARE
	if is_instance_valid(esc_menu_instance) or is_frozen:
		if velocity.y > 0:
			velocity.y = 0
		
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
		move_and_slide()
		
		if multiplayer.multiplayer_peer:
			sync_transform.rpc(global_position, rotation.y)
		return
		
	# SOLUȚIE ERORI EXIT: Verificăm dacă nodul mai este în scenă
	if not is_inside_tree() or multiplayer.multiplayer_peer == null:
		return
		
	if is_multiplayer_authority():
		if is_frozen:
			if not is_on_floor():
				velocity.y -= gravity * delta
			else:
				velocity.y = 0
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
			if Animation_Player.current_animation != "Idle":
				Animation_Player.play("Idle", 0.2)
			return

		# Logica normală de mișcare
		if not is_on_floor():
			velocity.y -= gravity * delta
		
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY
		
		var current_target_speed = SPEED
		if Input.is_action_pressed("sprint"):
			current_target_speed = SPRINT_SPEED
		
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if direction:
			velocity.x = direction.x * current_target_speed
			velocity.z = direction.z * current_target_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_target_speed)
			velocity.z = move_toward(velocity.z, 0, current_target_speed)
		
		move_and_slide()
		
		# Sincronizăm doar dacă peer-ul este încă valid
		if multiplayer.multiplayer_peer:
			sync_transform.rpc(global_position, rotation.y)

		# Logica de animație
		_handle_animations(current_target_speed)

func _handle_animations(current_swpeed):
	var horiz_vel = Vector3(velocity.x, 0, velocity.z).length()
	var next_anim = "Idle"
	var playback_speed = 1.0

	if not is_on_floor():
		next_anim = "Jump"
	elif horiz_vel > 0.1:
		if Input.is_action_pressed("sprint"):
			next_anim = "Run"
			playback_speed = 1.5
		else:
			next_anim = "Walk"
	
	if Animation_Player.current_animation != next_anim:
		Animation_Player.play(next_anim, 0.2, playback_speed)
		play_animation_rpc.rpc(next_anim)
	
# RPC-urile rămân la fel, dar adaugă verificări de siguranță:
@rpc("any_peer", "unreliable")
func sync_transform(pos: Vector3, rot_y: float):
	if is_inside_tree() and not is_multiplayer_authority():
		global_position = pos
		rotation.y = rot_y
		
func cam_tilt(input_x, delta):
	if camera:
		camera.rotation.z = lerp(camera.rotation.z, -input_x * camera_rotation, 10 * delta)


func toggle_esc_menu():
	var existing_menu = get_tree().root.get_node_or_null("EscMenu")
	
	if is_instance_valid(esc_menu_instance) or existing_menu:
		# Dacă am găsit unul, îl închidem pe acela
		var menu_to_close = esc_menu_instance if esc_menu_instance else existing_menu
		menu_to_close.queue_free()
		esc_menu_instance = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		# 2. Creăm unul nou DOAR dacă nu am găsit nimic
		esc_menu_instance = ESC_MENU_SCENE.instantiate()
		esc_menu_instance.name = "EscMenu" # Îi dăm nume fix ca să îl găsim data viitoare
		get_tree().root.add_child(esc_menu_instance)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event):
	if !is_multiplayer_authority(): return
	
	if event.is_action_pressed("esc"):
		toggle_esc_menu()
		get_viewport().set_input_as_handled()
		return

	# Dacă meniul e deschis, tăiem restul input-ului (cameră, mișcare, unelte)
	if is_instance_valid(esc_menu_instance):
		return

	# 3. UNELTE (Flashlight, Radiometru)
	if event.is_action_pressed("flash"):
		r_two_bone_ik_3d.active = !r_two_bone_ik_3d.active
		Flash_Light.visible = r_two_bone_ik_3d.active
		Flash.visible = r_two_bone_ik_3d.active
			
	if event.is_action_pressed("radiometru"):
		l_two_bone_ik_3d_2.active = !l_two_bone_ik_3d_2.active
		radiation_device.visible = l_two_bone_ik_3d_2.active
			
	# 4. TAB MENU (Player List)
	if event.is_action_pressed("ui_tab"):
		if tab_canvas:
			tab_canvas.visible = true
			update_all_player_lists.rpc()
	
	if event.is_action_released("ui_tab"):
		if tab_canvas:
			tab_canvas.visible = false
	
	# 5. CAMERA (Mouse Motion)
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_v_rot -= event.relative.y * MOUSE_SENSITIVITY
		camera_v_rot = clamp(camera_v_rot, deg_to_rad(-90), deg_to_rad(50))
		camera.rotation.x = camera_v_rot
		update_camera_rotation.rpc(camera_v_rot)
		accumulated_mouse_input += event.relative
	
	#if event.is_action_pressed("L_Click"):
		#play_shoot_animation.rpc("Shoot")

@rpc("any_peer", "call_local", "reliable")
func play_animation_rpc(anim_name: String):
	if Animation_Player and Animation_Player.has_animation(anim_name):
		Animation_Player.play(anim_name, 0.2)

@rpc("any_peer", "unreliable")
func update_camera_rotation(vertical_rotation: float):
	if not is_multiplayer_authority():
		camera.rotation.x = vertical_rotation

#@rpc("any_peer", "call_local", "reliable")
#func play_shoot_animation(_tip: String):
	#if PortalAnim:
		#PortalAnim.stop()
		#PortalAnim.play("Shoot")
