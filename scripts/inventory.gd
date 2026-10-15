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
		"meat":
			return Color(0.75, 0.25, 0.28)
		"leaves":
			return Color(0.22, 0.55, 0.25)
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

func select(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	selected = index
	selection_changed.emit(selected)

func cycle(dir: int) -> void:
	select((selected + dir + SLOT_COUNT) % SLOT_COUNT)

func count_of(kind: String) -> int:
	var total := 0
	for s in slots:
		if str(s.get("id", "")) == kind and not s.get("is_tool", false):
			total += int(s.get("count", 0))
	return total

func add_block(kind: String, amount: int = 1) -> void:
	if amount <= 0 or kind == "":
		return
	var max_stack := get_max_stack()
	var color := _color_for(kind)
	var left := amount
	for s in slots:
		if str(s.get("id", "")) == kind and not s.get("is_tool", false):
			var space := max_stack - int(s.get("count", 0))
			if space > 0:
				var add := mini(space, left)
				s["count"] = int(s["count"]) + add
				left -= add
				if left <= 0:
					counts_changed.emit()
					return
	for s in slots:
		if str(s.get("id", "")) == "" and not s.get("is_tool", false):
			var add := mini(max_stack, left)
			s["id"] = kind
			s["count"] = add
			s["color"] = color
			s["is_tool"] = false
			left -= add
			if left <= 0:
				counts_changed.emit()
				return
	counts_changed.emit()

func _remove_amount(kind: String, amount: int) -> bool:
	if count_of(kind) < amount:
		return false
	var left := amount
	for s in slots:
		if str(s.get("id", "")) == kind and not s.get("is_tool", false):
			var c := int(s.get("count", 0))
			var take := mini(c, left)
			s["count"] = c - take
			left -= take
			if int(s["count"]) <= 0:
				s["id"] = ""
				s["count"] = 0
			if left <= 0:
				break
	counts_changed.emit()
	return true

func get_place_kind() -> String:
	var s: Dictionary = slots[selected]
	if s.get("is_tool", false):
		return ""
	return str(s.get("id", ""))

func consume_place() -> bool:
	var s: Dictionary = slots[selected]
	if s.get("is_tool", false) or str(s.get("id", "")) == "":
		return false
	if int(s.get("count", 0)) <= 0:
		return false
	s["count"] = int(s["count"]) - 1
	if int(s["count"]) <= 0:
		s["id"] = ""
		s["count"] = 0
	counts_changed.emit()
	return true

func try_upgrade() -> bool:
	var next := get_next_tier()
	if next == "":
		return false
	var cost: Dictionary = UPGRADE_COST[next]
	for k in cost:
		if count_of(k) < int(cost[k]):
			return false
	for k in cost:
		_remove_amount(k, int(cost[k]))
	backpack_tier = next
	backpack_changed.emit(backpack_tier)
	return true
