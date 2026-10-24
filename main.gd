extends Node

const ITEM_SCENE = preload("res://interact/item.tscn")
const SHELF = preload("res://missions/shelf.gd")
const DIALOGUE = preload("res://ui/dialogue.gd")
const CASHIER_FACE = preload("res://ui/cashier.png")
const CUSTOMER_FACE = preload("res://ui/customer.png")
const RAT_SPAWNER = preload("res://rats/rat_spawner.gd")
const BROOM = preload("res://rats/broom.gd")
const MUSIC = preload("res://sounds/music.gd")
const MENU = preload("res://ui/menu.gd")
const ITEM_COUNT = 5
const COLORS = [Color.TOMATO, Color.GOLD, Color.MEDIUM_SEA_GREEN, Color.DODGER_BLUE, Color.ORCHID]

@onready var progress_bar: ProgressBar = $UI/Progress/Bar
@onready var progress_label: Label = $UI/Progress/Label

var dialogue = DIALOGUE.new()

func _ready():
	$UI.add_child(dialogue)
	var file = FileAccess.open("res://data/countries.enriched.json", FileAccess.READ)
	var countries = JSON.parse_string(file.get_as_text())
	print(countries.size())

	# Put the first 5 countries on top of the 5 display freezers
	for i in ITEM_COUNT:
		var item = ITEM_SCENE.instantiate()
		$Items.add_child(item)
		item.position = Vector3(-8 + i * 4, 1.3, 3)
		item.setup(countries[i], COLORS[i])
		item.selected.connect(show_popup)

	$player.clicked_empty.connect(hide_popup)
	$player.vr.setup($UI)

	var shelf = SHELF.new()
	add_child(shelf)
	shelf.setup(countries, $Store, $player.hand)
	shelf.say.connect(show_text)

	$Quest.setup(countries, shelf)
	$Quest.say.connect(show_text)

	# Optional fun, separate from the missions: rats and a broom
	var rats = RAT_SPAWNER.new()
	rats.player = $player
	add_child(rats)
	var broom = BROOM.new()
	add_child(broom)
	broom.setup($player, $UI, rats)
	$player.broom = broom
	$player.dialogue = dialogue
	$Cashier.talked_to.connect($Quest.on_cashier)

	var music = MUSIC.new()
	music.voice = dialogue.voice
	add_child(music)
	$Quest.mission_completed.connect(music.play_mission_complete)

	var menu = MENU.new()
	menu.setup(music, $player.vr)
	add_child(menu)

# Keep the mission progress bar at the top up to date
func _process(_delta: float) -> void:
	var total: int = $Quest.missions.size()
	var finished := 0
	for m in $Quest.missions:
		if m.done:
			finished += 1
	progress_bar.max_value = total
	progress_bar.value = finished
	var left := total - finished
	progress_label.text = "All missions complete!" if left == 0 else "Missions left: %d of %d" % [left, total]
	if $player.vr.active:
		var hud := progress_label.text
		if dialogue.visible:
			hud += "\n\n" + (dialogue.name_label.text + ": " if dialogue.name_tab.visible else "") + dialogue.shown_text()
		hud += "\n" + $player.broom.counter.text
		if $player.vr.DEBUG_BUTTONS:
			hud += "\n[debug] broom out: %s" % $player.broom.equipped
		$player.vr.set_hud(hud)

# Lines starting with "Cashier: " or "Customer: " get a name tab and portrait
func show_text(text: String) -> void:
	for speaker in [["Cashier", CASHIER_FACE], ["Customer", CUSTOMER_FACE]]:
		var prefix: String = speaker[0] + ": "
		if text.begins_with(prefix):
			dialogue.say(speaker[0], text.trim_prefix(prefix), speaker[1])
			return
	dialogue.say("", text)

func show_popup(country: Dictionary) -> void:
	var facts = country["facts"]
	var text = "Capital: %s\nRegion: %s\nPopulation: %s million\n" % [
		facts["capital"], facts["region"], facts["population_millions"]]
	for key in facts["metrics"]:
		var m = facts["metrics"][key]
		text += "%s: %s %s\n" % [m["label"], m["value"], m["unit"]]
	dialogue.say(country["name"], text.strip_edges(), null, false)

func hide_popup() -> void:
	dialogue.hide()
