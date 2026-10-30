extends GdUnitTestSuite
## A new Rival has one producer, RivalContact, and the crew-task Rival rules ride on it.
##
## Until 2026-10-29 the crew-task Rival (Core Rules p.79 Contraband, p.81 Pick a
## fight) was a "Rival N" of one of five invented types with invented hostility and
## resources, handed to NPCTracker, a HISTORY tracker. It never reached
## campaign.rivals, so it never attacked (p.85) and never showed on the Rivals screen.
## Creation Rivals and Patrons came from invented type lists too. p.81 "Got yourself
## noticed" ADDED a Rival where the book forces a fight with one you already have;
## the K'Erin "-1 enemy the first time you meet them" was shown and applied nowhere;
## and a K'Erin went to Sick Bay on the p.80 row the book says they ignore, because
## the table's "K'Erin" never matched the enum key "KERIN".
##
## Every case reads where the damage lands: the campaign's own list, the forced
## battle flag, the enemy count, the card a player reads.

const RivalContactScript = preload("res://src/core/campaign/RivalContact.gd")
const RivalCheckScript = preload("res://src/core/campaign/RivalEncounterCheck.gd")
const EnemyGeneratorScript = preload("res://src/core/systems/EnemyGenerator.gd")
const CampaignCoreScript = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const CrewTaskComponentScript = preload(
	"res://src/ui/screens/world/components/CrewTaskComponent.gd")
const CampaignTurnControllerScript = preload(
	"res://src/ui/screens/campaign/CampaignTurnController.gd")
const PostBattleContextScript = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const DashboardScript = preload("res://src/ui/screens/campaign/CampaignDashboard.gd")
const NPCTrackerScript = preload("res://src/core/campaign/NPCTracker.gd")
const CharacterGenerationScript = preload("res://src/core/character/CharacterGeneration.gd")
const TransferServiceScript = preload("res://src/core/character/CharacterTransferService.gd")
const FactionSystemScript = preload("res://src/core/systems/FactionSystem.gd")
const PatronJobEffectsScript = preload("res://src/core/patrons/PatronJobEffects.gd")
const EXPLORATION_JSON := "res://data/campaign_tables/crew_tasks/exploration_events.json"

## The keys every new Rival carries, and nothing a book never gave one.
const SHAPE := ["id", "name", "type", "planet_id", "threat_level", "created_turn", "origin"]

var _prior_campaign: Resource = null
var _prior_tracker: Dictionary = {}


func before_test() -> void:
	_prior_campaign = GameState.current_campaign
	_prior_tracker = NPCTracker.serialize()
	var campaign = CampaignCoreScript.new()
	campaign.from_dictionary({"campaign_id": "rival_contact_suite"})
	GameState.current_campaign = campaign


func after_test() -> void:
	DiceManager.clear_forced_results("Got Yourself Noticed")
	DiceManager.clear_forced_results("Encounter Category")
	DiceManager.clear_forced_results("Encounter Enemy Type")
	NPCTracker.deserialize(_prior_tracker)
	GameState.current_campaign = _prior_campaign


func _campaign():
	return GameState.current_campaign


func _comp():
	var c = auto_free(CrewTaskComponentScript.new())
	add_child(c)
	return c


## A table row exactly as the live loader builds it, so a key the loader drops is a
## key the case loses too.
func _row(comp, row_name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXPLORATION_JSON))
	for entry in (parsed as Dictionary).get("results", []):
		if str((entry as Dictionary).get("name", "")) == row_name:
			return comp._build_result_from_json(entry)
	return {}


func _base(member: Dictionary) -> Dictionary:
	return {"crew_id": "c1", "crew_name": "Ila", "crew_member": member,
		"task_type": "Explore", "event_name": "Test", "effect_text": "",
		"table_result": {}, "result_ref": {"task_id": "explore"}}


# ── The one producer ─────────────────────────────────────────────────────────

func test_an_unnamed_rival_rolls_a_real_enemy_type_and_is_named_by_it() -> void:
	for _i in 12:
		var rival: Dictionary = RivalContactScript.make("crew_task")
		assert_bool(EnemyGeneratorScript.is_known_enemy_type(str(rival["type"]))) \
			.override_failure_message("'%s' is not an enemy type" % rival["type"]).is_true()
		assert_str(str(rival["name"])).is_equal(str(rival["type"]))
		# p.92's second roll rides along when it differs (see the pick cases below).
		var keys: Array = rival.keys()
		keys.erase("type_alternative")
		assert_array(keys).contains_exactly_in_any_order(SHAPE)


func test_a_rival_that_names_an_enemy_type_keeps_it() -> void:
	## p.92: "Once a Rival has been established, they will always be the same type."
	var rival: Dictionary = RivalContactScript.make("planetfall_independence_lost",
		"Bounty Hunters")
	assert_str(str(rival["type"])).is_equal("Bounty Hunters")
	assert_str(str(rival["name"])).is_equal("Bounty Hunters")


func test_a_rider_is_written_only_when_a_rule_gives_one() -> void:
	assert_bool(RivalContactScript.make("x").has("first_battle_enemy_modifier")).is_false()
	var rider: Dictionary = RivalContactScript.make("x", "", {"first_battle_enemy_modifier": -1})
	assert_int(int(rider["first_battle_enemy_modifier"])).is_equal(-1)


# ── p.79 / p.81: a crew task Rival reaches the campaign ──────────────────────

func test_a_crew_task_rival_lands_on_the_campaign_not_the_tracker() -> void:
	var tracked_before: int = NPCTracker.rivals.size()
	_comp()._apply_rival({})
	var rivals: Array = _campaign().rivals
	assert_int(rivals.size()).override_failure_message(
		"the Rival never reached campaign.rivals, so p.85 can never roll it").is_equal(1)
	var rival: Dictionary = rivals[0]
	assert_str(str(rival["origin"])).is_equal("crew_task")
	assert_bool(EnemyGeneratorScript.is_known_enemy_type(str(rival["type"]))).is_true()
	assert_bool(rival.has("hostility") or rival.has("resources")).is_false()
	assert_int(NPCTracker.rivals.size()).is_equal(tracked_before)


func test_the_kerin_rider_is_set_only_when_a_kerin_picks_the_fight() -> void:
	var comp = _comp()
	var row: Dictionary = _row(comp, "Pick a fight")
	assert_bool(row.is_empty()).override_failure_message("premise: the p.81 row loads").is_false()
	var kerin := {"origin": "KERIN"}
	var human := {"origin": "HUMAN"}
	var for_kerin: Array = comp._classify_result(_base(kerin), row, kerin)
	var for_human: Array = comp._classify_result(_base(human), row, human)
	assert_bool(bool(for_kerin[0].get("kerin_rider", false))).is_true()
	assert_bool(bool(for_human[0].get("kerin_rider", false))).is_false()
	comp._apply_rival(for_kerin[0])
	comp._apply_rival(for_human[0])
	var rivals: Array = _campaign().rivals
	assert_int(int((rivals[0] as Dictionary).get("first_battle_enemy_modifier", 0))).is_equal(-1)
	assert_bool((rivals[1] as Dictionary).has("first_battle_enemy_modifier")).is_false()


func test_a_kerin_ignores_the_bad_food_row() -> void:
	## p.80 rows 7-8: "Soulless and K'Erin ignore this event."
	var comp = _comp()
	var row := {"immune_species": ["Soulless", "K'Erin"]}
	assert_bool(comp._check_species_immunity(row, {"origin": "KERIN"})).is_true()
	assert_bool(comp._check_species_immunity(row, {"origin": "SOULLESS"})).is_true()
	assert_bool(comp._check_species_immunity(row, {"origin": "HUMAN"})).is_false()


# ── p.81 Got yourself noticed: fight an existing Rival, add none ─────────────

func test_got_yourself_noticed_forces_an_existing_rival_and_creates_none() -> void:
	## Six Rivals, each forced in turn: a pick that ignored the QA seam would match
	## every target by chance (1/6)^6 of the time, where two Rivals passed half the
	## time and hid a roll_custom() that never consults the seam at all.
	var listed: Array = ["Ganger boss"]
	for i in range(2, 7):
		listed.append({"id": "r%d" % i, "name": "Rival %d" % i, "type": "Gangers"})
	_campaign().rivals = listed
	var comp = _comp()
	var row: Dictionary = _row(comp, "Got yourself noticed")
	var events: Array = []
	for target in range(1, 7):
		assert_bool(DiceManager.queue_forced_result("Got Yourself Noticed", target)).is_true()
		events = comp._classify_result(_base({}), row, {})
		assert_int(events.size()).is_equal(1)
		assert_int(int(events[0]["type"])).is_equal(
			CrewTaskEventDialog.EventType.FORCED_RIVAL_BATTLE)
		assert_str(str(events[0].get("forced_rival_id", ""))).is_equal(
			RivalCheckScript.rival_id_of(listed[target - 1]))
	comp._auto_resolve_event(events[0])
	var pd: Dictionary = _campaign().progress_data
	assert_str(str(pd.get("forced_rival_battle", ""))).is_equal("r6")
	assert_str(str(pd.get("forced_rival_cite", ""))).contains("p.81")
	assert_int(_campaign().rivals.size()).override_failure_message(
		"p.81 picks a Rival you have; it must not add one").is_equal(6)


func test_with_no_rivals_nobody_comes_after_you() -> void:
	var comp = _comp()
	var events: Array = comp._classify_result(_base({}), _row(comp, "Got yourself noticed"), {})
	assert_bool(events[0].has("forced_rival_id")).is_false()
	comp._auto_resolve_event(events[0])
	assert_bool(_campaign().progress_data.has("forced_rival_battle")).is_false()
	assert_int(_campaign().rivals.size()).is_equal(0)


func test_a_forced_battle_names_the_rule_that_forced_it() -> void:
	var rivals := [{"id": "r2", "name": "Krag pirates", "type": "Gangers"}]
	var p81: Dictionary = RivalCheckScript.check(rivals, 0, null, "", "r2",
		"Core Rules p.81 - Got yourself noticed")
	var p128: Dictionary = RivalCheckScript.check(rivals, 0, null, "", "r2")
	assert_str(str(p81["reason"])).contains("p.81")
	assert_str(str(p128["reason"])).contains("p.128")


# ── p.81 K'Erin: -1 enemy the FIRST time, and only then ──────────────────────

func test_the_kerin_rider_reaches_the_first_battle_and_no_other() -> void:
	var rival := {"id": "r1", "name": "Gangers", "type": "Gangers",
		"first_battle_enemy_modifier": -1}
	_campaign().rivals = [rival]
	var check: Dictionary = RivalCheckScript.check([rival], 0, null, "", "r1")
	var enc: Dictionary = CampaignTurnControllerScript.build_encounter_data(check, {})
	assert_bool(bool(enc.get("rival_first_battle_rider", false))).is_true()
	var mission := {"mission_source": "patron", "enemy_type": "Mutants"}
	var ctc: Node = auto_free(CampaignTurnControllerScript.new())
	ctc._apply_rival_ambush_override(mission, enc)
	assert_int(int(mission.get("rival_enemy_count_bonus", 0))).is_equal(-1)
	var after: Dictionary = _campaign().rivals[0]
	assert_bool(after.has("first_battle_enemy_modifier")).override_failure_message(
		"the -1 was not spent, so every later battle against this Rival is short").is_false()
	var second: Dictionary = RivalCheckScript.check([after], 0, null, "", "r1")
	assert_int(int(second.get("rival_enemy_count_bonus", 0))).is_equal(0)


# ── The Contacts card lists the campaign's Rivals ────────────────────────────

func test_the_contacts_card_lists_the_campaign_not_the_tracker() -> void:
	var tracker: Node = auto_free(NPCTrackerScript.new())
	tracker.rivals = {
		"r1": {"rival_id": "r1", "name": "R1", "encounters": 3, "victories": 1, "defeats": 2},
		"ghost": {"rival_id": "ghost", "name": "Ghost", "encounters": 1},
	}
	var entries: Array = DashboardScript.contact_entries(
		["Ganger boss", {"id": "r1", "name": "Krag pirates"}], tracker, "rival")
	assert_int(entries.size()).is_equal(2)
	assert_str(str(entries[0]["name"])).is_equal("Ganger boss")
	assert_str(str(entries[1]["name"])).override_failure_message(
		"the tracker's capitalised id replaced the Rival's name").is_equal("Krag pirates")
	assert_int(int(entries[1].get("encounters", 0))).is_equal(3)


func test_a_rivals_record_reads_from_the_crews_side() -> void:
	## NPCTracker counts from the Rival's side: its "victories" are your losses.
	var line: String = DashboardScript.contact_info_line(
		{"encounters": 3, "victories": 1, "defeats": 2}, "rival")
	assert_str(line).is_equal("Fought 3 times: you won 2, lost 1")
	var patron_line: String = DashboardScript.contact_info_line(
		{"jobs_completed": 2, "jobs_failed": 1, "relationship": 4}, "patron")
	assert_str(patron_line).is_equal("Jobs: 2 completed, 1 failed")


# ── Rivals a crew task gave out before the fix come home once ────────────────

func test_a_legacy_crew_task_rival_is_brought_home_once() -> void:
	var tracker := {
		"rival_task_9_1": {"rival_id": "rival_task_9_1", "source": "crew_task",
			"name": "Rival 42", "type": "Cult", "created_turn": 3},
		"r_battle": {"rival_id": "r_battle", "source": "battle"},
	}
	var first: Array = RivalContactScript.legacy_crew_task_rivals(tracker, ["Ganger boss"])
	assert_int(first.size()).is_equal(1)
	assert_str(str(first[0]["id"])).is_equal("rival_task_9_1")
	assert_bool(EnemyGeneratorScript.is_known_enemy_type(str(first[0]["type"]))).is_true()
	assert_int(int(first[0]["created_turn"])).is_equal(3)
	var again: Array = RivalContactScript.legacy_crew_task_rivals(tracker,
		["Ganger boss", first[0]])
	assert_int(again.size()).is_equal(0)


func test_loading_a_save_brings_a_legacy_rival_home() -> void:
	var campaign = CampaignCoreScript.new()
	campaign.from_dictionary({"campaign_id": "legacy_rival_load", "qol_data": {
		"npc_tracker": {"rivals": {"rival_task_9_1": {"rival_id": "rival_task_9_1",
			"source": "crew_task", "name": "Rival 42"}}}}})
	campaign.apply_pending_qol_data()
	var ids: Array = []
	for r in campaign.rivals:
		ids.append(RivalCheckScript.rival_id_of(r))
	assert_array(ids).contains(["rival_task_9_1"])


# ── Every other producer uses the same shape ─────────────────────────────────

func test_a_post_battle_rival_keeps_its_shape_and_its_named_type() -> void:
	var ctx = PostBattleContextScript.new()
	ctx.campaign = _campaign()
	ctx.add_rival("Enforcers", {"origin": "campaign_event"})
	ctx.add_rival("")
	var rivals: Array = _campaign().rivals
	assert_str(str(rivals[0]["type"])).is_equal("Enforcers")
	assert_str(str(rivals[0]["origin"])).is_equal("campaign_event")
	assert_bool(EnemyGeneratorScript.is_known_enemy_type(str(rivals[1]["type"]))).is_true()
	assert_str(str(rivals[1]["name"])).is_equal(str(rivals[1]["type"]))


func test_a_creation_rival_and_patron_come_from_the_book_tables() -> void:
	var rival: Dictionary = CharacterGenerationScript._create_starting_rival(0, "Ila")
	assert_bool(EnemyGeneratorScript.is_known_enemy_type(str(rival["type"]))) \
		.override_failure_message("'%s' is not an enemy type" % rival["type"]).is_true()
	assert_str(str(rival["source_character"])).is_equal("Ila")
	var p83 := ["Corporation", "Local Government", "Sector Government",
		"Wealthy Individual", "Private Organization", "Secretive Group"]
	for _i in 12:
		var patron: Dictionary = CharacterGenerationScript._create_starting_patron(0, "Ila")
		assert_array(p83).contains([str(patron["type"])])


func test_the_planetfall_rival_keeps_its_own_type() -> void:
	## Planetfall pp.165-166: Independence lost adds Enforcers or Bounty Hunters.
	TransferServiceScript.apply_transfer_rewards(_campaign(),
		{"character": {"name": "Vet", "add_rival": "Bounty Hunters"}})
	var rivals: Array = _campaign().rivals
	assert_int(rivals.size()).is_equal(1)
	assert_str(str(rivals[0]["type"])).is_equal("Bounty Hunters")


# ── The wiring the cases above cannot reach on their own ─────────────────────

func test_the_dialog_path_forces_the_battle_too() -> void:
	## Interactive events resolve through _on_event_completed, auto-resolved ones
	## through _auto_resolve_event. Both must carry the p.81 force.
	_campaign().rivals = [{"id": "r2", "name": "Krag pirates", "type": "Gangers"}]
	var comp = _comp()
	var events: Array = comp._classify_result(_base({}), _row(comp, "Got yourself noticed"), {})
	comp._on_event_completed({}, events[0])
	assert_str(str(_campaign().progress_data.get("forced_rival_battle", ""))).is_equal("r2")


func test_the_contacts_panel_shows_the_campaigns_rivals() -> void:
	_campaign().rivals = [{"id": "r1", "name": "Krag pirates", "type": "Gangers"}]
	NPCTracker.rivals = {
		"r1": {"rival_id": "r1", "name": "R1", "encounters": 3, "victories": 1, "defeats": 2},
		"ghost": {"rival_id": "ghost", "name": "Ghost", "encounters": 1},
	}
	var dash: Node = auto_free(
		(load("res://src/ui/screens/campaign/CampaignDashboard.tscn") as PackedScene).instantiate())
	add_child(dash)
	await await_idle_frame()
	var panel: Node = auto_free(dash._build_contacts_panel())
	var texts: Array = []
	for label in panel.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_array(texts).contains(["Krag pirates", "Fought 3 times: you won 2, lost 1"])
	assert_array(texts).not_contains(["Ghost"])


class QuestStateStub:
	extends RefCounted
	var current_campaign: Variant = null
	func has_active_quest() -> bool:
		return true


func test_a_p128_force_does_not_inherit_a_p81_cite() -> void:
	## p.81 and p.128 ride the same flag. A p.128 force written over a waiting p.81
	## one must not be announced as "Got yourself noticed".
	var ctx = PostBattleContextScript.new()
	ctx.campaign = _campaign()
	var stub := QuestStateStub.new()
	stub.current_campaign = _campaign()
	ctx.game_state = stub
	ctx.battle_result = {"turn": 4, "planet_id": "planet_x"}
	_campaign().progress_data["forced_rival_cite"] = "Core Rules p.81 - Got yourself noticed"
	load("res://src/core/campaign/phases/post_battle/CampaignEventEffects.gd").new() \
		.apply_effect("Got Noticed", ctx)
	assert_bool(_campaign().progress_data.has("forced_rival_battle")).is_true()
	assert_bool(_campaign().progress_data.has("forced_rival_cite")).is_false()


func test_the_rival_check_reads_and_spends_the_cite() -> void:
	## Source-anchored: _check_rival_encounter_backend needs a controller in the tree,
	## and the controller's _ready() binds the CampaignPhaseManager autoload. Each
	## anchor is the exact enabling form, and each is proven by a revert arm.
	var src: String = FileAccess.get_file_as_string(
		"res://src/ui/screens/campaign/CampaignTurnController.gd")
	var start: int = src.find("func _check_rival_encounter_backend(")
	assert_int(start).is_greater(-1)
	var body: String = src.substr(start, src.find("\nfunc ", start + 10) - start)
	for anchor in [
			'forced_cite = str(campaign.progress_data.get("forced_rival_cite", ""))',
			"forced_rival_id, forced_cite)",
			'campaign.progress_data.erase("forced_rival_cite")']:
		assert_bool(body.contains(anchor)).override_failure_message(
			"_check_rival_encounter_backend lost: %s" % anchor).is_true()


func _dialog_text(event: Dictionary) -> String:
	var dialog: Window = auto_free(CrewTaskEventDialog.new())
	add_child(dialog)
	dialog.show_event(event)
	var out := ""
	for node in dialog.find_children("*", "", true, false):
		if node is Label or node is RichTextLabel:
			out += str(node.text) + "\n"
	dialog.hide()
	return out


func test_the_dialog_names_who_comes_after_you_and_shows_the_rider_only_for_a_kerin() -> void:
	var forced: Dictionary = _base({})
	forced["type"] = CrewTaskEventDialog.EventType.FORCED_RIVAL_BATTLE
	forced["forced_rival_name"] = "Krag pirates"
	assert_str(_dialog_text(forced)).contains("Krag pirates will fight you this campaign turn.")
	forced.erase("forced_rival_name")
	assert_str(_dialog_text(forced)).contains("You have no Rivals")
	var gain: Dictionary = _base({})
	gain["type"] = CrewTaskEventDialog.EventType.GAIN_RIVAL
	gain["kerin_bonus"] = "-1 enemy the first time you meet them"
	assert_str(_dialog_text(gain)).not_contains("K'Erin bonus")
	gain["kerin_rider"] = true
	assert_str(_dialog_text(gain)).contains("K'Erin bonus")



# ── p.92: an unexpected Rival rolls twice and the player picks ──────────────

## Two different rolls on the p.94 Unknown Rival column (data/enemy_types.json):
## 10 -> Criminal Elements, 5 -> Gangers (1-10); 60 -> Hired Muscle, 20 -> Enforcers
## (15-26). Each context is its own FIFO queue, consumed in roll order.
func _force_two_rolls() -> void:
	DiceManager.queue_forced_result("Encounter Category", 10)
	DiceManager.queue_forced_result("Encounter Enemy Type", 5)
	DiceManager.queue_forced_result("Encounter Category", 60)
	DiceManager.queue_forced_result("Encounter Enemy Type", 20)


func test_an_unexpected_rival_rolls_twice_and_offers_the_second() -> void:
	## p.92: "If you are not sure, or have acquired an unexpected Rival, roll twice
	## and pick the more interesting or appropriate."
	_force_two_rolls()
	var rival: Dictionary = RivalContactScript.make("crew_task")
	assert_str(str(rival["type"])).is_equal("Gangers")
	assert_str(str(rival.get("type_alternative", ""))).override_failure_message(
		"p.92: the second roll is the player's alternative").is_equal("Enforcers")
	# A given or named type is not unexpected: no second roll, so no choice.
	assert_bool(RivalContactScript.make("x", "Bounty Hunters").has("type_alternative")) \
		.is_false()
	assert_bool(RivalContactScript.make("x", "Local Enforcers", {"type": "Enforcers"}) \
		.has("type_alternative")).is_false()


func test_the_player_picks_and_may_change_their_mind_until_established() -> void:
	_force_two_rolls()
	var rival: Dictionary = RivalContactScript.make("crew_task")
	assert_bool(RivalContactScript.swap_type(rival)).is_true()
	assert_str(str(rival["type"])).is_equal("Enforcers")
	assert_str(str(rival["name"])).override_failure_message(
		"a name that was only the type follows it").is_equal("Enforcers")
	assert_str(str(rival["type_alternative"])).is_equal("Gangers")
	RivalContactScript.swap_type(rival)
	assert_str(str(rival["type"])).is_equal("Gangers")
	# p.84 Vengeful: the Patron's own name stays theirs whichever type is picked.
	_force_two_rolls()
	var vengeful: Dictionary = RivalContactScript.make("vengeful_patron", "Vex Holdings")
	RivalContactScript.swap_type(vengeful)
	assert_str(str(vengeful["name"])).is_equal("Vex Holdings")
	assert_str(str(vengeful["type"])).is_equal("Enforcers")
	# Fought as Enforcers, they are law enforcement (p.96) for the p.84 Clean rule,
	# though nothing in the name says so.
	assert_bool(PatronJobEffectsScript.has_law_enforcement_rival([vengeful])).is_true()


func test_the_first_battle_establishes_the_type() -> void:
	## p.92: "Once a Rival has been established, they will always be the same type."
	var rival := {"id": "r2", "name": "Enforcers", "type": "Enforcers",
		"type_alternative": "Gangers"}
	_campaign().rivals = [rival]
	var check: Dictionary = RivalCheckScript.check([rival], 0, null, "", "r2")
	var enc: Dictionary = CampaignTurnControllerScript.build_encounter_data(check, {})
	var mission := {"mission_source": "patron"}
	var ctc: Node = auto_free(CampaignTurnControllerScript.new())
	ctc._apply_rival_ambush_override(mission, enc)
	assert_str(str(mission.get("enemy_type", ""))).override_failure_message(
		"the battle is fought as the picked type").is_equal("Enforcers")
	var after: Dictionary = _campaign().rivals[0]
	assert_bool(after.has("type_alternative")).override_failure_message(
		"the pick is still open after the Rival was met in battle").is_false()
	assert_bool(RivalContactScript.swap_type(after)).is_false()


func test_a_faction_enforcer_rival_comes_from_the_one_producer() -> void:
	## Compendium p.115: "they send an Enforcer Rival after you."
	var sys = auto_free(FactionSystemScript.new())
	add_child(sys)
	sys.active_factions = {"f1": {"name": "Iron Hand"}}
	sys._add_enforcer_rival("f1")
	var rival: Dictionary = _campaign().rivals.back()
	assert_str(str(rival["type"])).is_equal("Enforcers")
	assert_str(str(rival["name"])).is_equal("Iron Hand Enforcers")
	assert_str(str(rival["faction_id"])).is_equal("f1")
	assert_str(str(rival["origin"])).is_equal("faction_event")
	assert_bool(rival.has("type_alternative")).is_false()
	assert_bool(PatronJobEffectsScript.has_law_enforcement_rival([rival])).is_true()


## The two Job Offer Rivals run inside screen code that also writes the journal
## autoload, so the call itself is pinned. Comment lines are stripped so a docblock
## naming the call cannot satisfy the check.
func test_the_job_offer_rivals_come_from_the_one_producer() -> void:
	var code := PackedStringArray()
	for line in FileAccess.get_file_as_string(
			"res://src/ui/screens/world/components/JobOfferComponent.gd").split("\n"):
		if not line.strip_edges().begins_with("#"):
			code.append(line)
	var src := "\n".join(code)
	assert_str(src).contains("RivalContactRef.make(\"vengeful_patron\", patron_name,")
	assert_str(src).contains("RivalContactRef.make(\"forged_licence\",")
	assert_str(src).override_failure_message(
		"p.84 Vengeful gave the Rival invented hostility and resources").not_contains(
		"\"hostility\"")
