extends CanvasLayer

# Pause menu: Tab or Esc opens and closes it. The whole game pauses while it's open
# (music included, since AudioStreamPlayers pause with the tree).
# On the Datopia website, Fullscreen and Quit ask the page around the game
# (ShopGame.tsx's window.shopGame), because the page owns the fullscreen shell.
# In VR, Y opens it on a floating screen instead (ui/vr_menu.gd), and the laser is the mouse.

const CONTROLS = [
	["WASD", "Move"],
	["Mouse", "Look around"],
	["Click", "Interact / capture mouse"],
	["B", "Broom"],
	["Tab / Esc", "Open this menu"],
]
const CONTROLS_VR = [
	["Left stick", "Move"],
	["Right stick", "Turn"],
	["Right trigger", "Interact"],
	["Right grip", "Broom"],
	["Y / B", "Open / close this menu"],
]
const BUTTON_WIDTH = 256

var music      # music.gd
var vr         # vr.gd; in VR the menu opens on vr.menu_screen
var is_open := false
var was_captured := false   # to notice the browser freeing the mouse on Esc
var opened_at := 0          # msec; the same Esc can arrive both as a key and as "mouse freed"
var fullscreen_button := Button.new()   # "Exit VR" while in VR
var controls_desktop: GridContainer
var controls_vr: GridContainer
var js_open   # keeps the window.shopOpenMenu callback alive

func setup(the_music, the_vr) -> void:
	music = the_music
	vr = the_vr
	vr.menu_pressed.connect(func(): close() if is_open else open())
	vr.ended.connect(close)

func _ready() -> void:
	layer = 10   # above the game's UI
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while the game is paused

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	# The margin keeps the column off the left edge; the column centers itself vertically
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title := Label.new()
	title.text = "DATOPIA\nSHOP"
	title.rotation_degrees = -6
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color.BLACK)
	var tag := StyleBoxFlat.new()
	tag.bg_color = Color(0.99, 0.88, 0.28)
	tag.set_content_margin_all(10)
	title.add_theme_stylebox_override("normal", tag)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(title)
	column.add_child(Control.new())   # a little extra space under the title

	_add_button(column, Button.new(), "Resume", close)
	_add_button(column, fullscreen_button, "Fullscreen", _toggle_fullscreen)
	_add_button(column, Button.new(), "Restart", _restart)
	if _can_quit():
		_add_button(column, Button.new(), "Quit Game", _quit)

	_add_volume(column, "MUSIC VOLUME", music.volume, music.set_volume)
	_add_volume(column, "VOICE VOLUME", music.voice_volume, music.set_voice_volume)

	var controls := PanelContainer.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0, 0, 0, 0.6)
	panel.border_color = Color(1, 1, 1, 0.3)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(16)
	controls.add_theme_stylebox_override("panel", panel)
	controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	controls.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	controls.position += Vector2(-24, 24)
	var stack := VBoxContainer.new()   # holds both lists; open() shows the one for this mode
	controls_desktop = _controls_grid(CONTROLS)
	controls_vr = _controls_grid(CONTROLS_VR)
	stack.add_child(controls_desktop)
	stack.add_child(controls_vr)
	controls.add_child(stack)
	add_child(controls)

	hide()

	# The website calls this when the browser leaves fullscreen (Esc there never reaches the game)
	if OS.has_feature("web"):
		js_open = JavaScriptBridge.create_callback(func(_args): open())
		JavaScriptBridge.get_interface("window").shopOpenMenu = js_open

func open() -> void:
	if is_open:
		return
	is_open = true
	opened_at = Time.get_ticks_msec()
	get_tree().paused = true
	controls_desktop.visible = not vr.active
	controls_vr.visible = vr.active
	if vr.active:
		fullscreen_button.text = "Exit VR"
		vr.menu_screen.attach(self)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		fullscreen_button.text = "Exit Fullscreen" if _is_fullscreen() else "Fullscreen"
	show()

func close() -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = false
	hide()
	vr.menu_screen.detach()
	if not vr.active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode in [KEY_TAB, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()   # so Tab doesn't move button focus
		if is_open:
			if Time.get_ticks_msec() - opened_at > 300:
				close()
		else:
			open()

func _process(_delta: float) -> void:
	# In a browser, Esc frees the mouse without the game seeing the key: treat that as "open menu"
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	# (Entering VR frees the mouse too; that one doesn't count)
	if was_captured and not captured and not is_open and not vr.active:
		open()
	was_captured = captured

func _add_button(column: VBoxContainer, button: Button, text: String, action: Callable) -> void:
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.x = BUTTON_WIDTH
	button.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		var lit: bool = state != "normal"
		s.bg_color = Color.WHITE if lit else Color(0, 0, 0, 0.3)
		s.border_color = Color(1, 1, 1, 0.8)
		s.set_border_width_all(2)
		s.set_corner_radius_all(6)
		s.content_margin_left = 20
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		button.add_theme_stylebox_override(state, s)
	button.add_theme_color_override("font_hover_color", Color.BLACK)
	button.add_theme_color_override("font_pressed_color", Color.BLACK)
	button.add_theme_color_override("font_focus_color", Color.BLACK)
	button.pressed.connect(action)
	column.add_child(button)

# A "TITLE  50%" row with a 0-1 slider under it
func _add_volume(column: VBoxContainer, title: String, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.x = BUTTON_WIDTH
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var percent := Label.new()
	percent.add_theme_color_override("font_color", Color(0.99, 0.88, 0.28))
	percent.text = "%d%%" % roundi(value * 100)
	row.add_child(percent)
	column.add_child(row)
	var slider := HSlider.new()
	slider.custom_minimum_size.x = BUTTON_WIDTH
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.value_changed.connect(on_change)
	slider.value_changed.connect(func(v: float): percent.text = "%d%%" % roundi(v * 100))
	column.add_child(slider)

func _controls_grid(rows: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	for row in rows:
		var key := Label.new()
		key.text = row[0]
		key.add_theme_color_override("font_color", Color(0.99, 0.88, 0.28))
		grid.add_child(key)
		var action := Label.new()
		action.text = row[1]
		grid.add_child(action)
	return grid

func _restart() -> void:
	vr.menu_screen.detach()   # the menu has to be back in the scene to be freed with it
	get_tree().paused = false
	get_tree().reload_current_scene()

# The website shell (window.parent.shopGame) handles these when it's there
func _in_website() -> bool:
	return OS.has_feature("web") and JavaScriptBridge.eval("!!(window.parent !== window && window.parent.shopGame)")

func _can_quit() -> bool:
	return _in_website() or not OS.has_feature("web")

func _quit() -> void:
	if _in_website():
		JavaScriptBridge.eval("window.parent.shopGame.quit()")
	else:
		get_tree().quit()

func _is_fullscreen() -> bool:
	if _in_website():
		return JavaScriptBridge.eval("!!window.parent.document.fullscreenElement")
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

func _toggle_fullscreen() -> void:
	if vr.active:   # this button is "Exit VR" in the headset
		close()
		vr.exit()
		return
	if _in_website():
		JavaScriptBridge.eval("window.parent.shopGame.toggleFullscreen()")
		fullscreen_button.text = "Fullscreen" if _is_fullscreen() else "Exit Fullscreen"   # the browser switches a moment later
		return
	var full := _is_fullscreen()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen_button.text = "Fullscreen" if full else "Exit Fullscreen"
