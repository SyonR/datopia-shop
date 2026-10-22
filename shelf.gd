extends Node3D

# A shelf of food you can pick up and put back on any empty spot.
# The shelf's collision is on layer 2, so the aim ray reaches food inside it.
# Each item is one "row" of a small table: product, origin, price, spot.
# Products and prices are made-up examples; origins come from the country JSON.

signal say(text)

const CLICKABLE = preload("res://clickable.gd")
const SHELF_NAME = "shelf-boxes_3"      # in store.tscn, at x 3.6, z -2.5
const FRONT = Vector3(3.6, 0, -2.05)    # where the store's own front-row goods sat
const COLUMNS = [-0.6, -0.2, 0.2, 0.6]   # inside the side panels
const LEVELS = [0.525, 1.65]            # heights of the two shelf boards
const ITEM_SIZE = Vector3(0.38, 0.5, 0.38)
const PAD_COLOR = Color(0.3, 1, 0.45, 0.7)
# name, model, price, origin (index in the country JSON).
# No Argentina (2): mission 3 starts with no Argentina product on the shelf.
const PRODUCTS = [
	["Canned beans", "can", 2.00, 0],
	["Milk", "carton", 1.50, 1],
	["Bread", "loaf", 3.00, 3],
	["Cheese", "cheese", 4.50, 4],
	["Apple", "apple", 0.75, 5],
	["Olive oil", "bottle-oil", 6.00, 6],
]

var hand: Node3D
var spots := []   # {"pad": clickable, "item": the item sitting there, or null}
var held = null   # the item you are carrying
var busy_handler := Callable()   # a mission can answer clicks on products while your hands are full

func setup(countries: Array, store: Node, player_hand: Node3D) -> void:
	hand = player_hand
	hand.child_entered_tree.connect(_on_hand_took)
	_empty_front_row(store.find_child(SHELF_NAME))

	for level in LEVELS:
		for x in COLUMNS:
			var pad = _clickable(Area3D.new(), Vector3(0.38, 0.04, 0.38), PAD_COLOR)
			pad.position = FRONT + Vector3(x, level + 0.02, 0)
			pad.clicked.connect(_on_pad.bind(spots.size()))
			spots.append({"pad": pad, "item": null})
	_show_pads(false)

	for i in PRODUCTS.size():
		var p = PRODUCTS[i]
		_place(_new_item(p[0], p[1], p[2], countries[p[3]]["name"]), i)

# A new product arrives in the first empty spot: it grows in from nothing
func add_item(product: String, model: String, price: float, origin: String) -> Dictionary:
	var empty := spots.filter(func(s): return s["item"] == null)
	var item := _new_item(product, model, price, origin)
	_place(item, spots.find(empty[0]))
	item["body"].scale = Vector3.ONE * 0.01
	create_tween().tween_property(item["body"], "scale", Vector3.ONE, 0.8)
	return item

# Take an item off the shelf (or out of your hands) for good
func remove(item: Dictionary) -> void:
	if held == item:
		held = null
		_show_pads(false)
	if spots[item["spot"]]["item"] == item:
		spots[item["spot"]]["item"] = null
	item["body"].queue_free()

func _new_item(product: String, model: String, price: float, origin: String) -> Dictionary:
	var body = _clickable(Area3D.new(), ITEM_SIZE, Color.WHITE, load("res://models/food/%s.glb" % model))
	var item := {"body": body, "name": product, "origin": origin, "price": price, "spot": -1}
	body.clicked.connect(_on_item.bind(item))
	return item

func find_item(origin: String) -> Dictionary:
	for s in spots:
		if s["item"] and s["item"]["origin"] == origin:
			return s["item"]
	return {}

func _on_item(_node, item: Dictionary) -> void:
	pick(item)

func pick(item: Dictionary) -> void:
	if held or hand.get_child_count() > 0:
		if busy_handler.is_valid() and not held:
			busy_handler.call(item)
		else:
			say.emit("Your hands are full! Put that down first.")
		return
	spots[item["spot"]]["item"] = null
	held = item
	var body = item["body"]
	_set_clickable(body, false)   # so your aim goes through it
	body.reparent(hand, false)
	body.position = Vector3.ZERO
	body.scale = Vector3.ONE * 0.6   # smaller in your hand, so it doesn't block the view
	_show_pads(true)
	say.emit("%s\n\nClick a glowing spot on the shelf to put it down." % _record(item))

func _on_pad(_node, spot: int) -> void:
	if not held:
		return
	var item = held
	held = null
	_place(item, spot)
	_show_pads(false)
	say.emit("Put back in spot %d.\n\n%s" % [spot + 1, _record(item)])

# Hand the carried item to someone else (like a customer); returns its body
func give_held() -> Node3D:
	var item = held
	held = null
	_show_pads(false)
	return item["body"]

# Put an item back on the shelf from wherever it is: its old spot, or any free one
func restock(item: Dictionary) -> void:
	if held == item:
		held = null
		_show_pads(false)
	if spots[item["spot"]]["item"] == item:
		return
	var spot: int = item["spot"]
	if spots[spot]["item"] != null:
		spot = spots.find(spots.filter(func(s): return s["item"] == null)[0])
	_place(item, spot)

# Something else (like a mission sticker) went into your hand: put the food back
func _on_hand_took(node: Node) -> void:
	if held and node != held["body"]:
		var item = held
		held = null
		_place.call_deferred(item, item["spot"])
		_show_pads(false)

func _place(item: Dictionary, spot: int) -> void:
	var body = item["body"]
	if body.get_parent() != self:
		body.reparent(self, false)
	body.position = spots[spot]["pad"].position + Vector3(0, ITEM_SIZE.y / 2, 0)
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE
	_set_clickable(body, true)
	item["spot"] = spot
	spots[spot]["item"] = item

func _record(item: Dictionary) -> String:
	var text := "Row: %s\nOrigin: %s\nPrice: $%.2f\nShelf spot: %d of %d" % [
		item["name"], item["origin"], item["price"], item["spot"] + 1, spots.size()]
	if item.has("note"):   # extra column a mission adds, like a capital tag
		text += "\n" + item["note"]
	return text

# The item and anything stuck on it (like a tag)
func _set_clickable(body: Node3D, on: bool) -> void:
	body.collision_layer = 1 if on else 0
	for c in body.find_children("*", "CollisionObject3D", true, false):
		c.collision_layer = 1 if on else 0

# Only empty spots glow (and can be clicked) while you carry something
func _show_pads(on: bool) -> void:
	for s in spots:
		var show: bool = on and s["item"] == null
		s["pad"].visible = show
		s["pad"].collision_layer = 1 if show else 0

# The store model comes stocked; hide the goods on the side facing the player
func _empty_front_row(shelf: Node3D) -> void:
	for m in shelf.find_children("*", "MeshInstance3D"):
		if m.name.begins_with("carton") or m.name.begins_with("box"):
			if (shelf.global_transform.affine_inverse() * m.global_position).z > 0:
				m.hide()

func _clickable(body, size: Vector3, color: Color, model: PackedScene = null):
	body.set_script(CLICKABLE)
	add_child(body)
	body.build(size, color, model, false)
	return body
