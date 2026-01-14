extends CanvasLayer

@onready var PlayerName: Label = $BoxContainer/Name

func _ready() -> void:
	self.visible = false
	
	
func _process(_delta: float) -> void:
	self.visible = Input.is_action_pressed("tab")
