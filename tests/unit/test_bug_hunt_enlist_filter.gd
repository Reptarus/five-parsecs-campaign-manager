extends GdUnitTestSuite
## Does Bug Hunt's "Enlist" offer a STANDARD campaign to recruit from?
##
## Bug Hunt Sprint 1, Phase 0 step 3 — fail-first evidence. The Sep 10 parity audit
## found eight incompatible ways to ask "which mode is this?", and this is the one
## that costs a player data: GameState.get_campaign_info() emits "campaign_type"
## (GameState.gd:1353) while BugHuntDashboard reads "type", so the filter compares
## "" against "bug_hunt", is ALWAYS true, and the first save in the scan wins —
## a Bug Hunt save included. Enlisting then pulls a marine out of another Bug Hunt
## campaign as though it were a 5PFH veteran.
##
## WHY A STATIC. BugHuntDashboard.pick_enlist_source() is the rule extracted from
## _on_enlist_pressed() with its body preserved verbatim, so these cases measure the
## shipped behaviour without building the dashboard, the transfer panel or a
## GameState node. Phase 2 step 3 changes the key it reads; nothing else moves.
##
## WHY THE ORDER MATTERS, AND WHY IT IS ASSERTED. The rule returns the FIRST eligible
## save. With the 5PFH save first, HEAD returns the right path by luck and the case
## would pass for the wrong reason. The Bug Hunt save is therefore placed first, and
## that premise is asserted before the rule is called — an ordering assumption left
## implicit is how a detection case goes quietly vacuous.
##
## SIDE EFFECTS. Both cores are written with core.save_to_file() directly, NOT
## GameState.save_campaign(), which also sets last_campaign and rewrites the whole of
## user://settings.cfg — the documented cross-suite bleed. Nothing here touches
## GameState.current_campaign or the settings, so no snapshot/restore is needed; the
## two saves (and the .tmp/.bak siblings SaveFileWriter leaves) are removed before and
## after every case, because a run aborted mid-case would otherwise seed the next.

const DashboardScript := preload("res://src/ui/screens/bug_hunt/BugHuntDashboard.gd")
const BugHuntCoreScript := preload("res://src/game/campaign/BugHuntCampaignCore.gd")

const BH_ID := "zz_enlist_filter_bug_hunt_probe"
const FP_ID := "zz_enlist_filter_five_parsecs_probe"
const BH_SAVE := "user://saves/zz_enlist_filter_bug_hunt_probe.save"
const FP_SAVE := "user://saves/zz_enlist_filter_five_parsecs_probe.save"


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameState")


func before_test() -> void:
	_remove_probe_saves()


func after_test() -> void:
	_remove_probe_saves()


func _remove_probe_saves() -> void:
	# SaveFileWriter.write_text_atomic() writes path + ".tmp" and keeps path + ".bak".
	for base in [BH_SAVE, FP_SAVE]:
		for suffix in ["", ".tmp", ".bak"]:
			var path: String = base + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)


func _write_bug_hunt_save() -> void:
	var core: Resource = BugHuntCoreScript.new()
	core.campaign_name = "Enlist filter — Bug Hunt probe"
	core.campaign_id = BH_ID
	core.save_to_file(BH_SAVE)


func _write_five_parsecs_save() -> void:
	var core := FiveParsecsCampaignCore.new()
	core.campaign_name = "Enlist filter — 5PFH probe"
	core.campaign_id = FP_ID
	core.save_to_file(FP_SAVE)


## The info array the dashboard consumes, built by the REAL producer
## (GameState.get_campaign_info), Bug Hunt first. Built here rather than taken from
## get_available_campaigns() so the order is fixed and no unrelated save on this
## machine can enter the fixture.
func _campaign_infos(paths: Array) -> Array:
	var gs := _gs()
	var out: Array = []
	if gs == null:
		return out
	for p in paths:
		out.append(gs.get_campaign_info(p))
	return out


func test_get_campaign_info_labels_the_two_probe_saves() -> void:
	# The premise every other case rests on: the producer CAN tell these apart, so a
	# filter that gets it wrong is reading the wrong key, not reading missing data.
	var gs := _gs()
	assert_that(gs).is_not_null()
	if gs == null:
		return
	_write_bug_hunt_save()
	_write_five_parsecs_save()

	var bh: Dictionary = gs.get_campaign_info(BH_SAVE)
	var fp: Dictionary = gs.get_campaign_info(FP_SAVE)

	assert_bool(bh.get("valid", false)).override_failure_message(
			"the Bug Hunt probe save did not parse: %s" % bh.get("reason", "")).is_true()
	assert_bool(fp.get("valid", false)).override_failure_message(
			"the 5PFH probe save did not parse: %s" % fp.get("reason", "")).is_true()
	assert_str(str(bh.get("campaign_type", ""))).override_failure_message(
			"get_campaign_info must report the Bug Hunt save as bug_hunt"
	).is_equal("bug_hunt")
	assert_str(str(fp.get("campaign_type", ""))).override_failure_message(
			"get_campaign_info must report the 5PFH save as five_parsecs"
	).is_equal("five_parsecs")
	# The half the dashboard actually reads. If "type" ever starts being emitted, this
	# case says so, and the filter below stops being a bug.
	assert_bool(bh.has("type")).override_failure_message(
			"get_campaign_info emits campaign_type, not type — if that changed, "
			+ "the enlist filter's key is no longer the defect this suite pins"
	).is_false()


func test_enlist_offers_the_standard_save_not_the_bug_hunt_one() -> void:
	## FAILS ON HEAD, by design. The filter reads "type", gets "", and returns the
	## Bug Hunt save because it is first.
	var gs := _gs()
	assert_that(gs).is_not_null()
	if gs == null:
		return
	_write_bug_hunt_save()
	_write_five_parsecs_save()

	var infos: Array = _campaign_infos([BH_SAVE, FP_SAVE])
	assert_int(infos.size()).is_equal(2)
	if infos.size() != 2:
		return
	# Instrument the ordering premise before relying on it.
	assert_str(str((infos[0] as Dictionary).get("path", ""))).override_failure_message(
			"the fixture must put the Bug Hunt save FIRST, or HEAD passes by luck"
	).is_equal(BH_SAVE)

	var picked: String = DashboardScript.pick_enlist_source(infos)

	assert_str(picked).override_failure_message(
			"Enlist must recruit from a STANDARD campaign save. It picked %s, "
			% ("the Bug Hunt save" if picked == BH_SAVE else "'%s'" % picked)
			+ "so a Bug Hunt marine can be enlisted into Bug Hunt as a 5PFH veteran."
	).is_equal(FP_SAVE)


func test_enlist_offers_nothing_when_only_bug_hunt_saves_exist() -> void:
	## FAILS ON HEAD, by design. With no standard campaign there is nobody to enlist,
	## and the correct answer is "" — not the player's other squad.
	var gs := _gs()
	assert_that(gs).is_not_null()
	if gs == null:
		return
	_write_bug_hunt_save()

	var infos: Array = _campaign_infos([BH_SAVE])
	assert_int(infos.size()).is_equal(1)
	if infos.size() != 1:
		return
	assert_bool((infos[0] as Dictionary).get("valid", false)).is_true()

	var picked: String = DashboardScript.pick_enlist_source(infos)

	assert_str(picked).override_failure_message(
			"with only a Bug Hunt save on disk, Enlist must offer nothing; it offered "
			+ "'%s'" % picked
	).is_equal("")


func test_pick_enlist_source_tolerates_an_empty_and_a_malformed_list() -> void:
	## Passes on HEAD and after the fix — the two shapes get_available_campaigns() can
	## hand over on a machine with no saves, pinned so the Phase 2 rewrite keeps them.
	assert_str(DashboardScript.pick_enlist_source([])).is_equal("")
	assert_str(DashboardScript.pick_enlist_source([null, 7, "not a dict"])).is_equal("")
	# A valid info with no path is not a candidate.
	assert_str(DashboardScript.pick_enlist_source(
			[{"valid": true, "campaign_type": "five_parsecs", "path": ""}])).is_equal("")
