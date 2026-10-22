extends "res://quest_kit.gd"

# Mission 2: "The Last Crate" (deletion anomaly)
# Algeria's capital is written ONLY on its one crate. Sell the crate and the
# fact is gone too. The fix: move the fact to the Algeria sign before selling.

enum State { SELL_FIRST, ASK_CASHIER, REWIND, SAVE_FACT, SELL_AGAIN, DONE }

const CRATE_SPOT = Vector3(-10.5, 0.5, -7)
const SIGN_SPOT = Vector3(-13.5, 2, -7)
const SIDES = [Vector3(1, 0, 0), Vector3(0, 0, 1)]   # sign is on the -x side
const GREEN = Color(0.1, 0.55, 0.3)

var state := State.SELL_FIRST
var country_name := ""
var capital := ""
var crate: Dictionary
var shop_sign: Dictionary

func setup(country: Dictionary) -> void:
	country_name = country["name"]
	capital = country["facts"]["capital"]

func start() -> void:
	started = true
	_spawn_crate()
	say.emit("Cashier: New job! Our ONLY %s crate is in the back LEFT corner.\nIts sticker is the only place we wrote %s's capital.\n\nA customer wants it. Go click the crate to sell it!" % [country_name, country_name])

func on_cashier() -> void:
	match state:
		State.ASK_CASHIER:
			state = State.REWIND
			say.emit("Cashier: %s's capital? Hmm... I don't know!\nIt was only written on that crate. When the crate left, the fact left too.\nThat's a DELETION ANOMALY.\n\nTalk to me again to rewind time." % country_name)
		State.REWIND:
			_spawn_crate()
			shop_sign = make_sign(SIGN_SPOT, "%s SIGN\n(put stickers here)" % country_name.to_upper())
			shop_sign["body"].clicked.connect(_on_sign)
			state = State.SAVE_FACT
			say.emit("Time rewound! The crate is back.\nThis time, SAVE the fact first: put the capital sticker on the %s sign." % country_name)
		State.DONE:
			say.emit("Cashier: Thanks! Now we'll never forget %s's capital." % country_name)
		_:
			say.emit(_goal())

func _goal() -> String:
	match state:
		State.SELL_FIRST:
			return "Click the %s crate (back left corner) to sell it." % country_name
		State.SAVE_FACT:
			return "Pick up the capital sticker and put it on the %s sign." % country_name
		State.SELL_AGAIN:
			return "Click the %s crate to sell it again." % country_name
	return ""

func _spawn_crate() -> void:
	crate = make_crate(CRATE_SPOT, SIDES)
	set_text(crate["names"], "%s\nCRATE" % country_name.to_upper())
	set_text(crate["info"], "LAST ONE")
	make_sticker(crate, GREEN, 20)
	set_text(crate["sticker_text"], capital.to_upper())
	crate["body"].clicked.connect(_on_crate)
	crate["sticker"].clicked.connect(_on_sticker)

func _on_crate(_node) -> void:
	match state:
		State.SELL_FIRST:
			sell(crate)
			state = State.ASK_CASHIER
			say.emit("Sold! The crate is gone.\n\nQuick: what is %s's capital? Go ask the cashier." % country_name)
		State.SELL_AGAIN:
			sell(crate)
			state = State.DONE
			done = true
			say.emit("Sold again... and the sign STILL says %s!\nFacts about a country live with the country, not on one crate.\n\nMission complete!" % capital)
		State.SAVE_FACT:
			say.emit("Not yet! Save the capital first: " + _goal())

func _on_sticker(node) -> void:
	# Before the fix, the sticker is just part of the crate
	if state != State.SAVE_FACT:
		_on_crate(node)
		return
	if held:
		return
	pick_up(crate["sticker"])
	say.emit("Got it! Now click the %s sign." % country_name)

func _on_sign(_node) -> void:
	if state != State.SAVE_FACT:
		return
	if not held:
		say.emit("Pick up the sticker from the crate first.")
		return
	put_on_sign(shop_sign, 1)
	shop_sign["label"].text = "%s SIGN\nCapital: %s" % [country_name.to_upper(), capital]
	set_text(crate["names"], "%s CRATE\nreads sign:" % country_name.to_upper())
	set_text(crate["info"], capital.to_upper())
	state = State.SELL_AGAIN
	say.emit("Saved! The capital now lives on the sign.\n\n" + _goal())
