extends GdUnitTestSuite
## Core Rules appendices II, IV, VI and VIII, plus the two multiplayer chapters.
## Sep 2026 page walk.
##
## THE GAP THIS PINS. These are not dead implementations — there was NO code at
## all. Appendix II (Playing on a Grid, p.147), Appendix IV (Problem Solving,
## p.152) and Appendix VIII (Neutral Characters, pp.172-173) had zero presence
## anywhere in the repository: no data file, no resolver, no reference text. They
## are in the BASE book, so every player already owns them.
##
## Appendix VI (Cooperative Play, p.161) was likewise absent, and the Compendium
## PvP (pp.35-38) and Expanded Co-op (pp.39-41) chapters had complete rules data
## with ZERO CALLERS — the two chapters docs/COMPENDIUM_CHAPTER_TRACE_2026-08.md
## still records as DEAD. A player who bought the Freelancer's Handbook could not
## read the chapters they paid for. Delivered as reference text by user decision
## (Sep 3 2026): both need a second player this app has no surface for.
##
## One ordering trap worth stating, because it is easy to "fix" wrongly:
## Appendix II says moving one space uses ONE INCH. The Compendium's separate
## grid chapter (pp.90-93) has no inch-to-square conversion at all, and the
## fabricated "1 square = 2 inches" this panel used to print for THAT chapter is
## not this appendix either. Two different grids, one of them with a rule.
##
## gdUnit4 v6.0.3 compatible.

const Sections = preload("res://src/ui/components/battle/CheatSheetSections.gd")
const ProblemSolving = preload("res://src/core/battle/ProblemSolvingTests.gd")

const NEUTRAL_PATH := "res://data/RulesReference/NeutralCharacters.json"
const PANEL_SRC := "res://src/ui/components/battle/CheatSheetPanel.gd"
const QUICK_ROLL_SRC := "res://src/ui/components/battle/CharacterQuickRollPanel.gd"

## Core Rules pp.172-173, in book order.
const NEUTRAL_NAMES := [
	"Bystander", "Street punk", "Gangster", "Corporate slick",
	"Hardened shopkeep", "Hardened colonist", "Service Bot", "Scientist",
	"Technician", "Dock worker", "Security guard", "Enforcer",
]


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot read %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


func _neutral_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(_read(NEUTRAL_PATH))
	assert_bool(parsed is Dictionary).is_true()
	return (parsed as Dictionary).get("NeutralCharacters", {})


# ── Appendix VIII: Neutral Characters (pp.172-173) ───────────────────────

func test_all_twelve_neutral_profiles_are_present() -> void:
	var profiles: Array = _neutral_data().get("profiles", [])
	assert_int(profiles.size()).override_failure_message(
		"Appendix VIII prints twelve profiles, found %d" % profiles.size()
	).is_equal(12)
	var names: Array = []
	for profile in profiles:
		names.append(str(profile.get("name", "")))
	for wanted in NEUTRAL_NAMES:
		assert_bool(wanted in names).override_failure_message(
			"'%s' is missing from the Neutral Characters data" % wanted).is_true()


func test_the_enforcer_profile_matches_the_book() -> void:
	# The one profile with a non-zero Combat Skill, so it is the clearest proof
	# the stat columns were read in the right order rather than transposed.
	# p.173: Enforcer — Reactions 2, Speed 5", Combat Skill +1, Toughness 4,
	# Savvy +0, "Half with Shotguns, half with Handguns."
	var found: Dictionary = {}
	for profile in _neutral_data().get("profiles", []):
		if str(profile.get("name", "")) == "Enforcer":
			found = profile
	assert_dict(found).is_not_empty()
	assert_int(int(found.get("reactions", 0))).is_equal(2)
	assert_int(int(found.get("speed", 0))).is_equal(5)
	assert_int(int(found.get("combat_skill", -1))).is_equal(1)
	assert_int(int(found.get("toughness", 0))).is_equal(4)
	assert_int(int(found.get("savvy", -1))).is_equal(0)
	assert_str(str(found.get("weapon", ""))).contains("Shotguns")


func test_the_service_bot_keeps_its_conditional_savvy() -> void:
	# p.172 prints "+0 / +2" in one column: "+2 Savvy when performing a task it
	# was built for." A flat +2 would make every Service Bot the crew's best
	# technician; a flat +0 would drop the rule. It is stored as a NOTE.
	var found: Dictionary = {}
	for profile in _neutral_data().get("profiles", []):
		if str(profile.get("id", "")) == "service_bot":
			found = profile
	assert_dict(found).is_not_empty()
	assert_int(int(found.get("savvy", -1))).is_equal(0)
	assert_str(str(found.get("savvy_note", ""))).override_failure_message(
		"the conditional +2 Savvy was flattened into the stat or dropped"
	).contains("+2")


func test_the_request_for_help_rule_is_recorded() -> void:
	var data: Dictionary = _neutral_data()
	var roll: Dictionary = data.get("help_roll", {})
	assert_int(int(roll.get("target", 0))).is_equal(5)
	assert_str(str(roll.get("add_stat", ""))).is_equal("savvy")
	assert_int(int(roll.get("gm_modifier", 0))).is_equal(1)
	assert_str(str(data.get("phase_rule", ""))).override_failure_message(
		"the Neutral phase placement is part of the appendix and changes the"
		+ " round sequence"
	).contains("after the Slow phase")


func test_the_neutral_section_renders_from_the_data() -> void:
	var text: String = Sections.neutral_characters()
	assert_str(text).is_not_empty()
	for wanted in NEUTRAL_NAMES:
		assert_str(text).override_failure_message(
			"'%s' did not reach the reference drawer" % wanted).contains(wanted)


# ── Appendix IV: Problem Solving (p.152) ─────────────────────────────────

func test_the_quick_test_targets_are_the_book_numbers() -> void:
	# p.152: "An Easy test is passed on a roll of 3+ while a Hard test is passed
	# on a roll of 5+."
	assert_int(ProblemSolving.EASY_TARGET).is_equal(3)
	assert_int(ProblemSolving.HARD_TARGET).is_equal(5)
	var easy_pass: Dictionary = ProblemSolving.quick_test(false, false, func(): return 3)
	assert_bool(bool(easy_pass.get("passed", false))).is_true()
	var hard_fail: Dictionary = ProblemSolving.quick_test(true, false, func(): return 3)
	assert_bool(bool(hard_fail.get("passed", true))).override_failure_message(
		"a 3 must fail a Hard test"
	).is_false()


func test_an_opposed_draw_is_unresolved_not_a_pass() -> void:
	# p.152: "On a draw, the action is unresolved this round." Treating a draw as
	# success would quietly hand the player every contested door.
	var draw: Dictionary = ProblemSolving.opposed_test(
		false, func(): return 4, func(): return 4)
	assert_bool(bool(draw.get("draw", false))).is_true()
	assert_bool(bool(draw.get("passed", true))).is_false()
	assert_str(str(draw.get("winner", "x"))).is_empty()


func test_a_wits_test_adds_savvy_against_the_challenge_rating() -> void:
	# p.152: "Set a Challenge Rating from 2 to 7. Roll 1D6 and add the Savvy score
	# of the character. If the result is equal or better, the test is passed."
	var pass_case: Dictionary = ProblemSolving.wits_test(5, 2, false, 0, func(): return 3)
	assert_int(int(pass_case.get("total", 0))).is_equal(5)
	assert_bool(bool(pass_case.get("passed", false))).override_failure_message(
		"equal to the rating passes"
	).is_true()
	var fail_case: Dictionary = ProblemSolving.wits_test(7, 0, false, 0, func(): return 6)
	assert_bool(bool(fail_case.get("passed", true))).override_failure_message(
		"a rating of 7 cannot be passed at +0 Savvy — the book says so"
	).is_false()


func test_the_challenge_rating_is_clamped_to_the_books_range() -> void:
	var low: Dictionary = ProblemSolving.wits_test(-4, 0, false, 0, func(): return 2)
	assert_int(int(low.get("target", 0))).is_equal(ProblemSolving.WITS_RATING_MIN)
	var high: Dictionary = ProblemSolving.wits_test(99, 0, false, 0, func(): return 2)
	assert_int(int(high.get("target", 0))).is_equal(ProblemSolving.WITS_RATING_MAX)


func test_a_natural_one_stuns_before_modifiers() -> void:
	# p.152: "Rolling a 1 on the die for any Problem Solving tests above (BEFORE
	# MODIFIERS) Stuns the character." So a big Savvy bonus does not rescue the
	# figure from the fumble even when it carries the total over the rating.
	var fumble: Dictionary = ProblemSolving.wits_test(2, 5, false, 0, func(): return 1)
	assert_bool(bool(fumble.get("passed", false))).override_failure_message(
		"1 + Savvy 5 = 6 beats a Challenge of 2, so the test still PASSES"
	).is_true()
	assert_bool(bool(fumble.get("stunned", false))).override_failure_message(
		"the natural 1 must still Stun — the fumble is checked before modifiers"
	).is_true()


func test_only_a_risky_test_adds_the_damage_hit() -> void:
	# p.152: "If you deem a given test to be inherently Risky, rolling a 1
	# inflicts a Damage +0 Hit as well." Applying it always would be harsher than
	# the book.
	var safe: Dictionary = ProblemSolving.quick_test(false, false, func(): return 1)
	assert_bool(bool(safe.get("stunned", false))).is_true()
	assert_bool(bool(safe.get("damage_hit", true))).is_false()
	var risky: Dictionary = ProblemSolving.quick_test(false, true, func(): return 1)
	assert_bool(bool(risky.get("damage_hit", false))).is_true()


func test_the_neutral_help_roll_is_a_wits_test_at_five() -> void:
	# Appendix VIII p.172 resolves through Appendix IV: "a 1D6+Savvy roll of 5+".
	var result: Dictionary = ProblemSolving.request_neutral_help(1, 0, func(): return 4)
	assert_int(int(result.get("target", 0))).is_equal(5)
	assert_bool(bool(result.get("passed", false))).is_true()
	assert_bool(bool(result.get("wants_to_join", true))).is_false()


func test_a_natural_six_makes_the_neutral_ask_to_join() -> void:
	# p.172: "A natural 6 means the NC is so enamored with adventuring life that
	# they will request to join your crew permanently as a PC."
	var result: Dictionary = ProblemSolving.request_neutral_help(0, 0, func(): return 6)
	assert_bool(bool(result.get("wants_to_join", false))).override_failure_message(
		"the natural-6 recruitment clause did not fire"
	).is_true()


func test_the_gm_modifier_is_capped_at_one_either_way() -> void:
	# p.172: "The GM can apply a +/-1 modifier based on circumstances."
	var result: Dictionary = ProblemSolving.request_neutral_help(0, 5, func(): return 3)
	assert_int(int(result.get("modifier", 0))).override_failure_message(
		"the help roll accepted a modifier larger than the book's +/-1"
	).is_equal(1)


func test_the_battle_panel_offers_the_test_roll() -> void:
	# A resolver with no caller is the defect shape this whole sprint is about.
	var src: String = _read(QUICK_ROLL_SRC)
	assert_str(src).contains("RollType.TEST")
	assert_str(src).override_failure_message(
		"the Problem Solving tests have no entry point in the battle UI"
	).contains('_roll_type_option.add_item("Problem Solving", RollType.TEST)')
	assert_str(src).contains("func _execute_problem_solving_roll()")


# ── Appendix II: Playing on a Grid (p.147) ───────────────────────────────

func test_the_grid_appendix_states_one_space_is_one_inch() -> void:
	# p.147: "moving one space on the board is assumed to use 1" of movement.
	# Hence a character with a movement speed of 5" could move 5 spaces."
	#
	# ⚠ NOT the Compendium's grid chapter. The fabricated "1 square = 2 inches"
	# CheatSheetPanel used to print belonged to pp.90-93, which has no conversion
	# at all. Two different grids; only this one carries a rule.
	var text: String = Sections.playing_on_a_grid()
	assert_str(text).is_not_empty()
	assert_str(text).contains("1\" of movement")
	assert_bool(text.contains("1 square = 2")).override_failure_message(
		"the fabricated 2-inch conversion leaked into the Appendix II text"
	).is_false()


func test_the_grid_appendix_keeps_the_diagonal_rule() -> void:
	# p.147: "No difference is made between orthogonal and diagonal moves: Each
	# move is simply counted as 1"." A diagonal costing more is the commonest
	# house rule, and the book explicitly does not use it.
	assert_str(Sections.playing_on_a_grid()).contains("diagonal")


# ── Appendix VI and the two multiplayer chapters ─────────────────────────

func test_cooperative_play_is_available_without_any_dlc() -> void:
	# Appendix VI is in the BASE book, so it must not be gated.
	var text: String = Sections.cooperative_play()
	assert_str(text).is_not_empty()
	assert_str(text).contains("Reaction Roll")


func test_the_gm_appendix_reaches_the_player_as_reference() -> void:
	# Appendix VII (pp.162-171) is REFERENCE ONLY on purpose: Plot Points, Mass
	# Battle and War Exhaustion are campaign subsystems in their own right, and
	# building them is net-new scope rather than a gap-close. What was missing was
	# the TEXT — the appendix had no code presence at all, and the book itself
	# says a solo player can use the chapter (p.162).
	var text: String = Sections.game_mastering_tools()
	assert_str(text).is_not_empty()
	# p.163 Plot Points: "roll 4D6 and advance the plot one point for every 6".
	assert_str(text).contains("4D6")
	# p.164 Bystanders: firing on them earns an Enforcer Rival, which is the one
	# clause here with a real campaign consequence.
	assert_str(text).contains("Enforcer Rival")
	# p.168 Turrets carry a specific profile a player has to run.
	assert_str(text).contains("Toughness 4")


func test_the_panel_registers_the_core_appendices() -> void:
	var src: String = _read(PANEL_SRC)
	for call_name in ["problem_solving()", "playing_on_a_grid()",
			"neutral_characters()", "cooperative_play()",
			"game_mastering_tools()"]:
		assert_str(src).override_failure_message(
			"CheatSheetSections.%s never reaches the reference drawer" % call_name
		).contains(call_name)


func test_pvp_and_coop_have_their_first_callers() -> void:
	# Both chapters' rules data has been complete since it was written and had
	# ZERO callers repo-wide — the reason the chapter trace lists them as DEAD.
	var src: String = _read("res://src/ui/components/battle/CheatSheetSections.gd")
	assert_str(src).contains("MissionsExpandedRef.get_pvp_setup()")
	assert_str(src).contains("MissionsExpandedRef.get_coop_rules(")
	var panel: String = _read(PANEL_SRC)
	assert_str(panel).contains("CheatSheetSectionsRef.pvp_battles()")
	assert_str(panel).contains("CheatSheetSectionsRef.coop_battles()")


func test_a_gated_section_has_a_toggle_the_player_can_reach() -> void:
	# ⚠ THE TRAP THIS CATCHES, found while auditing this very sprint.
	#
	# `DLCContentCatalog.UNIMPLEMENTED_FLAGS` HIDES a flag's toggle: both
	# ExpansionFeatureSection and DLCManagementDialog `continue` past a listed
	# flag, and owning the pack does not help because
	# `DLCManager.is_feature_enabled()` requires `_enabled_flags[flag]`, which
	# only `set_feature_enabled()` writes. So a listed flag is permanently OFF.
	#
	# The PvP and Co-op reference sections gate on exactly those flags. Had they
	# stayed listed, the sections would have been UNREACHABLE — a consumer whose
	# gate cannot be opened, which is the defect shape this whole sweep is about,
	# manufactured fresh.
	# DERIVED from the panel, not hardcoded. A hardcoded list would pass forever
	# while a NEW gated section quietly picked an unreachable flag — which is
	# precisely how this defect got in.
	var panel_src: String = _read(
		"res://src/ui/components/battle/CheatSheetPanel.gd")
	var gated: Array[String] = []
	for m in RegEx.create_from_string("ContentFlag[.]([A-Z_]+)").search_all(panel_src):
		var flag_name: String = m.get_string(1)
		if not gated.has(flag_name):
			gated.append(flag_name)
	assert_int(gated.size()).override_failure_message(
		"no ContentFlag gates found in CheatSheetPanel — the scan is broken, so"
		+ " this test would pass vacuously"
	).is_greater(5)
	var catalog = load("res://src/ui/screens/store/DLCContentCatalog.gd")
	for flag_name in gated:
		assert_bool(catalog.is_flag_unimplemented(flag_name)).override_failure_message(
			"CheatSheetPanel gates a section on '%s', but that flag is on" % flag_name
			+ " UNIMPLEMENTED_FLAGS, which hides its toggle everywhere — so the"
			+ " section can never be switched on"
		).is_false()


func test_the_multiplayer_sections_stay_gated() -> void:
	# They are Compendium content. A player without the pack must see nothing —
	# the builders return "" and the panel drops the empty section.
	var dlc: Node = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")
	if dlc == null:
		return
	var saved_pvp: bool = dlc.is_feature_enabled(dlc.ContentFlag.get("PVP_BATTLES"))
	var saved_coop: bool = dlc.is_feature_enabled(dlc.ContentFlag.get("COOP_BATTLES"))
	dlc.set_feature_enabled(dlc.ContentFlag.get("PVP_BATTLES"), false)
	dlc.set_feature_enabled(dlc.ContentFlag.get("COOP_BATTLES"), false)
	assert_str(Sections.pvp_battles()).is_empty()
	assert_str(Sections.coop_battles()).is_empty()
	dlc.set_feature_enabled(dlc.ContentFlag.get("PVP_BATTLES"), saved_pvp)
	dlc.set_feature_enabled(dlc.ContentFlag.get("COOP_BATTLES"), saved_coop)
