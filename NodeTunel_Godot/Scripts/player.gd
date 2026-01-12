extends CharacterBody3D

const SPEED = 10.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

# Get the gravity from the project settings
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var control: Control = $UI/Control

# Debugging
#func _ready_check():
	#print("Player ready - Position: ", global_position)
	#if has_node("CollisionShape3D"):
		#print("Collision shape valid: ", $CollisionShape3D.shape != null)
	#print("Collision layers: ", collision_layer)
	#print("Collision mask: ", collision_mask)
	#print("Multiplayer ID: ", multiplayer.get_unique_id())
	#print("Node authority: ", get_multiplayer_authority())

@onready var camera = $Camera3D  # Asigură-te că numele e exact
@onready var mesh = $MeshInstance3D

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())
	#if control:
func _ready():
	#%UI.visible = false	
	
	print("Player ready - Authority: ", is_multiplayer_authority())
	print("Camera found: ", camera != null)
	
	# Only the local player should have an active camera and capture mouse
	if is_multiplayer_authority():
		# Activate camera for local player
		if camera:
			camera.current = true
			print("Camera activated for local player")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		# Disable camera for remote players
		if camera:
			camera.current = false
			camera.queue_free()  # Remove camera entirely from remote players
			print("Camera removed from remote player")

func _input(event):
	# Only process input for the local player
	if !is_multiplayer_authority():
		return
	
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	# Toggle mouse capture
	#if event.is_action_pressed("ui_cancel"):
		#if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		#else:
			#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# Debug info
	#if is_multiplayer_authority():
		#print("Player Y position: ", global_position.y, " | On floor: ", is_on_floor())
	
	# Only process physics for the local player
	if !is_multiplayer_authority():
		return
	
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Get input direction
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	move_and_slide()
