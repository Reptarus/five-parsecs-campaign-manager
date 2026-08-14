extends GdUnitTestSuite
## Two Compendium world-layer rows: the p.94 Terrain Generation opt-in, and the
## removal of a fabricated "exploration progress" statistic.
##
## 1. TERRAIN GENERATION IS OPT-IN. Compendium p.94, verbatim: "The following
##    terrain generators are SUPPLIED FOR PEOPLE WHO PREFER a randomly generated
##    table setup... for players who prefer to have less direct control over
##    aspects of the scenario." `TERRAIN_GENERATION` is a real, defined
##    ContentFlag with a real accessor, listed in the store catalogue and the DLC
##    dialog — and `is_terrain_generation_enabled()` had ZERO callers, so the
##    switch a player can see and turn off did nothing.
##
##    The fix must NOT re-create the 2026-07-02 blank-battlefield bug, where an
##    earlier gate on a flag that DLCManager never defined returned {} for every
##    player. Off means "I lay out my own table", not "no battlefield": the grid,
##    table size, quarters, deployment condition and p.109 terrain-count guidance
##    are still owed.
##
## 2. `exploration_progress` WAS FABRICATED. The term appears in neither rulebook.
##    Nothing consumed it, its `exploration_progress_updated` signal had zero
##    listeners, and it read `mission_data["exploration_value"]` — a key with no
##    producer anywhere — so it defaulted to a flat 0.1 per mission and displayed
##    a world as "100% explored" after ten missions: a completion bar for a
##    completion mechanic that does not exist.
##
## gdUnit4 v6.0.3 compatible.

const PHASE_MANAGER_SRC := "res://src/core/campaign/CampaignPhaseManager.gd"
const PDM_SRC := "res://src/core/world/PlanetDataManager.gd"
const DETAIL_BUILDER_SRC := "res://src/core/world/PlanetDetailBuilder.gd"
const DASHBOARD_SRC := "res://src/ui/screens/campaign/CampaignDashboard.gd"


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var t: String = f.get_as_text()
	f.close()
	return t


## Comment-stripped source — a scan that forbids a string must ignore the comment
## that explains why it is forbidden.
func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line: String in _src(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


func _dlc() -> Node:
	return get_node_or_null("/root/DLCManager")


# ── 1. Terrain Generation opt-in ───────────────────────────────────────────

func test_the_terrain_option_is_actually_consulted() -> void:
	var src: String = _code_only(PHASE_MANAGER_SRC)
	assert_bool(src.contains("is_terrain_generation_enabled")).override_failure_message(
		"generate_battlefield() no longer consults the TERRAIN_GENERATION option,"
		+ " so the p.94 opt-in the player can switch off does nothing again"
	).is_true()


## The regression that matters more than the feature: turning the option off must
## not hand back {} and leave the battle with no battlefield.
func test_switching_it_off_still_yields_a_usable_table() -> void:
	var dlc: Node = _dlc()
	if dlc == null:
		return
	var saved: bool = dlc.is_feature_enabled(dlc.ContentFlag.TERRAIN_GENERATION)
	dlc.set_feature_enabled(dlc.ContentFlag.TERRAIN_GENERATION, false)

	var pm: Node = get_node_or_null("/root/CampaignPhaseManager")
	if pm == null or not pm.has_method("generate_battlefield"):
		dlc.set_feature_enabled(dlc.ContentFlag.TERRAIN_GENERATION, saved)
		return
	var bf: Dictionary = pm.generate_battlefield("", [], {}, 12345, 3.0)
	dlc.set_feature_enabled(dlc.ContentFlag.TERRAIN_GENERATION, saved)

	assert_bool(bf.is_empty()).override_failure_message(
		"generate_battlefield() returned {} with Terrain Generation off — that is"
		+ " the 2026-07-02 blank-battlefield bug, not the p.94 opt-in").is_false()
	assert_bool(bf.get("player_defined_terrain", false)).override_failure_message(
		"the blank-table contract is not flagged as player-defined").is_true()
	# Everything the generator does NOT own must survive.
	assert_int((bf.get("sectors", []) as Array).size()).override_failure_message(
		"p.94 step 1 divides the table into 16 sectors regardless of who places"
		+ " the terrain").is_equal(16)
	assert_float(float(bf.get("table_size_ft", 0.0))).override_failure_message(
		"table size is a Core Rules p.108 setting, not a generator output"
	).is_equal(3.0)
	# ...and the random layout must NOT.
	var placed := 0
	for s: Variant in bf.get("sectors", []):
		placed += ((s as Dictionary).get("features", []) as Array).size()
	assert_int(placed).override_failure_message(
		"terrain features were placed with the generator switched off").is_equal(0)


func test_switching_it_on_generates_terrain() -> void:
	var dlc: Node = _dlc()
	if dlc == null:
		return
	var saved: bool = dlc.is_feature_enabled(dlc.ContentFlag.TERRAIN_GENERATION)
	dlc.set_feature_enabled(dlc.ContentFlag.TERRAIN_GENERATION, true)

	var pm: Node = get_node_or_null("/root/CampaignPhaseManager")
	if pm == null or not pm.has_method("generate_battlefield"):
		dlc.set_feature_enabled(dlc.ContentFlag.TERRAIN_GENERATION, saved)
		return
	var bf: Dictionary = pm.generate_battlefield("wilderness", [], {}, 4242, 3.0)
	dlc.set_feature_enabled(dlc.ContentFlag.TERRAIN_GENERATION, saved)

	var placed := 0
	for s: Variant in bf.get("sectors", []):
		placed += ((s as Dictionary).get("features", []) as Array).size()
	assert_int(placed).override_failure_message(
		"with the option ON the pp.94-98 generator placed no terrain — the gate is"
		+ " now suppressing the feature it is supposed to offer").is_greater(0)
	assert_bool(bf.get("player_defined_terrain", false)).override_failure_message(
		"a generated table is flagged player-defined").is_false()


# ── 2. The fabricated statistic is gone ────────────────────────────────────

func test_no_exploration_progress_anywhere_in_the_world_layer() -> void:
	var offenders: PackedStringArray = []
	for path: String in [PDM_SRC, DETAIL_BUILDER_SRC, DASHBOARD_SRC]:
		var line_no := 0
		for line: String in _code_only(path).split("\n"):
			line_no += 1
			if "exploration_progress" in line or "exploration_value" in line:
				offenders.append("%s: %s" % [path.get_file(), line.strip_edges()])
	assert_int(offenders.size()).override_failure_message(
		"`exploration_progress` is back. It is in neither rulebook, no rule reads"
		+ " it, and it showed a world at '100%% explored' after ten missions:\n  "
		+ "\n  ".join(offenders)).is_equal(0)


func test_the_dead_progress_bar_is_deleted() -> void:
	assert_bool(_src(DASHBOARD_SRC).contains("func _add_exploration_bar")) \
		.override_failure_message(
			"_add_exploration_bar() is back; it rendered the fabricated statistic"
		).is_false()


func test_completing_a_mission_still_counts_the_mission() -> void:
	# The removal must not take the legitimate counter with it.
	var pdm: Node = get_node_or_null("/root/PlanetDataManager")
	if pdm == null or not pdm.has_method("complete_mission"):
		return
	var src: String = _code_only(PDM_SRC)
	assert_bool(src.contains("planet.missions_completed += 1")).override_failure_message(
		"missions_completed is a real counter and must survive the exploration"
		+ " removal").is_true()
	assert_bool(src.contains("planet.resources_extracted += resources_gained")) \
		.override_failure_message("resources_extracted was removed too").is_true()
