extends CharacterBody3D

signal clicked_empty

const SPEED = 4.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003
const VR = preload("res://player/vr.gd")

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D

var hovered: Node = null
var vr: XROrigin3D
var broom   # broom.gd, set by main; while it's out, clicks swing it
var dialogue   # dialogue.gd, set by main; see _click for clicks while a line is typing
var hand := Node3D.new()   # where a carried sticker sits

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Layer 2 = the food shelf: it blocks walking, but the aim ray sees through it
	set_collision_mask_value(2, true)
	camera.add_child(hand)
	hand.position = Vector3(0.35, -0.3, -0.9)

	vr = VR.new()
	add_child(vr)
	vr.trigger.connect(_click)
	vr.started.connect(_hold_in.bind(vr.right, Vector3(0, 0.05, -0.12), 0.4))
	vr.ended.connect(_on_vr_ended)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse look: left/right turns the body, up/down tilts the camera
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# Esc / Tab open the pause menu (ui/menu.gd), which frees the mouse; clicking grabs it again
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if vr.active:
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_click()

func _click() -> void:
	if broom and broom.equipped:
		broom.try_swing()
		return
	# While a line is typing, clicking empty space or the cashier just shows the rest of it
	# (so you can't skip the cashier's next line unread); clicks on anything else still work.
	if dialogue and dialogue.is_typing() and (not is_instance_valid(hovered) or hovered.is_in_group("finishes_dialogue")):
		dialogue.finish()
		return
	if is_instance_valid(hovered):
		hovered.select()
	else:
		clicked_empty.emit()

# Move the carried-sticker spot to the camera (desktop) or right hand (VR)
func _hold_in(parent: Node3D, pos: Vector3, size: float) -> void:
	hand.reparent(parent, false)
	hand.position = pos
	hand.rotation = Vector3.ZERO
	hand.scale = Vector3.ONE * size

func _on_vr_ended() -> void:
	camera.current = true
	_hold_in(camera, Vector3(0.35, -0.3, -0.9), 1.0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# WASD / arrows: walk relative to where you're facing
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input.x += 1
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	if vr.active:
		dir = vr.move_direction()
		rotate_y(vr.turn(delta))
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED

	move_and_slide()
	update_hover()

# Outline whatever item the crosshair (or VR laser) is pointing at
func update_hover() -> void:
	var hit = (vr.ray if vr.active else ray).get_collider()
	if hit and not hit.has_method("set_highlight"):
		hit = null
	if hit == hovered:
		return
	if is_instance_valid(hovered):
		hovered.set_highlight(false)
	hovered = hit
	if hovered:
		hovered.set_highlight(true)
