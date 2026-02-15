class_name Player

extends CharacterBody3D

const SPEED = 5.0
const SPRINT_SPEED = 10.0
const JUMP_VELOCITY = 4.5

var MOUSE_SENSITIVITY = Global.mouse_sensitivity

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_moving_state: bool = false 
var camera_v_rot: float = 0.0
var current_anim: String = ""
var player_name: String = ""
var hand: Marker3D
var accumulated_mouse_input: Vector2 = Vector2.ZERO
var ik_base_position: Vector3 = Vector3(-0.4, 1.38, 0.475)  # SETEAZĂ POZIȚIA MANUALĂ CA FALLBACK
var ik_initialized: bool = false
var esc_menu_instance = null
var is_frozen: bool = false

var hand_sway_offset: Vector2 = Vector2.ZERO
var hand_sway_velocity: Vector2 = Vector2.ZERO
var walk_cycle_time: float = 0.0
var is_moving: bool


# Voice Chat VARS (LAN Support - funcționează fără Steam)
@export var voice_player: AudioStreamPlayer3D
var playback: AudioStreamGeneratorPlayback = null
var audio_effect_capture: AudioEffectCapture = null
var recording_bus_index: int = -1
var mic_stream: AudioStreamMicrophone = null
var mic_player: AudioStreamPlayer = null



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


@onready var light_cone: MeshInstance3D = $Character/metarig/Skeleton3D/CameraBoneAtachment/RemoteTransform3D/BoneAttachment3D/FlashLight/SpotLight3D/light_cone
@onready var Flash: Node3D = $Character/metarig/Skeleton3D/CameraBoneAtachment/RemoteTransform3D/BoneAttachment3D/FlashLight
@onready var Flash_Light: SpotLight3D = $Character/metarig/Skeleton3D/CameraBoneAtachment/RemoteTransform3D/BoneAttachment3D/FlashLight/SpotLight3D
@onready var radiation_device: Node3D = $Character/metarig/Skeleton3D/BoneAttachment3D/RadiationDevice

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
	await get_tree().create_timer(0.5).timeout
	if is_multiplayer_authority():
		camera.make_current()
		print("CAMERA: Forțată pe peer ", multiplayer.get_unique_id())
	
	Net.notify_client_ready.rpc_id(1)
	
	var peer_id = str(name).to_int()
	set_multiplayer_authority(peer_id)
	
		
	if is_multiplayer_authority():
		camera.make_current()
		Transition_anim.play("FadeOut")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		camera.current = false
		
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		esc_menu_instance = null
	
	print("=== PLAYER DEBUG ===")
	print("Player name in scene: ", name)
	print("Multiplayer unique ID: ", multiplayer.get_unique_id())
	print("Player authority ID: ", get_multiplayer_authority())
	print("Is multiplayer authority: ", is_multiplayer_authority())
	
	player_name = Steam.getPersonaName()
	
	add_to_group("Players")
	
	if player_name == "":
		player_name = "Guest_" + str(multiplayer.get_unique_id())
		
	if tab_canvas:
		tab_canvas.visible = false
	
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
		light_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY 
		
		call_deferred("_setup_mouse_capture")
		call_deferred("_send_player_name")
	else:
		print("✓ Setting up REMOTE player (no controls)")
		if camera:
			camera.current = false
	
	# SALVĂM POZIȚIA DE BAZĂ DUPĂ CE TOTUL E ÎNCĂRCAT
	await get_tree().process_frame
	await get_tree().process_frame

	
	radiation_device.visible = false
	Flash.visible = false

	# CONFIGURARE VOICE CHAT LAN - funcționează fără Steam
	_setup_voice_chat()

func _setup_voice_chat():
	# 1. Setup AudioStreamPlayer3D pentru redare (TOȚI jucătorii)
	if voice_player == null:
		voice_player = AudioStreamPlayer3D.new()
		voice_player.name = "VoicePlayer"
		add_child(voice_player)
	
	var stream_gen = AudioStreamGenerator.new()
	stream_gen.mix_rate = 44100  # 44.1 kHz standard
	stream_gen.buffer_length = 0.1  # 100ms buffer
	
	voice_player.stream = stream_gen
	voice_player.max_distance = 50.0  # Distanța maximă de auzire
	voice_player.unit_size = 10.0
	voice_player.play()
	playback = voice_player.get_stream_playback()
	
	print("✓ Voice playback ready pentru: ", name)
	
	# 2. Setup AudioEffectCapture pentru înregistrare (DOAR local player)
	if is_multiplayer_authority():
		_setup_voice_recording()

	var mic_player = AudioStreamPlayer.new()
	mic_player.stream = mic_stream
	mic_player.bus = "VoiceCapture_" + str(name)
	mic_player.name = "MicrophonePlayer"
	add_child(mic_player)
	
	# Pornim player-ul, dar controlăm transmisia prin cod
	mic_player.play()
	
	# Curățăm buffer-ul inițial ca să nu avem "ecou" din trecut la prima apăsare
	if audio_effect_capture:
		audio_effect_capture.clear_buffer()
	
	print("✓ Voice recording initialized (Muted by default) for: ", name)
	
func _setup_voice_recording():
	recording_bus_index = AudioServer.get_bus_count()
	AudioServer.add_bus(recording_bus_index)
	var bus_name = "VoiceCapture_" + str(name)
	AudioServer.set_bus_name(recording_bus_index, bus_name)
	
	# --- MODIFICAREA CRUCIALĂ AICI ---
	# Dezactivăm trimiterea către Master. 
	# Vrem ca datele să ajungă DOAR în AudioEffectCapture, nu în boxe.
	AudioServer.set_bus_mute(recording_bus_index, true) 
	# ---------------------------------

	var capture_effect = AudioEffectCapture.new()
	AudioServer.add_bus_effect(recording_bus_index, capture_effect)
	audio_effect_capture = capture_effect
	
	var mic_stream = AudioStreamMicrophone.new()
	mic_player = AudioStreamPlayer.new()
	mic_player.stream = mic_stream
	mic_player.bus = bus_name
	add_child(mic_player)
	mic_player.play()

func _send_player_name():
	await get_tree().process_frame
	
	# Folosim direct player_name care e deja setat în _ready()
	if player_name != "":
		set_player_name.rpc(player_name)
		print("Sending player name: ", player_name, " for peer: ", name)
		
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
	
	# Trebuie să fie RPC call, nu call_deferred direct
	update_all_player_lists.rpc()

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

func _on_focus_gained(_node = null):
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# VERIFICARE CRITICĂ - oprește procesarea dacă nodul e în curs de ștergere
	if not is_inside_tree() or is_queued_for_deletion():
		return
	
	if multiplayer.multiplayer_peer == null or not is_multiplayer_authority():
		return

	# GRAVITAȚIA
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
		
	# SOLUȚIE ERORI EXIT
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
				Animation_Player.play("Idle", 0.15, 0.15)
				r_hand_marker.position.y = 1.2
			return
	
		# Logica normală de mișcare
		if not is_on_floor():
			velocity.y -= gravity * delta
		
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY
		
		var current_target_speed = SPEED
		var is_sprinting = Input.is_action_pressed("sprint")
		if is_sprinting:
			current_target_speed = SPRINT_SPEED
		
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		# Aplică sway-ul de la mouse
		hand_sway_velocity = hand_sway_velocity.lerp(Vector2.ZERO, delta * 8.0)
		hand_sway_offset += hand_sway_velocity * delta * 2.0
		
		# Limitează offset-ul total
		hand_sway_offset.x = clamp(hand_sway_offset.x, -0.1, 0.1)
		hand_sway_offset.y = clamp(hand_sway_offset.y, -0.1, 0.1)
		
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if direction:
			velocity.x = direction.x * current_target_speed
			velocity.z = direction.z * current_target_speed
			is_moving = true
			
		else:
			velocity.x = move_toward(velocity.x, 0, current_target_speed)
			velocity.z = move_toward(velocity.z, 0, current_target_speed)
			is_moving = false
			
		
		if !is_moving:
			r_hand_marker.position.y = 1.2
			
			
		move_and_slide()
		
		if multiplayer.multiplayer_peer:
			sync_transform.rpc(global_position, rotation.y)

		_handle_animations(current_target_speed)
		
		# ===== VOICE CHAT - CAPTURARE CONTINUĂ =====
		_handle_voice_capture()

# FUNCȚIE pentru capturare voce LAN (fără Steam)
func _handle_voice_capture():
	if not is_multiplayer_authority() or audio_effect_capture == null:
		return
	
	if Input.is_action_pressed("voice_key"):
		var available_frames = audio_effect_capture.get_frames_available()
		
		if available_frames > 0:
			var audio_data = audio_effect_capture.get_buffer(available_frames)
			
			var byte_array = PackedByteArray()
			for frame in audio_data:
				var float_value = (frame.x + frame.y) / 2.0
				byte_array.append_array(PackedFloat32Array([float_value]).to_byte_array())
			
			send_voice_to_peers.rpc(byte_array)
	else:
		# Când nu apeși V, doar curățăm buffer-ul ca să nu se adune lag
		if audio_effect_capture.get_frames_available() > 0:
			audio_effect_capture.clear_buffer()

# MODIFICARE AICI: Verifică ID-ul ca să nu te auzi pe tine
@rpc("any_peer", "unreliable_ordered", "call_local")
func send_voice_to_peers(buffer: PackedByteArray):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = multiplayer.get_unique_id()
	
	# DACĂ SUNT EU, NU REDA SUNETUL (Asta elimină ecoul!)
	if sender_id == multiplayer.get_unique_id():
		return
		
	_play_voice(buffer)

func _play_voice(data: PackedByteArray):
	# Verificare pentru crash
	
	if not is_inside_tree() or is_queued_for_deletion():
		return
	
	if playback == null:
		if voice_player and voice_player.stream:
			playback = voice_player.get_stream_playback()
		if playback == null:
			return
	
	# Convertim bytes înapoi la float array
	var float_array = data.to_float32_array()
	
	if float_array.size() == 0:
		return
	
	# Adăugăm frames la playback (convertim mono la stereo)
	for i in range(float_array.size()):
		playback.push_frame(Vector2(float_array[i], float_array[i]))

func _handle_animations(current_swpeed):
	var horiz_vel = Vector3(velocity.x, 0, velocity.z).length()
	var next_anim = "Idle"
	var playback_speed = 1.0

	if not is_on_floor():
		next_anim = "Jump"
	elif horiz_vel > 0.1:
		r_hand_marker.position.y = 1.1
		if Input.is_action_pressed("sprint"):
			next_anim = "Run"
			playback_speed = 1.5
		else:
			next_anim = "Walk"
	
	if Animation_Player.current_animation != next_anim:
		Animation_Player.play(next_anim, 0.2, playback_speed)
		play_animation_rpc.rpc(next_anim)

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
		var menu_to_close = esc_menu_instance if esc_menu_instance else existing_menu
		menu_to_close.queue_free()
		esc_menu_instance = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		esc_menu_instance = ESC_MENU_SCENE.instantiate()
		esc_menu_instance.name = "EscMenu"
		get_tree().root.add_child(esc_menu_instance)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

@rpc("any_peer", "unreliable_ordered", "call_local")
func show_flash():
	if !is_multiplayer_authority():
		return
	
	if Input.is_action_pressed("flash"):
		r_two_bone_ik_3d.active = !r_two_bone_ik_3d.active
		Flash_Light.visible = r_two_bone_ik_3d.active
		Flash.visible = r_two_bone_ik_3d.active
	
	
	# RPC-ul care execută schimbarea vizuală pe toate instanțele
@rpc("any_peer", "call_local", "reliable")
func sync_flashlight(is_on: bool):
	if r_two_bone_ik_3d:
		r_two_bone_ik_3d.active = is_on
	
	if Flash:
		Flash.visible = is_on
	
	if Flash_Light:
		Flash_Light.visible = is_on
		
	if Flash:
		Flash.visible = is_on
		
func _input(event):
	if !is_multiplayer_authority(): 
		return
	
	if event.is_action_pressed("esc"):
		toggle_esc_menu()
		get_viewport().set_input_as_handled()
		return

	if is_instance_valid(esc_menu_instance):
		return

	if event.is_action_pressed("flash"):
		var new_state = !Flash.visible 
		sync_flashlight.rpc(new_state)
			
	
			
	if event.is_action_pressed("radiometru"):
		l_two_bone_ik_3d_2.active = !l_two_bone_ik_3d_2.active
		radiation_device.visible = l_two_bone_ik_3d_2.active
			
	if event.is_action_pressed("ui_tab"):
		if tab_canvas:
			tab_canvas.visible = true
			update_all_player_lists.rpc()
	
	if event.is_action_released("ui_tab"):
		if tab_canvas:
			tab_canvas.visible = false
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_v_rot -= event.relative.y * MOUSE_SENSITIVITY
		camera_v_rot = clamp(camera_v_rot, deg_to_rad(-90), deg_to_rad(50))
		camera.rotation.x = camera_v_rot
		update_camera_rotation.rpc(camera_v_rot)
		accumulated_mouse_input += event.relative

@rpc("any_peer", "call_local", "reliable")
func play_animation_rpc(anim_name: String):
	if Animation_Player and Animation_Player.has_animation(anim_name):
		Animation_Player.play(anim_name, 0.2)

@rpc("any_peer", "unreliable")
func update_camera_rotation(vertical_rotation: float):
	if not is_multiplayer_authority():
		camera.rotation.x = vertical_rotation
