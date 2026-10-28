extends GdUnitTestSuite

## Planetfall battle delivery: the opposition a mission really fields (pp.117-129,
## pp.148-153) and the Lifeform encounter roll at Contact Reveal (pp.41-42, p.146).
##
## ⚠ Before 2026-10-27 the turn controller handed the battle one literal "Lifeform"
## copied from the first filled encounter entry, one Tactical Enemy figure with no
## weapons, and literal Slyn and Sleeper stat lines. The p.146 encounter roll ran
## nowhere, so the colony's encounter table never filled in play. The Slyn check was
## rolled a step early, so Lock and Load announced "SLYN ATTACKING!" before the player
## chose who to deploy (the book: "After deploying, roll 2D6"), and a Slyn-check mission
## the Slyn stayed away from still fielded Slyn.

const Guide = preload("res://src/core/battle/PlanetfallBattleGuide.gd")
const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const TurnScene = preload("res://src/ui/screens/planetfall/PlanetfallTurnController.tscn")
const MissionPanel = preload("res://src/ui/screens/planetfall/panels/PlanetfallMissionPanel.gd")
const LockAndLoad = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallLockAndLoadPanel.gd")
const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const MISSIONS := "res://data/planetfall/mission_types.json"
const ENEMIES := "res://data/planetfall/tactical_enemies_generation.json"

var _user_state: Dictionary
var _saved_campaign: Variant
var _dm: Node


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")
	_dm.clear_forced_results()


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


# ── fixtures ──────────────────────────────────────────────────────────────────────

func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _mission(id: String) -> Dictionary:
	var data: Dictionary = _json(MISSIONS)
	var missions: Variant = data.get("missions", data)
	if missions is Dictionary:
		var m: Dictionary = (missions[id] as Dictionary).duplicate(true)
		m["id"] = id
		return m
	for m in missions:
		if m is Dictionary and str(m.get("id", "")) == id:
			return (m as Dictionary).duplicate(true)
	return {}


func _enemy_type(id: String) -> Dictionary:
	for t in _json(ENEMIES).enemy_types:
		if str(t.get("id", "")) == id:
			return t
	return {}


func _core(enemy_id: String = "") -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	core.roster = [{"id": "c1", "name": "Ash", "class": "trooper"}]
	core.lifeform_table = []
	for _i in range(10):
		core.lifeform_table.append({})
	if enemy_id != "":
		core.tactical_enemies = [{"type": _enemy_type(enemy_id), "boss_located": false,
			"defeated": false}]
	return core


func _force(key: String, values: Array) -> void:
	for v in values:
		_dm.queue_forced_result(key, v)


func _queued(key: String) -> int:
	return (_dm.get_forced_results().get(key.to_lower(), []) as Array).size()


func _of_role(figures: Array, role: String) -> Array:
	return figures.filter(func(f): return str(f.get("role", "")) == role)


func _creature(kp: int, evolutions: Array = []) -> Dictionary:
	return {"name": "Glasswing", "speed": 6, "combat_skill": 1, "toughness": 4,
		"strike_damage": 0, "kp": kp, "special_attacks": [], "defense_additional": null,
		"unique_ability": {}, "evolutions_applied": evolutions, "generated": true}


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


# ── the Slyn check: rolled after deploying, resolved to what is really fought ─────

## p.117: 2-4 the Slyn attack; "On any other result, the threat is from wildlife".
## p.125 Scout Down!: 2-3, otherwise Tactical Enemies.
func test_a_slyn_check_resolves_to_the_slyn_or_the_missions_own_fallback() -> void:
	_force("Planetfall Slyn Aggression", [3, 7, 3, 4])
	var exploration: Dictionary = _mission("exploration")
	assert_str(str(Guide.resolve_opposition(exploration).type)).is_equal("slyn")
	var calm: Dictionary = Guide.resolve_opposition(exploration)
	assert_str(str(calm.type)).override_failure_message(
		"p.117: no Slyn means wildlife and the Contact system").is_equal("lifeforms")
	assert_bool(bool(calm.slyn_attacking)).is_false()
	var scout_down: Dictionary = _mission("scout_down")
	assert_str(str(Guide.resolve_opposition(scout_down).type)).is_equal("slyn")
	assert_str(str(Guide.resolve_opposition(scout_down).type)).override_failure_message(
		"p.125: 4 is outside Scout Down!'s 2-3, so Tactical Enemies").is_equal("tactical")


func test_a_mission_without_a_slyn_check_rolls_nothing() -> void:
	_force("Planetfall Slyn Aggression", [3])
	assert_str(str(Guide.resolve_opposition(_mission("investigation")).type)) \
		.is_equal("lifeforms")
	assert_int(_queued("Planetfall Slyn Aggression")).is_equal(1)


## "After deploying, roll 2D6": choosing the mission must not roll it. The forced value
## is still queued after the panel confirms, and the panel hands on the raw type.
func test_the_mission_panel_does_not_roll_the_slyn_check() -> void:
	var panel: Control = auto_free(MissionPanel.new())
	add_child(panel)
	panel.set_campaign(_core())
	panel._selected_mission = _mission("patrol")
	var emitted: Array = []
	panel.phase_completed.connect(func(d: Dictionary) -> void: emitted.append(d))
	_force("Planetfall Slyn Aggression", [3])
	panel._on_confirm_pressed()
	assert_int(emitted.size()).is_equal(1)
	assert_str(str(emitted[0].get("opposition_type", ""))).is_equal("slyn_check")
	assert_bool(emitted[0].has("slyn_attacking")).is_false()
	assert_int(_queued("Planetfall Slyn Aggression")).override_failure_message(
		"the Slyn check was rolled when the mission was chosen").is_equal(1)


# ── the Tactical Enemy force (pp.149-151) ─────────────────────────────────────────

## One specialist always, a leader at 6 or more (one of the figures), the rest grunts.
## The specialist weapon REPLACES the grunt weapon; leaders carry both.
func test_the_tactical_force_follows_pp149_to_151() -> void:
	var core := _core("outlaws")
	_force("Planetfall Enemy Number D3", [3, 3])
	_force("Planetfall Enemy Grunt Weapons", [4])
	_force("Planetfall Enemy Specialist Weapons", [5])
	_force("Planetfall Enemy Leader Weapons", [6])
	var force: Dictionary = Guide.build_force(core, "tactical", {}, 0)
	var figures: Array = force.enemies
	assert_int(figures.size()).override_failure_message("2D3+3 rolled 3,3 is 9") \
		.is_equal(9)
	assert_int(_of_role(figures, "specialist").size()).is_equal(1)
	assert_int(_of_role(figures, "leader").size()).is_equal(1)
	assert_int(_of_role(figures, "grunt").size()).is_equal(7)
	assert_int(int(_of_role(figures, "leader")[0].kp)).is_equal(1)
	var spec: Array = _of_role(figures, "specialist")[0].weapons
	assert_int(spec.size()).is_equal(1)
	assert_str(str(spec[0])).starts_with("Rattle gun")
	var leader: String = " ".join(_of_role(figures, "leader")[0].weapons)
	assert_str(leader).contains("Military rifle").contains("Shotgun")
	assert_str(str(force.enemy_type)).is_equal("Outlaws")


## p.149: a split Combat Skill's second value is for leaders AND specialists; a split
## Toughness's second value for the leader only.
func test_split_values_go_to_the_right_figures() -> void:
	_force("Planetfall Enemy Number D3", [1])
	var figures: Array = Guide.build_force(_core("nomad_patrol"), "tactical", {}, 0).enemies
	assert_int(figures.size()).is_equal(6)
	var spec: Dictionary = _of_role(figures, "specialist")[0]
	var leader: Dictionary = _of_role(figures, "leader")[0]
	var grunt: Dictionary = _of_role(figures, "grunt")[0]
	assert_array([spec.combat_skill, spec.toughness]).is_equal([1, 3])
	assert_array([leader.combat_skill, leader.toughness]).is_equal([1, 4])
	assert_array([grunt.combat_skill, grunt.toughness]).is_equal([0, 3])


## p.126 Pitched Battle: two forces, one at -1 and one at +1.
func test_a_pitched_battle_fields_two_forces() -> void:
	_force("Planetfall Enemy Number D3", [1, 1, 1, 1])
	var force: Dictionary = Guide.build_force(_core("outlaws"), "tactical",
		_mission("pitched_battle").opposition, 0)
	assert_int(force.enemies.size()).override_failure_message("5-1 and 5+1").is_equal(10)
	assert_int(_of_role(force.enemies, "leader").size()).override_failure_message(
		"only the 6-figure force reaches the leader threshold").is_equal(1)


## p.129 Assault: the maximum encounter size, plus 2 regular, 2 specialists and a leader
## with +1 KP. Nothing is rolled for the number.
func test_an_assault_starts_at_the_maximum_and_adds_its_extras() -> void:
	_force("Planetfall Enemy Number D3", [1])
	var force: Dictionary = Guide.build_force(_core("outlaws"), "tactical",
		_mission("assault").opposition, 0)
	assert_int(force.enemies.size()).is_equal(9 + 2 + 2 + 1)
	assert_int(_of_role(force.enemies, "specialist").size()).is_equal(3)
	var kps: Array = _of_role(force.enemies, "leader").map(func(f): return int(f.kp))
	kps.sort()
	assert_array(kps).is_equal([1, 2])
	assert_int(_queued("Planetfall Enemy Number D3")).override_failure_message(
		"an Assault rolled its number").is_equal(1)


## p.149 Bosses: 2 KP, +1 Combat Skill and Toughness; p.150 K'Erin Champion: leaders 2 KP,
## Bosses 3 KP. A Boss is a leader, so it takes the split Toughness's second value.
func test_a_strike_on_a_located_boss_adds_the_boss() -> void:
	var core := _core("kerin_landing_party")
	core.tactical_enemies[0].boss_located = true
	_force("Planetfall Enemy Number D3", [3])
	var force: Dictionary = Guide.build_force(core, "tactical", _mission("strike").opposition, 0)
	var bosses: Array = _of_role(force.enemies, "boss")
	assert_int(bosses.size()).is_equal(1)
	assert_array([bosses[0].kp, bosses[0].combat_skill, bosses[0].toughness]) \
		.is_equal([3, 2, 6])
	assert_int(int(_of_role(force.enemies, "leader")[0].kp)).is_equal(2)
	assert_int(force.enemies.size()).override_failure_message(
		"1D3+4 rolled 3, +2 for a Strike, + the Boss").is_equal(10)


## p.125: with no Tactical Enemy on the map, one is rolled for this battle only.
func test_scout_down_without_an_enemy_rolls_one_that_is_not_added() -> void:
	var core := _core()
	_force("Planetfall Tactical Enemy Type", [1])
	var force: Dictionary = Guide.build_force(core, "tactical", {}, -1)
	assert_str(str(force.enemy_type)).is_equal("Outlaws")
	assert_bool(force.enemies.is_empty()).is_false()
	assert_int(core.tactical_enemies.size()).is_equal(0)


## p.153: "6 or 8 individuals formed into 3 or 4 pairs", with the pair rules.
func test_the_slyn_force_is_sized_and_carries_its_rules() -> void:
	_force("Planetfall Slyn Encounter Size", [5])
	var force: Dictionary = Guide.build_force(_core(), "slyn", {}, -1)
	assert_int(force.enemies.size()).is_equal(8)
	assert_array([force.enemies[0].combat_skill, force.enemies[0].toughness]) \
		.is_equal([1, 4])
	var heads: String = "\n".join(force.rows.map(func(r): return str(r.head)))
	assert_str(heads).contains("4 pairs").contains("Slyn pairs").contains("Withdrawal")


# ── the encounter roll (p.146) ────────────────────────────────────────────────────

## The first hostile reveal rolls the table and fixes the creature; later ones are more
## of it, with no second D100.
func test_the_first_reveal_fixes_the_missions_creature() -> void:
	var core := _core()
	var state: Dictionary = Guide.new_encounter_state()
	_force("Planetfall Lifeform Encounter", [20])
	var first: Dictionary = Guide.encounter_lifeform(core, state)
	assert_int(int(first.slot)).override_failure_message("D100 20 is entry 2") \
		.is_equal(1)
	assert_bool(bool(first.new)).is_true()
	assert_bool(core.lifeform_table[1].is_empty()).override_failure_message(
		"a blank entry is generated and recorded on the colony's table").is_false()
	_force("Planetfall Lifeform Encounter", [1])
	var second: Dictionary = Guide.encounter_lifeform(core, state)
	assert_int(int(second.slot)).is_equal(1)
	assert_int(_queued("Planetfall Lifeform Encounter")).is_equal(1)
	assert_int(Guide.known_lifeforms(core).size()).is_equal(1)


func test_the_sixth_lifeform_is_the_pack_leader() -> void:
	var core := _core()
	core.lifeform_table[0] = _creature(1)
	var state: Dictionary = Guide.new_encounter_state()
	_force("Planetfall Lifeform Encounter", [1])
	var kps: Array = []
	for _i in range(7):
		kps.append(int(Guide.encounter_lifeform(core, state).kp))
	assert_array(kps).is_equal([1, 1, 1, 1, 1, 3, 1])


## p.160: Bigger Leaders makes the 4th a secondary leader (+1) and the 6th +3; Tougher
## Specimens rolls a D6 per creature placed, 5-6 is +1 KP.
func test_bigger_leaders_and_tougher_specimens() -> void:
	var core := _core()
	core.lifeform_table[0] = _creature(0, ["bigger_leaders", "tougher_specimens"])
	var state: Dictionary = Guide.new_encounter_state()
	_force("Planetfall Lifeform Encounter", [1])
	_force("Planetfall Tougher Specimens", [1, 1, 1, 1, 1, 5])
	var kps: Array = []
	for _i in range(6):
		kps.append(int(Guide.encounter_lifeform(core, state).kp))
	assert_array(kps).is_equal([0, 0, 0, 1, 0, 4])


func test_contact_reveal_follows_the_p42_table() -> void:
	var core := _core()
	core.lifeform_table[0] = _creature(1)
	var state: Dictionary = Guide.new_encounter_state()
	_force("Planetfall Lifeform Encounter", [1])
	_force("Planetfall Contact Reveal", [6, 3, 1])
	var two: Dictionary = Guide.reveal_contact(core, state)
	assert_int(two.lifeforms.size()).is_equal(2)
	assert_int(int(state.encountered)).is_equal(2)
	var more: Dictionary = Guide.reveal_contact(core, state)
	assert_int(int(more.new_contacts)).is_equal(2)
	assert_bool(more.lifeforms.is_empty()).is_true()
	assert_bool(Guide.reveal_contact(core, state).lifeforms.is_empty()).is_true()


## p.121 Hunt: a scout on 1D6+Savvy 5+ "can choose which Lifeform you are facing".
func test_a_hunt_scouts_choice_fixes_the_creature_without_a_roll() -> void:
	var core := _core()
	core.lifeform_table[4] = _creature(1)
	var state: Dictionary = Guide.new_encounter_state()
	_force("Planetfall Lifeform Encounter", [1])
	assert_int(int(Guide.encounter_lifeform(core, state, 4).slot)).is_equal(4)
	assert_int(_queued("Planetfall Lifeform Encounter")).is_equal(1)


## p.159 Dramatic Transformations: a fresh Unique Ability "each battle", one per battle.
func test_dramatic_transformations_roll_once_per_battle() -> void:
	var core := _core()
	var lf := _creature(1, ["dramatic_transformations"])
	lf["unique_ability_each_battle"] = true
	core.lifeform_table[0] = lf
	var state: Dictionary = Guide.new_encounter_state()
	_force("Planetfall Lifeform Encounter", [1])
	_force("Planetfall Lifeform Unique Ability", [1, 100])
	var a: Dictionary = Guide.encounter_lifeform(core, state)
	var b: Dictionary = Guide.encounter_lifeform(core, state)
	assert_that(b.lifeform.unique_ability).is_equal(a.lifeform.unique_ability)
	assert_int(_queued("Planetfall Lifeform Unique Ability")).is_equal(1)


# ── the screens: the turn controller's payload and the battle card ────────────────

func _tc(core: Resource) -> Control:
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	var tc: Control = TurnScene.instantiate()
	add_child(tc)
	auto_free(tc)
	await get_tree().process_frame
	await get_tree().process_frame
	return tc


## What Step 8 hands the battle and stamps on the turn is the guide's force, not the
## deleted literals.
func test_the_turn_controller_payload_carries_the_force_and_the_stamp() -> void:
	var core := _core("outlaws")
	var tc: Control = await _tc(core)
	tc._mission_context = _mission("skirmish")
	tc._deployed_data = {"deployed_characters": {"c1": {"weapon_id": ""}}}
	_force("Planetfall Enemy Number D3", [3, 3])
	var payload: Dictionary = tc.build_battle_payload()
	assert_int(payload.context.enemies.size()).is_equal(9)
	assert_str(str(payload.stamp.enemy_type)).is_equal("Outlaws")
	assert_int(int(payload.stamp.tactical_enemy_index)).is_equal(0)
	var md: Dictionary = payload.context.mission_data
	assert_str(str(md.opposition_type)).is_equal("tactical")
	assert_bool((md.opposition_force_rows as Array).is_empty()).is_false()


## A Skirmish against the second enemy's sector fights THAT enemy (pp.123-124), and the
## sector picked at Step 6 is stamped for Step 12's map effects.
func test_the_stamp_carries_the_sector_and_its_enemy() -> void:
	var core := _core("outlaws")
	core.tactical_enemies.append({"type": _enemy_type("outlaws"), "boss_located": false,
		"defeated": false})
	var tc: Control = await _tc(core)
	var mission := _mission("skirmish")
	mission["sector"] = "0,1"
	mission["site_enemy_index"] = 1
	tc._mission_context = mission
	tc._deployed_data = {"deployed_characters": {"c1": {"weapon_id": ""}}}
	_force("Planetfall Enemy Number D3", [3, 3])
	var payload: Dictionary = tc.build_battle_payload()
	assert_str(str(payload.stamp.sector)).is_equal("0,1")
	assert_int(int(payload.stamp.tactical_enemy_index)).override_failure_message(
		"the battle fought the first enemy, not the one holding the sector").is_equal(1)


## The weapon picked at Step 7 reaches the battle screen's quick roll as a weapon row
## (pp.75-76). It used to arrive as `assigned_weapon`, an id nothing read, so every
## Planetfall shot was rolled as the quick roll's fallback rifle.
func test_the_deployed_weapon_reaches_the_quick_roll() -> void:
	var core := _core("outlaws")
	var tc: Control = await _tc(core)
	tc._mission_context = _mission("skirmish")
	tc._deployed_data = {"deployed_characters": {"c1": {"weapon_id": "handgun"}}}
	_force("Planetfall Enemy Number D3", [3, 3])
	var crew: Array = tc.build_battle_payload().context.crew
	assert_int(crew.size()).override_failure_message("premise: Ash deployed").is_equal(1)
	assert_str(str(crew[0].assigned_weapon)).is_equal("handgun")
	var quick: Node = load("res://src/ui/components/battle/CharacterQuickRollPanel.gd").new()
	add_child(quick)
	auto_free(quick)
	quick.set_crew(crew)
	quick.select_character("Ash")
	var weapon: Dictionary = quick._equipped_weapon()
	assert_int(int(weapon.get("range", 0))).override_failure_message(
		"the quick roll found no weapon on a Planetfall figure").is_equal(6)
	assert_bool(quick._weapon_is_pistol(weapon)).override_failure_message(
		"the Handgun's pistol trait did not reach the battle").is_true()


func test_a_slyn_attack_is_what_the_turn_controller_stamps() -> void:
	var tc: Control = await _tc(_core())
	tc._mission_context = _mission("exploration")
	tc._deployed_data = {}
	_force("Planetfall Slyn Aggression", [2])
	_force("Planetfall Slyn Encounter Size", [1])
	var payload: Dictionary = tc.build_battle_payload()
	assert_str(str(payload.stamp.opposition_type)).is_equal("slyn")
	assert_int(payload.context.enemies.size()).is_equal(6)
	assert_str(str(payload.context.mission_data.opposition_force_rows[0].head)) \
		.contains("2D6 2")


func test_a_planetfall_battle_shows_the_planetfall_card() -> void:
	var core := _core("outlaws")
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	_force("Planetfall Enemy Number D3", [1, 1])
	var force: Dictionary = Guide.build_force(core, "tactical", {}, 0)
	var md: Dictionary = {"battle_mode": "planetfall", "opposition_type": "tactical",
		"opposition": _mission("skirmish").opposition,
		"opposition_force_rows": force.rows}
	ui._stored_mission_data = md
	var card: Control = ui._build_battle_card()
	assert_object(card).is_not_null()
	auto_free(card)
	var text := _labels(card)
	assert_str(text).contains("PLANETFALL BATTLE CARD").contains("Outlaws: 5 figures")
	assert_str(text).not_contains("Core Rules p.90")
	assert_str(text).override_failure_message(
		"p.117: Contacts are the wildlife battle's system, not a Tactical Enemy's") 		.not_contains("Contact Reveal")
	ui._stored_mission_data = {"battle_mode": "planetfall", "opposition_type": "lifeforms",
		"opposition": _mission("investigation").opposition}
	var wild: Control = auto_free(ui._build_battle_card())
	assert_str(_labels(wild)).contains("Contact Reveal, D6").contains("First Contact")


## The reveal controls live in the Mission Rules drawer and write the colony's table.
func test_the_contact_panel_reveals_into_the_drawer_and_the_table() -> void:
	var core := _core()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui._setup_planetfall_contact_panel({"opposition_type": "lifeforms",
		"opposition": _mission("investigation").opposition})
	var panel: Node = ui._drawer_bodies["mission"].find_child("PlanetfallContacts", true,
		false)
	assert_object(panel).override_failure_message(
		"the panel is in the Mission Rules drawer").is_not_null()
	assert_bool(ui._mission_drawer_used).is_true()
	_force("Planetfall Contact Reveal", [4])
	_force("Planetfall Lifeform Encounter", [1])
	(panel.find_child("RevealContact", true, false) as Button).pressed.emit()
	var results: Node = panel.find_child("EncounterResults", true, false)
	assert_int(results.get_child_count()).is_greater(1)
	assert_bool(core.lifeform_table[0].is_empty()).override_failure_message(
		"the revealed creature is recorded on the colony's table").is_false()


## The live entry point, not the builder: a wildlife battle gets the Contacts panel in
## the Mission Rules drawer, and the next battle on the same screen starts its count
## over and gets no panel when it fights Tactical Enemies.
func test_initialize_battle_gives_a_wildlife_battle_the_contacts_panel() -> void:
	var core := _core()
	core.lifeform_table[0] = _creature(1)
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	gs.current_campaign = core
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui.initialize_battle([], [], {"battle_mode": "planetfall", "title": "Investigation",
		"opposition_type": "lifeforms", "opposition": _mission("investigation").opposition})
	await get_tree().process_frame
	var body: Node = ui._drawer_bodies["mission"]
	assert_object(body.find_child("PlanetfallContacts", true, false)).is_not_null()
	_force("Planetfall Lifeform Encounter", [1])
	_force("Planetfall Contact Reveal", [4])
	(body.find_child("RevealContact", true, false) as Button).pressed.emit()
	assert_int(int(ui._planetfall_encounters.encountered)).is_equal(1)
	ui.initialize_battle([], [], {"battle_mode": "planetfall", "title": "Skirmish",
		"opposition_type": "tactical", "opposition": _mission("skirmish").opposition})
	await get_tree().process_frame
	assert_bool(ui._planetfall_encounters.is_empty()).override_failure_message(
		"p.146 counts during A mission; the last mission's count survived").is_true()
	assert_object(ui._drawer_bodies["mission"].find_child("PlanetfallContacts", true,
		false)).is_null()


## "After deploying, roll 2D6": Lock and Load names the roll, never a result.
func test_lock_and_load_says_the_slyn_check_comes_after_deployment() -> void:
	var panel: Control = auto_free(LockAndLoad.new())
	add_child(panel)
	panel.set_campaign(_core())
	panel.set_mission_context({"selected_mission": _mission("patrol"),
		"opposition_type": "slyn_check"})
	panel.refresh()
	var text := _labels(panel._mission_info_section)
	assert_str(text).contains("rolled after you deploy").contains("2D6 2-4")
	assert_str(text).not_contains("SLYN ATTACKING")
