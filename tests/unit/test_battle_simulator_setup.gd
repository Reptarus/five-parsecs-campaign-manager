extends GdUnitTestSuite
## Battle Simulator: the battle the setup screen shows is a Core Rules battle, it is
## the battle that launches, and the results screen can show how it ended.
##
## Sprint U, 2026-10-29. Each case pins one defect found by rendering the screens:
##   SIM-1  the results card was blank on every return path (int into an Array var)
##   SIM-2  enemy numbers were a flat 5 + an invented difficulty bonus, not p.63
##   SIM-3  the crew had random stats in neither book; crew size allowed 3 (p.63: 4-6)
##   SIM-4  "Hard (+1 enemy)" / "Brutal (+2 enemies)" are not Core Rules modes
##   SIM-5  no p.88 Deployment Condition, p.89 Notable Sight or objective was rolled
##   SIM-6  no Seize the Initiative context: Hardcore -2 / Insanity -3 never applied
##   SIM-7  the preview was a throwaway roll; Launch rolled a SECOND battle
##   SIM-8  a standalone force read the auto-loaded campaign's settings (T11-49 shape)
##   SIM-9  after a battle the screen lost its centring and its Settings-band margin
##
## No case launches TacticalBattleUI, and nothing here saves; the guard is belt and
## braces because the screen suites around this one do persist.

const SetupScript := preload("res://src/core/battle/BattleSimulatorSetup.gd")
const EnemyGeneratorScript := preload("res://src/core/systems/EnemyGenerator.gd")
const SeizeScript := preload("res://src/core/battle/SeizeInitiativeSystem.gd")
const ResultsPanelScript := preload(
	"res://src/ui/screens/battle_simulator/panels/BattleSimulatorResultsPanel.gd")
const SetupPanelScript := preload(
	"res://src/ui/screens/battle_simulator/panels/BattleSimulatorSetupPanel.gd")
const ScreenScene := preload("res://src/ui/screens/battle_simulator/BattleSimulatorUI.tscn")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")


class StubCampaign extends Resource:
	var progress_data: Dictionary = {}


var _guard_snap: Dictionary = {}
var _prior_campaign = null
var _prior_progressive: bool = false


func before_test() -> void:
	_guard_snap = SaveDirGuard.snapshot()
	_prior_campaign = GameState.current_campaign
	_prior_progressive = DLCManager.is_feature_enabled(
		DLCManager.ContentFlag.PROGRESSIVE_DIFFICULTY)
	DiceManager.clear_forced_results()


func after_test() -> void:
	GameState.current_campaign = _prior_campaign
	# One flag, restored as found. Never set_dlc_owned(false): that switches off every
	# flag of the pack, real entitlements included.
	DLCManager.set_feature_enabled(
		DLCManager.ContentFlag.PROGRESSIVE_DIFFICULTY, _prior_progressive)
	DiceManager.clear_forced_results()
	SaveDirGuard.restore(_guard_snap)


func _dice() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DiceManager")


# --- SIM-1 --------------------------------------------------------------------

## The four emit shapes TacticalBattleUI produces (Record Result form, played end,
## auto-resolve, evacuation). Every one carries the casualty COUNT as an int.
func _emit_shapes() -> Array:
	return [
		{"victory": true, "won": true, "held_field": true, "rounds_fought": 5,
			"crew_casualties": 1, "crew_injuries": 2,
			"crew_casualties_data": [{"name": "A"}],
			"crew_injuries_data": [{"name": "B"}, {"name": "C"}],
			"enemies_defeated_count": 6, "objective_id": "FIGHT_OFF", "objective_met": true},
		{"victory": false, "won": false, "held_field": false, "rounds_fought": 3,
			"crew_casualties": 2, "crew_injuries": 0, "auto_resolved": true,
			"crew_casualties_data": [{}, {}], "crew_injuries_data": []},
		{"victory": false, "held_field": false, "rounds_fought": 2,
			"crew_casualties": 0, "crew_injuries": 1, "crew_injuries_data": [{}]},
		{"victory": false, "held_field": true, "rounds_fought": 6,
			"crew_casualties": 3, "crew_injuries": 0,
			"objective_id": "SEARCH", "objective_met": false},
	]


func test_the_results_card_shows_every_return_shape() -> void:
	var panel: Control = auto_free(ResultsPanelScript.new())
	add_child(panel)
	var expected_titles := ["VICTORY", "DEFEAT", "DEFEAT", "HELD THE FIELD"]
	var expected_casualties := [1, 2, 0, 3]
	var shapes: Array = _emit_shapes()
	for i in range(shapes.size()):
		(panel.get("_title_label") as Label).text = ""
		panel.show_results(shapes[i])
		var title: String = (panel.get("_title_label") as Label).text
		assert_str(title).override_failure_message(
			"shape %d left the results title blank: show_results() aborted before it "
			% i + "wrote anything (an int casualty count assigned to an Array var)"
		).is_equal(expected_titles[i])
		assert_int(int(ResultsPanelScript.summarize(shapes[i])["casualties"])).is_equal(
			expected_casualties[i])
		var stats: String = (panel.get("_stats_label") as RichTextLabel).get_parsed_text()
		assert_str(stats).contains("Casualties: %d" % expected_casualties[i])
	# p.90: the card reports the objective, which a won fight can still miss.
	panel.show_results(shapes[0])
	assert_str((panel.get("_stats_label") as RichTextLabel).get_parsed_text()).contains(
		"Objective (Fight Off): achieved")
	panel.show_results(shapes[3])
	assert_str((panel.get("_stats_label") as RichTextLabel).get_parsed_text()).contains(
		"Objective (Search): not achieved")


# --- SIM-2 / SIM-3 / SIM-4 ------------------------------------------------------

func test_crew_is_the_p15_baseline_and_sized_4_to_6() -> void:
	var setup = SetupScript.new()
	for asked in [3, 7]:
		var ctx: Dictionary = setup.generate_battle_context(
			{"crew_size": asked, "mission_type": "OPPORTUNITY"})
		var expected: int = 4 if asked < 4 else 6
		assert_int(int(ctx["crew_size"])).override_failure_message(
			"crew size %d is not a p.63 size; it must clamp to %d" % [asked, expected]
		).is_equal(expected)
	var ctx2: Dictionary = setup.generate_battle_context({"crew_size": 6})
	var crew: Array = ctx2["crew"]
	for member: Dictionary in crew:
		for stat in SetupScript.BASELINE_HUMAN:
			assert_int(int(member.get(stat, -99))).override_failure_message(
				"%s's %s is %s; p.15 Baseline Human is %s" % [member.get("name"), stat,
				member.get(stat), SetupScript.BASELINE_HUMAN[stat]]
			).is_equal(int(SetupScript.BASELINE_HUMAN[stat]))
	# p.28: one weapon per crew member, from the starting tables, every time.
	for member: Dictionary in crew:
		assert_str(str(member.get("weapon_name", ""))).override_failure_message(
			"%s was issued no p.28 starting weapon" % member.get("name")).is_not_empty()


func test_only_the_five_book_difficulty_modes_are_accepted() -> void:
	for mode in [1, 2, 4, 6, 8]:
		assert_int(SetupScript.normalize_difficulty_mode(mode)).is_equal(mode)
	# 3, 5 and 7 are the deprecated HARD / NIGHTMARE / ELITE aliases; 0 and 9 are not
	# modes. The old 1-5 scale sent 3 for "Challenging" and 5 for "Brutal".
	for mode in [0, 3, 5, 7, 9]:
		assert_int(SetupScript.normalize_difficulty_mode(mode)).is_equal(2)


func test_enemy_numbers_come_from_the_crew_size_dice() -> void:
	## Old code: exactly 5 + numbers + a difficulty bonus, every time, identical clones.
	## p.63 crew 4: 2D6 keep the LOWER, so the base varies and is usually under 5.
	## ⚠ Count the force BEFORE the p.88 condition adjusts it. Each battle also rolls a
	## Deployment Condition whose enemy_delta changes the size, so the raw count varies
	## even from a fixed force of 5 (measured: this case stayed green with the dice
	## reverted until the delta was taken out).
	var setup = SetupScript.new()
	var counts: Dictionary = {}
	for i in range(40):
		var ctx: Dictionary = setup.generate_battle_context({"crew_size": 4,
			"enemy_category": "criminal_elements", "enemy_type": "punks",
			"mission_type": "OPPORTUNITY", "difficulty_mode": 2})
		var delta: int = int(ctx["mission_data"].get("setup_rules", {}).get("enemy_delta", 0))
		counts[ctx["enemies"].size() - delta] = true
	assert_int(counts.size()).override_failure_message(
		"40 Simulator battles at crew 4 all fielded the same number of enemies %s: the "
		% str(counts.keys()) + "count is not being rolled on the p.63 crew-size dice"
	).is_greater(1)


# --- SIM-5 / SIM-6 ---------------------------------------------------------------

func test_the_battle_carries_its_p88_p89_rolls_and_their_consequences() -> void:
	var dm: Node = _dice()
	assert_object(dm).is_not_null()
	# Opportunity column of the p.88 table: 41-45 is Small Encounter, whose set-up
	# sits a random crew member out and reduces the opposition.
	dm.queue_forced_result("Deployment Condition", 43)
	var ctx: Dictionary = SetupScript.new().generate_battle_context({"crew_size": 6,
		"mission_type": "OPPORTUNITY", "difficulty_mode": 2})
	var md: Dictionary = ctx["mission_data"]
	var condition_id: String = str(md.get("deployment_condition", {}).get("condition_id", ""))
	assert_str(condition_id).override_failure_message(
		"the forced p.88 roll did not reach the Simulator's battle").is_equal("SMALL_ENCOUNTER")
	assert_bool(md.get("objective_details", {}).is_empty()).override_failure_message(
		"no p.89 objective was rolled").is_false()
	assert_bool(md.has("notable_sight")).override_failure_message(
		"no p.89 Notable Sight was rolled").is_true()
	assert_int((ctx["crew"] as Array).size()).override_failure_message(
		"Small Encounter (p.88) sits one crew member out; 6 still deploy").is_equal(5)
	assert_int((ctx["sitting_out"] as Array).size()).is_equal(1)
	assert_bool(md.get("standalone", false)).is_true()


func test_hardcore_carries_its_seize_the_initiative_penalty() -> void:
	var ctx: Dictionary = SetupScript.new().generate_battle_context({"crew_size": 6,
		"mission_type": "OPPORTUNITY", "difficulty_mode": 6})
	var init: Dictionary = ctx["mission_data"].get("initiative_context", {})
	assert_bool(init.is_empty()).override_failure_message(
		"no initiative_context: TacticalBattleUI's calculator rolls unmodified").is_false()
	assert_int(int(init.get("difficulty_index", -1))).is_equal(2)
	var found := false
	for m: Dictionary in init.get("modifiers", []):
		if int(m.get("value", 0)) == -2:
			found = true
	assert_bool(found).override_failure_message(
		"Hardcore's -2 (p.65) is not among the Seize modifiers: %s" % str(init.get("modifiers"))
	).is_true()


func test_one_initiative_builder_serves_the_campaign_too() -> void:
	## The campaign assembled this inline; it now calls the shared builder, so the two
	## cannot drift. Wiring, so asserted on the source.
	var src: String = FileAccess.get_file_as_string(
		"res://src/ui/screens/campaign/CampaignTurnController.gd")
	assert_bool(src.contains("SeizeInitiativeSystemClass.build_battle_context(")).is_true()
	var built: Dictionary = SeizeScript.build_battle_context(
		[{"savvy": 2}, {"savvy": 0}], 5, 8, -1, "Punks")
	assert_bool(bool(built["outnumbered"])).is_true()
	assert_int(int(built["difficulty_index"])).is_equal(3)
	assert_int(int(built["highest_savvy"])).is_equal(2)
	assert_int(int(built["enemy_modifier"])).is_equal(-1)


# --- SIM-7 -------------------------------------------------------------------------

func test_launch_sends_the_battle_the_preview_shows() -> void:
	var panel: Control = auto_free(SetupPanelScript.new())
	add_child(panel)
	await await_idle_frame()
	var shown: Dictionary = panel.get_context()
	var sent: Array = []
	panel.launch_requested.connect(func(ctx): sent.append(ctx))
	panel.call("_on_launch_pressed")
	assert_int(sent.size()).is_equal(1)
	var sent_battle: bool = sent[0] is Dictionary and (sent[0] as Dictionary).has("crew")
	assert_bool(sent_battle).override_failure_message(
		"Launch sent the SETTINGS, so the screen rolls a second battle").is_true()
	assert_str(str(sent[0]["mission_data"]["title"])).is_equal(str(shown["mission_data"]["title"]))
	assert_int((sent[0]["enemies"] as Array).size()).is_equal((shown["enemies"] as Array).size())
	var preview: String = (panel.get("_enemy_preview") as RichTextLabel).get_parsed_text()
	assert_str(preview).contains("%d ×" % (shown["enemies"] as Array).size())


# --- SIM-8 -------------------------------------------------------------------------

func test_a_standalone_force_reads_no_campaign_setting() -> void:
	## GameState auto-loads the last campaign at every launch. A campaign 50 turns
	## into Compendium p.30 Progressive Difficulty adds figures to ITS battles; it must
	## add none to a Simulator battle.
	var stub := StubCampaign.new()
	# Options 1 AND 2: Option 2 (p.31) is what unlocks strength_adjusted at turn 3, so
	# the toggle assertion below has something to withhold.
	stub.progress_data = {"progressive_difficulty_options": [1, 2], "turns_played": 50}
	GameState.current_campaign = stub
	# The p.31 unlock is behind the Progressive Difficulty flag (owned AND toggled).
	DLCManager.set_feature_enabled(DLCManager.ContentFlag.PROGRESSIVE_DIFFICULTY, true)
	var gen = EnemyGeneratorScript.new()
	assert_int(int(gen.call("_progressive_strength_bonus", {}))).override_failure_message(
		"premise: a campaign battle with this campaign loaded gets the p.30 bonus").is_greater(0)
	assert_bool(bool(gen.call("_campaign_toggle", "strength_adjusted"))).override_failure_message(
		"premise: this campaign's Option 2 has unlocked strength_adjusted").is_true()
	gen.set("_standalone", true)
	assert_int(int(gen.call("_progressive_strength_bonus", {}))).override_failure_message(
		"a standalone battle inherited the loaded campaign's Progressive Difficulty").is_equal(0)
	assert_bool(bool(gen.call("_campaign_toggle", "strength_adjusted"))).override_failure_message(
		"a standalone battle inherited the loaded campaign's p.31 toggle").is_false()
	# And generation itself sets the flag from the mission it is handed.
	gen.generate_enemies_as_dicts({"standalone": true, "mission_source": "opportunity"}, 4)
	assert_bool(bool(gen.get("_standalone"))).is_true()
	gen.generate_enemies_as_dicts({"mission_source": "opportunity"}, 4)
	assert_bool(bool(gen.get("_standalone"))).override_failure_message(
		"a campaign battle generated after a Simulator one stayed standalone").is_false()


# --- SIM-9 -------------------------------------------------------------------------

func test_returning_from_a_battle_restores_the_centred_column() -> void:
	var screen: Control = auto_free(ScreenScene.instantiate())
	add_child(screen)
	await await_idle_frame()
	await await_idle_frame()
	var margin: MarginContainer = screen.get("_content_margin")
	var before: int = margin.get_theme_constant("margin_left")
	assert_int(before).override_failure_message(
		"premise: the test viewport is wide enough for the 800 px column to be centred"
	).is_greater(20)
	screen.call("_set_margins", 0)  # what _show_battle() does
	screen.call("_restore_margins")
	assert_int(margin.get_theme_constant("margin_left")).override_failure_message(
		"after a battle the column is no longer centred (was %d)" % before).is_equal(before)


func test_a_rotation_mid_battle_leaves_the_battle_full_screen() -> void:
	## _apply_content_max_width() runs on every viewport resize. Without its battle
	## guard, rotating a tablet mid-battle re-centred the 800 px column around the
	## battle that _show_battle() had given the whole screen.
	var screen: Control = auto_free(ScreenScene.instantiate())
	add_child(screen)
	await await_idle_frame()
	var stand_in := Control.new()  # what _show_battle() puts in _battle_ui
	screen.add_child(stand_in)
	screen.set("_battle_ui", stand_in)
	screen.call("_set_margins", 0)
	screen.call("_apply_content_max_width")
	var margin: MarginContainer = screen.get("_content_margin")
	assert_int(margin.get_theme_constant("margin_left")).override_failure_message(
		"a resize mid-battle squeezed the battle into the centred column").is_equal(0)


func test_the_phone_title_never_breaks_mid_word() -> void:
	## 393x851 rendered "BATTLE / SIMULATO / R": a word-wrapped title in an HBox gets
	## only the width the Back button leaves. The header is a flow row now, so on a
	## narrow screen the title takes a line of its own, whole and inside the screen.
	var sv := SubViewport.new()
	sv.size = Vector2i(310, 551)
	add_child(sv)
	auto_free(sv)
	var screen: Control = ScreenScene.instantiate()
	sv.add_child(screen)
	await get_tree().create_timer(0.3).timeout
	for _i in range(3):
		await get_tree().process_frame
	var title: Label = null
	for child in (screen.get("_header") as Node).get_children():
		if child is Label:
			title = child
	assert_object(title).is_not_null()
	assert_int(title.get_line_count()).override_failure_message(
		"the title wrapped onto %d lines at 310 px" % title.get_line_count()).is_equal(1)
	var right: float = title.get_global_rect().end.x
	assert_float(right).override_failure_message(
		"the title runs %.1f px past the right edge of a 310 px screen" % (right - 310.0)
	).is_less_equal(310.5)
