extends GdUnitTestSuite
## Difficulty Toggles — Compendium pp.32-34.
##
## THE DEFECT THIS PINS. Two separate UIs have collected toggle selections since
## they were written — ExpandedConfigPanel into
## `local_campaign_config["difficulty_toggles"]` and the Settings
## DifficultyTogglesPanel into `user://difficulty_toggles.cfg` — and NOTHING in
## the game ever read a toggle id. All 12 options were switches wired to nothing.
##
## The creation panel's selection did not even leave the panel:
## `CampaignCreationCoordinator.update_campaign_config_state` is a whitelist and
## it did not name the key, so the array was dropped at the panel boundary. Same
## defect, same file, and the same fix as Progressive Difficulty before it.
##
## gdUnit4 v6.0.3 compatible.

const Toggles = preload("res://src/data/compendium_difficulty_toggles.gd")

const ENEMY_GEN_SRC := "res://src/core/systems/EnemyGenerator.gd"
const UPKEEP_SRC := "res://src/ui/screens/world/components/UpkeepPhaseComponent.gd"
const COORDINATOR_SRC := "res://src/ui/screens/campaign/CampaignCreationCoordinator.gd"
const FINALIZATION_SRC := "res://src/core/campaign/creation/CampaignFinalizationService.gd"
const INJURY_SRC := "res://src/core/campaign/phases/post_battle/InjuryProcessor.gd"
const BATTLE_UI_SRC := "res://src/ui/screens/battle/TacticalBattleUI.gd"
const ADV_CONST_SRC := "res://src/core/systems/CharacterAdvancementConstants.gd"
const ADV_SYS_SRC := "res://src/core/character/advancement/AdvancementSystem.gd"
const ADV_PANEL_SRC := "res://src/ui/screens/campaign/phases/AdvancementPhasePanel.gd"

## Every id printed on pp.32-34, as the data file spells them.
const ALL_TOGGLE_IDS := [
	"strength_adjusted", "slaves_to_stargrind_money",
	"slaves_to_stargrind_progression", "veteran", "actually_specialized",
	"armored_leaders", "better_leadership", "paying_by_hour",
	"movement_all_over", "fickle_scans", "starting_gutter", "reduced_lethality",
]

var _saved_flag: bool = false
var _saved_owned: bool = false


func _dlc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


func before_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	_saved_owned = dlc.has_dlc("freelancers_handbook")
	_saved_flag = dlc.is_feature_enabled(dlc.ContentFlag.get("DIFFICULTY_TOGGLES"))


func after_test() -> void:
	Toggles.clear_creation_toggles()
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("DIFFICULTY_TOGGLES"), _saved_flag)
	dlc.set_dlc_owned("freelancers_handbook", _saved_owned)


## Turn the option pack on and select `ids`. Uses the creation override, which
## is both the simplest deterministic activation and the path the wizard uses.
func _activate(ids: Array) -> bool:
	var dlc := _dlc()
	if dlc == null:
		return false
	dlc.set_dlc_owned("freelancers_handbook", true)
	dlc.set_feature_enabled(dlc.ContentFlag.get("DIFFICULTY_TOGGLES"), true)
	Toggles.set_creation_toggles(ids)
	return true


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


## Source with whole-line comments stripped — these files quote the dead
## identifiers they replaced in their docblocks, so a raw grep would read an
## explanation as a regression.
func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line in _src(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


# --- The data ---------------------------------------------------------------

func test_all_twelve_book_options_are_present() -> void:
	if not _activate([]):
		return
	var ids: Array = []
	for toggle in Toggles.get_difficulty_toggles():
		ids.append(str(toggle.get("id", "")))
	assert_array(ids).override_failure_message(
		"pp.32-34 print twelve options; the file has %s" % str(ids)
	).contains_exactly_in_any_order(ALL_TOGGLE_IDS)


# --- The resolver -----------------------------------------------------------

func test_nothing_is_active_when_the_option_pack_is_off() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	Toggles.set_creation_toggles(ALL_TOGGLE_IDS)
	dlc.set_feature_enabled(dlc.ContentFlag.get("DIFFICULTY_TOGGLES"), false)
	assert_array(Toggles.get_active_toggles()).override_failure_message(
		"an unowned/disabled option pack must report nothing active").is_empty()
	for id in ALL_TOGGLE_IDS:
		assert_bool(Toggles.is_toggle_active(id)).is_false()


func test_only_the_selected_options_are_active() -> void:
	if not _activate(["veteran", "fickle_scans"]):
		return
	assert_bool(Toggles.is_toggle_active("veteran")).is_true()
	assert_bool(Toggles.is_toggle_active("fickle_scans")).is_true()
	for id in ALL_TOGGLE_IDS:
		if id in ["veteran", "fickle_scans"]:
			continue
		assert_bool(Toggles.is_toggle_active(id)).override_failure_message(
			"%s was not selected but reports active" % id).is_false()


func test_the_creation_override_is_cleared_cleanly() -> void:
	# Left set, it would answer for every later read in the session — including a
	# DIFFERENT campaign loaded from disk afterwards.
	if not _activate(["starting_gutter"]):
		return
	assert_bool(Toggles.is_toggle_active("starting_gutter")).is_true()
	Toggles.clear_creation_toggles()
	assert_bool(Toggles.is_toggle_active("starting_gutter")).override_failure_message(
		"the wizard's override outlived creation"
	).is_false()


# --- p.32 Slower Progression ------------------------------------------------

func test_slower_progression_replaces_the_costs() -> void:
	# Core Rules p.123 -> Compendium p.32: Reactions 7->8, Combat 7->8,
	# Toughness 6->8; Speed, Savvy and Luck unchanged.
	if not _activate(["slaves_to_stargrind_progression"]):
		return
	assert_int(Toggles.progression_cost("reactions", 7)).is_equal(8)
	assert_int(Toggles.progression_cost("combat_skill", 7)).is_equal(8)
	assert_int(Toggles.progression_cost("toughness", 6)).is_equal(8)
	assert_int(Toggles.progression_cost("speed", 5)).is_equal(5)
	assert_int(Toggles.progression_cost("savvy", 5)).is_equal(5)
	assert_int(Toggles.progression_cost("luck", 10)).is_equal(10)


func test_slower_progression_lowers_three_maximums() -> void:
	# Reactions 6->4, Combat +5->+3, Toughness 6->5.
	if not _activate(["slaves_to_stargrind_progression"]):
		return
	assert_int(Toggles.progression_maximum("reactions", 6)).is_equal(4)
	assert_int(Toggles.progression_maximum("combat_skill", 5)).is_equal(3)
	assert_int(Toggles.progression_maximum("toughness", 6)).is_equal(5)
	assert_int(Toggles.progression_maximum("speed", 8)).is_equal(8)
	assert_int(Toggles.progression_maximum("savvy", 5)).is_equal(5)


func test_slower_progression_never_raises_a_maximum() -> void:
	# THE SUBTLE ONE. The Compendium prints a bare "3" for Luck where the Core
	# Rules print "1 (3 Human)". Read as a flat 3, this option would hand every
	# NON-Human species a Luck cap of 3 — in a chapter whose whole purpose is to
	# make the game harder. Humans-only-above-1 is a SPECIES rule (Core Rules
	# p.12), not part of either upgrade table, so the maximum may only ever be
	# clamped DOWN.
	if not _activate(["slaves_to_stargrind_progression"]):
		return
	assert_int(Toggles.progression_maximum("luck", 1)).override_failure_message(
		"Slower Progression raised a non-Human Luck cap from 1 to 3"
	).is_equal(1)
	assert_int(Toggles.progression_maximum("luck", 3)).is_equal(3)
	# And an Engineer's p.124 Toughness cap of 4 must survive.
	assert_int(Toggles.progression_maximum("toughness", 4)).is_equal(4)


func test_progression_is_untouched_when_the_option_is_off() -> void:
	if not _activate([]):
		return
	assert_int(Toggles.progression_cost("reactions", 7)).is_equal(7)
	assert_int(Toggles.progression_maximum("reactions", 6)).is_equal(6)


# --- p.32 Money is Tight ----------------------------------------------------

func test_credit_dice_lose_one_with_a_floor_of_one() -> void:
	# "Whenever you would roll 1D6 for credits, roll 1D6-1 instead (minimum
	# score 1)."
	if not _activate(["slaves_to_stargrind_money"]):
		return
	var seen := {}
	for _i in range(600):
		var roll: int = Toggles.roll_credit_die()
		assert_int(roll).override_failure_message(
			"1D6-1 with a floor of 1 must land in 1..5, got %d" % roll
		).is_between(1, 5)
		seen[roll] = true
	assert_int(seen.size()).override_failure_message(
		"only ever rolled %s" % str(seen.keys())).is_greater(3)


func test_credit_dice_are_a_plain_d6_when_the_option_is_off() -> void:
	if not _activate([]):
		return
	var saw_six: bool = false
	for _i in range(300):
		var roll: int = Toggles.roll_credit_die()
		assert_int(roll).is_between(1, 6)
		if roll == 6:
			saw_six = true
	assert_bool(saw_six).override_failure_message(
		"a plain 1D6 never rolled a 6 in 300 tries").is_true()


func test_find_a_patron_and_repair_your_kit_cost_a_credit() -> void:
	# "Taking Find a Patron or Repair Your Kit actions costs 1 credit."
	if not _activate(["slaves_to_stargrind_money"]):
		return
	assert_int(Toggles.crew_task_surcharge("find_patron")).is_equal(1)
	assert_int(Toggles.crew_task_surcharge("repair_kit")).is_equal(1)
	assert_int(Toggles.crew_task_surcharge("explore")).override_failure_message(
		"only the two named actions are charged").is_equal(0)
	assert_int(Toggles.crew_task_surcharge("trade")).is_equal(0)


func test_the_free_hull_point_repair_is_denied() -> void:
	# "You do not receive 1 point of free Hull Point repair each turn."
	if not _activate(["slaves_to_stargrind_money"]):
		return
	assert_bool(Toggles.free_hull_repair_denied()).is_true()
	Toggles.set_creation_toggles([])
	assert_bool(Toggles.free_hull_repair_denied()).is_false()


# --- The wiring -------------------------------------------------------------
#
# Each of these greps a site where the rule cannot be exercised without standing
# up a whole subsystem. They are anti-regressions on the CALL, not on the maths —
# the maths is asserted above.

func test_strength_adjusted_replaces_the_enemy_count_roll() -> void:
	# p.32: "Instead of rolling for the number encountered, always assume the
	# enemy rolled equal to the number of crew you brought to the fight."
	var src: String = _code_only(ENEMY_GEN_SRC)
	assert_str(src).contains('is_toggle_active("strength_adjusted")')
	assert_str(src).override_failure_message(
		"the crew-brought count no longer replaces the p.63 dice"
	).contains("crew_in_field if crew_in_field > 0 else crew_size")


func test_the_three_hit_me_harder_figure_options_reach_the_squad_loop() -> void:
	var src: String = _code_only(ENEMY_GEN_SRC)
	for id in ["veteran", "actually_specialized", "armored_leaders"]:
		assert_str(src).override_failure_message(
			"%s is no longer read where the squad is built" % id
		).contains('is_toggle_active("%s")' % id)
	# "Enemy specialist figures have a minimum Combat Skill of +1 and Toughness
	# 4" — a floor, so maxi, never an assignment.
	assert_str(src).contains("figure_tough = maxi(figure_tough, 4)")


func test_better_leadership_drops_the_unique_threshold_to_seven() -> void:
	# "The base roll to face a Unique Individual is 7+, not 9+."
	var src: String = _code_only(ENEMY_GEN_SRC)
	assert_str(src).contains('is_toggle_active("better_leadership")')
	assert_str(src).override_failure_message(
		"the 7+/9+ threshold is no longer selected by the option"
	).contains("var threshold: int = 7 if better_leadership else 9")
	# Second bullet: an enemy type that cannot have a Unique Individual still
	# rolls, and on a success promotes one of its own figures instead.
	assert_str(src).contains("_pending_leadership_promotion")


func test_money_is_tight_replaces_the_upkeep_scale() -> void:
	# "Upkeep costs change to 0 credits for a single crew, 1 credit for a crew
	# of 2-4 figures, and +1 credit for each crew member past 4."
	var src: String = _code_only(UPKEEP_SRC)
	assert_str(src).contains('is_toggle_active("slaves_to_stargrind_money")')
	assert_str(src).override_failure_message(
		"the p.32 upkeep scale is gone — the Core Rules p.76 one is not a "
		+ "substitute, its threshold and cap are different numbers"
	).contains("results.crew_upkeep = 1 + max(0, effective_crew_size - 4)")


func test_all_three_advancement_cost_copies_route_through_the_option() -> void:
	# There are THREE parallel copies of the advancement numbers in this
	# codebase. A difficulty option applied to two of them reads as implemented
	# and silently does not apply on whichever screen the player happens to use.
	for path in [ADV_CONST_SRC, ADV_SYS_SRC, ADV_PANEL_SRC]:
		assert_str(_code_only(path)).override_failure_message(
			"%s no longer applies Slower Progression" % path
		).contains("CompendiumTogglesRef.progression_cost(")


func test_the_time_pressure_options_resolve_at_end_of_round() -> void:
	var src: String = _code_only(BATTLE_UI_SRC)
	for fn in ["_check_movement_all_over", "_check_fickle_scans",
			"_check_paying_by_the_hour", "_roll_paying_by_the_hour_limit"]:
		assert_str(src).override_failure_message(
			"%s is gone — the p.34 option it carries cannot fire" % fn
		).contains("func %s" % fn)
	# "roll two D6, pick the highest die and add 4 (for a final total of 5-10)"
	assert_str(src).contains("_paying_by_hour_limit = maxi(a, b) + 4")


func test_reduced_lethality_exempts_before_the_rolls() -> void:
	# p.34: "BEFORE rolling for post-battle injuries [...] you may select one to
	# be exempt from rolling." Offering it after the rolls were visible would
	# make the option strictly stronger than the book's, so the exemption is
	# chosen on the results form and read here.
	var src: String = _code_only(INJURY_SRC)
	assert_str(src).contains('is_toggle_active("reduced_lethality")')
	assert_str(src).contains("reduced_lethality_exempt_crew_id")
	assert_str(src).override_failure_message(
		"the book requires two or more injured before an exemption is offered"
	).contains("ctx.injuries_sustained.size() >= 2")


func test_the_selection_survives_the_coordinator_whitelist() -> void:
	# THE ORIGINAL DEFECT. update_campaign_config_state is a whitelist; the key
	# was not named, so the array was dropped at the panel boundary and every
	# toggle downstream was unreachable no matter how it was wired.
	assert_str(_code_only(COORDINATOR_SRC)).override_failure_message(
		"difficulty_toggles is being dropped at the coordinator again"
	).contains('campaign_config_data.has("difficulty_toggles")')
	assert_str(_code_only(FINALIZATION_SRC)).override_failure_message(
		"the toggles never reach campaign.progress_data"
	).contains('campaign.progress_data["difficulty_toggles"]')
