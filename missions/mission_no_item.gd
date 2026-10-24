extends "res://missions/quest_kit.gd"

# Mission 3: "Nothing to Stick It On" (insertion anomaly)
# You're handed Argentina's capital, but capitals only live on product tags and
# the shelf has no Argentina product, so there's nowhere to put it. The fix:
# give the country its own sign, so facts can be saved before any product exists.

enum State { FIND_ITEM, NO_ITEM, STICK, ORDER, DONE }

const SIGN_SPOT = Vector3(7.7, 2, -0.6)   # right end of the food shelf, facing the aisle
const SIDES = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)]
const BLUE = Color(0.35, 0.65, 0.95)
const PRODUCT = ["Honey", "honey", 4.00]   # name, model, price (made up)

var state := State.FIND_ITEM
var country_name := ""
var capital := ""
var shop_sign: Dictionary
var item: Dictionary   # the product delivered at the end

func setup(country: Dictionary) -> void:
	country_name = country["name"]
	capital = country["facts"]["capital"]

func start() -> void:
	started = true
	var sticker = make_loose_sticker(BLUE, SIDES, capital.to_upper().replace(" ", "\n"), 20)
	pick_up(sticker)
	shelf.busy_handler = _on_product
	say.emit("Cashier: Last job! Here's a fact: %s's capital is %s.\nOn our shelf, capitals go on product tags, so stick it on the %s product.\n\nIf you can't find one, come back and tell me." % [country_name, capital, country_name])

func on_cashier() -> void:
	match state:
		State.FIND_ITEM:
			state = State.NO_ITEM
			say.emit("Cashier: No %s product? Oh no... we don't stock one yet!\nSo there's NOWHERE to write %s's capital.\nYou can't save a fact until a product exists for it. That's an INSERTION ANOMALY.\n\nTalk to me again and I'll put up a %s sign." % [country_name, country_name, country_name])
		State.NO_ITEM:
			shop_sign = make_sign(SIGN_SPOT, "%s SIGN\n(put stickers here)" % country_name.to_upper())
			shop_sign["body"].clicked.connect(_on_sign)
			state = State.STICK
			say.emit("Cashier: Done! The %s sign is at the RIGHT end of the food shelf.\nStick the capital on it." % country_name)
		State.ORDER:
			item = shelf.add_item(PRODUCT[0], PRODUCT[1], PRODUCT[2], country_name)
			var tag = make_tag(item["body"], BLUE, capital.to_upper().replace(" ", "\n"), 0.2)
			tag.clicked.connect(func(_n): shelf.pick(item))
			item["note"] = "Capital: %s (reads the %s sign)" % [capital, country_name]
			state = State.DONE
			complete()
			shelf.busy_handler = Callable()
			say.emit("Cashier: Delivered! The new %s %s is on the shelf, and it already knows its capital, because it reads the sign.\n\nAll 3 missions complete!\nOne fact, one place. That's database normalization!" % [country_name, PRODUCT[0].to_lower()])
		State.DONE:
			say.emit("Cashier: You fixed the whole store. Thank you!")
		State.STICK:
			say.emit("Stick the capital on the %s sign (right end of the food shelf)." % country_name)

# Clicking a product while holding the sticker: it's never the right country
func _on_product(product: Dictionary) -> void:
	if state == State.FIND_ITEM and held:
		say.emit("That's %s %s, not %s.\nThere's no %s product on the shelf to stick the capital on.\n\nTell the cashier." % [product["origin"], product["name"].to_lower(), country_name, country_name])
	else:
		say.emit("Your hands are full! Put that down first.")

func _on_sign(_node) -> void:
	if state != State.STICK or not held:
		return
	put_on_sign(shop_sign, 1)
	shop_sign["label"].text = "%s SIGN\nCapital: %s" % [country_name.to_upper(), capital]
	state = State.ORDER
	say.emit("Saved! The fact has a home, even with ZERO %s products.\n\nNow ask the cashier to order a %s product." % [country_name, country_name])

# Dev jumps throw this mission away: take the delivered product off the shelf
func cleanup() -> void:
	shelf.busy_handler = Callable()
	if not item.is_empty() and is_instance_valid(item["body"]):
		shelf.remove(item)
