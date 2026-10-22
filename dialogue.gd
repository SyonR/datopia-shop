extends HBoxContainer

# Dialogue box at the bottom of the screen: portrait, name tab, text.
# Grows upward when the text is long, so it never covers the progress bar.

const WIDTH = 640
const PORTRAIT_SIZE = 150

var portrait := TextureRect.new()
var name_tab := PanelContainer.new()
var name_label := Label.new()
var label := Label.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -20
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)

	# Space for a portrait is always kept, so the box doesn't jump sideways
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(portrait)

	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_SHRINK_END
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	name_tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_tab.add_theme_stylebox_override("panel", _box(Vector4(14, 4, 14, 4)))
	name_label.add_theme_font_size_override("font_size", 18)
	name_tab.add_child(name_label)
	column.add_child(name_tab)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(WIDTH, 110)
	box.add_theme_stylebox_override("panel", _box(Vector4(16, 12, 16, 14)))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	box.add_child(label)
	column.add_child(box)
	hide()

# speaker "" hides the name tab; portrait null leaves the portrait spot empty
func say(speaker: String, text: String, face: Texture2D = null) -> void:
	name_label.text = speaker
	name_tab.visible = speaker != ""
	portrait.texture = face
	label.text = text
	show()

# Dark see-through panel with a light border, like a classic RPG text box
func _box(margins: Vector4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	s.border_color = Color(0.85, 0.85, 0.85)
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.content_margin_left = margins.x
	s.content_margin_top = margins.y
	s.content_margin_right = margins.z
	s.content_margin_bottom = margins.w
	return s
