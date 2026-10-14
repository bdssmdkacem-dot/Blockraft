extends Node
## Hotbar inventory with backpack tier upgrades.

signal selection_changed(index: int)
signal counts_changed
signal backpack_changed(tier: String)

const SLOT_COUNT := 9

const BACKPACKS := {
	"leather": {"label": "Leather Backpack", "max_stack": 64, "color": Color("#8b5a2b")},
	"iron": {"label": "Iron Backpack", "max_stack": 128, "color": Color("#8a9aaa")},
	"diamond": {"label": "Diamond Backpack", "max_stack": 256, "color": Color("#5ce1e6")},
}

const UPGRADE_COST := {
	"iron": {"stone": 24, "wood": 12},
	"diamond": {"stone": 40, "iron": 16, "wood": 8},
}

var slots: Array = []
var selected := 0
var backpack_tier := "leather"

func _ready() -> void:
	slots.clear()
	for i in range(SLOT_COUNT):
		slots.append({"id": "", "count": 0, "color": Color.GRAY, "is_tool": false})
	slots[0] = {"id": "pickaxe", "count": 1, "color": Color("#5ce1e6"), "is_tool": true}
	slots[1] = {"id": "grass", "count": 36, "color": _color_for("grass"), "is_tool": false}
	slots[2] = {"id": "dirt", "count": 64, "color": _color_for("dirt"), "is_tool": false}
	slots[3] = {"id": "stone", "count": 32, "color": _color_for("stone"), "is_tool": false}
	slots[4] = {"id": "wood", "count": 16, "color": _color_for("wood"), "is_tool": false}

func _color_for(kind: String) -> Color:
	match kind:
		"grass":
			return Color(0.30, 0.58, 0.24)
		"dirt":
			return Color(0.40, 0.26, 0.14)
		"stone":
			return Color(0.48, 0.50, 0.52)
		"wood":
			return Color(0.42, 0.25, 0.11)
		"sand":
			return Color(0.82, 0.72, 0.48)
		"water":
			return Color(0.22, 0.48, 0.72)
		"gravel":
			return Color(0.55, 0.52, 0.48)
		"rock":
			return Color(0.35, 0.36, 0.38)
		"coal":
			return Color(0.12, 0.12, 0.14)
		"iron":
			return Color(0.72, 0.58, 0.48)
		"gold":
			return Color(0.92, 0.78, 0.22)
		"crystal":
			return Color(0.45, 0.85, 0.95)
		"chest":
			return Color(0.55, 0.32, 0.12)
		_:
			return Color(0.5, 0.5, 0.5)

func get_max_stack() -> int:
	return int(BACKPACKS[backpack_tier]["max_stack"])

func get_backpack_label() -> String:
	return str(BACKPACKS[backpack_tier]["label"])

func get_backpack_color() -> Color:
	return BACKPACKS[backpack_tier]["color"]

func get_next_tier() -> String:
	if backpack_tier == "leather":
		return "iron"
	if backpack_tier == "iron":
		return "diamond"
	return ""

func get_upgrade_cost() -> Dictionary:
	var nxt := get_next_tier()
	if nxt == "":
		return {}
	return UPGRADE_COST[nxt].duplicate()

func _count_of(kind: String) -> int:
	var total := 0
	for s in slots:
		if str(s.get("id", "")) == kind and not s.get("is_tool", false):
			total += int(s.get("count", 0))
	return total

func can_upgrade() -> bool:
	var cost := get_upgrade_cost()
	if cost.is_empty():
		return false
	for k in cost.keys():
		if _count_of(str(k)) < int(cost[k]):
			return false
	return true

func try_upgrade() -> bool:
	if not can_upgrade():
		return false
	var cost := get_upgrade_cost()
	for k in cost.keys():
		_consume_kind(str(k), int(cost[k]))
	var nxt := get_next_tier()
	backpack_tier = nxt
	backpack_changed.emit(backpack_tier)
	counts_changed.emit()
	return true

func _consume_kind(kind: String, amount: int) -> void:
	var left := amount
	for i in range(SLOT_COUNT):
		if left <= 0:
			break
		var s: Dictionary = slots[i]
		if str(s.get("id", "")) != kind or s.get("is_tool", false):
			continue
		var c := int(s.get("count", 0))
		var take := mini(c, left)
		s["count"] = c - take
		left -= take
		if int(s["count"]) <= 0:
			slots[i] = {"id": "", "count": 0, "color": Color.GRAY, "is_tool": false}

func select(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	selected = index
	selection_changed.emit(selected)

func cycle(dir: int) -> void:
	selected = (selected + dir) % SLOT_COUNT
	if selected < 0:
		selected += SLOT_COUNT
	selection_changed.emit(selected)

func add_block(kind: String, amount: int = 1) -> void:
	if amount <= 0 or kind == "":
		return
	var max_stack := get_max_stack()
	for i in range(SLOT_COUNT):
		var s: Dictionary = slots[i]
		if str(s.get("id", "")) == kind and not s.get("is_tool", false):
			var room := max_stack - int(s.get("count", 0))
			if room > 0:
				var add := mini(room, amount)
				s["count"] = int(s["count"]) + add
				amount -= add
				if amount <= 0:
					counts_changed.emit()
					return
	for i in range(SLOT_COUNT):
		if amount <= 0:
			break
		var s2: Dictionary = slots[i]
		if str(s2.get("id", "")) == "" and not s2.get("is_tool", false):
			var add2 := mini(max_stack, amount)
			slots[i] = {"id": kind, "count": add2, "color": _color_for(kind), "is_tool": false}
			amount -= add2
	counts_changed.emit()

func get_place_kind() -> String:
	var s: Dictionary = slots[selected]
	if s.get("is_tool", false):
		return ""
	var id := str(s.get("id", ""))
	if id == "" or int(s.get("count", 0)) <= 0:
		return ""
	if id in ["pickaxe", "chest"]:
		return ""
	return id

func consume_place() -> bool:
	var s: Dictionary = slots[selected]
	if s.get("is_tool", false):
		return false
	var c := int(s.get("count", 0))
	if c <= 0 or str(s.get("id", "")) == "":
		return false
	s["count"] = c - 1
	if int(s["count"]) <= 0:
		slots[selected] = {"id": "", "count": 0, "color": Color.GRAY, "is_tool": false}
	counts_changed.emit()
	return true
