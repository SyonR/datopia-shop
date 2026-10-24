extends Node3D

# Runs the cashier's missions in order. Each mission is its own script.

signal say(text)
signal mission_completed

# Dev shortcut: press 1, 2 or 3 while playing to jump straight to that mission.
# Set to false before exporting the game.
const DEV_MODE := true

# [mission script, which country from the JSON]
const MISSIONS = [
	[preload("res://missions/mission_mixed_crates.gd"), 0],   # Albania
	[preload("res://missions/mission_last_item.gd"), 1],      # Algeria
	[preload("res://missions/mission_no_item.gd"), 2],        # Argentina
]

var countries: Array
var shelf
var missions := []
var current := 0

func setup(country_list: Array, food_shelf) -> void:
	countries = country_list
	shelf = food_shelf
	_create_missions()

func on_cashier() -> void:
	var m = missions[current]
	if not m.started:
		m.start()
	elif m.done and current + 1 < missions.size():
		current += 1
		missions[current].start()
	else:
		m.on_cashier()

func _unhandled_input(event: InputEvent) -> void:
	if not DEV_MODE or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var n: int = event.physical_keycode - KEY_1
	if n >= 0 and n < missions.size():
		_jump_to(n)

# Throw away every mission (and anything they built) and start mission n fresh
func _jump_to(n: int) -> void:
	for m in missions:
		m.cleanup()
		if is_instance_valid(m.held):
			m.held.queue_free()   # a sticker you were carrying
		m.queue_free()
	_create_missions()
	current = n
	for i in n:
		missions[i].done = true   # count skipped missions as done on the progress bar
	say.emit("[DEV] Jumped to mission %d." % (n + 1))
	missions[n].start()

func _create_missions() -> void:
	missions.clear()
	var hand: Node3D = get_node("../player").hand
	for entry in MISSIONS:
		var m = entry[0].new()
		add_child(m)
		m.hand = hand
		m.shelf = shelf
		m.setup(countries[entry[1]])
		m.say.connect(say.emit)
		m.completed.connect(mission_completed.emit)
		missions.append(m)
