extends GdUnitTestSuite
## Does the Load Campaign dialog tag a save with the mode it actually is, and does the
## Bug Hunt menu list the saves the loader would actually open as Bug Hunt?
##
## Bug Hunt Sprint 1, Phase 2 steps 1-2. GameState.get_campaign_info() emits
## "campaign_type" (GameState.gd:1353, resolved through the shared
## campaign_type_from_data so the loader and the menu cannot disagree). MainMenu reads
## "type", which no producer writes, and falls back to a substring of the SAVE PATH.
##
## THE SUBSTRING NEVER MATCHES A REAL BUG HUNT SAVE. Bug Hunt writes to
## "user://saves/" + get_campaign_id() + ".save" (BugHuntCampaignCore.gd:345), and that
## id is <name>_bh_<ts> for a named campaign or bughunt_<ts> for an unnamed one
## (:137-143). Neither contains "bug_hunt". Planetfall and Tactics are _pf_/_tac_ and
## planetfall_/tactics_, so only their UNNAMED fallback matches. Both arms of every `or`
## are therefore false for a named variant campaign: the tag has never rendered on one.
##
## AND IT FIRES ON THE WRONG SAVES. FiveParsecsCampaignCore builds its id the same way
## (<name>_<ts>), so a STANDARD campaign a player names "Bug Hunt Veterans" becomes
## bug_hunt_veterans_<ts> and is tagged [BH]. The predicate is wrong in both directions,
## which is why the fix reads the key the producer writes rather than widening the
## substring list.
##
## WHY STATICS. MainMenu.campaign_type_tag() and MainMenu.find_saves_of_type() are the
## two rules extracted from _on_load_campaign_pressed() and the three _find_*_saves()
## functions with their bodies preserved verbatim — those call sites build modal
## AcceptDialogs and cannot be driven from a test. Phase 2 changes what they READ;
## nothing else moves.
##
## WHY THE IDS ARE GENERATED, NOT HARDCODED. Every fixture sets campaign_name, leaves
## campaign_id empty and asks the core's own get_campaign_id() for the id, so the id
## SHAPE under test is the shipped one. A hardcoded "zz_probe_bh_1" would pin this suite
## to my transcription of the generator rather than to the generator.
##
## SIDE EFFECTS. Saves are written with core.save_to_file() directly, never
## GameState.save_campaign(), which also rewrites user://settings.cfg and sets
## last_campaign — the documented cross-suite bleed. Every file written is tracked and
## removed before and after each case, with the .tmp/.bak siblings SaveFileWriter leaves.
## user://saves/ holds the developer's own campaigns, so every case asserts membership
## of its OWN probe paths and never the size of a result.

const MainMenuScript := preload("res://src/ui/screens/mainmenu/MainMenu.gd")
const BugHuntCoreScript := preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const PlanetfallCoreScript := preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const TacticsCoreScript := preload("res://src/game/campaign/TacticsCampaignCore.gd")

## The loader's own reader and type router, so the cases below assert that the menu
## agrees with the thing that actually opens the save rather than with my restatement of
## it. Preloading an autoload's script to reach a static is well precedented here (10
## sites for GameState.gd, 10 for SaveFileWriter.gd) and instantiates nothing.
const GameStateScript := preload("res://src/core/state/GameState.gd")
const SaveFileWriterRef := preload("res://src/core/state/SaveFileWriter.gd")

var _written: Array = []


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameState")


func before_test() -> void:
	_cleanup()


func after_test() -> void:
	_cleanup()


func _cleanup() -> void:
	for base in _written:
		for suffix in ["", ".tmp", ".bak"]:
			var path: String = str(base) + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	_written.clear()


## Write one save through the real core and return its path. The id comes from the
## core's own generator, so the path shape is production's, not this suite's.
func _write(core: Resource, campaign_name: String) -> String:
	core.campaign_name = campaign_name
	var id: String = core.get_campaign_id()
	var path: String = "user://saves/%s.save" % id
	core.save_to_file(path)
	_written.append(path)
	return path


func _info(path: String) -> Dictionary:
	var gs := _gs()
	if gs == null:
		return {}
	return gs.get_campaign_info(path)


func _tag(path: String) -> String:
	return MainMenuScript.campaign_type_tag(_info(path))


func test_the_producer_labels_every_mode_and_writes_no_type_key() -> void:
	# The premise every other case rests on. If this fails, the tag is reading missing
	# data and the fix is on the producer; it passing means the tag reads the WRONG KEY.
	# It also retires this suite honestly: the day something starts emitting "type",
	# this case says so rather than leaving the others pinning a defect that is gone.
	var gs := _gs()
	assert_object(gs).override_failure_message(
		"GameState autoload missing; this suite measures its real output"
	).is_not_null()

	var cases := {
		"bug_hunt": _write(BugHuntCoreScript.new(), "zz mode predicates bh"),
		"planetfall": _write(PlanetfallCoreScript.new(), "zz mode predicates pf"),
		"tactics": _write(TacticsCoreScript.new(), "zz mode predicates tac"),
		"five_parsecs": _write(FiveParsecsCampaignCore.new(), "zz mode predicates fp"),
	}
	for expected: String in cases:
		var info := _info(cases[expected])
		assert_bool(info.get("valid", false)).override_failure_message(
			"probe save for %s did not read back as valid" % expected).is_true()
		assert_str(str(info.get("campaign_type", ""))).override_failure_message(
			"get_campaign_info must label the %s save; got %s"
			% [expected, info.get("campaign_type", "<absent>")]
		).is_equal(expected)
		assert_bool(info.has("type")).override_failure_message(
			"no producer writes a \"type\" key; if one now does, the tag's second arm"
			+ " is live and this suite's premise has changed"
		).is_false()


func test_a_named_bug_hunt_campaign_is_tagged() -> void:
	# A player's Bug Hunt campaign has a name, so its id is <name>_bh_<ts>. The substring
	# "bug_hunt" is absent from it and "type" is absent from the info, so on HEAD both
	# arms are false and the row renders with no tag at all.
	var path := _write(BugHuntCoreScript.new(), "zz mode predicates bh")
	assert_str(path).override_failure_message(
		"fixture premise: a NAMED Bug Hunt id must not contain the substring the tag"
		+ " looks for, or this case would pass by accident. Path was %s" % path
	).not_contains("bug_hunt")
	assert_str(_tag(path)).override_failure_message(
		"a Bug Hunt save must be tagged [BH] in the Load Campaign dialog"
	).is_equal("[BH] ")


func test_named_planetfall_and_tactics_campaigns_are_tagged() -> void:
	# Same shape, and the reason the fix is one predicate rather than three: the
	# Planetfall and Tactics tags fail for exactly the reason the Bug Hunt one does.
	var pf := _write(PlanetfallCoreScript.new(), "zz mode predicates pf")
	var tac := _write(TacticsCoreScript.new(), "zz mode predicates tac")
	assert_str(pf).not_contains("planetfall")
	assert_str(tac).not_contains("tactics")
	assert_str(_tag(pf)).override_failure_message(
		"a Planetfall save must be tagged [PF]").is_equal("[PF] ")
	assert_str(_tag(tac)).override_failure_message(
		"a Tactics save must be tagged [TAC]").is_equal("[TAC] ")


func test_a_standard_campaign_named_after_a_mode_is_not_mistagged() -> void:
	# The other direction of the same defect, and the one a player can actually hit:
	# FiveParsecsCampaignCore derives its id from the campaign name too, so naming a
	# STANDARD campaign "Bug Hunt Veterans" puts the substring in the save path and the
	# row is tagged [BH]. Loading it then opens a 5PFH campaign the menu called Bug Hunt.
	var path := _write(FiveParsecsCampaignCore.new(), "Bug Hunt Veterans")
	assert_str(path).override_failure_message(
		"fixture premise: this 5PFH id must CONTAIN the substring, or the case cannot"
		+ " detect the false positive. Path was %s" % path
	).contains("bug_hunt")
	assert_str(_tag(path)).override_failure_message(
		"a STANDARD campaign must carry no mode tag however the player named it"
	).is_equal("")


func test_an_ordinary_standard_campaign_carries_no_tag() -> void:
	# Passes before and after the fix. Here so the fix cannot be "tag everything".
	var path := _write(FiveParsecsCampaignCore.new(), "zz mode predicates fp")
	assert_str(_tag(path)).is_equal("")


func test_the_tag_tolerates_the_shapes_get_available_campaigns_can_hand_over() -> void:
	# get_available_campaigns() appends whatever get_campaign_info() returned, and that
	# is {"valid": false, "reason": ...} with NO path key for an unreadable file. Passes
	# before and after; pinned so the Phase 2 rewrite keeps it.
	assert_str(MainMenuScript.campaign_type_tag({})).is_equal("")
	assert_str(MainMenuScript.campaign_type_tag(
		{"valid": false, "reason": "File not found"})).is_equal("")
	assert_str(MainMenuScript.campaign_type_tag(
		{"path": "", "campaign_type": ""})).is_equal("")


# ---------------------------------------------------------------------------
# Phase 2 step 2 — the save scan. Does the Bug Hunt menu list the saves the
# loader would actually open as Bug Hunt?
# ---------------------------------------------------------------------------


## Rows of a scan reduced to their paths, so membership is assertable.
func _paths(rows: Array) -> Array:
	var out: Array = []
	for row in rows:
		out.append(str((row as Dictionary).get("path", "")))
	return out


func _row(rows: Array, path: String) -> Dictionary:
	for row in rows:
		if str((row as Dictionary).get("path", "")) == path:
			return row as Dictionary
	return {}


## Leave the artefact an interrupted write leaves behind: a good .bak beside a 0-byte
## main file. FileAccess.WRITE truncates the live save the instant it opens, which is
## the whole reason SaveFileWriter exists — its _try_parse names "the exact 0-byte
## artefact a truncated write leaves behind" — and read_json_with_fallback recovers it.
func _truncate_leaving_backup(path: String) -> void:
	var good := FileAccess.open(path, FileAccess.READ)
	var bytes := good.get_buffer(good.get_length())
	good.close()
	var bak := FileAccess.open(path + ".bak", FileAccess.WRITE)
	bak.store_buffer(bytes)
	bak.close()
	var wipe := FileAccess.open(path, FileAccess.WRITE)
	wipe.close()


## A save carrying campaign_type ONLY under meta. SYNTHETIC: every shipped core writes
## the field at root AND under meta (BugHuntCampaignCore.gd to_dictionary, both places).
## It is here because it is the one input on which the two readers provably differ, and
## campaign_type_from_data's own comment says the meta branch exists "so a future writer
## moving the field cannot silently mis-route a save". The case pins that invariant.
func _write_meta_only_type(campaign_type: String, campaign_name: String) -> String:
	var path: String = "user://saves/zz_meta_only_%s.save" % campaign_type
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"campaign_id": "zz_meta_only_%s" % campaign_type,
		"meta": {"campaign_name": campaign_name, "campaign_type": campaign_type},
		"state": {"campaign_turn": 3},
	}))
	f.close()
	_written.append(path)
	return path


func test_the_save_scans_find_each_mode_and_only_its_own() -> void:
	# Regression guard for collapsing three byte-identical scans into one parameterised
	# helper. Passes before and after; here so the collapse cannot cross-match.
	var bh := _write(BugHuntCoreScript.new(), "zz scan bh")
	var pf := _write(PlanetfallCoreScript.new(), "zz scan pf")
	var tac := _write(TacticsCoreScript.new(), "zz scan tac")
	var fp := _write(FiveParsecsCampaignCore.new(), "zz scan fp")
	var by_mode := {"bug_hunt": bh, "planetfall": pf, "tactics": tac}

	for mode: String in by_mode:
		var found := _paths(MainMenuScript.find_saves_of_type(mode))
		assert_array(found).override_failure_message(
			"the %s scan must list the %s save" % [mode, mode]
		).contains([by_mode[mode]])
		assert_array(found).override_failure_message(
			"no variant scan may list a standard 5PFH save").not_contains([fp])
		for other: String in by_mode:
			if other == mode:
				continue
			assert_array(found).override_failure_message(
				"the %s scan must not list the %s save" % [mode, other]
			).not_contains([by_mode[other]])


func test_the_save_scan_reports_the_name_and_turn_the_dialog_prints() -> void:
	# The dialog renders "Continue: %s (Turn %d)" from these two keys
	# (MainMenu._on_bug_hunt_pressed), so losing either turns a real campaign into
	# "Unknown (Turn 0)". Planetfall is here because its turn is the ONE key the three
	# scans did not share: progression.campaign_turn, not state.campaign_turn
	# (PlanetfallCampaignCore.gd:599 vs BugHuntCampaignCore.gd:396). Passes before and
	# after — it exists so the collapse cannot quietly drop the odd one out.
	var bh_core := BugHuntCoreScript.new()
	bh_core.campaign_turn = 7
	var bh := _write(bh_core, "zz harvest bh")
	var pf_core := PlanetfallCoreScript.new()
	pf_core.campaign_turn = 5
	var pf := _write(pf_core, "zz harvest pf")

	var bh_row := _row(MainMenuScript.find_saves_of_type("bug_hunt"), bh)
	assert_str(str(bh_row.get("name", ""))).override_failure_message(
		"the Bug Hunt name is at meta.campaign_name, never at root"
	).is_equal("zz harvest bh")
	assert_int(int(bh_row.get("turn", -1))).override_failure_message(
		"the Bug Hunt turn is serialized under state.campaign_turn").is_equal(7)

	var pf_row := _row(MainMenuScript.find_saves_of_type("planetfall"), pf)
	assert_str(str(pf_row.get("name", ""))).is_equal("zz harvest pf")
	assert_int(int(pf_row.get("turn", -1))).override_failure_message(
		"the Planetfall turn is under progression.campaign_turn, not state"
	).is_equal(5)


func test_a_bug_hunt_save_recovered_from_its_backup_is_listed() -> void:
	# GameState._detect_campaign_type's docblock already names this function as a victim:
	# "the campaign is destroyed AND vanishes from the Bug Hunt menu
	# (MainMenu.find_saves_of_type("bug_hunt") filters on that field)". The loader was given
	# read_json_with_fallback; the menu was not, so the menu still drops a save the
	# loader can open. A fix applied to one reader of a shared fact is not a fix.
	var path := _write(BugHuntCoreScript.new(), "zz recovered bh")
	_truncate_leaving_backup(path)

	assert_bool(SaveFileWriterRef.read_json_with_fallback(path).is_empty()
	).override_failure_message(
		"fixture premise: the .bak must still parse, or this case proves nothing"
	).is_false()
	assert_str(GameStateScript._detect_campaign_type(path)).override_failure_message(
		"fixture premise: the loader must route this save to Bug Hunt"
	).is_equal("bug_hunt")

	assert_array(_paths(MainMenuScript.find_saves_of_type("bug_hunt"))
	).override_failure_message(
		"a save the loader can open must appear in the Bug Hunt menu; this one is a"
		+ " 0-byte main file beside an intact .bak, the artefact an interrupted write"
		+ " leaves and the exact case SaveFileWriter exists to survive"
	).contains([path])


func test_the_menu_lists_exactly_what_the_loader_would_open_as_bug_hunt() -> void:
	# The invariant Phase 2 step 2 exists for, stated directly: a save is in the Bug Hunt
	# menu IF AND ONLY IF the loader would route it to Bug Hunt. Asserted over every
	# shape the two readers can differ on, in both directions, so neither a missed save
	# nor a false listing can pass.
	var truncated := _write(BugHuntCoreScript.new(), "zz agree trunc bh")
	_truncate_leaving_backup(truncated)
	var probes: Array = [
		_write(BugHuntCoreScript.new(), "zz agree bh"),
		_write(PlanetfallCoreScript.new(), "zz agree pf"),
		_write(FiveParsecsCampaignCore.new(), "zz agree fp"),
		truncated,
		_write_meta_only_type("bug_hunt", "zz agree meta bh"),
	]

	var listed := _paths(MainMenuScript.find_saves_of_type("bug_hunt"))
	for path: String in probes:
		var loader_says: String = GameStateScript._detect_campaign_type(path)
		var in_menu: bool = path in listed
		if loader_says == "bug_hunt":
			assert_bool(in_menu).override_failure_message(
				"the loader opens %s as Bug Hunt but the menu does not list it" % path
			).is_true()
		else:
			assert_bool(in_menu).override_failure_message(
				"the menu lists %s as Bug Hunt but the loader opens it as '%s'"
				% [path, loader_says]
			).is_false()
