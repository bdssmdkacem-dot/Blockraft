extends Node
## Hotbar inventory with backpack tiers (Leather → Iron → Diamond).
## Higher tiers raise max stack size per slot (capacity).

signal selection_changed(index: int)
signal counts_changed
signal backpack_changed(tier_id: String)

const SLOT_COUNT := 9

const BACKPACKS := {
	"leather": {
		"label": "Leather Backpack",
		"max_stack": 64,
		"color": Color("#8b5a2b"),
		"next": "iron",
		"cost": {},
	},
	"iron": {
		"label": "Iron Backpack",
		"max_stack": 128,
		"color": Color("#9aa3a8"),
		"next": "diamond",
		"cost": {"stone": 24, "wood": 12},
	},
	"diamond": {
		"label": "Diamond Backpack",
		"max_stack": 256,
		"color": Color("#5ce1e6"),
		"next": "",
		"cost": {"stone": 40, "wood": 20, "dirt": 16},
	},
}

var backpack_tier: String = "leather"

var slots: Array = [
	{"id": "tool_pickaxe", "label": "Pickaxe", "color": Color("#5ce1e6"), "count": 1, "is_tool": true},
	{"id": "grass", "label": "Grass", "color": Color(0.28, 0.62, 0.22), "count": 32, "is_tool": false},
	{"id": "dirt", "label": "Dirt", "color": Color(0.38, 0.24, 0.13), "count": 64, "is_tool": false},
	{"id": "stone", "label": "Stone", "color": Color(0.42, 0.45, 0.48), "count": 32, "is_tool": false},
	{"id": "wood", "label": "Wood", "color": Color(0.42, 0.25, 0.11), "count": 16, "is_tool": false},
	{"id": "", "label": "", "color": Color(0.2, 0.2, 0.2), "count": 0, "is_tool": false},
	{"id": "", "label": "", "color": Color(0.2, 0.2, 0.2), "count": 0, "is_tool": false},
	{"id": "", "label": "", "color": Color(0.2, 0.2, 0.2), "count": 0, "is_tool": false},
	{"id": "", "label": "", "color": Color(0.2, 0.2, 0.2), "count": 0, "is_tool": false},
]
var selected: int = 0

func get_max_stack() -> int:
	return int(BACKPACKS[backpack_tier]["max_stack"])

func get_backpack_label() -> String:
	return str(BACKPACKS[backpack_tier]["label"])

func get_backpack_color() -> Color:
	return BACKPACKS[backpack_tier]["color"]

func get_next_tier() -> String:
	return str(BACKPACKS[backpack_tier].get("next", ""))

func get_upgrade_cost() -> Dictionary:
	var nxt := get_next_tier()
	if nxt == "":
		return {}
	return BACKPACKS[nxt]["cost"]

func select(index: int) -> void:
	selected = clampi(index, 0, SLOT_COUNT - 1)
	selection_changed.emit(selected)

func cycle(delta: int) -> void:
	select((selected + delta + SLOT_COUNT) % SLOT_COUNT)

func get_selected() -> Dictionary:
	return slots[selected]

func can_place() -> bool:
	var s: Dictionary = slots[selected]
	return not s.get("is_tool", false) and str(s.get("id", "")) != "" and int(s.get("count", 0)) > 0

func get_place_kind() -> String:
	if not can_place():
		return ""
	return str(slots[selected]["id"])

func consume_place() -> bool:
	if not can_place():
		return false
	slots[selected]["count"] = int(slots[selected]["count"]) - 1
	counts_changed.emit()
	return true

func count_of(kind: String) -> int:
	var total := 0
	for s in slots:
		if not s.get("is_tool", false) and str(s.get("id", "")) == kind:
			total += int(s.get("count", 0))
	return total

func _remove_amount(kind: String, amount: int) -> bool:
	if count_of(kind) < amount:
		return false
	var left := amount
	for i in range(SLOT_COUNT):
		var s: Dictionary = slots[i]
		if s.get("is_tool", false) or str(s.get("id", "")) != kind:
			continue
		var have := int(s.get("count", 0))
		var take: int = mini(have, left)
		slots[i]["count"] = have - take
		left -= take
		if int(slots[i]["count"]) <= 0:
			slots[i] = {"id": "", "label": "", "color": Color(0.2, 0.2, 0.2), "count": 0, "is_tool": false}
		if left <= 0:
			break
	counts_changed.emit()
	return left <= 0

func can_upgrade() -> bool:
	var nxt := get_next_tier()
	if nxt == "":
		return false
	var cost: Dictionary = BACKPACKS[nxt]["cost"]
	for kind in cost.keys():
		if count_of(str(kind)) < int(cost[kind]):
			return false
	return true

func try_upgrade() -> bool:
	var nxt := get_next_tier()
	if nxt == "":
		return false
	var cost: Dictionary = BACKPACKS[nxt]["cost"]
	if not can_upgrade():
		return false
	for kind in cost.keys():
		_remove_amount(str(kind), int(cost[kind]))
	backpack_tier = nxt
	backpack_changed.emit(backpack_tier)
	counts_changed.emit()
	return true

func add_block(kind: String, amount: int = 1) -> void:
	var max_stack := get_max_stack()
	var remaining := amount
	for i in range(SLOT_COUNT):
		if remaining <= 0:
			break
		var s: Dictionary = slots[i]
		if s.get("is_tool", false) or str(s.get("id", "")) != kind:
			continue
		var have := int(s.get("count", 0))
		var space: int = max_stack - have
		if space <= 0:
			continue
		var add: int = mini(space, remaining)
		slots[i]["count"] = have + add
		remaining -= add
	while remaining > 0:
		var placed := false
		for i in range(SLOT_COUNT):
			var s2: Dictionary = slots[i]
			if str(s2.get("id", "")) != "" or s2.get("is_tool", false):
				continue
			var add2: int = mini(max_stack, remaining)
			slots[i] = {
				"id": kind,
				"label": kind.capitalize(),
				"color": _color_for(kind),
				"count": add2,
				"is_tool": false,
			}
			remaining -= add2
			placed = true
			break
		if not placed:
			break
	counts_changed.emit()

func _color_for(kind: String) -> Color:
	match kind:
		"grass":
			return Color(0.28, 0.62, 0.22)
		"dirt":
			return Color(0.38, 0.24, 0.13)
		"stone":
			return Color(0.42, 0.45, 0.48)
		"wood":
			return Color(0.42, 0.25, 0.11)
		_:
			return Color(0.5, 0.5, 0.5)
