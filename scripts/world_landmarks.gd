extends RefCounted
## Deterministic voxel landmarks authored into the persistent world block map.

const SOLID_GROUND := ["grass", "dirt", "stone", "rock", "sand", "gravel"]

func populate(blocks: Dictionary) -> Dictionary:
	var castle_site := _find_site(blocks, Vector2i(34, 24), 8, 2)
	var village_site := _find_site(blocks, Vector2i(-32, 22), 12, 2, [castle_site])
	if castle_site == Vector2i(9999, 9999) or village_site == Vector2i(9999, 9999):
		return {"ok": false, "castle": castle_site, "village": village_site, "added": 0}
	var before := blocks.size()
	_build_castle(blocks, castle_site)
	_build_village(blocks, village_site)
	return {
		"ok": true,
		"castle": castle_site,
		"village": village_site,
		"added": blocks.size() - before,
		"castle_blocks": _count_region(blocks, castle_site, 9),
		"village_blocks": _count_region(blocks, village_site, 13)
	}

func _surface_y(blocks: Dictionary, x: int, z: int) -> int:
	for y in range(24, -6, -1):
		var kind := str(blocks.get(Vector3i(x, y, z), ""))
		if kind in SOLID_GROUND:
			return y
	return -999

func _find_site(blocks: Dictionary, desired: Vector2i, radius: int, half_extent: int, excluded: Array = []) -> Vector2i:
	for ring in range(radius + 1):
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var candidate := desired + Vector2i(dx, dz)
				if excluded.any(func(p): return p != Vector2i(9999, 9999) and candidate.distance_to(p) < 25.0):
					continue
				var low := 999
				var high := -999
				var valid := true
				for x in range(candidate.x - half_extent, candidate.x + half_extent + 1):
					for z in range(candidate.y - half_extent, candidate.y + half_extent + 1):
						var ground := _surface_y(blocks, x, z)
						if ground < 3:
							valid = false
							break
						low = mini(low, ground)
						high = maxi(high, ground)
					if not valid:
						break
				if valid and high - low <= 2:
					return candidate
	return Vector2i(9999, 9999)

func _put(blocks: Dictionary, x: int, y: int, z: int, kind: String) -> void:
	blocks[Vector3i(x, y, z)] = kind

func _clear(blocks: Dictionary, x: int, y: int, z: int) -> void:
	blocks.erase(Vector3i(x, y, z))

func _fill(blocks: Dictionary, x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, kind: String) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				_put(blocks, x, y, z, kind)

func _build_castle(blocks: Dictionary, site: Vector2i) -> void:
	var x := site.x
	var z := site.y
	var ground := _surface_y(blocks, x, z)
	var base := ground + 1
	# A broad stone plinth anchors the keep and its four corner towers.
	_fill(blocks, x - 8, x + 8, base, base + 1, z - 8, z + 8, "stone_brick")
	# Outer curtain walls. The south gate is left open for a walkable entrance.
	for y in range(base + 2, base + 6):
		for offset in range(-7, 8):
			if not (y < base + 5 and absi(offset) <= 1):
				_put(blocks, x + offset, y, z - 7, "stone_brick")
			_put(blocks, x + offset, y, z + 7, "stone_brick")
			_put(blocks, x - 7, y, z + offset, "stone_brick")
			_put(blocks, x + 7, y, z + offset, "stone_brick")
	# Four crenellated towers with timber roof caps and narrow slit windows.
	for tx in [-7, 7]:
		for tz in [-7, 7]:
			_fill(blocks, x + tx - 1, x + tx + 1, base + 2, base + 9, z + tz - 1, z + tz + 1, "stone_brick")
			_clear(blocks, x + tx, base + 4, z + tz - 1)
			_clear(blocks, x + tx, base + 6, z + tz - 1)
			_fill(blocks, x + tx - 2, x + tx + 2, base + 10, base + 10, z + tz - 2, z + tz + 2, "planks")
			for edge in range(-2, 3, 2):
				_put(blocks, x + tx + edge, base + 11, z + tz, "stone_brick")
				_put(blocks, x + tx, base + 11, z + tz + edge, "stone_brick")
	# Main keep: solid lower walls, upper hall, recessed windows and layered roof.
	_fill(blocks, x - 4, x + 4, base + 2, base + 7, z - 4, z + 4, "stone_brick")
	_fill(blocks, x - 3, x + 3, base + 3, base + 6, z - 3, z + 3, "wood")
	for wx in [-2, 0, 2]:
		for wy in [base + 4, base + 6]:
			_put(blocks, x + wx, wy, z - 4, "crystal")
			_put(blocks, x + wx, wy, z + 4, "crystal")
	for edge in range(-4, 5):
		_put(blocks, x + edge, base + 8, z - 4, "planks")
		_put(blocks, x + edge, base + 8, z + 4, "planks")
		_put(blocks, x - 4, base + 8, z + edge, "planks")
		_put(blocks, x + 4, base + 8, z + edge, "planks")
	for layer in range(4):
		var half := 4 - layer
		_fill(blocks, x - half, x + half, base + 9 + layer, base + 9 + layer, z - half, z + half, "planks")
	# Raised causeway links the gate to the outer approach.
	for step in range(1, 8):
		_fill(blocks, x - 1, x + 1, base + 1, base + 1, z - 7 - step, z - 7 - step, "stone_brick")
		if step % 2 == 0:
			_put(blocks, x - 2, base + 2, z - 7 - step, "stone_brick")
			_put(blocks, x + 2, base + 2, z - 7 - step, "stone_brick")

func _build_house(blocks: Dictionary, x: int, z: int, ground: int, width: int, depth: int) -> void:
	var base := ground + 1
	var hx := int(floor(float(width) * 0.5))
	var hz := int(floor(float(depth) * 0.5))
	_fill(blocks, x - hx, x + hx, base, base, z - hz, z + hz, "stone_brick")
	for y in range(base + 1, base + 4):
		for dx in range(-hx, hx + 1):
			_put(blocks, x + dx, y, z - hz, "planks")
			_put(blocks, x + dx, y, z + hz, "planks")
		for dz in range(-hz, hz + 1):
			_put(blocks, x - hx, y, z + dz, "planks")
			_put(blocks, x + hx, y, z + dz, "planks")
	# Warm timber frame, windows and a clear two-block doorway.
	for wx in [-hx + 1, hx - 1]:
		_put(blocks, x + wx, base + 1, z - hz, "wood")
		_put(blocks, x + wx, base + 2, z - hz, "wood")
		_put(blocks, x + wx, base + 2, z - hz, "crystal")
	_put(blocks, x, base + 1, z - hz, "wood")
	_clear(blocks, x, base + 1, z + hz)
	_clear(blocks, x, base + 2, z + hz)
	# Stepped pitched roof with overhanging eaves.
	for layer in range(hz + 1):
		var roof_z := hz - layer
		_fill(blocks, x - hx - 1 + layer, x + hx + 1 - layer, base + 4 + layer, base + 4 + layer, z - roof_z, z + roof_z, "planks")
	_put(blocks, x, base + 5 + hz, z, "wood")

func _build_village(blocks: Dictionary, site: Vector2i) -> void:
	var x := site.x
	var z := site.y
	for offset in [Vector2i(-5, -4), Vector2i(5, -3), Vector2i(-4, 5), Vector2i(5, 6)]:
		var hx := x + offset.x
		var hz := z + offset.y
		var ground := _surface_y(blocks, hx, hz)
		if ground < 3:
			continue
		_build_house(blocks, hx, hz, ground, 5 if offset.x < 0 else 7, 5)
	# Village square and a clear path of stone slabs between the houses.
	var ground := _surface_y(blocks, x, z)
	for step in range(-5, 6):
		_put(blocks, x, ground + 1, z + step, "stone_brick")
		if step % 3 == 0:
			_put(blocks, x - 1, ground + 1, z + step, "gravel")
			_put(blocks, x + 1, ground + 1, z + step, "gravel")

func _count_region(blocks: Dictionary, center: Vector2i, radius: int) -> int:
	var count := 0
	for pos in blocks:
		var cell: Vector3i = pos
		if Vector2(float(cell.x - center.x), float(cell.z - center.y)).length() <= float(radius):
			count += 1
	return count
