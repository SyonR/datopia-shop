extends Node

# Optional fun, not part of the missions: a broom for smacking rats.
# Desktop: B or the "Broom" slot toggles it; left click swings while it's out.
# VR: right grip toggles; right trigger swings. The broom rides your left side.
# While the broom is out, clicks swing instead of interacting. Put it away to interact.

const CLICKABLE = preload("res://interact/clickable.gd")
const MODEL = preload("res://models/low_poly_broom.glb")
const SMACK = preload("res://sounds/smack.mp3")
const WALLS = 1 | 2   # store collision + the food shelf
const SMACK_START = 0.92   # the sound file has ~0.9 s of lead-in before the smack
const SMACK_LENGTH = 0.5   # then cut it, so the file's background hiss doesn't trail on

@export var hand_offset := Vector3(-0.4, 0.3, -0.5)    # grip, relative to the player body (desktop)
@export var rest_degrees := Vector3(30, 0, 15)            # x tips the head forward; 30 rests it just above the floor
@export var length := 1.2                                 # meters
@export var swing_time := 0.3      # wind-up + contact + recovery
@export var cooldown := 0.45       # between swing starts
@export var reach := 1.4           # horizontal meters from your eyes to the nearest end of a rat
@export var cone_degrees := 50.0   # half-angle in front of you

var equipped := false
var player
var rats                     # rat_spawner.gd
var grip := Node3D.new()     # the broom hangs from here; swings rotate it
var slot := Button.new()
var swatted := 0             # rats hit so far
var counter := Label.new()   # shown above the slot
var sound := AudioStreamPlayer.new()
var swing: Tween
var hitting := false         # only during the contact part of a swing
var hit_this_swing := []
var wait := 0.0              # cooldown left

func setup(the_player, ui: CanvasLayer, rat_spawner) -> void:
	player = the_player
	rats = rat_spawner
	var model := MODEL.instantiate()
	CLICKABLE.fit_model(model, Vector3.ONE * length, false)   # its long axis is up
	model.position.y -= length / 2   # top of the handle at the grip, bristles down
	grip.add_child(model)
	grip.hide()
	# On the body, not the camera: looking down at a rat mustn't tip the broom into the floor
	_hold_in(player, hand_offset)
	player.vr.started.connect(func(): _hold_in(player.vr.left, Vector3.ZERO))
	player.vr.ended.connect(func(): _hold_in(player, hand_offset))
	player.vr.grip.connect(toggle)

	sound.stream = SMACK
	add_child(sound)

	slot.text = "Broom (B)"
	slot.focus_mode = Control.FOCUS_NONE   # so Space (jump) can't press it
	slot.add_theme_font_size_override("font_size", 18)
	slot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	slot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	slot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slot.position -= Vector2(20, 20)
	slot.pressed.connect(toggle)
	ui.add_child(slot)
	_style_slot()

	counter.add_theme_font_size_override("font_size", 18)
	counter.add_theme_constant_override("outline_size", 6)
	counter.add_theme_color_override("font_outline_color", Color.BLACK)
	counter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	counter.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	counter.grow_vertical = Control.GROW_DIRECTION_BEGIN
	counter.position -= Vector2(20, 70)   # just above the slot
	ui.add_child(counter)
	_update_counter()

func toggle() -> void:
	equipped = not equipped
	grip.visible = equipped
	if not equipped:
		_cancel_swing()
	_style_slot()

func try_swing() -> void:
	if not equipped or wait > 0.0:
		return
	wait = cooldown
	hit_this_swing.clear()
	var rest := rest_degrees * PI / 180.0
	grip.rotation = rest
	swing = create_tween()
	swing.tween_property(grip, "rotation", rest + Vector3(deg_to_rad(100), 0, 0), swing_time * 0.25)   # wind-up: lift
	swing.tween_callback(func(): hitting = true)
	swing.tween_property(grip, "rotation", rest + Vector3(deg_to_rad(-10), 0, 0), swing_time * 0.4)   # contact: chop to the floor
	swing.tween_callback(func(): hitting = false)
	swing.tween_property(grip, "rotation", rest, swing_time * 0.35)   # recovery

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		toggle()

func _physics_process(delta: float) -> void:
	wait = maxf(wait - delta, 0.0)
	if sound.playing and sound.get_playback_position() > SMACK_START + SMACK_LENGTH:
		sound.stop()
	if hitting:
		_check_hits()

# Rats in front of you, within reach, with no wall in between
func _check_hits() -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position
	var forward := -cam.global_basis.z
	forward.y = 0
	for rat in rats.alive():
		if rat in hit_this_swing:
			continue
		var to: Vector3 = rat.global_position - eye
		to.y = 0
		if to.length() - rat.SIZE.x / 2 > reach or forward.angle_to(to) > deg_to_rad(cone_degrees):
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, rat.global_position, WALLS, [player.get_rid()])
		if not get_viewport().get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		hit_this_swing.append(rat)
		if rat.hit():
			sound.play(SMACK_START)
			swatted += 1
			_update_counter()

func _cancel_swing() -> void:
	if swing:
		swing.kill()
	hitting = false
	grip.rotation = rest_degrees * PI / 180.0

func _hold_in(parent: Node3D, offset: Vector3) -> void:
	if grip.get_parent():
		grip.reparent(parent, false)
	else:
		parent.add_child(grip)
	grip.position = offset
	grip.rotation = rest_degrees * PI / 180.0

func _update_counter() -> void:
	counter.text = "Rats swatted: %d" % swatted

# The equipped slot gets a bright yellow border
func _style_slot() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	s.border_color = Color(1, 0.85, 0.2) if equipped else Color(0.85, 0.85, 0.85)
	s.set_border_width_all(4 if equipped else 2)
	s.set_corner_radius_all(3)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	for state in ["normal", "hover", "pressed"]:
		slot.add_theme_stylebox_override(state, s)
