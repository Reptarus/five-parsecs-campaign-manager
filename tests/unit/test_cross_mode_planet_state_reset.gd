extends GdUnitTestSuite
## Tests for Opus 4.8 audit B3 + B4 — cross-mode and empty-save planet state
## contamination guards in the campaign cores' apply_pending_qol_data() methods.
##
## The bug being defended: PlanetDataManager is a shared autoload. Prior to
## these fixes, switching modes (5PFH → Bug Hunt / Planetfall / Tactics) or
## loading a 5PFH save without planet_data left stale visited_planets in the
## autoload, which the Galaxy Log (and any other PDM consumer) would then show
## as ghost planets from the previous session.

const BugHuntCampaignCore := preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const PlanetfallCampaignCore := preload(
	"res://src/game/campaign/PlanetfallCampaignCore.gd"
)
const TacticsCampaignCore := preload(
	"res://src/game/campaign/TacticsCampaignCore.gd"
)
const FiveParsecsCampaignCore := preload(
	"res://src/game/campaign/FiveParsecsCampaignCore.gd"
)


func _get_pdm() -> Node:
	# PlanetDataManager is registered as an autoload in project.godot, so it
	# lives at /root/PlanetDataManager at runtime. In gdUnit4 the scene tree
	# is live and autoloads are accessible.
	return get_tree().root.get_node_or_null("/root/PlanetDataManager")


func _populate_pdm_with_fake_planets(pdm: Node, count: int) -> void:
	# Inject fake entries directly into visited_planets + travel_history rather
	# than going through get_or_generate_planet(). The clear()-based reset
	# we're verifying only cares about presence/absence; the entry value types
	# are irrelevant for that. Bypassing WorldGenerator also dodges an
	# unrelated Array[String] typing quirk in PlanetData.traits assignment
	# that surfaces in the generation path.
	for i in range(count):
		var fake_id: String = "fake_planet_" + str(i)
		pdm.visited_planets[fake_id] = {
			"id": fake_id,
			"name": "Fake Planet %d" % i,
		}
		pdm.travel_history.append({
			"planet_id": fake_id,
			"planet_name": "Fake Planet %d" % i,
			"turn": i,
			"visit_number": 1,
		})


func before_test() -> void:
	# Ensure each test starts with a clean PDM regardless of previous test order.
	var pdm: Node = _get_pdm()
	if pdm and pdm.has_method("deserialize_all"):
		pdm.deserialize_all({})


func after_test() -> void:
	# Leave a clean PDM so other test suites aren't contaminated.
	var pdm: Node = _get_pdm()
	if pdm and pdm.has_method("deserialize_all"):
		pdm.deserialize_all({})


# ============================================================================
# B3: cross-mode state reset (Bug Hunt / Planetfall / Tactics clear on load)
# ============================================================================

func test_bug_hunt_clears_planet_data_manager() -> void:
	var pdm: Node = _get_pdm()
	assert_that(pdm).is_not_null()
	_populate_pdm_with_fake_planets(pdm, 3)
	assert_int(pdm.visited_planets.size()).is_equal(3)

	# Bug Hunt apply_pending_qol_data must clear PDM, even with no pending data.
	var bh = BugHuntCampaignCore.new()
	bh.apply_pending_qol_data()

	assert_bool(pdm.visited_planets.is_empty()).is_true()
	assert_bool(pdm.travel_history.is_empty()).is_true()


func test_planetfall_clears_planet_data_manager() -> void:
	var pdm: Node = _get_pdm()
	assert_that(pdm).is_not_null()
	_populate_pdm_with_fake_planets(pdm, 5)
	assert_int(pdm.visited_planets.size()).is_equal(5)

	var pf = PlanetfallCampaignCore.new()
	pf.apply_pending_qol_data()

	assert_bool(pdm.visited_planets.is_empty()).is_true()
	assert_bool(pdm.travel_history.is_empty()).is_true()


func test_tactics_clears_planet_data_manager() -> void:
	var pdm: Node = _get_pdm()
	assert_that(pdm).is_not_null()
	_populate_pdm_with_fake_planets(pdm, 4)
	assert_int(pdm.visited_planets.size()).is_equal(4)

	var t = TacticsCampaignCore.new()
	t.apply_pending_qol_data()

	assert_bool(pdm.visited_planets.is_empty()).is_true()
	assert_bool(pdm.travel_history.is_empty()).is_true()


# ============================================================================
# B4: 5PFH-loading-empty-save state reset
# ============================================================================

func test_five_parsecs_empty_save_clears_planet_data_manager() -> void:
	# Pre-populate PDM to simulate stale state from a previous session.
	var pdm: Node = _get_pdm()
	assert_that(pdm).is_not_null()
	_populate_pdm_with_fake_planets(pdm, 2)
	assert_int(pdm.visited_planets.size()).is_equal(2)

	# Load a campaign whose save bundle has NO planet_data (legacy/empty save).
	# from_dictionary stashes qol_data into _pending_qol_data; apply applies it.
	var camp = FiveParsecsCampaignCore.new()
	camp.from_dictionary({
		"campaign_id": "empty_save_test",
		"qol_data": {},  # No "planet_data" key at all
	})
	camp.apply_pending_qol_data()

	# Audit B4: even though the save had no planet_data, PDM must be cleared
	# so the previous session's planets don't appear in the loaded campaign.
	assert_bool(pdm.visited_planets.is_empty()).is_true()
	assert_bool(pdm.travel_history.is_empty()).is_true()


# Happy-path round-trip is covered by tests/unit/test_planet_persistence.gd,
# which already exercises serialize_all → deserialize_all through real
# WorldGenerator-backed planet data. The Phase 0 changes here only affect the
# empty-data and cross-mode paths; those are covered by the tests above.
