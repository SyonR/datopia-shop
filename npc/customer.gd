extends "res://interact/clickable.gd"

# A shopper who walks along a path, waits, takes what you hand them, and walks
# out. The Kenney mini-characters come rigged, with animations built in.

signal arrived

const MODEL = preload("res://models/characters/character-female-b.glb")
const SIZE = Vector3(1.8, 1.8, 1.1)   # wide enough for the arms, so they come out 1.8 m tall
const SPEED = 1.8   # meters per second

var anim: AnimationPlayer
var hand := Node3D.new()   # whatever they carry sits here, in front of them

func setup() -> void:
	build(SIZE, Color.WHITE, MODEL, false)
	anim = find_children("*", "AnimationPlayer", true, false)[0]
	for a in ["idle", "walk", "holding-right"]:
		anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	hand.position = Vector3(-0.3, 0.05, 0.35)   # their right side (they face +z)
	add_child(hand)
	anim.play("idle")

# Start at `from` and walk through `points` (all on the floor), then wait
func walk(from: Vector3, points: Array) -> void:
	position = _stand(from)
	var tween := create_tween()
	var last := position
	for p in points:
		var to := _stand(p)
		tween.tween_callback(_face.bind(to))
		tween.tween_property(self, "position", to, last.distance_to(to) / SPEED)
		last = to
	tween.tween_callback(_stop)
	anim.play("walk")

func take(body: Node3D) -> void:
	body.reparent(hand, false)
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	anim.play("holding-right")

# Nod thanks, then walk off with what you gave them
func thank_and_walk(points: Array) -> void:
	anim.play("emote-yes")
	await anim.animation_finished
	walk(position - Vector3(0, SIZE.y / 2, 0), points)

# Nod (yes) or shake their head (no), then go back to standing
func react(yes: bool) -> void:
	anim.play("emote-yes" if yes else "emote-no")
	anim.queue("holding-right" if carrying() else "idle")

func carrying() -> bool:
	return hand.get_child_count() > 0

func _stand(floor_point: Vector3) -> Vector3:
	return floor_point + Vector3(0, SIZE.y / 2, 0)

func _face(target: Vector3) -> void:
	if not position.is_equal_approx(target):
		look_at(target, Vector3.UP, true)

func _stop() -> void:
	anim.play("holding-right" if carrying() else "idle")
	arrived.emit()
