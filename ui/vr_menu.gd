extends Node3D

# The pause menu in VR. menu.gd is a CanvasLayer, which the headset can't show, so while
# it's open in VR it moves into a SubViewport drawn on a floating screen in front of you.
# The right-hand laser is the mouse: aim to hover, hold the trigger to click or drag a slider.

const SIZE := Vector2i(1280, 720)   # pixels; the menu lays itself out as if on a 1280x720 window
const WIDTH := 1.6                   # metres
const DISTANCE := 1.4                # metres in front of your head

var head: XRCamera3D
var hand: XRController3D   # the laser hand
var viewport := SubViewport.new()
var quad := QuadMesh.new()
var cursor := MeshInstance3D.new()
var menu: CanvasLayer
var home: Node             # where the menu lives on desktop
var pressing := false
var last_pos := Vector2.ZERO

func setup(the_head: XRCamera3D, the_hand: XRController3D) -> void:
	head = the_head
	hand = the_hand

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # the game is paused while the menu is open
	top_level = true                          # stays put in the world while you look around

	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)

	var screen := MeshInstance3D.new()
	quad.size = Vector2(WIDTH, WIDTH * SIZE.y / SIZE.x)
	screen.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true   # never hidden behind a shelf
	mat.albedo_texture = viewport.get_texture()
	screen.material_override = mat
	add_child(screen)

	# A dot where the laser touches the screen
	var dot := SphereMesh.new()
	dot.radius = 0.008
	dot.height = 0.016
	cursor.mesh = dot
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.no_depth_test = true
	dot_mat.albedo_color = Color(0.99, 0.88, 0.28)
	cursor.material_override = dot_mat
	add_child(cursor)
	hide()

func attach(the_menu: CanvasLayer) -> void:
	menu = the_menu
	home = menu.get_parent()
	menu.reparent(viewport, false)
	var forward := -head.global_basis.z
	forward.y = 0
	global_position = head.global_position + forward.normalized() * DISTANCE
	look_at(head.global_position, Vector3.UP, true)   # +Z (the quad's front) faces you
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pressing = false
	show()

func detach() -> void:
	if not menu:
		return
	menu.reparent(home, false)
	menu = null
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()

func is_open() -> bool:
	return menu != null

# Trigger down / up while the menu is open
func press(down: bool) -> void:
	pressing = down
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	click.position = last_pos
	click.global_position = last_pos
	viewport.push_input(click)

func _process(_delta: float) -> void:
	if not menu:
		return
	# Where the laser meets the screen, in viewport pixels
	var plane := Plane(global_basis.z, global_position)
	var hit = plane.intersects_ray(hand.global_position, -hand.global_basis.z)
	if hit == null:
		cursor.hide()
		return
	var local := to_local(hit)
	var uv := Vector2(local.x / quad.size.x + 0.5, 0.5 - local.y / quad.size.y)
	if not Rect2(0, 0, 1, 1).has_point(uv) and not pressing:
		cursor.hide()
		return
	cursor.show()
	cursor.position = Vector3(local.x, local.y, 0.01)
	var pos := uv.clamp(Vector2.ZERO, Vector2.ONE) * Vector2(SIZE)
	if pos == last_pos:
		return
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	motion.relative = pos - last_pos
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if pressing else 0
	last_pos = pos
	viewport.push_input(motion)
