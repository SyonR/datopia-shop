extends CollisionObject3D

# Any quest object the player can aim at and click.
# Works on a StaticBody3D (solid) or an Area3D (walk-through).

signal clicked(node)

const OUTLINE_WIDTH = 0.04

var meshes := []   # every mesh that gets the outline
var outline := StandardMaterial3D.new()

# A plain colored box, or `model` fitted into the box.
# stretch = false keeps the model's proportions and sits it on the box's bottom.
func build(size: Vector3, color: Color, model: PackedScene = null, stretch := true) -> void:
	# Same outline trick as the shop items
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = OUTLINE_WIDTH
	outline.albedo_color = Color.WHITE

	if model:
		_add_model(model.instantiate(), size, stretch)
	else:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		if color.a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = mat
		add_child(mesh)
		meshes.append(mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	add_child(shape)

func set_highlight(on: bool) -> void:
	for m in meshes:
		m.material_overlay = outline if on else null

func select() -> void:
	clicked.emit(self)

func _add_model(model: Node3D, size: Vector3, stretch: bool) -> void:
	meshes.append_array(fit_model(model, size, stretch))
	add_child(model)
	# The outline grows in the model's own units, so undo the stretch
	outline.grow_amount = OUTLINE_WIDTH / maxf(model.scale.x, maxf(model.scale.y, model.scale.z))

# Scale and move a model so its bounds fit a box of `size` centered on its parent.
# stretch = false keeps proportions and sits it on the box's bottom.
# Returns the model's meshes. Also used by things that aren't clickable (rats, broom).
static func fit_model(model: Node3D, size: Vector3, stretch: bool) -> Array:
	var found := []
	var bounds := AABB()
	for m in model.find_children("*", "MeshInstance3D"):
		var t := Transform3D()
		var n: Node = m
		while n != model:   # transform relative to the model root
			t = n.transform * t
			n = n.get_parent()
		var b: AABB = t * m.get_aabb()
		bounds = b if found.is_empty() else bounds.merge(b)
		found.append(m)
	var s := size / bounds.size
	if not stretch:
		s = Vector3.ONE * minf(s.x, minf(s.y, s.z))
	model.scale = s
	model.position = -(bounds.position + bounds.size / 2) * s
	if not stretch:
		model.position.y = -size.y / 2 - bounds.position.y * s.y
	return found
