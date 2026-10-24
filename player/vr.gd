extends XROrigin3D

# VR mode for the web build (WebXR, e.g. the Meta Quest browser).
# Desktop controls keep working until the player presses "Enter VR".
# Right trigger = click, left stick = walk, right stick = snap turn, Y = pause menu.
# (The Quest's ≡ button belongs to the browser: WebXR never hands it to the game.)

signal started
signal ended
signal trigger
signal grip
signal menu_pressed

const RAY_LENGTH := 3.0
const DEADZONE := 0.2
const SNAP_TURN := PI / 6   # 30 degrees
const VR_MENU = preload("res://ui/vr_menu.gd")
const DEBUG_BUTTONS := true   # show the last button name per hand on the HUD; turn off for release

var xr: XRInterface
var active := false
var head: XRCamera3D
var left: XRController3D
var right: XRController3D
var ray: RayCast3D
var panel: Label3D
var button: Button
var menu_screen   # vr_menu.gd: where the pause menu shows up in VR
var turned := false   # snap turn waits for the stick to return to center
var last_button := {"left": "-", "right": "-"}   # for DEBUG_BUTTONS

func _ready() -> void:
	position = Vector3(0, -1, 0)   # the floor under the player's capsule
	head = XRCamera3D.new()
	add_child(head)
	left = _controller("left_hand")
	right = _controller("right_hand")
	right.button_pressed.connect(_on_button)
	right.button_released.connect(_on_released)
	left.button_pressed.connect(_on_left_button)

	menu_screen = VR_MENU.new()
	menu_screen.setup(head, right)
	add_child(menu_screen)

	# Laser pointer on the right hand (replaces the crosshair)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -RAY_LENGTH)
	ray.collide_with_areas = true
	ray.add_exception(get_parent())
	right.add_child(ray)
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.005, 0.005, RAY_LENGTH)
	beam.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = mat
	beam.position = Vector3(0, 0, -RAY_LENGTH / 2)
	right.add_child(beam)

	# Mission text floats above the left hand (the 2D HUD isn't visible in VR)
	panel = Label3D.new()
	panel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	panel.no_depth_test = true
	panel.pixel_size = 0.0006
	panel.font_size = 32
	panel.outline_size = 12
	panel.width = 600
	panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	panel.position = Vector3(0, 0.1, 0)
	left.add_child(panel)

	xr = XRServer.find_interface("WebXR")
	if xr:   # only exists in the web build
		xr.session_supported.connect(_on_supported)
		xr.session_started.connect(_on_started)
		xr.session_ended.connect(_on_ended)
		xr.session_failed.connect(_on_failed)
		xr.is_session_supported("immersive-vr")

# Put the "Enter VR" button on the game's 2D UI (hidden until VR is available)
func setup(ui: CanvasLayer) -> void:
	button = Button.new()
	button.text = "Enter VR"
	button.add_theme_font_size_override("font_size", 28)
	button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	button.position.y -= 40
	button.hide()
	button.pressed.connect(_enter)
	ui.add_child(button)

# Left stick, relative to where your head faces
func move_direction() -> Vector3:
	var stick := _stick(left)
	if stick.length() < DEADZONE:
		return Vector3.ZERO
	var forward := -head.global_basis.z
	var side := head.global_basis.x
	forward.y = 0
	side.y = 0
	return (forward.normalized() * stick.y + side.normalized() * stick.x).limit_length(1.0)

# Right stick: -1 / 1 once per flick, 0 otherwise
func snap_turn() -> float:
	var x := _stick(right).x
	if abs(x) < 0.6:
		turned = false
		return 0.0
	if turned:
		return 0.0
	turned = true
	return -SNAP_TURN * sign(x)

# WebXR calls the stick "thumbstick"; OpenXR action maps call it "primary".
# Some browsers put it on "touchpad" instead, so take whichever one is moving.
func _stick(hand: XRController3D) -> Vector2:
	for input_name in ["thumbstick", "primary", "touchpad"]:
		var v := hand.get_vector2(input_name)
		if v != Vector2.ZERO:
			return v
	return Vector2.ZERO

func set_hud(text: String) -> void:
	if DEBUG_BUTTONS:
		text += "\n\n[debug] L: %s  R: %s\nsticks L: %s  R: %s" % [last_button.left, last_button.right, _stick(left), _stick(right)]
	if panel.text != text:
		panel.text = text

func _controller(tracker: String) -> XRController3D:
	var c := XRController3D.new()
	c.tracker = tracker
	c.visible = false   # no laser or HUD on desktop
	add_child(c)
	return c

func _on_button(input_name: String) -> void:
	last_button.right = input_name
	if menu_screen.is_open():
		if input_name == "trigger_click":
			menu_screen.press(true)
		elif input_name == "by_button":
			menu_pressed.emit()   # B closes it too
		return
	if input_name == "trigger_click":
		trigger.emit()
	elif input_name == "grip_click":
		grip.emit()

func _on_released(input_name: String) -> void:
	if input_name == "trigger_click" and menu_screen.is_open():
		menu_screen.press(false)

func _on_left_button(input_name: String) -> void:
	last_button.left = input_name
	if input_name in ["by_button", "menu_button"]:   # Y (menu_button in case a browser ever passes ≡ through)
		menu_pressed.emit()

# The menu's "Exit VR" button
func exit() -> void:
	if active:
		xr.uninitialize()

func _on_supported(mode: String, supported: bool) -> void:
	if mode == "immersive-vr" and supported:
		button.show()

func _enter() -> void:
	# Must run from a click: browsers only start VR after a user gesture
	xr.session_mode = "immersive-vr"
	xr.requested_reference_space_types = "local-floor, local"
	xr.optional_features = "local-floor"
	if not xr.initialize():
		button.text = "VR failed to start"

func _on_started() -> void:
	# "local" puts the origin at your head instead of the floor
	position.y = -1.0 if xr.reference_space_type == "local-floor" else 0.6
	get_viewport().use_xr = true
	head.current = true
	active = true
	left.visible = true
	right.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	button.hide()
	started.emit()

func _on_ended() -> void:
	get_viewport().use_xr = false
	active = false
	left.visible = false
	right.visible = false
	button.show()
	ended.emit()

func _on_failed(message: String) -> void:
	button.text = "VR failed: " + message
