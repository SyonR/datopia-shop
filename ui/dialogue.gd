extends HBoxContainer

# Dialogue box at the bottom of the screen: portrait, name tab, text.
# Grows upward when the text is long, so it never covers the progress bar.
# Lines appear word by word (the box takes its full size at once, so nothing shifts),
# and the cashier and customer "speak" a gibberish blip per word (voice.gd).
# A click while a line is typing shows the rest of it (player.gd checks is_typing()).

const WIDTH = 640
const PORTRAIT_SIZE = 150
const VOICE = preload("res://ui/voice.gd")
const VOICE_PITCH = {"Cashier": 1.0, "Customer": 1.35}   # speakers not listed here stay silent

@export var words_per_second := 12.0
@export var comma_pause := 0.15      # extra seconds after , ; :
@export var sentence_pause := 0.35   # extra seconds after . ! ? and at line breaks

var portrait := TextureRect.new()
var name_tab := PanelContainer.new()
var name_label := Label.new()
var label := Label.new()
var voice = VOICE.new()

var words := []       # [end index in label.text, the word, extra pause after it]
var next_word := 0
var wait := 0.0       # seconds until the next word appears
var pitch := 0.0      # 0 = this speaker has no voice

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
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING   # lay out the whole line, then hide the rest
	label.add_theme_font_size_override("font_size", 20)
	box.add_child(label)
	column.add_child(box)
	add_child(voice)
	visibility_changed.connect(func(): if not visible: finish())   # dismissed: stop typing and talking
	hide()

# speaker "" hides the name tab; portrait null leaves the portrait spot empty
# animate = false shows the whole text at once (country fact popups)
func say(speaker: String, text: String, face: Texture2D = null, animate := true) -> void:
	finish()   # a new line cuts off the old one, and its voice
	name_label.text = speaker
	name_tab.visible = speaker != ""
	portrait.texture = face
	label.text = text
	pitch = VOICE_PITCH.get(speaker, 0.0)
	words.clear()
	if animate:
		_split_words(text)
	next_word = 0
	wait = 0.0
	label.visible_characters = 0 if animate and not words.is_empty() else -1
	show()

func is_typing() -> bool:
	return next_word < words.size()

# Show the rest of the line now, and stop talking
func finish() -> void:
	next_word = words.size()
	label.visible_characters = -1
	voice.stop()

# What's on screen so far (the VR hand HUD shows this)
func shown_text() -> String:
	return label.text if label.visible_characters < 0 else label.text.left(label.visible_characters)

func _process(delta: float) -> void:
	if not is_typing():
		return
	wait -= delta
	if wait > 0.0:
		return
	var w: Array = words[next_word]
	next_word += 1
	label.visible_characters = w[0]
	wait = 1.0 / words_per_second + w[2]
	if pitch > 0.0:
		voice.speak(w[1], pitch)
	if not is_typing():
		label.visible_characters = -1

func _split_words(text: String) -> void:
	var regex := RegEx.create_from_string("\\S+")
	for m in regex.search_all(text):
		var word := m.get_string()
		var pause := 0.0
		var end := m.get_end()
		if word.right(1) in [".", "!", "?"] or text.substr(end, 1) == "\n":
			pause = sentence_pause
		elif word.right(1) in [",", ";", ":"]:
			pause = comma_pause
		words.append([end, word, pause])

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
