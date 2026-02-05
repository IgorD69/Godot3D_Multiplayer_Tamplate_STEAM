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
var mouse_input: Vector2

@export var camera_rotation = 0.05
@export var arm_camera_rotation = 0.07
@export var arm_sway_amount = 0.03

@onready var arm: Node3D = $CameraPivot/Camera3D/Arm
@onready var camera_pivot: SpringArm3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var PortalAnim: AnimationPlayer = $CameraPivot/Camera3D/Arm/Portal_Gun2/AnimationPlayer
@onready var MouseAnim: AnimationPlayer = $MOUSE/AnimationPlayer
@onready var model: MeshInstance3D = $MOUSE/Model
@onready var tab_canvas: CanvasLayer = $TAB
@onready var box_container: BoxContainer = $TAB/BoxContainer


func _ready():
	# Setăm authority-ul bazat pe numele nodului
	var peer_id = str(name).to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)
	
	# DEBUG: Verifică authority-ul
	print("=== PLAYER DEBUG ===")
	print("Player name in scene: ", name)
	print("Multiplayer unique ID: ", multiplayer.get_unique_id())
	print("Player authority ID: ", get_multiplayer_authority())
	print("Is multiplayer authority: ", is_multiplayer_authority())
	
	#if Global.LAN == true:
	player_name = Steam.getPersonaName()
	
	add_to_group("Players")
	
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
		print("✓ Setting up LOCAL player controls")
		if camera:
			camera.make_current()
		model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		
		# Amână capturarea mouse-ului până când fereastra este în focus
		call_deferred("_setup_mouse_capture")
		
		# Trimitem numele jucătorului după ce totul este gata
		call_deferred("_send_player_name")
	else:
		print("✓ Setting up REMOTE player (no controls)")
		if camera:
			camera.current = false

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

func _on_focus_gained():
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	if is_multiplayer_authority():
		# Doar jucătorul local procesează input-ul
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
		cam_tilt(input_dir.x, delta)
		arm_tilt(input_dir.x, delta)
		arm_sway(delta)
		
		# Sincronizează poziția și rotația cu ceilalți jucători
		sync_transform.rpc(global_position, rotation.y)
		
		# Animații
		var current_speed = Vector3(velocity.x, 0, velocity.z).length()
		var next_anim = "Idle"
		if current_speed > 0.1:
			if Input.is_action_pressed("sprint"):
				next_anim = "FastRun"
			else:
				next_anim = "Walk"
		else:
			next_anim = "Idle"
		
		if current_anim != next_anim:
			current_anim = next_anim
			play_animation_rpc.rpc(next_anim)

func cam_tilt(input_x, delta):
	if camera:
		camera.rotation.z = lerp(camera.rotation.z, -input_x * camera_rotation, 10 * delta)
	
func arm_tilt(input_x, delta):
	if arm:
		arm.rotation.z = lerp(arm.rotation.z, -input_x * camera_rotation, 10 * delta)
		
func arm_sway(delta):
	mouse_input = lerp(mouse_input, Vector2.ZERO, 10 * delta)
	arm.rotation.x = lerp(arm.rotation.x, mouse_input.y * arm_sway_amount, 10 * delta)
	arm.rotation.y = lerp(arm.rotation.y, mouse_input.x * arm_sway_amount, 10 * delta)
	
# RPC pentru sincronizarea transformării
@rpc("any_peer", "unreliable")
func sync_transform(pos: Vector3, rot_y: float):
	if !is_multiplayer_authority():
		global_position = pos
		rotation.y = rot_y

func _input(event):
	if !is_multiplayer_authority():
		return
	
	if event.is_action_pressed("esc"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
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
		camera_v_rot = clamp(camera_v_rot, deg_to_rad(-80), deg_to_rad(80))
		
		camera_pivot.rotation.x = camera_v_rot
		update_camera_rotation.rpc(camera_v_rot)
		mouse_input = event.relative
	
	if event.is_action_pressed("L_Click"):
		play_shoot_animation.rpc("Shoot")

@rpc("any_peer", "call_local", "reliable")
func play_animation_rpc(anim_name: String):
	if MouseAnim and MouseAnim.has_animation(anim_name):
		MouseAnim.play(anim_name, 0.2)

@rpc("any_peer", "unreliable")
func update_camera_rotation(vertical_rotation: float):
	if not is_multiplayer_authority():
		camera_pivot.rotation.x = vertical_rotation

@rpc("any_peer", "call_local", "reliable")
func play_shoot_animation(_tip: String):
	if PortalAnim:
		PortalAnim.stop()
		PortalAnim.play("Shoot")
