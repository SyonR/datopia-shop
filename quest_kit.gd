extends Node3D

# Shared building blocks for the cashier's missions: crates, stickers, signs.
# Each mission script extends this file.

signal say(text)

const CLICKABLE = preload("res://clickable.gd")
const CRATE_COLOR = Color(0.6, 0.4, 0.2)
const CRATE_MODEL = preload("res://models/furniture/cardboardBoxClosed.glb")

var hand: Node3D   # the player's carried-sticker spot
var shelf          # the food shelf (shelf.gd)
var started := false
var done := false
var held = null   # the sticker you are carrying

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
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.08
	cyl.height = 2.0
	post.mesh = cyl
	post.position = Vector3(pos.x, 1.0, pos.z)
	add_child(post)

	var body = _clickable(StaticBody3D.new(), Vector3(0.1, 1, 1.8), Color(0.95, 0.95, 0.9), self)
	body.position = pos
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
