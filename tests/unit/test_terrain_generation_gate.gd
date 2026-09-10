extends GdUnitTestSuite
## Terrain Generation is opt-in DLC content — and the app must both HONOUR that and
## SAY so.
##
## Compendium p.94: the generators are "supplied for people who prefer a randomly
## generated table setup". TERRAIN_GENERATION lives in freelancers_handbook, so a
## base-game player is meant to see a labelled empty grid and lay out their own table.
##
## ⭐ WHY THIS SUITE EXISTS AT ALL. During the 2026-09 tablet walk an empty campaign
## battle map was filed as a rendering defect FOUR times. It was not a defect — the
## gate was working exactly as its own comment describes. What was broken is that the
## app could not say so: _blank_table_contract() ships the sentence "Terrain Generation
## is off — lay out the table as you like." as summary line 0, and TacticalBattleUI's
## Setup tab renders lines[1], because for the GENERATOR's contract line 2 is the
## Compendium theme description. The two contracts share a shape deliberately, so the
## blank one inherited a reader written for the other and its explanation was dropped.
## The player saw a bare grid, p.109 guidance, and no reason.
##
## ⚠ A blank state that cannot explain itself is indistinguishable from a broken one.
## That cost four misdiagnoses with full source access; a player has none.
##
## The second half is the gate's own reach: ONE enforcement site
## (CampaignPhaseManager:2243) against THREE generator call sites. The campaign battle
## screen offered two "Regenerate Terrain" controls and a per-sector re-roll that call
## the generator directly — so the withheld layout was one button press away.
##
## gdUnit4 v6.0.3.

const BattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")

var _dlc: Node = null
var _gs: Node = null
var _saved_campaign: Variant = null
var _saved_owned: bool = false
## Every feature flag of the pack, not just the one this suite cares about —
## see the note in after_test().
var _saved_flags: Dictionary = {}


func before_test() -> void:
	_dlc = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")
	_gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if _dlc:
		_saved_owned = _dlc.has_dlc("freelancers_handbook")
		_saved_flags.clear()
		for flag: Variant in _dlc.get_features_for_dlc("freelancers_handbook"):
			_saved_flags[flag] = _dlc.is_feature_enabled(flag)
	if _gs:
		_saved_campaign = _gs.current_campaign


func after_test() -> void:
	# Restore the shared autoloads. DLCManager is an autoload, so a suite that
	# leaves it mutated silently changes every later suite in the same process.
	#
	# ⚠ RESTORE THE WHOLE PACK, not just the flag under test. set_dlc_owned(id,
	# false) walks get_features_for_dlc(id) and disables EVERY flag it carries
	# (DLCManager.gd:146-148) — thirteen for freelancers_handbook. An earlier
	# version of this teardown put back only TERRAIN_GENERATION and left twelve
	# Compendium features switched off for the rest of the run. The ambient state
	# on a dev machine is freelancers_handbook=true (persisted in
	# user://dlc_ownership.cfg), so the leak turned REAL entitlements off.
	if _dlc:
		_dlc.set_dlc_owned("freelancers_handbook", _saved_owned)
		if _saved_owned:
			for flag: Variant in _saved_flags:
				_dlc.set_feature_enabled(flag, bool(_saved_flags[flag]))
	if _gs:
		_gs.current_campaign = _saved_campaign


func _make_ui() -> Control:
	var ui: Control = auto_free(BattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	return ui


## Put the screen in "this battle belongs to a campaign" state deterministically.
## _is_standalone_battle() returns true when there is no campaign, and under a test
## runner whether GameState auto-loaded one depends on the machine's options.cfg —
## so the fixture states it rather than inheriting it.
func _make_campaign_owned(ui: Control) -> void:
	ui._standalone_declared = false
	ui._battle_mode_id = ""
	if _gs:
		_gs.current_campaign = Resource.new()


func _set_terrain_dlc(on: bool) -> void:
	if not _dlc:
		return
	_dlc.set_dlc_owned("freelancers_handbook", on)
	_dlc.set_feature_enabled(_dlc.ContentFlag.TERRAIN_GENERATION, on)


# ---------------------------------------------------------------------------
# the blank contract must explain itself, in the line the renderer reads
# ---------------------------------------------------------------------------

func test_the_blank_contract_leads_with_the_reason_not_the_guidance() -> void:
	# THE ORDERING IS LOAD-BEARING and nothing else asserted it. Line 0 is the reason
	# the table is empty; line 1 is the p.109 Standard Terrain Set guidance. Swap them
	# and the screen goes back to showing guidance with no explanation — which is the
	# exact state that produced four misdiagnoses.
	var cpm: Node = Engine.get_main_loop().root.get_node_or_null(
		"/root/CampaignPhaseManager")
	assert_object(cpm).override_failure_message(
		"CampaignPhaseManager autoload missing — cannot reach the blank contract"
		).is_not_null()

	var contract: Dictionary = cpm._blank_table_contract(3.0, {})
	var lines: PackedStringArray = str(contract.get("summary", "")).split("\n")

	assert_int(lines.size()).override_failure_message(
		"the blank summary lost a line — the renderer addresses it by index"
		).is_greater_equal(2)
	assert_str(str(lines[0])).override_failure_message(
		"line 0 must be the REASON the table is empty, got '%s'" % str(lines[0])
		).contains("Terrain Generation is off")
	assert_str(str(lines[1])).override_failure_message(
		"line 1 must stay the p.109 guidance, got '%s'" % str(lines[1])
		).contains("p.109")


func test_the_blank_contract_is_a_full_labelled_grid_not_an_absence() -> void:
	# Switching the option off means "I will lay out my own table", NOT "I get no
	# battlefield". The grid, the quarters and the table size are not the terrain
	# generator's to withhold — only the random feature placement is.
	var cpm: Node = Engine.get_main_loop().root.get_node_or_null(
		"/root/CampaignPhaseManager")
	var contract: Dictionary = cpm._blank_table_contract(3.0, {})
	var sectors: Array = contract.get("sectors", [])

	assert_int(sectors.size()).override_failure_message(
		"a player-defined table still needs its 4x4 sector grid").is_equal(16)
	for s: Variant in sectors:
		assert_int((s as Dictionary).get("features", []).size()
			).override_failure_message(
			"the blank contract must place NO features").is_equal(0)
		assert_bool(str((s as Dictionary).get("label", "")).is_empty()
			).override_failure_message("every sector keeps its label").is_false()


# ---------------------------------------------------------------------------
# the gate's reach — one rule, and the standalone exception stated once
# ---------------------------------------------------------------------------

func test_a_campaign_battle_may_not_roll_a_layout_without_the_dlc() -> void:
	var ui := await _make_ui()
	_make_campaign_owned(ui)
	_set_terrain_dlc(false)

	assert_bool(ui._layout_generation_allowed()).override_failure_message(
		"a campaign battle offered layout generation the player has not unlocked"
		).is_false()


func test_owning_the_dlc_restores_layout_generation() -> void:
	# ASSERT BOTH DIRECTIONS. A gate that only ever refuses is as broken as one that
	# only ever permits, and a predicate hard-wired to false would pass the case above.
	var ui := await _make_ui()
	_make_campaign_owned(ui)
	_set_terrain_dlc(true)

	assert_bool(ui._layout_generation_allowed()).override_failure_message(
		"owning freelancers_handbook must re-enable the layout generator"
		).is_true()


func test_a_standalone_battle_stays_ungated_for_demo() -> void:
	# THE DELIBERATE EXCEPTION, pinned so it is not "tidied away" as an oversight.
	# CLAUDE.md records Battle Simulator as "Ungated for demo (DLC gating planned)",
	# which is also why TacticalBattleUI's own fallback generation is left alone.
	var ui := await _make_ui()
	_set_terrain_dlc(false)
	ui._standalone_declared = true

	assert_bool(ui._layout_generation_allowed()).override_failure_message(
		"the Battle Simulator lost its demo terrain — this exception is intentional"
		).is_true()


func _regen_button_count(ui: Control) -> int:
	var host := VBoxContainer.new()
	auto_free(host)
	add_child(host)
	ui._build_terrain_controls(host)
	var n: int = 0
	for child: Node in host.get_children():
		if child is Button and str((child as Button).text).contains("Regenerate"):
			n += 1
	return n


func test_the_regenerate_controls_are_not_offered_when_gated() -> void:
	# ASSERT WHERE THE DAMAGE LANDS. The handler guard alone would leave the player
	# pressing a button that silently does nothing, which reads as a broken control.
	# An unavailable option is better absent than dangled.
	#
	# ⚠ BOTH DIRECTIONS ARE LOAD-BEARING, and the first draft of this case proved it:
	# it asserted only the absence, and PASSED under a reverted gate. _build_terrain_controls
	# returns early outside SETUP/DEPLOYMENT (terrain is locked once the physical table is
	# built), current_stage defaults to TIER_SELECT, so the probe never reached the button
	# and "no button found" was trivially true. The positive arm below is what stops that:
	# it fails if the builder stops reaching the button for ANY reason.
	var ui := await _make_ui()
	_make_campaign_owned(ui)
	ui.current_stage = ui.BattleStage.SETUP

	_set_terrain_dlc(true)
	assert_int(_regen_button_count(ui)).override_failure_message(
		"premise check: the builder never reached the Regenerate button even with the "
		+ "gate OPEN, so the absence assertion below would pass for the wrong reason"
		).is_equal(1)

	_set_terrain_dlc(false)
	assert_int(_regen_button_count(ui)).override_failure_message(
		"a Regenerate Terrain button was offered while the layout generator is gated"
		).is_equal(0)


# ---------------------------------------------------------------------------
# the RENDERER — the contract's line order is not enough, the damage lands here
# ---------------------------------------------------------------------------

func _setup_tab_text(ui: Control) -> String:
	var out: String = ""
	if ui.setup_content == null:
		return out
	for child: Node in ui.setup_content.get_children():
		if child is Label:
			out += str((child as Label).text) + "\n"
	return out


func test_a_player_defined_table_says_why_it_is_empty() -> void:
	# THE CASE THAT MATTERS, and the one the contract-ordering test cannot cover:
	# delete the render and that test still passes while the screen goes back to
	# showing p.109 guidance with no reason.
	var ui := await _make_ui()
	assert_object(ui.setup_content).override_failure_message(
		"setup_content did not resolve — this probe would pass vacuously"
		).is_not_null()

	var cpm: Node = Engine.get_main_loop().root.get_node_or_null(
		"/root/CampaignPhaseManager")
	ui._add_terrain_summary_lines(cpm._blank_table_contract(3.0, {}))

	var text: String = _setup_tab_text(ui)
	assert_str(text).override_failure_message(
		"an empty player-defined table gave the player NO reason it is empty; "
		+ "rendered:\n%s" % text).contains("Terrain Generation is off")
	assert_str(text).override_failure_message(
		"the p.109 guidance must still be shown alongside the reason"
		).contains("p.109")


func test_a_generated_table_does_not_repeat_its_theme_name() -> void:
	# THE REGRESSION THE FIRST DRAFT WOULD HAVE SHIPPED. The generator's summary
	# line 0 is "Theme: <name>" and the Setup tab already prints the theme in amber
	# two lines above, so rendering line 0 unconditionally duplicates it. Only the
	# player-defined contract needs its line 0 surfaced.
	var ui := await _make_ui()
	var generated: Dictionary = {
		"summary": "Theme: Industrial Zone\nRusting stacks and spoil heaps.",
		# no player_defined_terrain key at all — the generator does not write one
	}
	ui._add_terrain_summary_lines(generated)

	var text: String = _setup_tab_text(ui)
	assert_str(text).override_failure_message(
		"the generator's 'Theme:' line was echoed under the theme name already "
		+ "shown above it; rendered:\n%s" % text).not_contains("Theme: Industrial Zone")
	assert_str(text).override_failure_message(
		"the Compendium theme description must still render for a generated table"
		).contains("Rusting stacks")
