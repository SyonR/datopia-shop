extends "res://quest_kit.gd"

# Mission 3: "No Crate Yet" (insertion anomaly)
# You're handed Argentina's capital, but facts only live on crates and there
# are no Argentina crates yet, so there's nowhere to put it. The fix: give the
# country its own sign, so facts can be saved before any crate exists.

enum State { FIND_CRATE, NO_CRATE, STICK, ORDER, DONE }

const CRATE_SPOT = Vector3(-11, 0.5, 5.5)
const SIGN_SPOT = Vector3(-13.5, 2, 5.5)
const SIDES = [Vector3(1, 0, 0), Vector3(0, 0, 1)]   # sign is on the -x side
const BLUE = Color(0.35, 0.65, 0.95)

var state := State.FIND_CRATE
var country_name := ""
var capital := ""
var shop_sign: Dictionary

func setup(country: Dictionary) -> void:
	country_name = country["name"]
	capital = country["facts"]["capital"]

func start() -> void:
	started = true
	var sticker = make_loose_sticker(BLUE, SIDES, capital.to_upper().replace(" ", "\n"), 20)
	pick_up(sticker)
	say.emit("Cashier: Last job! Here's a sticker: %s's capital is %s.\nPlease stick it on the %s crate.\n\nIf you can't find one, come back and tell me." % [country_name, capital, country_name])

func on_cashier() -> void:
	match state:
		State.FIND_CRATE:
			state = State.NO_CRATE
			say.emit("Cashier: No %s crate? Oh no... we haven't got one yet!\nSo there's NOWHERE to write %s's capital.\nYou can't save a fact until a crate exists. That's an INSERTION ANOMALY.\n\nTalk to me again and I'll put up a %s sign." % [country_name, country_name, country_name])
		State.NO_CRATE:
			shop_sign = make_sign(SIGN_SPOT, "%s SIGN\n(put stickers here)" % country_name.to_upper())
			shop_sign["body"].clicked.connect(_on_sign)
			state = State.STICK
			say.emit("Cashier: Done! The %s sign is in the front LEFT corner.\nStick the capital on it." % country_name)
		State.ORDER:
			var crate := deliver(CRATE_SPOT, SIDES)
			set_text(crate["names"], "%s CRATE\nreads sign:" % country_name.to_upper())
			set_text(crate["info"], capital.to_upper().replace(" ", "\n"))
			state = State.DONE
			done = true
			say.emit("Cashier: Delivered! The new crate already knows its capital, because it reads the sign.\n\nAll 3 missions complete!\nOne fact, one place. That's database normalization!")
		State.DONE:
			say.emit("Cashier: You fixed the whole store. Thank you!")
		State.STICK:
			say.emit("Stick the capital on the %s sign (front left corner)." % country_name)

func _on_sign(_node) -> void:
	if state != State.STICK or not held:
		return
	put_on_sign(shop_sign, 1)
	shop_sign["label"].text = "%s SIGN\nCapital: %s" % [country_name.to_upper(), capital]
	state = State.ORDER
	say.emit("Saved! The fact has a home, even with ZERO crates.\n\nNow ask the cashier to order a %s crate." % country_name)
