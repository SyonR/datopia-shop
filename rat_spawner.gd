extends Node3D

# Every so often a rat appears at one of a few open floor spots.
# Rats are this node's children, so the count recovers by itself when one is
# freed (smacked, timed out, or the scene reloads).

const RAT = preload("res://rat.gd")
# Open floor, away from shelves, freezers, the counter and mission objects
const SPAWN_POINTS = [
	Vector3(0, 0, 7), Vector3(-6, 0, 7.5), Vector3(6, 0, 7),
	Vector3(0, 0, -5.2), Vector3(-11.5, 0, -6), Vector3(11.5, 0, 2),
]

@export var spawn_min := 8.0    # seconds between spawn attempts
@export var spawn_max := 15.0
@export var max_rats := 5
@export var min_player_distance := 3.0   # don't pop a rat right next to you

var player: Node3D
var timer := Timer.new()

func _ready() -> void:
	timer.one_shot = true
	timer.timeout.connect(_try_spawn)
	add_child(timer)
	timer.start(randf_range(spawn_min, spawn_max))

# Rats that can still be hit
func alive() -> Array:
	return all_rats().filter(func(r): return r.state == RAT.State.ALIVE)

# Includes flattened ones until they vanish (they still count toward max_rats)
func all_rats() -> Array:
	return get_children().filter(func(c): return c.get_script() == RAT)

func spawn(at: Vector3) -> Area3D:
	var rat := Area3D.new()
	rat.set_script(RAT)
	add_child(rat)
	rat.position = at + Vector3(0, RAT.FLOOR_Y + RAT.SIZE.y / 2, 0)
	return rat

func _try_spawn() -> void:
	timer.start(randf_range(spawn_min, spawn_max))
	if all_rats().size() >= max_rats:
		return
	var spots := SPAWN_POINTS.filter(_far_from_player)
	if not spots.is_empty():
		spawn(spots.pick_random())

func _far_from_player(p: Vector3) -> bool:
	if player == null:
		return true
	var d := p - player.global_position
	d.y = 0
	return d.length() >= min_player_distance
