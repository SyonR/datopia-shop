extends Node3D

# Shared building blocks for the cashier's missions: crates, stickers, signs.
# Each mission script extends this file.

signal say(text)
signal completed   # the mission was just finished (not emitted by dev jumps)

const CLICKABLE = preload("res://interact/clickable.gd")
const CRATE_COLOR = Color(0.6, 0.4, 0.2)
const CRATE_MODEL = preload("res://models/furniture/cardboardBoxClosed.glb")
const SIGN_GLOW = Color(0.45, 0.85, 1.0)   # light cyan
const SIGN_BOB = 0.06        # meters up and down
const SIGN_BOB_TIME = 1.5    # seconds per half bob

var hand: Node3D   # the player's carried-sticker spot
var shelf          # the food shelf (shelf.gd)
var started := false
var done := false
var held = null   # the sticker you are carrying

func complete() -> void:
	done = true
	completed.emit()

# Override these in each mission
func setup(_country: Dictionary) -> void:
	pass

func start() -> void:
	pass

func on_cashier() -> void:
	pass

# Called before a dev jump throws the mission away
func cleanup() -> void:
	pass

# ---------- Crates, stickers, signs ----------

# A solid crate (a Kenney cardboard box). `sides` = which faces get printed labels (never the sign side).
# names: top line(s), info: bottom line(s)
func make_crate(pos: Vector3, sides: Array) -> Dictionary:
	var body = _clickable(StaticBody3D.new(), Vector3(1, 1, 1), CRATE_COLOR, self, CRATE_MODEL)
	body.position = pos
	return {"body": body, "sides": sides,
		"names": face_labels(body, sides, 0.5, 0.25, 32),
		"info": face_labels(body, sides, 0.5, -0.2, 40)}

# A small cube on top of a crate that you can pick up
func make_sticker(crate: Dictionary, color: Color, text_size: int) -> void:
	var sticker = _clickable(Area3D.new(), Vector3(0.4, 0.4, 0.4), color, crate["body"])
	sticker.position = Vector3(0, 0.7, 0)
	crate["sticker"] = sticker
	crate["sticker_text"] = face_labels(sticker, crate["sides"], 0.2, 0.0, text_size)

func make_sign(pos: Vector3, title: String) -> Dictionary:
	var body = _clickable(StaticBody3D.new(), Vector3(0.1, 1, 1.8), Color(0.95, 0.95, 0.9), self)
	body.position = pos
	var board: StandardMaterial3D = body.meshes[0].material_override
	board.emission_enabled = true
	board.emission = SIGN_GLOW
	board.emission_energy_multiplier = 0.4

	# Soft halo around the board (not in body.meshes, so it gets no outline)
	var halo := MeshInstance3D.new()
	var halo_box := BoxMesh.new()
	halo_box.size = Vector3(0.14, 1.2, 2.0)
	halo.mesh = halo_box
	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	halo_mat.albedo_color = Color(SIGN_GLOW, 0.25)
	halo.material_override = halo_mat
	body.add_child(halo)

	# Sparkles drifting up from the board
	var sparkles := CPUParticles3D.new()
	var dot := QuadMesh.new()
	dot.size = Vector2(0.04, 0.04)
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dot_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dot_mat.vertex_color_use_as_albedo = true
	dot.material = dot_mat
	sparkles.mesh = dot
	sparkles.amount = 16
	sparkles.lifetime = 2.0
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparkles.emission_box_extents = Vector3(0.2, 0.5, 0.9)
	sparkles.direction = Vector3.UP
	sparkles.spread = 20.0
	sparkles.gravity = Vector3.ZERO
	sparkles.initial_velocity_min = 0.1
	sparkles.initial_velocity_max = 0.25
	var fade := Gradient.new()
	fade.set_color(0, Color(SIGN_GLOW, 0.9))
	fade.set_color(1, Color(SIGN_GLOW, 0.0))
	sparkles.color_ramp = fade
	body.add_child(sparkles)

	# Float: bob up and down, and the halo pulses. Tweens belong to the sign, so they stop when it's freed.
	var bob: Tween = body.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	bob.tween_property(body, "position:y", pos.y + SIGN_BOB, SIGN_BOB_TIME)
	bob.tween_property(body, "position:y", pos.y - SIGN_BOB, SIGN_BOB_TIME)
	var pulse: Tween = body.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_property(halo_mat, "albedo_color:a", 0.1, SIGN_BOB_TIME)
	pulse.tween_property(halo_mat, "albedo_color:a", 0.3, SIGN_BOB_TIME)

	var label := Label3D.new()
	label.text = title
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 56
	label.outline_size = 10
	label.position = Vector3(0, 0.9, 0)
	body.add_child(label)
	return {"body": body, "label": label, "slots": 0}

# A flat tag stuck on the front of a shelf product (shelf items face +z)
func make_tag(body: Node3D, color: Color, text: String, height := 0.14):
	var tag = _clickable(Area3D.new(), Vector3(0.34, height, 0.04), color, body)
	tag.position = Vector3(0, 0, 0.21)
	set_text(face_labels(tag, [Vector3(0, 0, 1)], 0.02, 0.0, 14), text)
	return tag

# A sticker that isn't on any crate (for example, the cashier hands it to you)
func make_loose_sticker(color: Color, sides: Array, text: String, text_size: int):
	var sticker = _clickable(Area3D.new(), Vector3(0.4, 0.4, 0.4), color, self)
	set_text(face_labels(sticker, sides, 0.2, 0.0, text_size), text)
	return sticker

# A new crate arrives: it grows in from nothing
func deliver(pos: Vector3, sides: Array) -> Dictionary:
	var crate := make_crate(pos, sides)
	crate["body"].scale = Vector3.ONE * 0.01
	create_tween().tween_property(crate["body"], "scale", Vector3.ONE, 0.8)
	return crate

func pick_up(sticker) -> void:
	held = sticker
	held.collision_layer = 0   # so your aim goes through the sticker you're holding
	held.reparent(hand, false)
	held.position = Vector3.ZERO

# Stick the held sticker on the sign, on the side that faces the player (x_side = -1 or 1)
func put_on_sign(shop_sign: Dictionary, x_side: float) -> void:
	held.reparent(shop_sign["body"], false)
	held.position = Vector3(x_side * 0.1, -0.2, -0.4 + shop_sign["slots"] * 0.8)
	held = null
	shop_sign["slots"] += 1

# A customer buys the crate: it shrinks away and is gone for good
func sell(crate: Dictionary) -> void:
	var body = crate["body"]
	body.collision_layer = 0
	if crate.has("sticker") and is_instance_valid(crate["sticker"]) and crate["sticker"].get_parent() == body:
		crate["sticker"].collision_layer = 0
	var tween := create_tween()
	tween.tween_property(body, "scale", Vector3.ONE * 0.01, 0.8)
	tween.tween_callback(body.queue_free)

# ---------- Labels ----------

# Flat labels printed on the given faces of a box
func face_labels(parent: Node3D, sides: Array, half: float, y: float, size: int) -> Array:
	var labels := []
	for side in sides:
		var l := Label3D.new()
		l.font_size = size
		l.outline_size = 8
		l.position = side * (half + 0.01) + Vector3(0, y, 0)
		l.rotation.y = atan2(side.x, side.z)
		parent.add_child(l)
		labels.append(l)
	return labels

func set_text(labels: Array, text: String) -> void:
	for l in labels:
		l.text = text

func _clickable(body, size: Vector3, color: Color, parent: Node, model: PackedScene = null):
	body.set_script(CLICKABLE)
	parent.add_child(body)
	body.build(size, color, model)
	return body
