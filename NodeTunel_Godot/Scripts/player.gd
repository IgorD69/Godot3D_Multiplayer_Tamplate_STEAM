extends CharacterBody3D


const SPEED = 5.0
const SPRINT_SPEED = 10.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_moving_state: bool = false 
var camera_v_rot: float = 0.0
var current_anim: String = ""

@onready var PortalAnim: AnimationPlayer = $CameraPivot/Camera3D/Portal_Gun2/AnimationPlayer
#@onready var PortalAnim: AnimationPlayer = $CameraPivot/Camera3D/Portal_Gun/AnimationPlayer
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var camera_pivot: SpringArm3D = $CameraPivot
@onready var MouseAnim: AnimationPlayer = $MOUSE/AnimationPlayer
@onready var model: MeshInstance3D = $MOUSE/Model

func _enter_tree() -> void:
	var id = name.to_int()
	if id > 0:
		set_multiplayer_authority(id)
	
func _ready():
	if is_multiplayer_authority():
		if camera:
			camera.make_current()
		model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		if camera:
			camera.current = false
		set_process_input(false)

func _physics_process(delta):
	if is_multiplayer_authority():
		if not is_on_floor():
			velocity.y -= gravity * delta
		
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY
		
		# --- LOGICA DE SPRINT ---
		# Verificăm dacă Shift este apăsat (asigură-te că ai "sprint" în Input Map sau folosește "ui_shift" dacă e definit)
		var current_target_speed = SPEED
		if Input.is_action_pressed("sprint"): # Poți folosi și KEY_SHIFT direct dacă nu ai Input Map
			current_target_speed = SPRINT_SPEED
		
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if direction:
			velocity.x = direction.x * current_target_speed
			velocity.z = direction.z * current_target_speed
		else:
			# Folosim current_target_speed și pentru decelerare pentru a fi fluid
			velocity.x = move_toward(velocity.x, 0, current_target_speed)
			velocity.z = move_toward(velocity.z, 0, current_target_speed)
		
		move_and_slide()
		
# --- LOGICA DE ANIMATIE OPTIMIZATĂ ---
		var current_speed = Vector3(velocity.x, 0, velocity.z).length()
		var is_now_moving = current_speed > 0.1
		var next_anim = "Idle"

		if is_now_moving:
			if Input.is_action_pressed("sprint"):
				next_anim = "FastRun"
			else:
				next_anim = "Walk"
		else:
			next_anim = "Idle"

		# Trimitem RPC DOAR dacă s-a schimbat animația (fără spam)
		if current_anim != next_anim:
			current_anim = next_anim
			play_animation_rpc.rpc(next_anim)

func _input(event):
	if !is_multiplayer_authority():
		return
	
	if event is InputEventMouseMotion:
		# Rotația orizontală (pe corp)
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		# Rotația verticală (pe pivotul camerei)
		camera_v_rot -= event.relative.y * MOUSE_SENSITIVITY
		camera_v_rot = clamp(camera_v_rot, deg_to_rad(-80), deg_to_rad(80)) # Limitează să nu se dea peste cap
		
		# AICI ERA LIPSA: Aplicăm rotația local
		camera_pivot.rotation.x = camera_v_rot
		
		# Trimite rotația prin RPC pentru ceilalți
		update_camera_rotation.rpc(camera_v_rot)
	
	if event.is_action_pressed("L_Click"):
		play_shoot_animation.rpc("Shoot")


@rpc("any_peer", "call_local", "reliable")
func play_animation_rpc(anim_name: String):
	if MouseAnim and MouseAnim.has_animation(anim_name):
		# custom_blend: 0.2 face tranziția și mai lină
		MouseAnim.play(anim_name, 0.2)
# RPC pentru sincronizarea rotației camerei
@rpc("any_peer", "unreliable")
func update_camera_rotation(vertical_rotation: float):
	if not is_multiplayer_authority():
		camera_pivot.rotation.x = vertical_rotation

@rpc("any_peer", "call_local", "reliable")
func play_run_rpc(anim_name: String):
	if MouseAnim:
		if MouseAnim.current_animation != anim_name:
			MouseAnim.play(anim_name)

@rpc("any_peer", "call_local", "reliable")
func play_idle_rpc():
	if MouseAnim: MouseAnim.play("Idle")

@rpc("any_peer", "call_local", "reliable")
func play_shoot_animation(_tip: String):
	if PortalAnim:
		PortalAnim.stop()
		PortalAnim.play("Shoot")
