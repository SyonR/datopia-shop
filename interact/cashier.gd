extends Area3D

# Tells the quest the player clicked the cashier
signal talked_to

func _ready() -> void:
	$Hint.hide()
	add_to_group("finishes_dialogue")   # clicking me mid-line shows my whole line instead of the next one

# Called by the player when the crosshair moves on/off the cashier
func set_highlight(on: bool) -> void:
	$Hint.visible = on

func select() -> void:
	talked_to.emit()
