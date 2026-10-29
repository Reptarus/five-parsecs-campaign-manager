extends GdUnitTestSuite
## Planetfall markers rolled during play: a Delve's Hazards (p.130), Traps (p.131),
## Environmental Hazards (p.132) and Devices (p.133), an Investigation's Discovery markers
## (p.115), and each Sleeper's weapon (p.154).
##
## ⚠ Before 2026-10-28 data/planetfall/delve_system.json had no reader and the Sleeper's
## weapon die was rolled only by PlanetfallMissionSetup.roll_sleeper_weapon(), which
## nothing called: a Delve showed one Sleeper stat line and none of its tables.

const Guide = preload("res://src/core/battle/PlanetfallBattleGuide.gd")
const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

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


func _force(key: String, values: Array) -> void:
	for v in values:
		_dm.queue_forced_result(key, v)


func _text(r: Dictionary) -> String:
	return "\n".join(r.get("lines", []).map(func(x): return str(x)))


## p.130 1-2 Enemy: a Sleeper, armed by its own die (p.154: 6 Heavy beam weapon).
func test_a_hazard_of_1_places_an_armed_sleeper() -> void:
	_force("Planetfall Delve Hazard", [1])
	_force("Planetfall Sleeper Weapon", [6])
	var t := _text(Guide.reveal_delve_hazard())
	assert_str(t).contains("Delve Hazard D6 1: Enemy")
	assert_str(t).contains("Heavy beam weapon, Range 18\", Shots 2, Damage 1")


## p.130 3-4 Trap -> p.131 47-60 Sleepers!: "Randomly place 2 Sleepers", each armed.
func test_a_trap_of_sleepers_arms_both() -> void:
	_force("Planetfall Delve Hazard", [3])
	_force("Planetfall Delve Trap", [47])
	_force("Planetfall Sleeper Weapon", [1, 6])
	var t := _text(Guide.reveal_delve_hazard())
	assert_str(t).contains("Delve Trap D100 47: Sleepers!")
	assert_str(t).contains("Weapon D6 1: Beam weapon")
	assert_str(t).contains("Weapon D6 6: Heavy beam weapon")


## p.130 5-6 -> p.132 89-00 Radiation build-up.
func test_a_hazard_of_6_rolls_the_environmental_table() -> void:
	_force("Planetfall Delve Hazard", [6])
	_force("Planetfall Environmental Hazard", [89])
	assert_str(_text(Guide.reveal_delve_hazard())) \
		.contains("Environmental Hazard D100 89: Radiation build-up")


## p.133: "If you roll a result you have already had, take the first result you have not."
func test_a_repeated_device_result_takes_the_first_not_had() -> void:
	var state: Dictionary = Guide.new_mission_tools_state()
	_force("Planetfall Delve Device", [4, 5])
	assert_str(_text(Guide.roll_delve_device(state))).contains("Automatic activation")
	assert_str(_text(Guide.roll_delve_device(state))).contains("already had") \
		.contains("Unusable")
	assert_array(state.devices).contains_exactly(["automatic", "unusable"])


## p.133: three activations unlock the Artifact, "placed 2D6" randomly from the center".
func test_three_activations_unlock_the_artifact() -> void:
	var state: Dictionary = Guide.new_mission_tools_state()
	_force("Planetfall Delve Device", [2, 4, 6])
	for _i in range(3):
		Guide.roll_delve_device(state)
	_force("Planetfall Delve Artifact Site", [7])
	Guide.record_device_activation(state)
	Guide.record_device_activation(state)
	var t := _text(Guide.record_device_activation(state))
	assert_str(t).contains("3 of 3").contains("place it 7\" from the center")
	assert_bool(bool(state.artifact_placed)).is_true()


## "not counting an Unusable result": two usable Devices cannot make three activations.
func test_an_unusable_device_never_counts() -> void:
	var state: Dictionary = Guide.new_mission_tools_state()
	_force("Planetfall Delve Device", [1, 2, 4])
	for _i in range(3):
		Guide.roll_delve_device(state)
	Guide.record_device_activation(state)
	Guide.record_device_activation(state)
	assert_str(_text(Guide.record_device_activation(state))).contains("never counts")
	assert_bool(bool(state.artifact_placed)).is_false()


## p.115 1 Enemy: "Place a Sleeper", armed by its die. Four markers, one per quarter.
func test_a_discovery_marker_of_1_places_a_sleeper() -> void:
	var state: Dictionary = Guide.new_mission_tools_state()
	_force("Planetfall Discovery Marker", [1])
	_force("Planetfall Sleeper Weapon", [3])
	var t := _text(Guide.investigate_discovery("investigation", state))
	assert_str(t).contains("Discovery marker 1, D6 1: Enemy").contains("Beam weapon")
	for _i in range(3):
		Guide.investigate_discovery("investigation", state)
	assert_str(_text(Guide.investigate_discovery("investigation", state))) \
		.contains("All four Discovery markers")


func test_the_delve_card_prints_its_tables_and_the_sleeper() -> void:
	var rows: Array = Guide.build_force(null, "delve_hazards", {}, -1).get("rows", [])
	var card: String = "\n".join(rows.map(
			func(r): return "%s %s" % [str(r.get("head", "")), str(r.get("detail", ""))]))
	assert_str(card).contains("Delve Hazard, 1D6").contains("Delve Device, 1D6")
	assert_str(card).contains("Sleeper weapon, 1D6").contains("Rapid Fire")
	assert_str(card).contains("6+ Saving Throw")


## The live entry point: a Delve gets the tools in the Mission Rules drawer, and the next
## battle on the same screen starts over and gets none when it is a Skirmish.
func test_initialize_battle_gives_a_delve_its_tools() -> void:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.roster = [{"id": "c1", "name": "Ash", "class": "trooper", "xp": 0}]
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui.initialize_battle([], [], {"battle_mode": "planetfall", "type": "delve",
		"title": "Delve", "opposition_type": "delve_hazards", "opposition": {}})
	await get_tree().process_frame
	var tools: Node = ui._drawer_bodies["mission"].find_child("PlanetfallMissionTools",
		true, false)
	assert_object(tools).override_failure_message(
		"a Delve's tables are rolled from the Mission Rules drawer").is_not_null()
	_force("Planetfall Delve Device", [6])
	(tools.find_child("RollDevice", true, false) as Button).pressed.emit()
	assert_int((ui._planetfall_tools.devices as Array).size()).is_equal(1)
	assert_int(tools.find_child("MissionToolResults", true, false).get_child_count()) \
		.is_greater(0)
	ui.initialize_battle([], [], {"battle_mode": "planetfall", "type": "skirmish",
		"title": "Skirmish", "opposition_type": "tactical", "opposition": {}})
	await get_tree().process_frame
	assert_bool(ui._planetfall_tools.is_empty()).override_failure_message(
		"the last mission's Devices survived into this one").is_true()
	assert_object(ui._drawer_bodies["mission"].find_child("PlanetfallMissionTools", true,
		false)).is_null()


# ── Uncertain terrain features (pp.137-138) ───────────────────────────────────────

## The briefing's count, verbatim when it is a phrase, plus the one the Uncertain terrain
## features condition adds ("add 1 additional Uncertain feature").
func test_uncertain_feature_counts_follow_the_briefing_and_the_condition() -> void:
	var cond := {"id": "uncertain_terrain_features", "additional_uncertain_features": 1}
	assert_str(Guide.uncertain_feature_text({"uncertain_features": 2})).is_equal("2")
	assert_str(Guide.uncertain_feature_text(
		{"uncertain_features": "1 per table quarter (optional)"})) \
		.is_equal("1 per table quarter (optional)")
	assert_str(Guide.uncertain_feature_text({"uncertain_features": false})).is_equal("")
	assert_str(Guide.uncertain_feature_text({"uncertain_features": 2, "active_condition": cond})) \
		.is_equal("2, +1 for the Uncertain terrain features condition")
	assert_str(Guide.uncertain_feature_text(
		{"uncertain_features": false, "active_condition": cond})) \
		.is_equal("1, from the Uncertain terrain features condition")
	assert_str(Guide.uncertain_feature_text(
		{"uncertain_features": 2, "active_condition": {"id": "fog"}})).is_equal("2")


## "Roll D100 on the table below."
func test_revealing_an_uncertain_feature_rolls_the_d100_table() -> void:
	_force("Planetfall Uncertain Feature", [47, 100])
	assert_str(" ".join(Guide.reveal_uncertain_feature().lines)).contains("D100 47") \
		.contains("Heavy growth (concerning)").contains("place one marker in the center")
	assert_str(" ".join(Guide.reveal_uncertain_feature().lines)).contains("Terrain block")


## A mission with Uncertain features gets a reveal tool and no Sleeper.
func test_initialize_battle_gives_uncertain_features_a_reveal_tool() -> void:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.roster = [{"id": "c1", "name": "Ash", "class": "trooper", "xp": 0}]
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui.initialize_battle([], [], {"battle_mode": "planetfall", "type": "skirmish",
		"title": "Skirmish", "opposition_type": "tactical", "opposition": {},
		"uncertain_features": 2})
	await get_tree().process_frame
	var tools: Node = ui._drawer_bodies["mission"].find_child("PlanetfallMissionTools",
		true, false)
	assert_object(tools).override_failure_message(
		"a mission's Uncertain features are revealed from the Mission Rules drawer") \
		.is_not_null()
	assert_object(tools.find_child("PlaceSleeper", true, false)).is_null()
	_force("Planetfall Uncertain Feature", [90])
	(tools.find_child("RevealUncertain", true, false) as Button).pressed.emit()
	var texts: Array = []
	for lbl in tools.find_child("MissionToolResults", true, false) \
			.find_children("*", "Label", true, false):
		texts.append((lbl as Label).text)
	assert_str(" ".join(texts)).contains("High ground")



# ── The Reference drawer (pp.26-40) ───────────────────────────────────────────────

func _titles(panel: Node) -> Array:
	var out: Array = []
	for s in panel._sections:
		out.append(str(s.get("title", "")))
	return out


func _section_text(panel: Node, title: String) -> String:
	for s in panel._sections:
		if str(s.get("title", "")) == title:
			return str(s.get("content", ""))
	return ""


## p.28: a Planetfall battle reads Planetfall's combat rules, not the Core Rules sheet.
func test_a_planetfall_battle_reads_planetfall_combat_rules() -> void:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.roster = [{"id": "c1", "name": "Ash", "class": "trooper", "xp": 0}]
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui.initialize_battle([], [], {"battle_mode": "planetfall", "type": "skirmish",
		"title": "Skirmish", "opposition_type": "tactical", "opposition": {}})
	await get_tree().process_frame
	var sheet: Node = ui.cheat_sheet_panel
	assert_object(sheet).override_failure_message("premise: the Reference drawer exists") \
		.is_not_null()
	var titles := _titles(sheet)
	assert_array(titles).contains(["Shooting (Planetfall p.37)", "Brawling (Planetfall p.39)",
		"AI Enemy Variations (optional rule, Planetfall pp.32-33)"])
	assert_array(titles).not_contains(["Turn Sequence (pp.112-113)", "Hit Rules (pp.44-46)"])
	assert_str(_section_text(sheet, "Shooting (Planetfall p.37)")) \
		.contains("Target within 6\" and in the open: [b]3+[/b]") \
		.contains("Target in Cover: [b]6+[/b]")
	assert_str(_section_text(sheet, "Saving Throws (Planetfall p.37)")) \
		.contains("Trooper armor: [b]5+[/b]").contains("Soulless (p.20): [b]6+[/b]")
	assert_str(_section_text(sheet, "Battle Round (Planetfall p.28)")) \
		.contains("2. Reaction Roll").contains("Seize the Initiative")
	assert_str(_section_text(sheet, "Imported Characters (Planetfall p.26)")) \
		.contains("1 Kill Point per Luck point").not_contains("Story Points")
	assert_str(_section_text(sheet, "AI Enemy Variations (optional rule, Planetfall pp.32-33)")) \
		.contains("[b]2-4[/b]  Nothing happens").contains("Redeploy").contains("Focus")


## The same panel goes back to the Core Rules sheet for any other battle.
func test_the_reference_drawer_returns_to_the_core_sheet() -> void:
	var sheet: Node = auto_free(load("res://src/ui/components/battle/CheatSheetPanel.gd").new())
	add_child(sheet)
	await get_tree().process_frame
	var core_titles := _titles(sheet)
	assert_array(core_titles).contains(["Turn Sequence (pp.112-113)"])
	sheet.set_rules_mode("planetfall")
	assert_array(_titles(sheet)).not_contains(["Turn Sequence (pp.112-113)"])
	assert_int(sheet._section_bodies.size()).is_equal(_titles(sheet).size())
	# A header and a body per section, and nothing left over from the Core sheet.
	assert_int(sheet._vbox.get_child_count()).is_equal(2 * _titles(sheet).size())
	sheet.set_rules_mode("core")
	assert_array(_titles(sheet)).is_equal(core_titles)


# ── Random Table Setup (pp.143-145) ───────────────────────────────────────────────────

func _labels(node: Node) -> String:
	var texts: Array = []
	for lbl in node.find_children("*", "Label", true, false):
		texts.append((lbl as Label).text)
	return "\n".join(texts)


## Steps 1-4 reach the book tables, and the optional 1D6-3 (p.144) only ever REMOVES
## clusters: "If the result is negative, reduce the total number of clusters".
func test_the_table_setup_rolls_the_book_tables() -> void:
	_force("Planetfall Ground Type", [47])
	_force("Planetfall Cluster Count", [1])
	_force("Planetfall Cluster Type", [17])
	_force("Planetfall Cluster Sub-feature", [52])
	var c: Dictionary = Guide.table_setup_contract(3.0, {}, 7)
	var s: Dictionary = c.get("planetfall_table_setup", {})
	assert_int(int(s.get("clusters_fit", 0))).is_equal(9)
	assert_int((s.get("clusters", []) as Array).size()).override_failure_message(
		"1D6-3 = -2 removes two of the nine 12\" clusters on a 3x3 table (p.144)").is_equal(7)
	var text := "\n".join((c.get("table_setup_lines", []) as Array).map(
		func(x): return str(x)))
	assert_str(text).contains("Ground (D100 47): Plant growth such as grass.")
	assert_str(text).contains("Cluster 1: Foliage (D100 17).")
	assert_str(text).contains("Sub-feature (D100 52): Trees.")
	assert_str(text).contains("Map Adjustments (p.145)")
	# The map stays a plain labelled grid: no piece the dice did not call for.
	assert_int((c.get("sectors", []) as Array).size()).is_equal(16)
	for sector in c.get("sectors", []):
		assert_array((sector as Dictionary).get("features", [])).is_empty()
	_force("Planetfall Cluster Count", [6])
	var small: Dictionary = Guide.table_setup_contract(2.0, {}, 7).get(
		"planetfall_table_setup", {})
	assert_int(int(small.get("clusters_fit", 0))).is_equal(4)
	assert_int((small.get("clusters", []) as Array).size()).override_failure_message(
		"a positive 1D6-3 never adds clusters").is_equal(4)


## A Planetfall battle lays out Planetfall's table, not the 5PFH Compendium generator's,
## and the re-roll refreshes every rolled line, the ground included.
func test_a_planetfall_battle_lays_out_the_planetfall_table() -> void:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.roster = [{"id": "c1", "name": "Ash", "class": "trooper", "xp": 0}]
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	_force("Planetfall Ground Type", [5])
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui.initialize_battle([], [], {"battle_mode": "planetfall", "type": "skirmish",
		"title": "Skirmish", "opposition_type": "tactical", "opposition": {}})
	await get_tree().process_frame
	assert_str(str(ui._battlefield_data.get("theme", ""))).override_failure_message(
		"a Planetfall battle rolls pp.143-145, never the Compendium 5-step") \
		.is_equal("planetfall_table_setup")
	assert_bool(ui._layout_generation_allowed()).override_failure_message(
		"no Compendium Regenerate or per-sector re-roll on a Planetfall table").is_false()
	var box: Node = ui.setup_content.find_child("PlanetfallTableSetup", true, false)
	assert_object(box).override_failure_message(
		"the Setup tab shows the rolled table setup").is_not_null()
	assert_str(_labels(box)).contains("Ground (D100 5): Sand or gravel.")
	_force("Planetfall Ground Type", [99])
	(box.find_child("RerollTableSetup", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_str(_labels(box)).contains("Ground (D100 99): Alien surface") \
		.not_contains("Sand or gravel")
