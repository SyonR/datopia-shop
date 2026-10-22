extends Node

const ITEM_SCENE = preload("res://item.tscn")
const ITEM_COUNT = 5
const COLORS = [Color.TOMATO, Color.GOLD, Color.MEDIUM_SEA_GREEN, Color.DODGER_BLUE, Color.ORCHID]

@onready var popup: PanelContainer = $UI/Popup
@onready var popup_label: Label = $UI/Popup/Label
@onready var progress_bar: ProgressBar = $UI/Progress/Bar
@onready var progress_label: Label = $UI/Progress/Label

func _ready():
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
	$Quest.setup(countries)
	$Quest.say.connect(show_text)
	$Cashier.talked_to.connect($Quest.on_cashier)
	popup.hide()

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
		$player.vr.set_hud(progress_label.text + ("\n\n" + popup_label.text if popup.visible else ""))

func show_text(text: String) -> void:
	popup_label.text = text
	popup.show()

func show_popup(country: Dictionary) -> void:
	var facts = country["facts"]
	var text = "%s\n\nCapital: %s\nRegion: %s\nPopulation: %s million\n" % [
		country["name"], facts["capital"], facts["region"], facts["population_millions"]]
	for key in facts["metrics"]:
		var m = facts["metrics"][key]
		text += "%s: %s %s\n" % [m["label"], m["value"], m["unit"]]
	popup_label.text = text
	popup.show()

func hide_popup() -> void:
	popup.hide()
