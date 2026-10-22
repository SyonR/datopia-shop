extends CollisionObject3D

# Any quest object the player can aim at and click.
# Works on a StaticBody3D (solid) or an Area3D (walk-through).

signal clicked(node)

var mesh: MeshInstance3D
var outline := StandardMaterial3D.new()

func build(size: Vector3, color: Color) -> void:
	mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	add_child(mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	add_child(shape)

	# Same outline trick as the shop items
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.04
	outline.albedo_color = Color.WHITE

func set_highlight(on: bool) -> void:
	mesh.material_override.next_pass = outline if on else null

func select() -> void:
	clicked.emit(self)
