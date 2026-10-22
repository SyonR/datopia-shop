extends "res://quest_kit.gd"

# Mission 1: "The Mixed-Up Crates" (update anomaly)
# Two crates each carry their own COPY of Albania's population, so the copies
# can disagree. The fix: keep the number in ONE place (the sign) and have the
# crates read it from there.

enum State { FIND_OLD, MOVE_STICKERS, ASK_CASHIER, DONE }

const CRATE_SPOTS = [Vector3(10.5, 0.5, -3), Vector3(11, 0.5, -7)]
const SIGN_SPOT = Vector3(13.5, 2, -5.5)
const SIDES = [Vector3(-1, 0, 0), Vector3(0, 0, 1)]   # sign is on the +x side
const RED = Color(0.85, 0.1, 0.15)
# Made-up census years so you can tell old numbers from new ones
const OLD_YEAR = 2020
const NEW_YEAR = 2025
const FINAL_YEAR = 2026

var state := State.FIND_OLD
var country_name := ""
var old_pop := 0.0
var new_pop := 0.0
var final_pop := 0.0
var crates := []
var shop_sign: Dictionary

func setup(country: Dictionary) -> void:
	country_name = country["name"]
	old_pop = country["facts"]["population_millions"]
	new_pop = snappedf(old_pop + 0.3, 0.1)
	final_pop = snappedf(old_pop + 0.5, 0.1)

func start() -> void:
	started = true
	for i in CRATE_SPOTS.size():
		var crate := make_crate(CRATE_SPOTS[i], SIDES)
		set_text(crate["names"], "%s\nCRATE" % country_name.to_upper())
		make_sticker(crate, RED, 28)
		crate["body"].clicked.connect(_on_crate.bind(i))
		crate["sticker"].clicked.connect(_on_sticker.bind(i))
		crates.append(crate)
		_set_crate_value(i, old_pop, OLD_YEAR)
	shop_sign = make_sign(SIGN_SPOT, "%s SIGN\n(put stickers here)" % country_name.to_upper())
	shop_sign["body"].clicked.connect(_on_sign)
	# The census only reaches ONE crate: now the two copies disagree
	_set_crate_value(0, new_pop, NEW_YEAR)
	say.emit("Cashier: The %d census is in! %s now has %sM people.\nBut only ONE crate got the update...\n\n%s" % [NEW_YEAR, country_name, new_pop, _goal()])

func on_cashier() -> void:
	match state:
		State.ASK_CASHIER:
			_final_census()
		State.DONE:
			say.emit("Cashier: Thanks! Those crates will never disagree again.")
		_:
			say.emit(_goal())

func _goal() -> String:
	match state:
		State.FIND_OLD:
			return "Find the %s crate with the OLDER year and click it.\n(Back right corner of the store.)" % country_name
		State.MOVE_STICKERS:
			return "Pick up both stickers and put them on the %s sign." % country_name
	return ""

func _on_crate(_node, i: int) -> void:
	if state != State.FIND_OLD:
		return
	if crates[i]["value"] == new_pop:
		say.emit("This crate already has the %d number. Find the other one!" % NEW_YEAR)
		return
	state = State.MOVE_STICKERS
	say.emit("Yes! It still has the old %d number.\nTwo copies of one fact can disagree. That's an ANOMALY.\n\nFix it: %s" % [OLD_YEAR, _goal()])

func _on_sticker(node, i: int) -> void:
	# While looking for the old crate, clicking its sticker counts as clicking the crate
	if state == State.FIND_OLD:
		_on_crate(node, i)
		return
	if state != State.MOVE_STICKERS:
		return
	if held:
		say.emit("Your hands are full! Put this sticker on the sign first.")
		return
	pick_up(crates[i]["sticker"])
	set_text(crates[i]["info"], "EMPTY")
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
	_show_value(new_pop, NEW_YEAR)
	state = State.ASK_CASHIER
	say.emit("Now the crates READ the sign instead of keeping their own copy.\nGo tell the cashier!")

func _final_census() -> void:
	_show_value(final_pop, FINAL_YEAR)
	state = State.DONE
	done = true
	say.emit("Cashier: The %d census is in! %s now has %sM.\n\nLook: BOTH crates changed at once, because the number lives in ONE place.\nOne fact, one place!\n\nTalk to me again for your next job." % [FINAL_YEAR, country_name, final_pop])

# The sign holds the number, and both crates point to it
func _show_value(pop: float, year: int) -> void:
	shop_sign["label"].text = "%s SIGN\n%sM people (%d)" % [country_name.to_upper(), pop, year]
	for c in crates:
		set_text(c["names"], "%s CRATE\nreads sign:" % country_name.to_upper())
		set_text(c["info"], "%sM\n%d" % [pop, year])
		set_text(c["sticker_text"], "")   # the stickers are part of the sign now
		c["value"] = pop

func _set_crate_value(i: int, pop: float, year: int) -> void:
	crates[i]["value"] = pop
	set_text(crates[i]["sticker_text"], "%sM" % pop)
	set_text(crates[i]["info"], str(year))
