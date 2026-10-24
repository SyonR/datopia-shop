extends "res://missions/quest_kit.gd"

# Mission 1: "The Mixed-Up Crates" (update anomaly)
# Two crates each keep their own COPY of the current price, and both claim to
# be current, so when only one gets relabeled they disagree. The fix: keep the
# price in ONE place (the sign) and have the crates read it from there.
# Prices are made-up teaching values, not from the country data.

enum State { FIND_OLD, MOVE_STICKERS, ASK_CASHIER, DONE }

const CRATE_SPOTS = [Vector3(10.5, 0.5, -3), Vector3(11, 0.5, -7)]
const SIGN_SPOT = Vector3(13.5, 2, -5.5)
const SIDES = [Vector3(-1, 0, 0), Vector3(0, 0, 1)]   # sign is on the +x side
const RED = Color(0.85, 0.1, 0.15)
const CLAIM_COLOR = Color(1, 0.85, 0.2)   # the "CURRENT PRICE" heading stands out
const OLD_PRICE = 5.0
const NEW_PRICE = 6.0
const FINAL_PRICE = 7.0

var state := State.FIND_OLD
var country_name := ""
var crates := []
var shop_sign: Dictionary

func setup(country: Dictionary) -> void:
	country_name = country["name"]

func start() -> void:
	started = true
	for i in CRATE_SPOTS.size():
		var crate := make_crate(CRATE_SPOTS[i], SIDES)
		_set_heading(crate, "%s\nCURRENT PRICE" % country_name.to_upper())
		make_sticker(crate, RED, 28)
		crate["body"].clicked.connect(_on_crate.bind(i))
		crate["sticker"].clicked.connect(_on_sticker.bind(i))
		crates.append(crate)
		_set_crate_price(i, OLD_PRICE)
	shop_sign = make_sign(SIGN_SPOT, "%s SIGN\n(put stickers here)" % country_name.to_upper())
	shop_sign["body"].clicked.connect(_on_sign)
	# The price change only reaches ONE crate: now the two copies disagree
	_set_crate_price(0, NEW_PRICE)
	say.emit("Cashier: Price change! %s goods now cost %s, but I only relabeled ONE crate.\nBoth crates say CURRENT PRICE, yet they disagree. Only one can be right!\n\n%s" % [country_name, _money(NEW_PRICE), _goal()])

func on_cashier() -> void:
	match state:
		State.ASK_CASHIER:
			_final_price_change()
		State.DONE:
			say.emit("Cashier: Thanks! Those crates will never disagree again.")
		_:
			say.emit(_goal())

func _goal() -> String:
	match state:
		State.FIND_OLD:
			return "Click the %s crate whose CURRENT PRICE still says the old %s (back right corner)." % [country_name, _money(OLD_PRICE)]
		State.MOVE_STICKERS:
			return "Pick up both price stickers and put them on the %s sign." % country_name
	return ""

func _on_crate(_node, i: int) -> void:
	if state != State.FIND_OLD:
		return
	if crates[i]["value"] == NEW_PRICE:
		say.emit("This crate already shows the new %s. Find the other one!" % _money(NEW_PRICE))
		return
	state = State.MOVE_STICKERS
	say.emit("Yes! It still says %s.\nBoth crates claim to show the CURRENT price, but they disagree.\nTwo copies of one fact got out of sync. That's an UPDATE ANOMALY.\n\nFix it: %s" % [_money(OLD_PRICE), _goal()])

func _on_sticker(node, i: int) -> void:
	# While looking for the wrong crate, clicking its sticker counts as clicking the crate
	if state == State.FIND_OLD:
		_on_crate(node, i)
		return
	if state != State.MOVE_STICKERS:
		return
	if held:
		say.emit("Your hands are full! Put this sticker on the sign first.")
		return
	pick_up(crates[i]["sticker"])
	set_text(crates[i]["info"], "?")
	say.emit("Got it! Now click the %s sign." % country_name)

func _on_sign(_node) -> void:
	if state != State.MOVE_STICKERS:
		return
	if not held:
		say.emit("Pick up a sticker from a crate first.")
		return
	put_on_sign(shop_sign, -1)
	if shop_sign["slots"] < 2:
		say.emit("One more sticker!")
		return
	_show_price(NEW_PRICE)
	state = State.ASK_CASHIER
	say.emit("Now there is ONE current price, on the sign, and both crates READ it.\nGo tell the cashier!")

func _final_price_change() -> void:
	_show_price(FINAL_PRICE)
	state = State.DONE
	complete()
	say.emit("Cashier: Another price change! %s goods now cost %s.\n\nI changed it ONCE, on the sign... and BOTH crates show the new current price, because it lives in ONE place.\nOne fact, one place!\n\nTalk to me again for your next job." % [country_name, _money(FINAL_PRICE)])

# The sign holds the price, and both crates point to it
func _show_price(price: float) -> void:
	shop_sign["label"].text = "%s SIGN\nCurrent price: %s" % [country_name.to_upper(), _money(price)]
	for c in crates:
		_set_heading(c, "%s\nCURRENT PRICE\n(READS SIGN)" % country_name.to_upper())
		set_text(c["info"], _money(price))
		set_text(c["sticker_text"], "")   # the stickers are part of the sign now
		c["value"] = price

func _set_crate_price(i: int, price: float) -> void:
	crates[i]["value"] = price
	set_text(crates[i]["sticker_text"], _money(price))
	set_text(crates[i]["info"], _money(price))

func _set_heading(crate: Dictionary, text: String) -> void:
	for l in crate["names"]:
		l.text = text
		l.modulate = CLAIM_COLOR
		l.font_size = 24

func _money(price: float) -> String:
	return "$%.2f" % price
