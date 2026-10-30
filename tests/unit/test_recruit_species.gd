extends GdUnitTestSuite
## A recruit is rolled on the p.14 Crew Type table and created as that species.
##
## Core Rules p.78: "Each recruit rolls using the random method in the character
## creation process (see p.14)." p.81 Make a new friend: "If your character is Feral,
## the new character is also Feral." Errata v1.06: recruits roll the normal creation
## tables "as you would when starting a new game".
##
## Measured on 2026-10-29 before the fix: `_apply_recruit()` called
## `create_character({})`, whose origin defaults to HUMAN, so every recruit was a
## Baseline Human with no species_id. A Bot rolled the creation tables it may not
## (p.15), no Strange Character could join, and a Feral's new friend was Human.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const CTCScript = preload("res://src/ui/screens/world/components/CrewTaskComponent.gd")
const EventDialogScript = preload("res://src/ui/components/dialogs/CrewTaskEventDialog.gd")
const CharGen = preload("res://src/core/character/CharacterGeneration.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _prior_campaign: Resource = null
var _user_state: Dictionary = {}


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_prior_campaign = GameState.current_campaign
	var c = CampaignCore.new()
	c.from_dictionary({"campaign_id": "recruit_species_suite", "crew": {"members": [
		{"character_id": "c1", "character_name": "Ana", "species_id": "human",
			"origin": "HUMAN", "equipment": [], "status_effects": []}]}})
	c.progress_data["turns_played"] = 3
	GameState.current_campaign = c


func after_test() -> void:
	DiceManager.clear_forced_results("Crew Type")
	GameState.current_campaign = _prior_campaign
	SaveDirGuard.restore(_user_state)


func _ctc():
	var comp = auto_free(CTCScript.new())
	add_child(comp)
	return comp


func _newest() -> Dictionary:
	var members: Array = GameState.current_campaign.crew_data["members"]
	return members.back()


func _traits_with(ch, prefix: String) -> Array:
	return (ch.traits as Array).filter(func(t: String) -> bool: return t.begins_with(prefix))


func test_a_recruit_rolls_the_crew_type_table() -> void:
	var comp = _ctc()
	DiceManager.queue_forced_result("Crew Type", 85)  # 81-90 Bot
	comp._apply_recruit()
	var bot: Dictionary = _newest()
	assert_str(str(bot.get("species_id", ""))).override_failure_message(
		"p.78: the random method, p.14 Crew Type table").is_equal("bot")
	assert_str(str(bot.get("origin", ""))).is_equal("BOT")

	DiceManager.queue_forced_result("Crew Type", 65)  # 61-80 Primary Alien
	DiceManager.queue_forced_result("Crew Type", 25)  # 21-40 K'Erin
	comp._apply_recruit()
	assert_str(str(_newest().get("species_id", ""))).is_equal("kerin")


func test_a_bot_recruit_makes_no_creation_rolls() -> void:
	var bot = CharGen.create_character({"species_id": "bot"})
	assert_bool(bot.has_meta("creation_table_results")).override_failure_message(
		"p.15: Bots do not make any rolls on the character creation tables").is_false()
	assert_array(_traits_with(bot, "Background: ")).is_empty()
	assert_int(bot.reactions).is_equal(2)
	assert_int(bot.savvy).is_equal(2)
	var comp = _ctc()
	comp._apply_recruit_creation_tables(bot)
	assert_bool(bot.has_meta("creation_table_results")).override_failure_message(
		"the errata's re-roll does not reach a Bot either").is_false()


func test_a_strange_character_recruit_has_its_profile_and_rules() -> void:
	var drone = CharGen.create_character({"species_id": "assault_bot"})
	assert_str(drone.species_id).is_equal("assault_bot")
	assert_str(drone.origin).is_equal("Assault Bot")
	assert_bool(drone.special_rules.is_empty()).is_false()
	# p.21: R+1, C+1, T+1 on the 1/4/0/3/0 base, and no creation rolls.
	assert_int(drone.reactions).is_equal(2)
	assert_int(drone.combat).is_equal(1)
	assert_int(drone.toughness).is_equal(4)


func test_species_creation_rules_reach_a_recruit() -> void:
	assert_str(CharGen.create_character({"species_id": "traveler"}).motivation) \
		.override_failure_message("p.23: Motivation is always Truth").is_equal("TRUTH")
	assert_str(CharGen.create_character({"species_id": "mutant"}).background) \
		.is_equal("LOWER_MEGACITY_CLASS")
	# Forced to distinct rows: add_trait() dedupes, so two equal rolls (or a Hakshan
	# who rolls Truth) leave one trait, and an unforced count was flaky.
	DiceManager.queue_forced_result("Background Table", 1)   # Peaceful, High-Tech Colony
	DiceManager.queue_forced_result("Background Table", 18)  # Military Brat
	assert_array(_traits_with(CharGen.create_character({"species_id": "mysterious_past"}),
		"Background: ")).override_failure_message(
		"p.20: roll twice on the Background Table and apply both").contains_exactly_in_any_order(
		["Background: Peaceful, High-Tech Colony", "Background: Military Brat"])
	DiceManager.queue_forced_result("Motivation Table", 22)  # Survival
	var hakshan = CharGen.create_character({"species_id": "hakshan"})
	assert_array(_traits_with(hakshan, "Motivation: ")).override_failure_message(
		"p.20: Truth in addition to the usual roll").contains_exactly_in_any_order(
		["Motivation: Survival", "Motivation: Truth"])
	DiceManager.clear_forced_results("Background Table")
	DiceManager.clear_forced_results("Motivation Table")


func test_a_ferals_new_friend_is_feral() -> void:
	var comp = _ctc()
	var finder := {"character_id": "f1", "character_name": "Grix", "species_id": "feral",
		"origin": "FERAL"}
	DiceManager.queue_forced_result("Crew Type", 10)  # would be a Baseline Human
	comp._on_event_completed({"recruit": true}, {
		"type": EventDialogScript.EventType.RECRUIT, "crew_member": finder,
		"event_name": "Make a new friend", "crew_name": "Grix"})
	assert_str(str(_newest().get("species_id", ""))).override_failure_message(
		"p.81: If your character is Feral, the new character is also Feral").is_equal("feral")

	DiceManager.clear_forced_results("Crew Type")
	var human := {"character_id": "h1", "character_name": "Ana", "species_id": "human",
		"origin": "HUMAN"}
	DiceManager.queue_forced_result("Crew Type", 10)
	comp._on_event_completed({"recruit": true}, {
		"type": EventDialogScript.EventType.RECRUIT, "crew_member": human,
		"event_name": "Make a new friend", "crew_name": "Ana"})
	assert_str(str(_newest().get("species_id", ""))).is_equal("human")
