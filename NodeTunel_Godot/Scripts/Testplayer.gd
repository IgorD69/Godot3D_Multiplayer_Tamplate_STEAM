extends CharacterBody3D

#@onready var animation_player: AnimationPlayer = $AnimationPlayer

const SPEED = 10.0
const SPRINT_SPEED = 15.0
const JUMP_VELOCITY = 4.5
var sensitivity = 0.001

@onready var cam: Camera3D = $CameraPivot/Camera3D
@onready var camera_pivot: SpringArm3D = $CameraPivot
@onready var PortalAnim: AnimationPlayer = $Portal_Gun/AnimationPlayer

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _input(event: InputEvent) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		camera_pivot.rotate_x(-event.relative.y * sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)
		
	if event.is_action_pressed("L_Click"):
		PortalAnim.play("Shoot")
