extends Area3D

# Tells main.gd this item was clicked
signal selected(country)

var country := {}
var outline := StandardMaterial3D.new()

func setup(data: Dictionary, color: Color) -> void:
	country = data
	$Label3D.text = data["name"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	$MeshInstance3D.material_override = mat

func _ready() -> void:
	# Outline trick: draw a slightly bigger copy of the box, inside-out, in white
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.03
	outline.albedo_color = Color.WHITE

# Called by the player when the crosshair moves on/off this item
func set_highlight(on: bool) -> void:
	$MeshInstance3D.material_override.next_pass = outline if on else null

func select() -> void:
	selected.emit(country)
