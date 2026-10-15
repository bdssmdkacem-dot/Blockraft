extends Node
## Hotbar + warehouse depot storage + backpack tiers.

signal selection_changed(index: int)
signal counts_changed
signal backpack_changed(tier: String)
signal storage_changed

const SLOT_COUNT := 9

const BACKPACKS := {
	"leather": {"label": "Leather Bag", "max_stack": 64, "color": Color("#8b5a2b")},
	"iron": {"label": "Iron Bag", "max_stack": 128, "color": Color("#8a9aaa")},
	"diamond": {"label": "Diamond Bag", "max_stack": 256, "color": Color("#5ce1e6")},
}

const UPGRADE_COST := {
	"iron": {"stone": 20, "wood": 16, "coal": 8},
	"diamond": {"iron": 18, "gold": 6, "crystal": 3, "wood": 12},
}

var slots: Array = []
var selected := 0
var backpack_tier := "leather"
var storage: Dictionary = {}

func _ready() -> void:
	slots.clear()
	for i in range(SLOT_COUNT):
		slots.append({"id": "", "count": 0, "color": Color.GRAY, "is_tool": false})
	slots[0] = {"id": "pickaxe", "count": 1, "color": Color("#5ce1e6"), "is_tool": true}
	slots[1] = {"id": "dirt", "count": 48, "color": _color_for("dirt"), "is_tool": false}
	slots[2] = {"id": "stone", "count": 24, "color": _color_for("stone"), "is_tool": false}
	slots[3] = {"id": "wood", "count": 16, "color": _color_for("wood"), "is_tool": false}
	slots[4] = {"id": "grass", "count": 24, "color": _color_for("grass"), "is_tool": false}

func _color_for(kind: String) -> Color:
	match kind:
		"grass": return Color(0.30, 0.58, 0.24)
		"dirt": return Color(0.40, 0.26, 0.14)
		"stone": return Color(0.48, 0.50, 0.52)
		"wood": return Color(0.42, 0.25, 0.11)
		"sand": return Color(0.82, 0.72, 0.48)
		"gravel": return Color(0.55, 0.52, 0.48)
		"rock": return Color(0.35, 0.36, 0.38)
		"coal": return Color(0.12, 0.12, 0.14)
		"iron": return Color(0.72, 0.58, 0.48)
		"gold": return Color(0.92, 0.78, 0.22)
		"crystal": return Color(0.45, 0.85, 0.95)
		"chest": return Color(0.55, 0.32, 0.12)
		"meat": return Color(0.75, 0.25, 0.28)
		"leaves": return Color(0.22, 0.55, 0.25)
		_: return Color(0.5, 0.5, 0.5)

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

func storage_count(kind: String) -> int:
	return int(storage.get(kind, 0))

func total_of(kind: String) -> int:
	return count_of(kind) + storage_count(kind)

func add_block(kind: String, amount: int = 1) -> void:
	if amount <= 0 or kind == "" or kind == "water":
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
	if left > 0:
		storage[kind] = storage_count(kind) + left
		storage_changed.emit()
	counts_changed.emit()

func _remove_amount(kind: String, amount: int) -> bool:
	if total_of(kind) < amount:
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
	if left > 0:
		storage[kind] = storage_count(kind) - left
		if storage[kind] <= 0:
			storage.erase(kind)
		storage_changed.emit()
	counts_changed.emit()
	return true

func deposit_selected() -> int:
	var s: Dictionary = slots[selected]
	if s.get("is_tool", false) or str(s.get("id", "")) == "":
		return 0
	var kind := str(s["id"])
	var amt := int(s["count"])
	storage[kind] = storage_count(kind) + amt
	s["id"] = ""
	s["count"] = 0
	counts_changed.emit()
	storage_changed.emit()
	return amt

func deposit_all() -> int:
	var moved := 0
	for s in slots:
		if s.get("is_tool", false) or str(s.get("id", "")) == "":
			continue
		var kind := str(s["id"])
		var amt := int(s["count"])
		storage[kind] = storage_count(kind) + amt
		moved += amt
		s["id"] = ""
		s["count"] = 0
	counts_changed.emit()
	storage_changed.emit()
	return moved

func withdraw(kind: String, amount: int = -1) -> int:
	var avail := storage_count(kind)
	if avail <= 0:
		return 0
	var want := avail if amount < 0 else mini(amount, avail)
	storage[kind] = avail - want
	if storage[kind] <= 0:
		storage.erase(kind)
	storage_changed.emit()
	add_block(kind, want)
	return want

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

func consume_food() -> bool:
	if count_of("meat") > 0:
		return _remove_amount("meat", 1)
	if storage_count("meat") > 0:
		storage["meat"] = storage_count("meat") - 1
		if storage["meat"] <= 0:
			storage.erase("meat")
		storage_changed.emit()
		return true
	return false

func try_upgrade() -> bool:
	var next := get_next_tier()
	if next == "":
		return false
	var cost: Dictionary = UPGRADE_COST[next]
	for k in cost:
		if total_of(k) < int(cost[k]):
			return false
	for k in cost:
		_remove_amount(k, int(cost[k]))
	backpack_tier = next
	backpack_changed.emit(backpack_tier)
	return true

func upgrade_cost_text() -> String:
	var next := get_next_tier()
	if next == "":
		return "Bag maxed (Diamond)"
	var cost: Dictionary = UPGRADE_COST[next]
	var parts: PackedStringArray = []
	for k in cost:
		parts.append("%s %d/%d" % [k, total_of(k), int(cost[k])])
	return "Next %s: %s" % [next.capitalize(), ", ".join(parts)]

func storage_summary(max_kinds: int = 6) -> String:
	if storage.is_empty():
		return "Depot empty — deposit with F near warehouse"
	var keys: Array = storage.keys()
	keys.sort()
	var parts: PackedStringArray = []
	var n := 0
	for k in keys:
		parts.append("%s×%d" % [k, int(storage[k])])
		n += 1
		if n >= max_kinds:
			break
	return "Depot: " + ", ".join(parts)
