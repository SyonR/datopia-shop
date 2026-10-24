extends "res://missions/quest_kit.gd"

# Mission 2: "The Last Item" (deletion anomaly)
# Algeria's capital is written ONLY on the tag of its one shelf product.
# A customer buys it and walks out, and the fact leaves with it.
# The fix: move the fact to the Algeria sign before handing the product over.

enum State { GIVE_FIRST, ASK_CASHIER, REWIND, SAVE_FACT, GIVE_AGAIN, DONE }

const CUSTOMER = preload("res://npc/customer.gd")
const SIGN_SPOT = Vector3(1.9, 2, -0.6)   # beside the food shelf, facing the aisle
const OUTSIDE = Vector3(1.5, 0, 17)       # beyond the front door
const PATH_IN = [Vector3(1.5, 0, 13), Vector3(2.0, 0, 5), Vector3(2.6, 0, 0.4)]
const GREEN = Color(0.1, 0.55, 0.3)

var state := State.GIVE_FIRST
var country_name := ""
var capital := ""
var item: Dictionary   # this country's row on the food shelf
var tag                # green capital tag stuck on the product
var customer
var shop_sign: Dictionary

func setup(country: Dictionary) -> void:
	country_name = country["name"]
	capital = country["facts"]["capital"]

func start() -> void:
	started = true
	item = shelf.find_item(country_name)
	tag = make_tag(item["body"], GREEN, capital.to_upper())
	tag.clicked.connect(_on_tag)
	item["note"] = "Capital: %s (only on this tag!)" % capital
	customer = Area3D.new()
	customer.set_script(CUSTOMER)
	add_child(customer)
	customer.setup()
	customer.clicked.connect(_on_customer)
	customer.walk(OUTSIDE, PATH_IN)
	say.emit("Cashier: A customer wants our LAST %s product: the %s on the food shelf.\nIts green tag is the ONLY place we wrote %s's capital.\n\nTake it off the shelf and hand it to the customer." % [country_name, _product(), country_name])

func on_cashier() -> void:
	match state:
		State.ASK_CASHIER:
			state = State.REWIND
			say.emit("Cashier: %s's capital? Hmm... I don't know!\nIt was only written on that tag. When the %s left, the fact left too.\nThat's a DELETION ANOMALY.\n\nTalk to me again to rewind time." % [country_name, _product()])
		State.REWIND:
			shelf.restock(item)
			item["note"] = "Capital: %s (only on this tag!)" % capital
			customer.walk(OUTSIDE, PATH_IN)
			customer.show()
			customer.collision_layer = 1
			shop_sign = make_sign(SIGN_SPOT, "%s SIGN\n(put stickers here)" % country_name.to_upper())
			shop_sign["body"].clicked.connect(_on_sign)
			state = State.SAVE_FACT
			say.emit("Cashier: Time rewound! The %s is back on the shelf, and the customer is coming in again.\nThis time, SAVE the fact first: move the green capital tag to the %s sign next to the shelf." % [_product(), country_name])
		State.DONE:
			say.emit("Cashier: Thanks! Now we'll never forget %s's capital." % country_name)
		_:
			say.emit(_goal())

func _goal() -> String:
	match state:
		State.GIVE_FIRST:
			return "Take the %s off the food shelf and hand it to the customer." % _product()
		State.SAVE_FACT:
			return "Move the green capital tag from the %s to the %s sign." % [_product(), country_name]
		State.GIVE_AGAIN:
			return "Now hand the %s to the customer." % _product()
	return ""

func _on_customer(_node) -> void:
	match state:
		State.GIVE_FIRST, State.GIVE_AGAIN:
			if shelf.held != item:
				customer.react(false)
				say.emit("Customer: I'd like the %s, please! It's on the food shelf." % _product())
				return
			customer.take(shelf.give_held())
			customer.thank_and_walk(_path_out())
			customer.arrived.connect(_on_customer_gone, CONNECT_ONE_SHOT)
			if state == State.GIVE_FIRST:
				state = State.ASK_CASHIER
				say.emit("The customer walked out with the %s, and its tag.\n\nQuick: what is %s's capital? Go ask the cashier." % [_product(), country_name])
			else:
				state = State.DONE
				complete()
				say.emit("The %s is gone... and the sign STILL says %s!\nFacts about a country live with the country, not on one product.\n\nMission complete!" % [_product(), capital])
		State.SAVE_FACT:
			customer.react(false)
			say.emit("Not yet! Save the capital first: " + _goal())

func _on_customer_gone() -> void:
	customer.hide()
	customer.collision_layer = 0

# Before the fix, the tag is just part of the product: clicking it picks the product up
func _on_tag(_node) -> void:
	if state != State.SAVE_FACT:
		shelf.pick(item)
		return
	if held or shelf.held:
		say.emit("Your hands are full! Put that down first.")
		return
	pick_up(tag)
	item.erase("note")
	say.emit("Got the tag! Now click the %s sign next to the shelf." % country_name)

func _on_sign(_node) -> void:
	if state != State.SAVE_FACT or held != tag:
		return
	put_on_sign(shop_sign, -1)
	tag.rotation.y = -PI / 2   # face the aisle like the sign
	shop_sign["label"].text = "%s SIGN\nCapital: %s" % [country_name.to_upper(), capital]
	item["note"] = "Capital: %s (reads the %s sign)" % [capital, country_name]
	state = State.GIVE_AGAIN
	say.emit("Saved! The capital now lives on the sign.\n\n" + _goal())

# Back the way they came, then out the door
func _path_out() -> Array:
	var path := PATH_IN.duplicate()
	path.reverse()
	path.pop_front()   # that's where they're standing
	path.append(OUTSIDE)
	return path

func _product() -> String:
	return item["name"].to_lower()

# Dev jumps throw this mission away: give the product back to the shelf, untagged
func cleanup() -> void:
	if item.is_empty():
		return
	if is_instance_valid(tag):
		tag.queue_free()
	item.erase("note")
	shelf.restock(item)
