extends GdUnitTestSuite
## Tests for GalaxyHexLayout — deterministic hex-coord assignment for the Galaxy Log.
##
## Invariants worth defending:
##  1. Same inputs ALWAYS produce the same output (no entropy from Time, RNG, etc).
##  2. Input order doesn't affect output (PlanetDataManager.visited_planets is a
##     Dictionary, iteration order across save/load is not guaranteed).
##  3. No two planets ever collide (the spiral-on-collision must terminate).
##  4. Starting world is pinned to origin (Vector2i.ZERO) for stable visual anchor.

const GalaxyHexLayout := preload("res://src/core/world/GalaxyHexLayout.gd")

const CAMPAIGN_ID := "test_camp_abc123"


func _make_planet_ids(n: int, prefix: String = "p_") -> Array:
	var out: Array = []
	for i in range(n):
		out.append(prefix + str(i))
	return out


# ============================================================================
# 1. Determinism
# ============================================================================

func test_determinism_same_inputs_same_output() -> void:
	# Same (campaign_id, planet_ids, starting_world_id) → identical Dictionary
	# across 100 invocations. If anything pulls from Time/RNG/state, this fails.
	var ids: Array = _make_planet_ids(10)
	var first: Dictionary = GalaxyHexLayout.assign_coords(
		CAMPAIGN_ID, ids, "p_0"
	)
	for _loop_iter in range(100):
		var again: Dictionary = GalaxyHexLayout.assign_coords(
			CAMPAIGN_ID, ids, "p_0"
		)
		assert_dict(again).is_equal(first)


func test_different_campaigns_produce_different_layouts() -> void:
	# Two different campaigns sharing the same planet_ids must NOT collide on
	# layout — otherwise the hash isn't keyed properly on campaign_id.
	var ids: Array = _make_planet_ids(8)
	var a: Dictionary = GalaxyHexLayout.assign_coords("camp_alpha", ids, "")
	var b: Dictionary = GalaxyHexLayout.assign_coords("camp_beta", ids, "")
	var matches: int = 0
	for pid in ids:
		if a.get(pid) == b.get(pid):
			matches += 1
	# Allow a couple of coincidental matches, but most must differ.
	assert_bool(matches < int(ids.size() * 0.5)).is_true()


# ============================================================================
# 2. Order independence
# ============================================================================

func test_shuffled_input_produces_same_output() -> void:
	# PlanetDataManager.visited_planets iteration order is unstable across
	# save/load. Layout must be invariant under that re-ordering.
	var ids: Array = _make_planet_ids(12)
	var baseline: Dictionary = GalaxyHexLayout.assign_coords(
		CAMPAIGN_ID, ids, "p_0"
	)
	var shuffled: Array = ids.duplicate()
	shuffled.shuffle()
	var reshuffled: Dictionary = GalaxyHexLayout.assign_coords(
		CAMPAIGN_ID, shuffled, "p_0"
	)
	assert_dict(reshuffled).is_equal(baseline)


# ============================================================================
# 3. Collision safety
# ============================================================================

func test_no_collisions_with_50_planets() -> void:
	# Every planet must occupy a unique coord; the spiral salt loop must
	# always terminate before the warning path fires.
	var ids: Array = _make_planet_ids(50)
	var coords: Dictionary = GalaxyHexLayout.assign_coords(
		CAMPAIGN_ID, ids, ""
	)
	var unique: Dictionary = {}
	for v in coords.values():
		unique[v] = true
	assert_int(unique.size()).is_equal(coords.size())
	assert_int(coords.size()).is_equal(ids.size())


func test_no_collisions_with_30_planets_and_starting_world() -> void:
	# Mid-game stress: 30 planets + a pinned starting world.
	var ids: Array = _make_planet_ids(30)
	var coords: Dictionary = GalaxyHexLayout.assign_coords(
		CAMPAIGN_ID, ids, "p_0"
	)
	var unique: Dictionary = {}
	for v in coords.values():
		unique[v] = true
	assert_int(unique.size()).is_equal(coords.size())


# ============================================================================
# 4. Starting-world anchor
# ============================================================================

func test_starting_world_at_origin() -> void:
	# When a starting_world_id is supplied, it always maps to Vector2i.ZERO.
	var ids: Array = _make_planet_ids(15)
	var coords: Dictionary = GalaxyHexLayout.assign_coords(
		CAMPAIGN_ID, ids, "p_7"
	)
	assert_that(coords.get("p_7")).is_equal(Vector2i.ZERO)
	# And no other planet sits on the origin.
	var origin_holders: int = 0
	for v in coords.values():
		if v == Vector2i.ZERO:
			origin_holders += 1
	assert_int(origin_holders).is_equal(1)


func test_empty_starting_world_leaves_origin_open() -> void:
	# When starting_world_id is "", origin is fair game but nothing is pinned.
	# (We don't assert origin is empty — a hash could legitimately land there;
	# we just assert the function runs.)
	var ids: Array = _make_planet_ids(5)
	var coords: Dictionary = GalaxyHexLayout.assign_coords(
		CAMPAIGN_ID, ids, ""
	)
	assert_int(coords.size()).is_equal(ids.size())


# ============================================================================
# 5. axial_to_pixel smoke
# ============================================================================

func test_axial_to_pixel_origin_at_zero() -> void:
	assert_that(GalaxyHexLayout.axial_to_pixel(Vector2i.ZERO)).is_equal(
		Vector2.ZERO
	)


func test_axial_to_pixel_horizontal_step() -> void:
	# Flat-top: moving +1 in q steps HEX_SIZE * 1.5 in pixel x.
	var p: Vector2 = GalaxyHexLayout.axial_to_pixel(Vector2i(1, 0))
	assert_float(p.x).is_equal_approx(GalaxyHexLayout.HEX_SIZE * 1.5, 0.001)


func test_hex_corners_returns_six_points() -> void:
	var corners: PackedVector2Array = GalaxyHexLayout.hex_corners(
		Vector2.ZERO
	)
	assert_int(corners.size()).is_equal(6)


# ============================================================================
# 6. Ring math sanity (ring 1 has 6 distinct hexes)
# ============================================================================

func test_ring_one_has_six_distinct_neighbors() -> void:
	# Probe by walking ring 1 via the (ring, slot) → axial helper.
	var seen: Dictionary = {}
	for s in range(6):
		var coord: Vector2i = GalaxyHexLayout.ring_slot_to_axial(1, s)
		seen[coord] = true
	assert_int(seen.size()).is_equal(6)


func test_ring_one_neighbors_are_all_distance_one_from_origin() -> void:
	# Every ring-1 coord must be exactly one of the 6 direction vectors.
	var valid: Dictionary = {}
	for d in GalaxyHexLayout.DIRS:
		valid[d] = true
	for s in range(6):
		var coord: Vector2i = GalaxyHexLayout.ring_slot_to_axial(1, s)
		assert_bool(valid.has(coord)).is_true()


# ============================================================================
# 7. Phase 0 B5 — Salt-overflow fallback (audit coverage gap)
# ============================================================================

func test_next_free_outward_finds_coord_in_empty_taken() -> void:
	# Empty taken: should return the first coord on the starting ring.
	var taken: Dictionary = {}
	var coord: Vector2i = GalaxyHexLayout.next_free_outward(taken, 1)
	assert_bool(taken.has(coord)).is_false()
	# slot 0 of ring 1 (per redblob walk: start at SW corner (-ring, ring))
	# = DIRS[4] * 1 = Vector2i(-1, 1).
	assert_that(coord).is_equal(Vector2i(-1, 1))


func test_next_free_outward_skips_pre_taken_coords() -> void:
	# Pre-populate ring 1 entirely; helper should jump to ring 2.
	var taken: Dictionary = {}
	for s in range(6):
		taken[GalaxyHexLayout.ring_slot_to_axial(1, s)] = true
	var coord: Vector2i = GalaxyHexLayout.next_free_outward(taken, 1)
	# Returned coord must NOT be on ring 1, and must NOT collide with taken.
	assert_bool(taken.has(coord)).is_false()
	# Ring-2 coords have absolute q or r ≥ 2 (with cube constraint q+r+s=0).
	# Safer check: confirm the coord is one of the ring-2 hexes.
	var ring_two: Dictionary = {}
	for s in range(12):
		ring_two[GalaxyHexLayout.ring_slot_to_axial(2, s)] = true
	assert_bool(ring_two.has(coord)).is_true()


func test_next_free_outward_handles_starting_ring_zero() -> void:
	# start_ring=0 should be clamped to 1 internally (no infinite loop on ring 0).
	var taken: Dictionary = {}
	var coord: Vector2i = GalaxyHexLayout.next_free_outward(taken, 0)
	assert_bool(taken.has(coord)).is_false()


# ============================================================================
# 8. Audit coverage: hex_corners angle correctness
# ============================================================================

func test_hex_corners_evenly_spaced_60_degrees() -> void:
	# Flat-top hex corners must be at angles 0°, 60°, 120°, 180°, 240°, 300°.
	var corners: PackedVector2Array = GalaxyHexLayout.hex_corners(Vector2.ZERO, 56.0)
	for i in range(6):
		var expected_angle: float = deg_to_rad(60.0 * float(i))
		var expected: Vector2 = Vector2(56.0 * cos(expected_angle), 56.0 * sin(expected_angle))
		assert_float(corners[i].x).is_equal_approx(expected.x, 0.001)
		assert_float(corners[i].y).is_equal_approx(expected.y, 0.001)


func test_hex_corners_all_at_correct_distance_from_centre() -> void:
	# Every corner must be exactly `size` away from the centre.
	var centre: Vector2 = Vector2(100, 200)
	var corners: PackedVector2Array = GalaxyHexLayout.hex_corners(centre, 56.0)
	for c in corners:
		assert_float(c.distance_to(centre)).is_equal_approx(56.0, 0.001)


# ============================================================================
# 9. Audit coverage: ring 2-5 distinct-hex count
# ============================================================================

func test_ring_2_has_12_distinct_hexes() -> void:
	var seen: Dictionary = {}
	for s in range(12):
		seen[GalaxyHexLayout.ring_slot_to_axial(2, s)] = true
	assert_int(seen.size()).is_equal(12)


func test_ring_3_has_18_distinct_hexes() -> void:
	var seen: Dictionary = {}
	for s in range(18):
		seen[GalaxyHexLayout.ring_slot_to_axial(3, s)] = true
	assert_int(seen.size()).is_equal(18)


func test_ring_4_has_24_distinct_hexes() -> void:
	var seen: Dictionary = {}
	for s in range(24):
		seen[GalaxyHexLayout.ring_slot_to_axial(4, s)] = true
	assert_int(seen.size()).is_equal(24)


func test_ring_5_has_30_distinct_hexes() -> void:
	var seen: Dictionary = {}
	for s in range(30):
		seen[GalaxyHexLayout.ring_slot_to_axial(5, s)] = true
	assert_int(seen.size()).is_equal(30)


func test_rings_2_through_5_do_not_overlap() -> void:
	# No hex on ring N should equal any hex on ring M for N != M.
	# (Sanity check that ring walking starts/ends correctly per ring.)
	var ring_to_set: Dictionary = {}
	for r in range(1, 6):
		var s: Dictionary = {}
		for slot in range(6 * r):
			s[GalaxyHexLayout.ring_slot_to_axial(r, slot)] = true
		ring_to_set[r] = s
	for r1 in range(1, 6):
		for r2 in range(r1 + 1, 6):
			for c in ring_to_set[r1].keys():
				assert_bool((ring_to_set[r2] as Dictionary).has(c)).is_false()


# ============================================================================
# 10. Audit coverage: axial_to_pixel y-axis
# ============================================================================

func test_axial_to_pixel_y_axis_step() -> void:
	# Flat-top: moving +1 in r (with q=0) steps HEX_SIZE * SQRT3 in pixel y.
	var p: Vector2 = GalaxyHexLayout.axial_to_pixel(Vector2i(0, 1))
	assert_float(p.x).is_equal_approx(0.0, 0.001)
	assert_float(p.y).is_equal_approx(
		GalaxyHexLayout.HEX_SIZE * GalaxyHexLayout.SQRT3, 0.001
	)


func test_axial_to_pixel_diagonal_combines_q_and_r() -> void:
	# (1, 1): x = HEX_SIZE * 1.5, y = HEX_SIZE * SQRT3 * (1 + 0.5) = HEX_SIZE * SQRT3 * 1.5
	var p: Vector2 = GalaxyHexLayout.axial_to_pixel(Vector2i(1, 1))
	assert_float(p.x).is_equal_approx(GalaxyHexLayout.HEX_SIZE * 1.5, 0.001)
	assert_float(p.y).is_equal_approx(
		GalaxyHexLayout.HEX_SIZE * GalaxyHexLayout.SQRT3 * 1.5, 0.001
	)


# ============================================================================
# 11. Audit coverage: duplicate planet_ids handling
# ============================================================================

func test_duplicate_planet_ids_produce_single_mapping() -> void:
	# Current behavior is "second-write-wins" via the sort+iteration loop.
	# Either way, the result must not have collisions and must be deterministic
	# across runs with the same input.
	var ids_with_dup: Array = ["p_1", "p_1", "p_2"]
	var first: Dictionary = GalaxyHexLayout.assign_coords(CAMPAIGN_ID, ids_with_dup, "")
	# The duplicate should resolve to ONE entry (Dictionary key uniqueness),
	# so size == 2 (one for p_1, one for p_2).
	assert_int(first.size()).is_equal(2)
	# Determinism across runs even with the dup.
	for _loop_iter in range(10):
		var again: Dictionary = GalaxyHexLayout.assign_coords(
			CAMPAIGN_ID, ids_with_dup, ""
		)
		assert_dict(again).is_equal(first)
