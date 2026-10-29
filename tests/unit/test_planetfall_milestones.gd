extends GdUnitTestSuite

## Planetfall pp.156-160, Milestones (C5).
##
## Before 2026-10-27 the turn controller rescanned every owned source at Research AND
## Building and granted a Milestone on the first match, so one granting building paid out
## twice a turn until the End Game launched itself. apply_milestone() emitted thirteen
## kinds of follow-up and the controller handled four: the extra Character Events, Colony
## Event and Enemy Activity, the Tactical Enemy buffs, the 4th Milestone's condition
## replacement, Slyn tracking, and the 7th Milestone ending Calamities reached nothing.
## The p.158 evolution read a note on a blank entry as the creature itself, overwrote one
## pending evolution with the next, and refused a duplicate instead of rerolling it.
##
## The phase manager saves at the end of a turn, so the user:// guard is mandatory.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const MilestoneScript = preload("res://src/core/systems/PlanetfallMilestoneSystem.gd")
const LifeformScript = preload("res://src/core/systems/PlanetfallLifeformGenerator.gd")
const ConditionScript = preload("res://src/core/systems/PlanetfallConditionSystem.gd")
const MilestonePanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallMilestonePanel.gd")
const CalamityPanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallCalamityPanel.gd")
const AutoResolve = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallAutoResolveDialog.gd")
const SimpleDialog = preload("res://src/ui/screens/planetfall/panels/PlanetfallSimpleDialog.gd")
const ColonyEvents = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallColonyEventsPanel.gd")
const TurnScene = preload("res://src/ui/screens/planetfall/PlanetfallTurnController.tscn")
const DashboardScene = preload("res://src/ui/screens/planetfall/PlanetfallDashboard.tscn")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const RosterRules = preload("res://src/core/systems/PlanetfallRosterRules.gd")
const Phase = PMScript.Phase

var _user_state: Dictionary
var _saved_campaign: Variant
var _dm: Node


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


func _core() -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	core.colony_morale = 0
	core.roster = [{"id": "c1", "name": "Ash", "class": "trooper"},
		{"id": "c2", "name": "Kip", "class": "scientist"}]
	return core


func _pm(core: Resource) -> Node:
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	return pm


func _pm_at(core: Resource, phase: int) -> Node:
	var pm := _pm(core)
	pm.start_new_turn()
	while pm.current_phase != phase:
		pm.complete_current_phase({})
	return pm


func _mount(script: GDScript) -> Control:
	var panel: Control = script.new()
	add_child(panel)
	auto_free(panel)
	return panel


func _step(script: GDScript, core: Resource, pm: Node, step: String) -> Control:
	var panel := _mount(script)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.configure(step, pm.current_phase)
	panel.phase_completed.connect(pm.complete_current_phase)
	panel.refresh()
	return panel


func _force(key: String, values: Array) -> void:
	for v in values:
		_dm.queue_forced_result(key, v)


func _queued(key: String) -> int:
	return (_dm.get_forced_results().get(key.to_lower(), []) as Array).size()


## The dice one Milestone owes, armed so nothing in it is left to chance: no Mission
## Data Breakthrough, no Calamity, and the evolution on entry 1.
func _quiet_milestone(evolution_roll: int = 15) -> void:
	_force("Planetfall Mission Data", [6])
	_force("Planetfall Calamity Check", [6])
	_force("Planetfall Evolution Slot", [1])
	_force("Planetfall Lifeform Evolution", [evolution_roll])


func _text(node: Node) -> String:
	var shown := ""
	for n in node.find_children("*", "Label", true, false):
		shown += (n as Label).text + "\n"
	for n in node.find_children("*", "RichTextLabel", true, false):
		shown += (n as RichTextLabel).text + "\n"
	return shown


func _filled_condition(core: Resource, slot: int, master_roll: int) -> Dictionary:
	_force("Planetfall Condition Detail", [1])
	return ConditionScript.new().fill_condition_slot(core, slot, master_roll)


# ── Grant once per source (p.156) ────────────────────────────────────────────────

func test_a_granting_source_pays_one_milestone_across_both_steps() -> void:
	var core := _core()
	core.research_data = {"unlocked_applications": ["frontier_doctrines"]}
	var pm := _pm_at(core, Phase.RESEARCH)
	_quiet_milestone()
	pm.complete_current_phase({})
	assert_int(core.milestones_completed).is_equal(1)
	var receipt: Dictionary = pm.take_milestone_receipt()
	assert_str(str((receipt.get("lines", [""]) as Array)[0])) \
		.override_failure_message("the receipt names the Milestone and what earned it") \
		.contains("Milestone 1 achieved")
	assert_dict(pm.take_milestone_receipt()) \
		.override_failure_message("a receipt is shown once").is_empty()
	pm.complete_current_phase({})  # Building, same source still owned
	assert_int(int(pm.current_phase)).is_equal(Phase.COLONY_INTEGRITY)
	assert_int(core.milestones_completed) \
		.override_failure_message("p.156: the source granted at Research, not again at Building") \
		.is_equal(1)
	assert_array(core.milestone_sources) \
		.contains(["research_applications:frontier_doctrines"])


func _receipts(host: Node) -> Array:
	var shown: Array = []
	for w in host.find_children("*", "Window", true, false):
		if "_pending_text" in w:
			shown.append(str(w._pending_text))
	return shown


## The real screen: the step's receipt reaches the player, once.
func test_the_turn_screen_shows_the_milestone_receipt_once() -> void:
	var core := _core()
	core.campaign_turn = 2
	core.research_data = {"unlocked_applications": ["frontier_doctrines"]}
	core.record_turn_phase(Phase.RESEARCH, {})
	get_tree().root.get_node_or_null("/root/GameState").current_campaign = core
	var tc: Control = TurnScene.instantiate()
	add_child(tc)
	auto_free(tc)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(int(tc.phase_manager.current_phase)) \
		.override_failure_message("premise: the screen opened on Research").is_equal(Phase.RESEARCH)
	_quiet_milestone()
	tc._on_panel_phase_completed({})
	var shown: Array = _receipts(tc)
	assert_int(shown.size()).is_equal(1)
	assert_str(str(shown[0])).contains("Milestone 1 achieved")
	tc._on_panel_phase_completed({})  # Building
	assert_int(_receipts(tc).size()) \
		.override_failure_message("no second receipt: the source has already paid") \
		.is_equal(1)


func test_a_save_from_before_the_claim_list_claims_without_granting() -> void:
	var core := _core()
	core.research_data = {"unlocked_applications": ["frontier_doctrines"]}
	core.milestones_completed = 1
	var data: Dictionary = core.to_dictionary()
	(data.progression as Dictionary).erase("milestone_sources")
	var loaded = CoreScript.new()
	loaded.from_dictionary(data)
	assert_bool(loaded.milestone_sources_unseeded).is_true()
	var system = MilestoneScript.new()
	var first: Dictionary = system.deliver_new_milestones(loaded)
	assert_array(first.milestones) \
		.override_failure_message("a source it already owned has already paid").is_empty()
	assert_int(loaded.milestones_completed).is_equal(1)
	loaded.buildings_data = {"constructed": ["orbital_facility"]}
	_quiet_milestone()
	var second: Dictionary = system.deliver_new_milestones(loaded)
	assert_int((second.milestones as Array).size()).is_equal(1)
	assert_int(loaded.milestones_completed).is_equal(2)


# ── Every follow-up reaches the campaign (pp.156-158) ────────────────────────────

func test_milestone_follow_ups_are_recorded_and_survive_a_save() -> void:
	var core := _core()
	var system = MilestoneScript.new()
	_quiet_milestone()
	system.deliver_milestone(core, 1)
	assert_int(core.get_extra_rolls("character_event")) \
		.override_failure_message("p.156: two Character Events in addition to the normal one") \
		.is_equal(2)
	_quiet_milestone()
	system.deliver_milestone(core, 2)
	assert_int(core.get_extra_rolls("colony_event")).is_equal(1)
	_quiet_milestone()
	system.deliver_milestone(core, 3)
	assert_int(core.get_extra_rolls("enemy_activity")).is_equal(1)
	assert_int(int(core.get_milestone_flag("tactical_panic_reduction", 0))).is_equal(1)
	assert_int(int(core.get_milestone_flag("tactical_specialist_kp", 0))).is_equal(1)
	_quiet_milestone()
	system.deliver_milestone(core, 6)
	assert_int(int(core.get_milestone_flag("tactical_extra_specialists", 0))).is_equal(1)
	assert_bool(bool(core.get_milestone_flag("enemy_activity_every_enemy", false))).is_true()
	assert_int(core.tactical_enemies.size()) \
		.override_failure_message("Milestones 1-3 each bring a Tactical Enemy (pp.156-157)") \
		.is_equal(3)
	var copy = CoreScript.new()
	copy.from_dictionary(core.to_dictionary())
	assert_dict(copy.milestone_flags).is_equal(core.milestone_flags)
	assert_dict(copy.pending_extra_rolls).is_equal(core.pending_extra_rolls)


func test_a_milestones_mission_data_is_checked_with_the_forced_die() -> void:
	var core := _core()
	core.mission_data = 0
	_force("Planetfall Mission Data", [1])
	_force("Planetfall Calamity Check", [6])
	_force("Planetfall Evolution Slot", [1])
	_force("Planetfall Lifeform Evolution", [15])
	var entry: Dictionary = MilestoneScript.new().deliver_milestone(core, 1)
	assert_int(core.mission_data_breakthroughs) \
		.override_failure_message("p.169: 1D6 at or below the Mission Data is a Breakthrough") \
		.is_equal(1)
	assert_int(core.mission_data).override_failure_message("then subtract the roll") \
		.is_equal(0)
	assert_str("\n".join(PackedStringArray(entry.lines))).contains("Breakthrough 1")


# ── Calamities (pp.158, 165) ─────────────────────────────────────────────────────

func test_a_calamity_strikes_at_or_below_the_points() -> void:
	var core := _core()
	core.calamity_points = 2
	_force("Planetfall Calamity Check", [1])
	_force("Planetfall Calamity Table", [50])
	var lines: Array = MilestoneScript.new().resolve_calamity_check(core, false)
	assert_int(core.active_calamities.size()).is_equal(1)
	assert_str(str(core.active_calamities[0].id)) \
		.override_failure_message("p.165: 49-63 Mega predators, from the forced D100") \
		.is_equal("mega_predators")
	assert_int(core.calamity_points).override_failure_message("subtract the roll") \
		.is_equal(1)
	assert_str(str(lines[0])).starts_with("Calamity:")


func test_the_seventh_milestone_without_a_calamity_ends_them() -> void:
	var core := _core()
	core.calamity_points = 1
	var system = MilestoneScript.new()
	_force("Planetfall Calamity Check", [6])
	system.resolve_calamity_check(core, true)
	assert_bool(bool(core.get_milestone_flag("calamities_ended", false))).is_true()
	core.calamity_points = 5
	_force("Planetfall Calamity Check", [1])
	system.resolve_calamity_check(core, false)
	assert_int(core.active_calamities.size()) \
		.override_failure_message("p.158: no more Calamities for the rest of the campaign") \
		.is_equal(0)
	assert_int(_queued("Planetfall Calamity Check")) \
		.override_failure_message("and the check is not even rolled").is_equal(1)


# ── Lifeform Evolution (p.158, table pp.159-160) ─────────────────────────────────

func test_an_evolution_on_a_blank_entry_waits_and_applies_when_it_fills() -> void:
	var core := _core()
	var gen = LifeformScript.new()
	_force("Planetfall Evolution Slot", [3, 3])
	_force("Planetfall Lifeform Evolution", [5, 15])
	var first: Dictionary = gen.evolve_random(core)
	gen.evolve_random(core)
	assert_int(int(first.slot)).is_equal(2)
	assert_bool(bool(first.get("pending", false))).is_true()
	assert_array(core.lifeform_table[2].get("pending_evolutions", [])) \
		.override_failure_message("a second evolution adds to the note, never replaces it") \
		.is_equal(["enhanced_profile", "poison"])
	assert_bool(LifeformScript.is_slot_filled(core.lifeform_table[2])) \
		.override_failure_message("a note of waiting evolutions is not a creature").is_false()
	# The live roller (PlanetfallBattleGuide): D100 to a slot, and a blank slot is filled.
	var creature: Dictionary = gen.fill_encounter_slot(core,
			gen.get_encounter_table_slot(40))  # 33-44 is entry 3
	assert_bool(creature.has("toughness")) \
		.override_failure_message("the encounter generated a creature, not the note").is_true()
	assert_array(creature.get("evolutions_applied", [])) \
		.contains(["enhanced_profile", "poison"])
	assert_int(int(creature.combat_skill)).is_greater_equal(1)
	assert_int(int(creature.strike_damage)).is_greater_equal(1)


func test_a_duplicate_evolution_is_rerolled() -> void:
	var core := _core()
	var gen = LifeformScript.new()
	_force("Planetfall Evolution Slot", [1, 1])
	_force("Planetfall Lifeform Evolution", [15, 15, 25])
	gen.evolve_random(core)
	var second: Dictionary = gen.evolve_random(core)
	assert_array(second.rolls) \
		.override_failure_message("p.158: \"exact duplicates require a reroll\"") \
		.is_equal([15, 25])
	assert_str(str(second.evolution.get("id", ""))).is_equal("spines")


func test_dramatic_transformations_clear_the_unique_ability() -> void:
	var core := _core()
	var gen = LifeformScript.new()
	gen.fill_encounter_slot(core, 0)
	gen.apply_evolution(core, 0, 45)
	assert_dict(core.lifeform_table[0].get("unique_ability", {"x": 1})).is_empty()
	assert_bool(bool(core.lifeform_table[0].get("unique_ability_each_battle", false))) \
		.override_failure_message("pp.159-160: roll a Unique Ability each battle instead") \
		.is_true()


# ── The 4th Milestone's condition replacement (pp.110, 157) ──────────────────────

func test_the_fourth_milestone_owes_a_replacement_only_when_a_condition_exists() -> void:
	var core := _core()
	var system = MilestoneScript.new()
	var empty: Dictionary = system.apply_milestone(core, 4)
	assert_int(core.pending_condition_replacements).is_equal(0)
	assert_str("\n".join(PackedStringArray(empty.effects_applied))) \
		.contains("none to erase")
	_filled_condition(core, 2, 5)
	system.apply_milestone(core, 4)
	assert_int(core.pending_condition_replacements).is_equal(1)


func test_replacing_a_condition_rolls_the_master_table_into_the_same_entry() -> void:
	var core := _core()
	_filled_condition(core, 2, 5)
	core.pending_condition_replacements = 1
	assert_str(str(core.condition_table[2].id)).is_equal("visibility_limits")
	_force("Planetfall Battlefield Condition", [50])
	_force("Planetfall Condition Detail", [1])
	var receipt: Dictionary = ConditionScript.new().replace_condition(core, 2)
	assert_str(str(receipt.erased.id)).is_equal("visibility_limits")
	assert_str(str(core.condition_table[2].id)).is_not_equal("visibility_limits")
	assert_str(str(core.condition_table[2].id)).is_equal(str(receipt.condition.id))
	assert_int(core.pending_condition_replacements).is_equal(0)
	assert_dict(ConditionScript.new().replace_condition(core, 2)) \
		.override_failure_message("nothing owed, nothing replaced").is_empty()


func test_a_mission_drawing_a_filled_entry_does_not_roll_the_master_table() -> void:
	var core := _core()
	_filled_condition(core, 0, 5)
	_force("Planetfall Condition Slot", [10])  # 01-15 is entry 1
	_force("Planetfall Battlefield Condition", [99])
	var drawn: Dictionary = ConditionScript.new().roll_mission_condition(core)
	assert_str(str(drawn.get("id", ""))) \
		.override_failure_message("p.110: \"you receive the same Condition again\"") \
		.is_equal("visibility_limits")
	assert_int(_queued("Planetfall Battlefield Condition")).is_equal(1)


func test_the_progression_overlay_offers_the_replacement_and_asks_for_a_save() -> void:
	var core := _core()
	_filled_condition(core, 2, 5)
	core.pending_condition_replacements = 1
	var panel := _mount(MilestonePanel)
	panel.set_campaign(core)
	panel.refresh()
	var saves: Array = []
	panel.campaign_changed.connect(func() -> void: saves.append(true))
	var button: Button = null
	for b in panel.find_children("*", "Button", true, false):
		if (b as Button).text == "Erase and replace entry 3":
			button = b
	assert_object(button).is_not_null()
	_force("Planetfall Battlefield Condition", [50])
	_force("Planetfall Condition Detail", [1])
	button.pressed.emit()
	assert_int(core.pending_condition_replacements).is_equal(0)
	assert_str(str(core.condition_table[2].id)).is_not_equal("visibility_limits")
	assert_array(saves).override_failure_message("the dashboard saves on this signal") \
		.has_size(1)


func test_the_dashboard_saves_when_an_overlay_changes_the_campaign() -> void:
	var core := _core()
	get_tree().root.get_node_or_null("/root/GameState").current_campaign = core
	var dash: Control = DashboardScene.instantiate()
	add_child(dash)
	auto_free(dash)
	await get_tree().process_frame
	dash._show_overlay_panel("milestones")
	var panel: Node = null
	for child in dash._overlay_frame.get_children():
		if child.has_signal("campaign_changed") and not child.is_queued_for_deletion():
			panel = child
	assert_object(panel).override_failure_message("premise: the overlay opened") \
		.is_not_null()
	assert_bool(panel.campaign_changed.is_connected(dash._on_save)) \
		.override_failure_message("a replacement the dashboard never saves is undone by a "
			+ "force-stop").is_true()


# ── The extra rolls are rolled at their own steps, and spent there ───────────────

func test_step_4_rolls_for_every_enemy_after_the_sixth_milestone() -> void:
	var core := _core()
	core.tactical_enemies = [
		{"type": {"id": "raiders", "name": "Raiders"}, "occupied_sectors": [4]},
		{"type": {"id": "swarm", "name": "Swarm"}, "occupied_sectors": [7]}]
	core.set_milestone_flag("enemy_activity_every_enemy", true)
	var pm := _pm_at(core, Phase.ENEMY_ACTIVITY)
	var dlg := _step(AutoResolve, core, pm, "enemy_activity")
	_force("Planetfall Enemy Activity", [10, 10])
	dlg.complete()
	assert_int(_text(dlg).count("Acting enemy:")) \
		.override_failure_message("p.158: Enemy Activity for every enemy on the map") \
		.is_equal(2)
	assert_int(_queued("Planetfall Enemy Activity")).is_equal(0)


func test_raids_by_every_enemy_add_up() -> void:
	var core := _core()
	core.tactical_enemies = [
		{"type": {"id": "raiders", "name": "Raiders"}, "occupied_sectors": [4]},
		{"type": {"id": "swarm", "name": "Swarm"}, "occupied_sectors": [7]}]
	core.set_milestone_flag("enemy_activity_every_enemy", true)
	var pm := _pm_at(core, Phase.ENEMY_ACTIVITY)
	var dlg := _step(AutoResolve, core, pm, "enemy_activity")
	_force("Planetfall Enemy Activity", [95, 95])
	dlg.complete()
	dlg.complete()
	assert_int(core.colony_integrity) \
		.override_failure_message("p.62: each Raid is its sectors + 1, so two raids cost 4") \
		.is_equal(-4)


func test_step_4_adds_the_third_milestones_roll_and_spends_it() -> void:
	var core := _core()
	core.tactical_enemies = [
		{"type": {"id": "raiders", "name": "Raiders"}, "occupied_sectors": [4]}]
	var pm := _pm_at(core, Phase.ENEMY_ACTIVITY)
	core.queue_extra_roll("enemy_activity")
	var dlg := _step(AutoResolve, core, pm, "enemy_activity")
	_force("Planetfall Enemy Activity", [10, 10])
	dlg.complete()
	assert_int(_text(dlg).count("Acting enemy:")) \
		.override_failure_message("p.157: in addition to the normal event").is_equal(2)
	dlg.complete()
	assert_int(core.get_extra_rolls("enemy_activity")) \
		.override_failure_message("spent when the step completes").is_equal(0)


func test_step_5_rolls_the_owed_event_one_press_at_a_time() -> void:
	var core := _core()
	var pm := _pm_at(core, Phase.COLONY_EVENTS)
	core.queue_extra_roll("colony_event")
	var panel := _mount(ColonyEvents)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.phase_completed.connect(pm.complete_current_phase)
	panel.refresh()
	_force("Planetfall Colony Event", [6, 6])
	panel.complete()  # roll the normal event
	panel.complete()  # continue: re-arms the roll for the Milestone's event
	panel.complete()  # roll it
	assert_int(int(pm.current_phase)) \
		.override_failure_message("each footer press is one click; the step is not over") \
		.is_equal(Phase.COLONY_EVENTS)
	panel.complete()  # continue past it
	assert_bool(pm.is_phase_complete(Phase.COLONY_EVENTS)).is_true()
	assert_int(int(pm.current_phase)).is_equal(Phase.MISSION_DETERMINATION)
	assert_bool(pm.is_phase_complete(Phase.MISSION_DETERMINATION)) \
		.override_failure_message("one completion, never a second one into the next step") \
		.is_false()
	assert_int((panel._result_data.get("events", []) as Array).size()).is_equal(2)
	assert_int(core.colony_integrity) \
		.override_failure_message("both Catastrophic malfunctions did their damage") \
		.is_equal(-2)
	assert_int(core.get_extra_rolls("colony_event")).is_equal(0)


func test_step_17_rolls_the_first_milestones_character_events() -> void:
	var core := _core()
	var pm := _pm_at(core, Phase.CHARACTER_EVENT)
	core.queue_extra_roll("character_event", 2)
	var dlg := _step(SimpleDialog, core, pm, "character_event")
	_force("Planetfall Step 17 Event", [50, 50, 50])
	dlg.complete()
	assert_int((dlg._result_data.get("events", []) as Array).size()) \
		.override_failure_message("the normal event plus the Milestone's two").is_equal(3)
	assert_int(_queued("Planetfall Step 17 Event")).is_equal(0)
	dlg.complete()
	assert_int(core.get_extra_rolls("character_event")).is_equal(0)


# ── The overlays can be closed ───────────────────────────────────────────────────

func test_the_progression_and_calamity_overlays_keep_their_close_button() -> void:
	for script in [MilestonePanel, CalamityPanel]:
		var panel := _mount(script)
		panel.set_campaign(_core())
		panel.refresh()
		await get_tree().process_frame
		var close: Button = null
		for b in panel.find_children("*", "Button", true, false):
			if (b as Button).text == "Close" and is_instance_valid(b):
				close = b
		assert_object(close) \
			.override_failure_message("%s opened with no way to close it"
				% script.resource_path.get_file()) \
			.is_not_null()


# ── p.156's list names ids the producers write ───────────────────────────────────

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _milestone_applications(node: Variant, out: Array) -> void:
	if node is Dictionary:
		if str(node.get("type", "")) == "milestone":
			out.append(str(node.get("id", "")))
		for v in node.values():
			_milestone_applications(v, out)
	elif node is Array:
		for v in node:
			_milestone_applications(v, out)


## The research half granted nothing for as long as the list said
## "frontier_world_doctrines" and the tree wrote "frontier_doctrines". Both directions:
## a listed id nothing writes can never grant; a granting item missing from the list
## never does either.
func test_every_source_on_the_milestone_list_is_an_id_its_producer_writes() -> void:
	var listed: Dictionary = _json("res://data/planetfall/milestone_effects.json") \
		.get("tech_that_grants_milestones", {})
	var produced: Dictionary = {"buildings": [], "augmentations": [],
		"alien_artifacts": [], "research_applications": []}
	for b in _json("res://data/planetfall/buildings.json").get("buildings", []):
		if bool(b.get("is_milestone", false)):
			produced.buildings.append(str(b.id))
	for a in _json("res://data/planetfall/augmentations.json").get("augmentations", []):
		if (a.get("effect", {}) as Dictionary).has("milestone"):
			produced.augmentations.append(str(a.id))
	for e in _json("res://data/planetfall/artifacts.json").get("entries", []):
		if bool((e.get("effect", {}) as Dictionary).get("grants_milestone", false)):
			produced.alien_artifacts.append(str(e.id))
	_milestone_applications(_json("res://data/planetfall/research_tree.json"),
		produced.research_applications)
	for category in produced:
		var want: Array = (produced[category] as Array).duplicate()
		var have: Array = (listed.get(category, []) as Array).duplicate()
		want.sort()
		have.sort()
		assert_array(want).override_failure_message("premise: %s has producers" % category) \
			.is_not_empty()
		assert_array(have).override_failure_message(
			"p.156 %s: the list %s against the producers %s" % [category, have, want]) \
			.is_equal(want)


# ── One grant site: building and augmenting do not count a Milestone themselves ──

func test_a_milestone_building_grants_one_milestone_not_two() -> void:
	var core := _core()
	core.buildings_data = {"current_bp": 99, "constructed": [], "in_progress": {}}
	var result: Dictionary = PlanetfallBuildingSystem.new().invest_bp(core, "orbital_facility", 20)
	assert_bool(bool(result.get("completed", false))).override_failure_message(
		"premise: the facility was built").is_true()
	assert_int(core.milestones_completed).override_failure_message(
		"construction counted a Milestone with none of its effects").is_equal(0)
	_quiet_milestone()
	MilestoneScript.new().deliver_new_milestones(core)
	assert_int(core.milestones_completed).is_equal(1)


func test_buying_mental_links_delivers_its_milestone_with_its_effects() -> void:
	var core := _core()
	core.augmentation_points = 5
	core.research_data = {}
	_quiet_milestone()
	var result: Dictionary = load("res://src/core/systems/PlanetfallAugmentationSystem.gd") \
		.new().apply_augmentation(core, "mental_links")
	assert_bool(bool(result.get("success", false))).is_true()
	assert_int(core.milestones_completed).override_failure_message(
		"p.105: Mental links counts as one Milestone, not two").is_equal(1)
	assert_array(core.milestone_sources).contains(["augmentations:mental_links"])
	assert_str(str(result.get("milestone_lines", []))).override_failure_message(
		"the purchase shows the Milestone it earned").contains("Milestone 1 achieved")


## The banner tested the THEORY id, which p.156 never lists, so it never showed.
func test_the_research_banner_names_the_application_it_unlocked() -> void:
	var core := _core()
	var others := ["conflict_resolution", "consensus_mechanics", "recreational_fac",
		"satellite_launch"]
	core.research_data = {"current_rp": 3, "completed_theories": ["social_theories"],
		"unlocked_applications": others}
	var host_script := GDScript.new()
	host_script.source_code = ("extends Node\nvar ms\n"
		+ "func get_milestone_system():\n\treturn ms\n")
	host_script.reload()
	var host: Node = host_script.new()
	host.ms = MilestoneScript.new()
	add_child(host)
	auto_free(host)
	var pm: Node = PMScript.new()
	host.add_child(pm)
	pm.setup(core)
	var panel := _mount(load("res://src/ui/screens/planetfall/panels/PlanetfallResearchPanel.gd"))
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.refresh()
	panel._on_research_app_pressed("social_theories")
	assert_array(core.research_data.unlocked_applications).override_failure_message(
		"premise: the only application left was Frontier World Doctrines") \
		.contains(["frontier_doctrines"])
	assert_str(_text(panel)).contains("MILESTONE GRANTED")


# ── Step 13 Replacements (p.69) and the roster's size (p.100) ────────────────────

func test_the_expanded_living_facility_adds_two_roster_slots() -> void:
	var core := _core()
	assert_int(RosterRules.roster_capacity(core)).is_equal(8)
	core.buildings_data = {"constructed": ["expanded_living_facility"]}
	assert_int(RosterRules.roster_capacity(core)) \
		.override_failure_message("p.100: You may expand your character roster by 2") \
		.is_equal(10)


func test_step_13_adds_the_replacement_the_player_takes() -> void:
	var core := _core()
	var pm := _pm_at(core, Phase.REPLACEMENTS)
	var dlg := _step(SimpleDialog, core, pm, "replacements")
	_force("Planetfall Replacement Roll", [7])
	_force("Planetfall Replacement Class", [5])
	dlg.complete()
	assert_int(dlg._replacement_offers.size()).is_equal(1)
	dlg.complete()
	assert_bool(pm.is_phase_complete(Phase.REPLACEMENTS)).is_true()
	assert_int(core.roster.size()).override_failure_message(
		"the replacement was announced and never added").is_equal(3)
	var added: Dictionary = core.roster[2]
	var standard: Dictionary = RosterRules.standard_character("scout", "x", "x")
	assert_str(str(added["class"])).is_equal("scout")
	assert_str(str(added.loyalty)).is_equal("committed")
	assert_int(int(added.speed)).is_equal(int(standard.speed))
	assert_str(str(added.id)).is_not_equal("c1").is_not_equal("c2")


func test_step_13_a_replacement_of_choice_is_the_class_the_player_picks() -> void:
	var core := _core()
	var pm := _pm_at(core, Phase.REPLACEMENTS)
	var dlg := _step(SimpleDialog, core, pm, "replacements")
	_force("Planetfall Replacement Roll", [10])
	dlg.complete()
	var pick: OptionButton = dlg._replacement_offers[0].pick
	assert_object(pick).override_failure_message("9-12: a replacement of your choice") \
		.is_not_null()
	pick.select(RosterRules.REPLACEMENT_CLASSES.find("scientist"))
	dlg.complete()
	assert_int(core.roster.size()).is_equal(3)
	assert_str(str(core.roster[2]["class"])) \
		.override_failure_message("a choice silently became a trooper").is_equal("scientist")


func test_step_13_a_replacement_the_player_declines_adds_nobody() -> void:
	var core := _core()
	var pm := _pm_at(core, Phase.REPLACEMENTS)
	var dlg := _step(SimpleDialog, core, pm, "replacements")
	_force("Planetfall Replacement Roll", [8])
	_force("Planetfall Replacement Class", [1])
	dlg.complete()
	(dlg._replacement_offers[0].take as CheckBox).button_pressed = false
	dlg.complete()
	assert_int(core.roster.size()).override_failure_message("p.69: you MAY take").is_equal(2)


func test_step_13_a_dismissal_makes_room_on_a_full_roster() -> void:
	var core := _core()
	for i in range(6):
		core.roster.append({"id": "f%d" % i, "name": "F%d" % i, "class": "trooper"})
	var pm := _pm_at(core, Phase.REPLACEMENTS)
	var dlg := _step(SimpleDialog, core, pm, "replacements")
	(dlg._dismiss_checks["c1"] as CheckBox).button_pressed = true
	_force("Planetfall Replacement Roll", [7])
	_force("Planetfall Replacement Class", [3])
	dlg.complete()
	assert_int(dlg._replacement_offers.size()).override_failure_message(
		"the dismissal made the room this roll needs").is_equal(1)
	dlg.complete()
	assert_int(core.roster.size()).is_equal(8)
	var ids: Array = core.roster.map(func(c): return c.id)
	assert_array(ids).not_contains(["c1"])
	assert_str(str(core.roster[7]["class"])).is_equal("scientist")


func test_step_13_never_fills_past_a_full_roster() -> void:
	var core := _core()
	for i in range(5):
		core.roster.append({"id": "f%d" % i, "name": "F%d" % i, "class": "trooper"})
	var pm := _pm(core)
	var added: Array = pm.resolve_replacements({"new_characters": [
		{"class": "trooper"}, {"class": "scout"}, {"class": "trooper"}]})
	assert_int(added.size()).is_equal(1)
	assert_int(core.roster.size()).is_equal(8)
	# On a roster WITH room, or the capacity check refuses it first and this proves nothing.
	var roomy := _core()
	assert_array(_pm(roomy).resolve_replacements({"new_characters": [{"class": "captain"}]})) \
		.override_failure_message("only the three p.69 classes").is_empty()
	assert_int(roomy.roster.size()).is_equal(2)
