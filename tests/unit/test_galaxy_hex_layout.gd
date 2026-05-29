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
	for _i in range(100):
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
		var coord: Vector2i = GalaxyHexLayout._ring_slot_to_axial(1, s)
		seen[coord] = true
	assert_int(seen.size()).is_equal(6)


func test_ring_one_neighbors_are_all_distance_one_from_origin() -> void:
	# Every ring-1 coord must be exactly one of the 6 direction vectors.
	var valid: Dictionary = {}
	for d in GalaxyHexLayout.DIRS:
		valid[d] = true
	for s in range(6):
		var coord: Vector2i = GalaxyHexLayout._ring_slot_to_axial(1, s)
		assert_bool(valid.has(coord)).is_true()
