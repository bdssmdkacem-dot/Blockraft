extends Node
## Hotbar inventory: tools + placeable blocks with stack counts.

signal selection_changed(index: int)
signal counts_changed

const SLOT_COUNT := 9

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

func add_block(kind: String, amount: int = 1) -> void:
	for i in range(SLOT_COUNT):
		var s: Dictionary = slots[i]
		if not s.get("is_tool", false) and str(s.get("id", "")) == kind:
			slots[i]["count"] = int(s.get("count", 0)) + amount
			counts_changed.emit()
			return
	for i in range(SLOT_COUNT):
		var s2: Dictionary = slots[i]
		if str(s2.get("id", "")) == "" and not s2.get("is_tool", false):
			slots[i] = {
				"id": kind,
				"label": kind.capitalize(),
				"color": _color_for(kind),
				"count": amount,
				"is_tool": false,
			}
			counts_changed.emit()
			return

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
