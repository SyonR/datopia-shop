extends Area3D

# A rat that scurries around the store floor. Optional fun, not part of the
# missions. Smack it with the broom: ALIVE -> FLAT (for one second) -> gone.

enum State { ALIVE, FLAT }

const CLICKABLE = preload("res://clickable.gd")
const MODEL = preload("res://models/characters/low_poly_rat.glb")
const SIZE = Vector3(0.7, 0.3, 0.3)   # long along x; the model's nose points -x
const FLOOR_Y = 0.075   # top of the floor tiles (physics floor is at 0, the tiles stick up)
const LAYER = 8          # physics layer 4: blocks nothing, and the click ray ignores it
const WALLS = 1 | 2      # store collision + the food shelf
const BOUNDS = 13.5      # stay inside the store walls
const FLAT_SCALE = Vector3(1.3, 0.15, 1.3)
const FLAT_TIME = 1.0

@export var speed := 1.5       # meters per second
@export var hop_range := 3.0   # farthest it runs in one go
@export var lifetime := 30.0   # an unhit rat leaves after this, freeing its spawn slot

var state := State.ALIVE
var visual := Node3D.new()   # what gets squashed (never the physics shape); pivots on the floor
var run: Tween
var resting := 0.0           # seconds until the next run
var age := 0.0
var bob := 0.0

func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	visual.position.y = -SIZE.y / 2
	add_child(visual)
	var model := MODEL.instantiate()
	CLICKABLE.fit_model(model, SIZE, false)
	model.position.y += SIZE.y / 2   # bottom of the model on the floor pivot
	visual.add_child(model)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = SIZE
	add_child(shape)
	resting = randf_range(0.2, 0.8)

func _physics_process(delta: float) -> void:
	if state != State.ALIVE:
		return
	age += delta
	if age >= lifetime:
		queue_free()
		return
	if run and run.is_running():
		bob += delta * 25.0   # little hops while it runs
		visual.position.y = -SIZE.y / 2 + absf(sin(bob)) * 0.02
		return
	visual.position.y = -SIZE.y / 2
	resting -= delta
	if resting <= 0.0:
		_scurry()

# First hit squashes it and starts a one-second exit. Later hits do nothing.
func hit() -> bool:
	if state != State.ALIVE:
		return false
	state = State.FLAT
	if run:
		run.kill()
	collision_layer = 0
	visual.position.y = -SIZE.y / 2
	visual.scale = FLAT_SCALE
	get_tree().create_timer(FLAT_TIME, false).timeout.connect(queue_free)   # pauses with the game
	return true

# Run to a random nearby point that has nothing in the way
func _scurry() -> void:
	for attempt in 6:
		var angle := randf() * TAU
		var dir := Vector3(cos(angle), 0, sin(angle))
		var target := position + dir * randf_range(0.8, hop_range)
		if _clear_path(target):
			rotation.y = PI - angle   # turn the nose (-x) toward dir
			run = create_tween()
			run.tween_property(self, "position", target, position.distance_to(target) / speed)
			resting = randf_range(0.3, 1.2)
			return
	resting = 0.5   # boxed in: try again soon

func _clear_path(target: Vector3) -> bool:
	if absf(target.x) > BOUNDS or absf(target.z) > BOUNDS:
		return false
	var query := PhysicsRayQueryParameters3D.create(position, target, WALLS)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
