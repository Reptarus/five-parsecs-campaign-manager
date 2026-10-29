extends GdUnitTestSuite

## Bug Hunt battle delivery — Compendium pp.186-199 reach the battle screen.
##
## ⚠ Before 2026-10-27 BugHuntBattleSetup built Contacts, Tactical Locations, Signals,
## Spawn Points and the contact rules, and TacticalBattleUI read none of it: a Bug Hunt
## battle showed the 5PFH Battle Card and the 5PFH end-of-round checklist. Two of the
## setup's own keys read data paths that do not exist, so they were always {}.
## These cases assert what reaches the SCREEN, not only what the builder returns.

const Setup = preload("res://src/core/battle/BugHuntBattleSetup.gd")
const Guide = preload("res://src/core/battle/BugHuntBattleGuide.gd")
const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
const MissionPanel = preload("res://src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd")
const FormClass = preload("res://src/ui/components/battle/BattleResultsInputForm.gd")
const CoreScript = preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const MISSIONS_PATH := "res://data/bug_hunt/bug_hunt_missions.json"
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
## The phase manager's persist() goes through GameState.save_campaign(), which also
## rewrites last_campaign: unguarded, the next process auto-loads this Bug Hunt core
## and a 5PFH suite reads its String difficulty (measured 2026-10-27, Sprint 3 gate).

var _user_state: Dictionary


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()


func after_test() -> void:
	var dm := get_tree().root.get_node_or_null("/root/DiceManager")
	if dm != null:
		dm.clear_forced_results()
	SaveDirGuard.restore(_user_state)


class RoundStub extends Node:
	var round_number: int = 2
	func get_current_round() -> int:
		return round_number


func _difficulty_row(id: String) -> Dictionary:
	var f := FileAccess.open(MISSIONS_PATH, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	for row in data.get("difficulty_settings", []):
		if row is Dictionary and str(row.get("id", "")) == id:
			return row
	return {}


func _mission(difficulty: String, spawn_rating: int = 2, priority: int = 3) -> Dictionary:
	return Setup.new().generate_battle_context({
		"priority": priority, "spawn_rating": spawn_rating, "contact_markers": 4,
		"difficulty": difficulty, "difficulty_rules": _difficulty_row(difficulty),
		"objectives": [{"die_value": 2, "rating": "vital", "weight": 2,
			"type": {"name": "Recover", "achieved_when": "Carry it off the table."}}],
	})


func _labels(root: Node) -> String:
	var text := ""
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label:
			text += (n as Label).text + "\n"
		elif n is Button:
			text += (n as Button).text + "\n"
		for c: Node in n.get_children():
			stack.append(c)
	return text


# ── the producer: the rules reach the battle payload ─────────────────────────────

func test_the_setup_carries_the_round_rules_and_the_difficulty_row() -> void:
	var md := _mission("living_nightmare")
	var contact: Dictionary = md.get("contact_rules", {})
	assert_dict(contact.get("movement", {})).override_failure_message(
		"p.192 Contact movement must reach the battle").is_not_empty()
	assert_array(contact.get("contact_table", [])).is_not_empty()
	assert_dict((md.get("spawn_point_rules", {}) as Dictionary).get("phases", {})) \
		.override_failure_message("p.199 Spawn Point phases must reach the battle") \
		.is_not_empty()
	assert_int(int((md.get("difficulty_rules", {}) as Dictionary).get("numbers_modifier", 0))) \
		.override_failure_message("p.194: Living Nightmare adds 1 to Numbers").is_equal(1)


## One encoding per rule: the p.186 Encounter Modifier column IS the p.194 Numbers
## adjustment, and p.190's extra centre marker IS the Initial Contact Markers column.
func test_each_difficulty_rule_is_encoded_once() -> void:
	for id in ["im_too_pretty_to_die", "hey_not_too_crazy", "mess_me_up",
			"mega_violence", "living_nightmare"]:
		var row := _difficulty_row(id)
		assert_dict(row).is_not_empty()
		assert_bool(row.has("encounter_modifier") or row.has("extra_contacts")) \
			.override_failure_message("%s still carries a duplicate encoding" % id) \
			.is_false()


# ── the guide: text the players act on ───────────────────────────────────────────

func test_the_briefing_names_what_the_setup_placed_and_the_numbers_adjustment() -> void:
	var md := _mission("living_nightmare")
	var text := ""
	for row in Guide.briefing_rows(md):
		text += "%s\n%s\n" % [row.head, row.detail]
	assert_str(text).contains("Contacts: 4 marker(s)")
	assert_str(text).contains("Spawn Rating 2")
	assert_str(text).contains("Objective 2 [VITAL, counts as 2]: Recover")
	assert_str(text).contains("+1 per marker on Living Nightmare")
	assert_str(_mission_text(_mission("mess_me_up"))).not_contains("per marker on")


func _mission_text(md: Dictionary) -> String:
	var text := ""
	for row in Guide.briefing_rows(md):
		text += "%s\n%s\n" % [row.head, row.detail]
	return text


func test_round_prompts_follow_the_round_and_the_difficulty() -> void:
	var nightmare: Array = Guide.round_end_prompts(1, _mission("living_nightmare"))
	var t1 := str(nightmare)
	assert_str(t1).contains("Reveal Spawn Point 1 of 2")
	assert_str(t1).contains("Start of Round 2")
	assert_str(t1).contains("roll 3D6")
	assert_str(t1).contains("Each 6 places one new Contact marker")
	var later := str(Guide.round_end_prompts(3, _mission("mess_me_up")))
	assert_str(later).not_contains("Reveal Spawn Point")
	assert_str(later).contains("If any die is a 6")
	assert_str(str(Guide.round_end_prompts(1, _mission("mess_me_up", 0)))) \
		.override_failure_message("p.199: Spawn Rating 0 means no Spawn Points") \
		.not_contains("Spawn Points")


# ── the consumer: the SCREEN shows it ────────────────────────────────────────────

func test_a_bug_hunt_battle_shows_the_bug_hunt_card() -> void:
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui._stored_mission_data = _mission("mega_violence")
	var card: Control = ui._build_battle_card()
	assert_object(card).is_not_null()
	auto_free(card)
	var text := _labels(card)
	assert_str(text).contains("BUG HUNT BATTLE CARD")
	assert_str(text).contains("Spawn Rating 2")
	assert_str(text).not_contains("Core Rules p.90")


func test_the_end_phase_carries_the_bug_hunt_round_prompts() -> void:
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui._stored_mission_data = _mission("mess_me_up")
	ui._is_bug_hunt_mode = true
	var stub := RoundStub.new()
	auto_free(stub)
	ui.round_tracker = stub
	ui._show_end_phase_ui()
	var text := _labels(ui)
	assert_str(text).override_failure_message("p.193 Beep... Sir? must reach the End Phase") \
		.contains("Start of Round 3")
	assert_str(text).contains("Bug Hunt has no morale")


## The results form used to substitute 8 when the battle tracked no enemies, so a Bug
## Hunt debrief read "/ 8 total" and reported 8 minus the kills as remaining.
func test_an_unknown_enemy_total_is_not_invented() -> void:
	var form = FormClass.new()
	add_child(form)
	auto_free(form)
	form.setup([{"character_name": "Alpha"}], 0, {"battle_mode": "bug_hunt"}, {})
	assert_str(_labels(form)).not_contains("/ 0 total")
	form._enemies_defeated_spin.value = 5
	assert_int(int(form._enemies_defeated_spin.value)) \
		.override_failure_message("an unknown total must not cap the kills").is_equal(5)
	var got: Array = []
	form.results_submitted.connect(func(r: Dictionary) -> void: got.append(r))
	form._on_submit()
	assert_int(int(got[0].get("enemies_remaining", -1))).is_equal(0)


# ── MG-10: Signals roll once per mission ─────────────────────────────────────────

func test_signals_are_rolled_once_per_mission() -> void:
	var dm: Node = get_tree().root.get_node_or_null("/root/DiceManager")
	assert_object(dm).is_not_null()
	var core = CoreScript.new()
	core.campaign_name = "T"
	var panel: Control = MissionPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel._generate_mission()
	var check: CheckBox = null
	for n in panel.find_children("*", "CheckBox", true, false):
		if (n as CheckBox).text == "Use Signals rule this mission":
			check = n
	assert_object(check).is_not_null()
	dm.queue_forced_result("Bug Hunt Signals", 2)
	dm.queue_forced_result("Bug Hunt Signals", 5)
	check.button_pressed = true
	assert_int(int(panel._mission_context.signals_total)).is_equal(2)
	check.button_pressed = false
	check.button_pressed = true
	assert_int(int(panel._mission_context.signals_total)) \
		.override_failure_message("p.208 Signals must not re-roll on a re-toggle") \
		.is_equal(2)
	# Drain the unconsumed forced roll so it cannot leak into another case.
	dm.roll_d6("Bug Hunt Signals: drain")


## Co-op (Compendium p.210). The card computes a Numbers line, a movement line and an Evac
## block, and a sector's Factors overrule parts of them: Swarming adds an enemy per
## revealed Contact, Hot zone stops the drop ship loitering, Obstructed removes its covering
## fire, and a patrolled sector adds +1 to the Aggression die. The card printed those
## Factors only in a separate co-op row, so it stated a numbers line, a loiter rule and
## covering fire that the sector had overruled. The stamp is built here by the real
## producer, BugHuntCoopCampaign.battle_modifiers().
func test_a_coop_sectors_factors_rewrite_the_lines_they_overrule() -> void:
	const CoopRef = preload("res://src/core/campaign/BugHuntCoopCampaign.gd")
	var coop: Dictionary = CoopRef.normalize({"enabled": true, "players": ["Ana"],
		"sectors": [{"id": "s1", "name": "Sector 1", "priority": 3,
			"factors": ["swarming", "hot_zone", "obstructed"], "conditions": ["patrolled"]}]})
	var mods: Dictionary = CoopRef.battle_modifiers(coop, "s1")
	assert_int((mods.get("factors", []) as Array).size()).override_failure_message(
		"premise: the sector keeps its three Factors").is_equal(3)
	var plain := _mission("mess_me_up")
	var md := plain.duplicate(true)
	md["coop"] = {"sector_id": "s1", "sector_name": "Sector 1", "modifiers": mods}
	var rows: Dictionary = {}
	for row in Guide.briefing_rows(md):
		rows[str(row.head)] = str(row.detail)
	var detail_of := func(prefix: String) -> String:
		for head: String in rows:
			if head.begins_with(prefix):
				return rows[head]
		return ""
	var reveal: String = detail_of.call("Detecting a Contact")
	var movement: String = detail_of.call("Contact movement")
	var evac: String = detail_of.call("Evac:")
	assert_str(reveal).contains("the number of enemies is increased by +1")
	assert_str(movement).contains("add +1 to the Aggression die")
	assert_str(evac).contains("The evac ship cannot loiter")
	assert_str(evac).contains("Evac ships cannot provide covering fire")
	assert_str(evac).not_contains("the drop ship leaves and you must call again")
	# Outside co-op the card is unchanged.
	var plain_text := _mission_text(plain)
	assert_str(plain_text).contains("the drop ship leaves and you must call again")
	assert_str(plain_text).not_contains("cannot loiter")
