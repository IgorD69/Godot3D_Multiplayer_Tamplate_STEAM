extends Marker3D

@export var sway_amount : float = 0.05
@export var lerp_speed : float = 10.0

@onready var l_hand_marker: Marker3D = $"."

var mouse_input : Vector2

func _input(event):
	if event is InputEventMouseMotion:
		mouse_input = event.relative
	
	self.position = lerp(self.position, self.position.x * mouse_input, lerp_speed)
		
