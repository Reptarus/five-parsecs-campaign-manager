extends GdUnitTestSuite
## Every rules die reaches DiceManager, so it lands in the roll history and a QA
## tester can force it.
##
## Measured on 2026-10-29 before the fix: 18 helpers probed the DiceManager autoload
## with has_method("roll_dice"). DiceManager has roll_d6 / roll_d10 / roll_d100 and no
## roll_dice, so every probe was permanently false and the roll fell to a raw randi:
## the Quest Progression D100 (Compendium p.79), the Story Clock and Evidence D6s,
## the Story Marker searches, the Travel Event D100 (Core Rules pp.70-71), Lay Low
## (errata v1.06), the Rainy Day Fund (p.67), the battle screen's dice roller and its
## quick dice bar. lint_dead_has_method_guards cannot see this: it asks whether a
## method exists ANYWHERE, and roll_dice exists on DiceSystem and FallbackDiceManager.
## The Story Track suite was green throughout because its scripted die defined the
## roll_dice the real one lacks.

const PostBattleContextScript = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const StoryTrackScript = preload("res://src/core/story/StoryTrackSystem.gd")
const StoryMarkerScript = preload("res://src/core/story/StoryMarkerInvestigation.gd")
const StarsScript = preload("res://src/core/systems/StarsOfTheStorySystem.gd")
const DiceDashboardScript = preload("res://src/ui/components/battle/DiceDashboard.gd")
const FactionSystemScript = preload("res://src/core/systems/FactionSystem.gd")
const CrewTaskEventDialogScript = preload("res://src/ui/components/dialogs/CrewTaskEventDialog.gd")
const FringeWorldStrifeScript = preload("res://src/core/world/FringeWorldStrife.gd")

## The one file still allowed to probe for roll_dice: its receiver is /root/DiceSystem,
## a test seam holding an FPCM_DiceSystem, which does define roll_dice().
const ROLL_DICE_PROBE_ALLOWED := ["res://src/utils/GameDataLoader.gd"]

const KEYS := ["Quest Progression", "Story Clock", "Marker 2 investigation",
	"Rainy Day Fund", "Dice Dashboard", "Patron Job Type", "Faction Activity",
	"Faction Vengeance", "Criminal Elements", "Loot subtable", "Bureaucratic mess"]


func after_test() -> void:
	for key in KEYS:
		DiceManager.clear_forced_results(key)


func _code_only(path: String) -> String:
	var code := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			code.append(line)
	return "\n".join(code)


func _scripts_under(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scripts_under(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))


func test_no_helper_probes_dice_manager_for_a_method_it_lacks() -> void:
	assert_bool(_code_only("res://src/core/managers/DiceManager.gd").contains("func roll_dice(")) \
		.override_failure_message("premise: DiceManager has no roll_dice()").is_false()
	var scripts: Array = []
	_scripts_under("res://src", scripts)
	assert_int(scripts.size()).override_failure_message("premise: the scan found src/").is_greater(400)
	var offenders: Array = []
	for path: String in scripts:
		var code := _code_only(path)
		if code.contains("has_method(\"roll_dice\")") and not path in ROLL_DICE_PROBE_ALLOWED:
			offenders.append(path)
		# Autoloads are scene-tree nodes, never engine singletons: this lookup is always null.
		if code.contains("Engine.has_singleton(\"DiceManager\")"):
			offenders.append(path + " (Engine.has_singleton)")
	assert_array(offenders).is_empty()


func test_the_quest_progression_d100_is_forceable() -> void:
	var ctx = PostBattleContextScript.new()
	ctx.dice_manager = DiceManager
	DiceManager.queue_forced_result("Quest Progression", 77)
	assert_int(ctx.roll_d100("Quest Progression table (Compendium p.79)")).is_equal(77)


func test_story_clock_and_marker_searches_roll_through_dice_manager() -> void:
	var track = StoryTrackScript.new()
	track.set_dice_manager(DiceManager)
	DiceManager.queue_forced_result("Story Clock", 6)
	assert_int(track._roll_d6("Story Clock")).is_equal(6)
	var markers = StoryMarkerScript.new()
	markers.set_dice_manager(DiceManager)
	DiceManager.queue_forced_result("Marker 2 investigation", 5)
	assert_int(markers._roll_d6("Marker 2 investigation")).is_equal(5)


func test_the_rainy_day_fund_rolls_through_dice_manager() -> void:
	DiceManager.queue_forced_result("Rainy Day Fund", 4)
	var result: Dictionary = StarsScript.new()._use_rainy_day_fund({})
	assert_int(int(result.get("credits_gained", 0))).override_failure_message(
		"p.67: 1D6+5, the D6 forced to 4").is_equal(9)


func test_the_battle_dice_roller_rolls_through_dice_manager() -> void:
	var dash = auto_free(DiceDashboardScript.new())
	dash.dice_system = DiceManager
	DiceManager.queue_forced_result("Dice Dashboard", 42)
	assert_int(dash._execute_roll("D100")).is_equal(42)
	DiceManager.queue_forced_result("Dice Dashboard", 5)
	assert_int(dash._execute_roll("D6")).is_equal(5)


func test_the_patron_job_type_d10_is_forceable() -> void:
	assert_object(get_tree().root.get_node_or_null("DiceSystem")) \
		.override_failure_message("premise: no DiceSystem test seam in this run").is_null()
	DiceManager.queue_forced_result("Patron Job Type", 7)
	assert_int(GameDataLoader.roll_d10("Patron Job Type (Core Rules pp.83-84)")).is_equal(7)
	assert_str(_code_only("res://src/ui/screens/world/components/JobOfferComponent.gd")).contains(
		"GameDataLoader.roll_d10(\"Patron Job Type (Core Rules pp.83-84)\")")


## Core Rules p.121: "Any character that became a casualty in the battle must roll on
## the Injury Table." Auto-resolve rolled a D6 first and killed on 1-2, in neither book.
func test_auto_resolve_sends_every_casualty_to_the_injury_table() -> void:
	var code := _code_only("res://src/ui/screens/battle/TacticalBattleUI.gd")
	assert_bool(code.contains("\"Death Check\"")).override_failure_message(
		"a D6 death check before the Injury Table is in neither book").is_false()
	assert_bool(code.contains("death_roll")).is_false()


## These rolls sit inside screens a unit test cannot drive cheaply, so their calls are
## pinned in the exact enabling form. Comment lines are stripped first.
func test_the_screen_rolls_use_dice_manager() -> void:
	assert_str(_code_only("res://src/ui/screens/campaign/CampaignTurnController.gd")).contains(
		"cost = int(dice.roll_d6(\"Lay Low (errata v1.06)\")) + 1")
	var upkeep := _code_only("res://src/ui/screens/world/components/UpkeepPhaseComponent.gd")
	assert_str(upkeep).contains("roll = dice_mgr.roll_d100(\"Travel Event (Core Rules pp.70-71)\")")
	assert_str(upkeep).contains("dm.roll_d100(\"Travel Event re-roll (Core Rules pp.70-71)\")")
	var battle := _code_only("res://src/ui/screens/battle/TacticalBattleUI.gd")
	assert_str(battle).contains("100: \"roll_d100\"}.get(sides, \"\"))")
	assert_str(battle).contains("roll = int(dice_mgr.call(method, context))")


## Compendium p.113: 01-10 Consolidate power base, "Roll 1D6. If it is higher than
## Power, the faction gains +1 power." Both dice forced through one key, in order.
func test_faction_dice_are_forceable() -> void:
	var sys = auto_free(FactionSystemScript.new())
	add_child(sys)
	DiceManager.queue_forced_result("Faction Activity", 1)
	DiceManager.queue_forced_result("Faction Activity", 6)
	var faction := {"name": "Iron Hand", "power": 3, "influence": 2}
	sys._perform_faction_activity(faction)
	assert_int(int(faction["power"])).override_failure_message(
		"01 Consolidate power base, D6 6 > Power 3").is_equal(4)
	# p.115 vengeance: the Hired Muscle column, 15-26 Enforcers.
	DiceManager.queue_forced_result("Faction Vengeance", 15)
	assert_str(sys._roll_hired_muscle()).is_equal("Enforcers")
	var code := _code_only("res://src/core/systems/FactionSystem.gd")
	for raw in ["randi_range(1, 6)", "randi_range(1, 3)", "randi() % 100 + 1"]:
		assert_bool(code.contains(raw)).override_failure_message(
			"a raw Faction die survives: %s" % raw).is_false()
	assert_str(code).contains("RivalContactRef.make(\"faction_destroyed\"")


func test_fringe_world_strife_dice_are_forceable() -> void:
	DiceManager.queue_forced_result("Criminal Elements", 11)
	assert_str(FringeWorldStrifeScript.roll_criminal_elements_name()).override_failure_message(
		"Criminal Elements 11-19 is Punks").is_equal("Punks")
	var code := _code_only("res://src/core/world/FringeWorldStrife.gd")
	assert_bool(code.contains("randi_range(1, 6)") or code.contains("randi_range(1, 100)")) \
		.override_failure_message("a raw Strife die survives").is_false()


func test_crew_task_dialog_dice_are_forceable() -> void:
	var dialog = auto_free(CrewTaskEventDialogScript.new())
	add_child(dialog)
	dialog._event_data = {"event_name": "Medical facility"}
	# Two forced D100s, so a helper that rolled locally could not match both by chance.
	DiceManager.queue_forced_result("Loot subtable", 77)
	DiceManager.queue_forced_result("Loot subtable", 3)
	assert_int(dialog._die(100, "Loot subtable")).is_equal(77)
	assert_int(dialog._die(100, "Loot subtable")).is_equal(3)
	# The helper's own fallback is the one raw roll left in the file.
	assert_int(_code_only("res://src/ui/components/dialogs/CrewTaskEventDialog.gd").count("randi")) \
		.override_failure_message("a die in this dialog bypasses _die()").is_equal(1)


func test_campaign_and_upkeep_dice_use_dice_manager() -> void:
	var cpm := _code_only("res://src/core/campaign/CampaignPhaseManager.gd")
	assert_str(cpm).contains("roll_2d6(\"Unity Agent favor (Core Rules p.20): \" + char_name)")
	assert_str(cpm).contains("roll_d6(\"Business Elsewhere XP\")")
	var upkeep := _code_only("res://src/ui/screens/world/components/UpkeepPhaseComponent.gd")
	assert_str(upkeep).contains("_upkeep_2d6(\"World trait: Bureaucratic mess\")")
	assert_str(upkeep).contains("roll_d3(\"World trait: travel surcharge\")")
	assert_str(upkeep).contains("_upkeep_2d6(\"Personal trinket\") >= 9")
	# The helper itself: two forced 2D6 results at the ends of the range.
	var u: Node = auto_free((load("res://src/ui/screens/world/components/UpkeepPhaseComponent.tscn")
		as PackedScene).instantiate())
	add_child(u)
	DiceManager.queue_forced_result("Bureaucratic mess", 12)
	DiceManager.queue_forced_result("Bureaucratic mess", 2)
	assert_int(u._upkeep_2d6("World trait: Bureaucratic mess")).is_equal(12)
	assert_int(u._upkeep_2d6("World trait: Bureaucratic mess")).is_equal(2)
