extends GdUnitTestSuite
## End-to-end check on the real dual-location-equipment test save.
##   (A) GameState.verify_consistency() is clean (the id->name equipment heal), and
##   (B1) the galaxy map is seeded from the loaded world (PlanetDataManager has a
##        current planet + at least one visited planet), proving load_campaign's
##        QoL-restore path runs the upsert_current_world backfill.
##
## Machine-specific by design (targets the user:// save this sprint diagnosed).
## Skips gracefully when the autoload or save is absent so it can't false-fail
## on a clean CI checkout.

const SAVE_PATH := "user://saves/asdasdasd_1778119724.save"

func _root() -> Node:
	return Engine.get_main_loop().root if Engine.get_main_loop() else null

func test_real_save_is_consistent_and_seeds_galaxy_map() -> void:
	var root := _root()
	if root == null:
		return
	var gs = root.get_node_or_null("/root/GameState")
	if gs == null or not FileAccess.file_exists(SAVE_PATH):
		return

	var result: Dictionary = gs.load_campaign(SAVE_PATH)
	assert_bool(result.get("success", false)).is_true()

	# (A) Dual-location equipment heal: verify_consistency reports no violations.
	if gs.has_method("verify_consistency"):
		var issues: Array = gs.verify_consistency()
		assert_array(issues).is_empty()

	# (B1) The galaxy map reflects the loaded world (seeded via the load backfill).
	var pdm = root.get_node_or_null("/root/PlanetDataManager")
	if pdm:
		assert_bool(pdm.visited_planets.size() >= 1).is_true()
		assert_bool(pdm.get_current_planet() != null).is_true()
