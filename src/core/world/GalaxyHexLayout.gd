class_name GalaxyHexLayout
extends RefCounted

## Deterministic hex-coord assignment for the Galaxy Log screen.
## Pure math: no Node, no state. Coords are pure functions of (campaign_id, planet_id),
## so they survive save/load without persisting positions and are independent of
## Dictionary iteration order from PlanetDataManager.visited_planets.

const HEX_SIZE := 56.0
const SQRT3 := 1.7320508

## Flat-top neighbor directions in axial (q, r) coords.
## Order is the standard redblobgames ring-walk order:
## 0=E, 1=NE, 2=NW, 3=W, 4=SW, 5=SE
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

## Assign axial coords to a set of planet IDs.
## - starting_world_id (if non-empty) is pinned to Vector2i.ZERO so the campaign's
##   first world always anchors the constellation centre.
## - Other planets get a hashed (ring, slot) seed, with collisions resolved by
##   re-hashing with a salt counter; salt also bumps the ring outward so dense
##   campaigns don't degenerate into one ring.
## - Input order is normalized via sort() so reload-order doesn't affect output.
static func assign_coords(
	campaign_id: String,
	planet_ids: Array,
	starting_world_id: String,
) -> Dictionary:
	var taken: Dictionary = {}
	var result: Dictionary = {}

	if not starting_world_id.is_empty():
		result[starting_world_id] = Vector2i.ZERO
		taken[Vector2i.ZERO] = true

	var sorted_ids: Array = planet_ids.duplicate()
	sorted_ids.sort()

	for pid_v in sorted_ids:
		var pid: String = str(pid_v)
		if pid == starting_world_id or pid.is_empty():
			continue
		var coord: Vector2i = _hash_to_coord(campaign_id, pid, 0)
		var salt: int = 1
		while taken.has(coord):
			if salt <= 200:
				coord = _hash_to_coord(campaign_id, pid, salt)
				salt += 1
			else:
				# Pathological collision (only triggers with hundreds of planets all
				# hashing into the same neighborhood). Fall through to a guaranteed
				# free coord via outward ring walk — collision-safe by construction,
				# unlike the prior fallback which assigned without re-checking taken.
				push_warning(
					"GalaxyHexLayout: salt overflow placing %s; falling back to outward walk" % pid
				)
				coord = next_free_outward(taken, 6)
				break
		taken[coord] = true
		result[pid] = coord

	return result

## Convert an axial coord to pixel space (flat-top, origin-centred).
static func axial_to_pixel(coord: Vector2i) -> Vector2:
	var fx: float = HEX_SIZE * 1.5 * float(coord.x)
	var fy: float = HEX_SIZE * SQRT3 * (float(coord.y) + float(coord.x) / 2.0)
	return Vector2(fx, fy)

## Return the six pixel-space corner positions of a flat-top hex of HEX_SIZE
## centred on the given pixel. Use for HexCell._draw() polygons.
static func hex_corners(centre: Vector2, size: float = HEX_SIZE) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var angle: float = deg_to_rad(60.0 * float(i))
		out.append(centre + Vector2(size * cos(angle), size * sin(angle)))
	return out

## Map (ring, slot) to an axial coord on that ring around origin.
## Ring 0 == origin. Ring N has 6*N slots, walked starting from the SW corner
## (start = dirs[4] * N) in the order dirs[0..5].
static func ring_slot_to_axial(ring: int, slot: int) -> Vector2i:
	if ring <= 0:
		return Vector2i.ZERO
	var slot_mod: int = posmod(slot, 6 * ring)
	var segment: int = slot_mod / ring
	var step: int = slot_mod % ring
	var coord: Vector2i = DIRS[4] * ring
	for i in range(segment):
		coord += DIRS[i] * ring
	coord += DIRS[segment] * step
	return coord

## Walk outward ring by ring, slot by slot, returning the first free coord.
## Guaranteed to terminate (rings grow without bound) and never collide with an
## already-taken coord. Used as the salt-overflow fallback in assign_coords();
## practically unreachable for normal campaign sizes (~30 planets) but defended
## here so the layout invariant "no two planets share a coord" cannot be
## violated even in pathological hash-collision cases.
static func next_free_outward(taken: Dictionary, start_ring: int) -> Vector2i:
	var ring: int = max(1, start_ring)
	while ring < 1000:
		var slot_count: int = 6 * ring
		for slot in range(slot_count):
			var coord: Vector2i = ring_slot_to_axial(ring, slot)
			if not taken.has(coord):
				return coord
		ring += 1
	push_error("GalaxyHexLayout: next_free_outward exhausted at ring 1000")
	return ring_slot_to_axial(1000, 0)

## Produce a candidate axial coord for (campaign_id, planet_id) with a salt
## counter. Salt 0 picks rings 1..4; higher salt bumps the ring outward.
static func _hash_to_coord(campaign_id: String, pid: String, salt: int) -> Vector2i:
	var key: String = campaign_id + "::" + pid
	if salt > 0:
		key += "::salt::" + str(salt)
	var h: int = hash(key)
	var ring_base: int = 1 + posmod(h, 4)
	var ring: int = ring_base + int(salt / 4)
	if ring < 1:
		ring = 1
	var slot_count: int = 6 * ring
	var slot: int = posmod(int(h / 256), slot_count)
	return ring_slot_to_axial(ring, slot)
