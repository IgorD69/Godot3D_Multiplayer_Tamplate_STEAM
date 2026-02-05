extends CharacterBody3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var cam: Camera3D = $SpringArm3D/Camera3D
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var hud: Control = $HUD
@onready var progress_bar: ProgressBar = $HUD/ProgressBar
@onready var timer: Timer = $Timer
@onready var score: Label = $HUD/Score
#var is_on_floor = is_on_floor()
# --- MULTIPLAYER & STEAM VARIABLES ---
var player_name: String = ""

# INTERACTION VARIABLES
var hand: Marker3D
var hand_indicator: MeshInstance3D  # Vizualizare 3D pentru hand
var ray_cast: RayCast3D
var current_interaction_component: Node = null
var is_holding_object: bool = false

# UI VARIABLES
var crosshair: Control
var interaction_prompt: Label

# INTERACTION SETTINGS
@export var interaction_distance: float = 3.0
@export var interaction_layer: int = 2
@export var show_hand_indicator: bool = true 

var sensitivity = 0.001
@export var was_in_air = false
var shake_intensity = 0.0
var shake_fade = 6.0
@export var fall_velocity = 0.0
@export var is_aiming: bool = false
@export var is_sprinting: bool = false
@export var is_dashing: bool = false

# STAMINA VAR
@export var stamina_amount = 100.0
var current_stamina: float = 100.0
@export var target_speed: float

const DashSpeed = 50.0
const SPEED = 7.0
const SPRINT_SPEED = 15.0
const JUMP_VELOCITY = 10.0
const FOV_NORMAL = 90.0
const FOV_SPRINT = 110.0
const FOV_CHANGE_SPEED = 6.0
const GRAVITY_MULTIPLIER = 1.8
const FALL_GRAVITY_MULTIPLIER = 2.8
const MAX_FALL_SPEED = 50.0
const JUMP_CUT_MULTIPLIER = 0.5

func _ready() -> void:
	# === MULTIPLAYER AUTHORITY SETUP ===
	# Numele nodului (setat la spawn) trebuie să fie ID-ul Steam al peer-ului
	var peer_id = str(name).to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)
	
	add_to_group("Players")
	
	# Configurăm vizibilitatea și controlul în funcție de autoritate
	if is_multiplayer_authority():
		cam.make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_create_interaction_ui()
		# Dacă ai un model mesh pentru corp, îl setăm să fie vizibil doar ca umbră pentru tine
		var mesh = get_node_or_null("Mesh")
		if mesh: mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	else:
		# Dezactivăm elementele de UI/Camera care nu aparțin acestui peer
		if hud: hud.visible = false
		cam.current = false

	# Setup componente
	spring_arm.position.x = 0.4 
	spring_arm.position.y = 2.0
	anim_tree.active = true
	progress_bar.max_value = stamina_amount
	progress_bar.value = stamina_amount
	
	# Setup Interacțiune
	if cam:
		_setup_interaction_nodes()
	
	# Sincronizare nume Steam
	if is_multiplayer_authority():
		call_deferred("_send_player_name")

func _setup_interaction_nodes():
	hand = cam.get_node_or_null("hand")
	if hand == null:
		hand = Marker3D.new()
		hand.name = "hand"
		hand.position = Vector3(0, 0, -1.5)
		cam.add_child(hand)
	
	if show_hand_indicator and is_multiplayer_authority():
		_create_hand_indicator()
	
	ray_cast = cam.get_node_or_null("InteractionRay")
	if ray_cast == null:
		ray_cast = RayCast3D.new()
		ray_cast.name = "InteractionRay"
		ray_cast.target_position = Vector3(0, 0, -interaction_distance)
		ray_cast.collision_mask = interaction_layer
		ray_cast.enabled = true
		cam.add_child(ray_cast)

# === MULTIPLAYER SYNC ===

func _send_player_name():
	player_name = Steam.getPersonaName()
	set_player_name_rpc.rpc(player_name)

@rpc("any_peer", "call_local", "reliable")
func set_player_name_rpc(new_name: String):
	player_name = new_name
	print("Player name synced: ", player_name)

@rpc("any_peer", "unreliable")
func sync_transform(pos: Vector3, rot_y: float, arm_x: float):
	if not is_multiplayer_authority():
		global_position = pos
		rotation.y = rot_y
		spring_arm.rotation.x = arm_x

# === PROCESSING ===

func _process(_delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	_check_for_interaction()
	_update_interaction_ui()
	_update_hand_indicator()

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return

	if not is_on_floor():
		var gravity_mult = FALL_GRAVITY_MULTIPLIER if velocity.y < 0 else GRAVITY_MULTIPLIER
		velocity += get_gravity() * delta * gravity_mult
		if velocity.y > 0 and Input.is_action_just_released("jump"):
			velocity.y *= JUMP_CUT_MULTIPLIER
		velocity.y = max(velocity.y, -MAX_FALL_SPEED)
		fall_velocity = velocity.y
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	is_aiming = Input.is_action_pressed("R_Click") and not is_holding_object
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	is_sprinting = direction.length() > 0 and Input.is_action_pressed("sprint") and not is_aiming
	
	if Input.is_action_pressed("dash") and current_stamina > 0.1 and direction.length() > 0:
		is_dashing = true
		target_speed = DashSpeed
		current_stamina -= 50.0 * delta
	else:
		is_dashing = false
		if not Input.is_action_pressed("dash") and current_stamina < stamina_amount:
			current_stamina += 35.0 * delta
			
	current_stamina = clamp(current_stamina, 0, stamina_amount)
	progress_bar.value = current_stamina
	
	if not is_dashing:
		target_speed = SPRINT_SPEED if is_sprinting else SPEED
	
	if direction:
		velocity.x = direction.x * target_speed
		velocity.z = direction.z * target_speed
	else:
		velocity.x = move_toward(velocity.x, 0, target_speed)
		velocity.z = move_toward(velocity.z, 0, target_speed)
	
	move_and_slide()
	
	# Sincronizăm mișcarea cu ceilalți peers
	sync_transform.rpc(global_position, rotation.y, spring_arm.rotation.x)
	
	if is_on_floor() and was_in_air:
		if fall_velocity < -10.0: 
			shake_intensity = clamp(abs(fall_velocity) * 0.01, 0.1, 0.2)
	
	apply_shake(delta)
	
	var target_fov = FOV_NORMAL
	if is_dashing: target_fov = 120.0
	elif is_sprinting: target_fov = FOV_SPRINT
	elif is_aiming: target_fov = 75.0
	cam.fov = lerp(cam.fov, target_fov, delta * FOV_CHANGE_SPEED)
	was_in_air = not is_on_floor()

# === INTERACTION LOGIC ===

func _create_hand_indicator() -> void:
	if hand == null: return
	hand_indicator = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.1
	sphere_mesh.height = 0.2
	hand_indicator.mesh = sphere_mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.8, 1.0, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.2, 0.8, 1.0)
	hand_indicator.material_override = material
	hand_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand.add_child(hand_indicator)

func _create_interaction_ui() -> void:
	var interaction_ui = CanvasLayer.new()
	interaction_ui.name = "InteractionUI"
	add_child(interaction_ui)
	
	crosshair = Control.new()
	crosshair.anchors_preset = Control.PRESET_CENTER
	interaction_ui.add_child(crosshair)
	
	var dot = ColorRect.new()
	dot.size = Vector2(4, 4)
	dot.position = Vector2(-2, -2)
	crosshair.add_child(dot)
	
	interaction_prompt = Label.new()
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.anchors_preset = Control.PRESET_CENTER_TOP
	interaction_prompt.position = Vector2(-100, 40)
	interaction_prompt.size = Vector2(200, 50)
	interaction_prompt.visible = false
	interaction_ui.add_child(interaction_prompt)

func _check_for_interaction() -> void:
	if ray_cast and ray_cast.is_colliding():
		var collider = ray_cast.get_collider()
		if collider:
			var interaction_comp = _find_interaction_component(collider)
			if interaction_comp != current_interaction_component:
				current_interaction_component = interaction_comp
	else:
		current_interaction_component = null

func _find_interaction_component(node: Node) -> Node:
	# Căutare simplificată a scriptului de interacțiune
	if node.get_script() and "interaction" in node.get_script().resource_path.to_lower():
		return node
	for child in node.get_children():
		if child.get_script() and "interaction" in child.get_script().resource_path.to_lower():
			return child
	return null

func _update_hand_indicator() -> void:
	if not hand_indicator: return
	var material = hand_indicator.material_override as StandardMaterial3D
	if is_holding_object:
		material.albedo_color = Color(0.2, 1.0, 0.2, 0.5)
	elif current_interaction_component:
		material.albedo_color = Color(1.0, 0.8, 0.0, 0.5)
	else:
		material.albedo_color = Color(0.2, 0.8, 1.0, 0.3)

func _update_interaction_ui() -> void:
	if not crosshair: return
	if current_interaction_component:
		interaction_prompt.visible = true
		interaction_prompt.text = "[E] Interact" if not is_holding_object else "[E] Release"
		crosshair.get_child(0).color = Color(0, 1, 0)
	else:
		interaction_prompt.visible = false
		crosshair.get_child(0).color = Color(1, 1, 1)

# === INPUTS ===

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensitivity)
		spring_arm.rotate_x(-event.relative.y * sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-70), deg_to_rad(70))
	
	if event.is_action_pressed("interact"):
		_handle_interaction()
	if event.is_action_released("interact"):
		_handle_interaction_release()
	if event.is_action_pressed("R_Click") and is_holding_object:
		_handle_aux_interaction()
	if event.is_action_pressed("force_close"):
		get_tree().quit()

func _handle_interaction() -> void:
	if not current_interaction_component: return
	if not is_holding_object:
		if current_interaction_component.has_method("Interact"):
			current_interaction_component.Interact()
		if current_interaction_component.get("interaction_type") == 0:
			is_holding_object = true

func _handle_interaction_release() -> void:
	if is_holding_object:
		is_holding_object = false

func _handle_aux_interaction() -> void:
	if is_holding_object and current_interaction_component.has_method("auxInteract"):
		current_interaction_component.auxInteract()
		is_holding_object = false

func apply_shake(delta):
	if shake_intensity > 0:
		shake_intensity = lerp(shake_intensity, 0.0, delta * shake_fade)
		cam.h_offset = randf_range(-0.6, 0.6) * shake_intensity
		cam.v_offset = randf_range(-0.6, 0.6) * shake_intensity
	else:
		cam.h_offset = 0
		cam.v_offset = 0
