extends GdUnitTestSuite
## On-board Items (Core Rules pp.57-58) + damaged Loot (p.131) + Interdiction (p.75).
##
## 1. ON-BOARD ITEMS were inert, all nineteen of them. The data was byte-exact
##    against pp.57-58 and `EquipmentManager.get_onboard_item_effect()` returned
##    correct structured effects — but its ONLY caller repo-wide lived in
##    `src/core/campaign/phases/TravelPhase.gd`, a file with zero instantiations.
##    A Purifier produced nothing, a Repair Bot added nothing to a Repair, a
##    Teach-bot taught nothing. Complete data, correct reader, no caller.
##
## 2. DAMAGED LOOT (p.131 rows 26-45, a fifth of all loot: "Both items require
##    Repair") was marked `needs_repair` by LootTableResolver while every rule
##    that acts on damage reads `damaged` — Repair Your Kit's stash scan, the
##    "[DAMAGED]" suffix in Assign Equipment, the campaign-event damage picker.
##    Two spellings for one concept, so broken loot could never be repaired and
##    was never even labelled.
##
## 3. INTERDICTION (p.75) had zero consumers, and it is the ONLY licence roll in
##    live campaign play — which is what made Fake ID ("+1 to all attempts to
##    obtain a license") and Sector Permit inert by construction. There was no
##    attempt for them to modify.
##
## gdUnit4 v6.0.3 compatible.

const OnboardRef := preload("res://src/core/equipment/OnboardItemService.gd")
const TransferRef := preload("res://src/core/equipment/EquipmentTransferService.gd")
const LootRef := preload("res://src/core/equipment/LootTableResolver.gd")
const InterdictionRef := preload("res://src/core/world/InterdictionRule.gd")
const WorldTraitsRef := preload("res://src/core/world/WorldTraitEffects.gd")
const PostBattleContextRef := preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")

const CTC_SRC := "res://src/ui/screens/world/components/CrewTaskComponent.gd"
const INJURY_SRC := "res://src/core/campaign/phases/post_battle/InjuryProcessor.gd"
const RPR_SRC := "res://src/core/campaign/phases/post_battle/RivalPatronResolver.gd"
const ADV_SRC := "res://src/core/services/CharacterAdvancementService.gd"


## A minimal campaign stand-in. The service only ever touches `equipment_data`
## and `progress_data`, both plain Dictionaries, so a Resource with those two
## properties exercises the real code paths without loading the 2000-line
## campaign core (which drags in autoloads a unit test has no business booting).
class FakeCampaign extends Resource:
	var equipment_data: Dictionary = {"equipment": []}
	var progress_data: Dictionary = {}


func _campaign(stash: Array = []) -> FakeCampaign:
	var c := FakeCampaign.new()
	c.equipment_data = {"equipment": stash.duplicate(true)}
	c.progress_data = {"turns_played": 5}
	return c


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var t: String = f.get_as_text()
	f.close()
	return t


## Source with whole-line comments removed.
##
## MANDATORY for any ordering or absence assertion. The first version of
## test_genetic_kit_discount_applies_where_affordability_is_checked scanned the
## raw file for "Insufficient XP" and matched the COMMENT that explains why the
## discount sits above the affordability check — so a correct fix reported
## itself as broken. A source-scanning test measures whatever it can see; make
## it see only code.
func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line in _src(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


# ── Data: all nineteen items, byte-exact ids ────────────────────────────────

func test_all_nineteen_onboard_items_load() -> void:
	var ids: Array = []
	for entry in OnboardRef.all():
		ids.append(str(entry.get("id", "")))
	assert_int(ids.size()).is_equal(19)
	# The nine that carry a mechanical effect wired by this change.
	for required in ["analyzer", "colonist_ration_packs", "duplicator", "fake_id",
			"fixer", "genetic_reconfiguration_kit", "loaded_dice", "lucky_dice",
			"mk_ii_translator", "med_patch", "meditation_orb", "nano_doc",
			"novelty_stuffed_animal", "purifier", "repair_bot", "sector_permit",
			"spare_parts", "teach_bot", "transcender"]:
		assert_bool(OnboardRef.is_onboard_item(required)) \
			.override_failure_message("missing on-board item id: %s" % required) \
			.is_true()


func test_normalize_id_accepts_display_names() -> void:
	## Stash items carry display NAMES; the book table is keyed by id. If these
	## did not resolve, every query below would silently answer "not held".
	assert_str(OnboardRef.normalize_id("Lucky Dice")).is_equal("lucky_dice")
	assert_str(OnboardRef.normalize_id("Repair Bot")).is_equal("repair_bot")
	assert_str(OnboardRef.normalize_id("Mk II Translator")).is_equal("mk_ii_translator")
	assert_str(OnboardRef.normalize_id("Med-patch")).is_equal("med_patch")
	assert_str(OnboardRef.normalize_id("Genetic Reconfiguration Kit")) \
		.is_equal("genetic_reconfiguration_kit")
	# Not an on-board item — must NOT resolve, or an ordinary gun would start
	# granting Repair bonuses.
	assert_str(OnboardRef.normalize_id("Hand Cannon")).is_equal("")


# ── Passive bonuses ─────────────────────────────────────────────────────────

func test_repair_bonuses_stack_and_are_named() -> void:
	## p.58 Repair Bot "+1 to all Repair attempts" and Spare parts "Add +1 when
	## making a Repair attempt" are separate items with separate entries.
	assert_int(int(OnboardRef.repair_bonus(_campaign()).get("value", -1))).is_equal(0)
	var bot := _campaign([{"name": "Repair Bot"}])
	assert_int(int(OnboardRef.repair_bonus(bot).get("value", 0))).is_equal(1)
	assert_bool(bool(OnboardRef.repair_bonus(bot).get("spare_parts", true))).is_false()
	var both := _campaign([{"name": "Repair Bot"}, {"name": "Spare Parts"}])
	var r: Dictionary = OnboardRef.repair_bonus(both)
	assert_int(int(r.get("value", 0))).is_equal(2)
	assert_bool(bool(r.get("spare_parts", false))).is_true()
	assert_int((r.get("sources", []) as Array).size()).is_equal(2)


func test_license_and_quest_and_recruit_bonuses() -> void:
	assert_int(OnboardRef.license_bonus(_campaign())).is_equal(0)
	assert_int(OnboardRef.license_bonus(_campaign([{"name": "Fake ID"}]))).is_equal(1)
	assert_int(OnboardRef.quest_roll_bonus(_campaign())).is_equal(0)
	assert_int(OnboardRef.quest_roll_bonus(_campaign([{"name": "Analyzer"}]))).is_equal(1)
	assert_int(OnboardRef.recruit_extra_dice(_campaign())).is_equal(0)
	assert_int(OnboardRef.recruit_extra_dice(
		_campaign([{"name": "Mk II Translator"}]))).is_equal(1)


func test_sector_permit_only_rolls_when_held() -> void:
	## p.58: "Whenever you arrive at a planet where a license is required, roll
	## 1D6. On a 4+, the Sector Permit is accepted."
	var none: Dictionary = OnboardRef.roll_sector_permit(_campaign())
	assert_bool(bool(none.get("applies", true))).is_false()
	assert_bool(bool(none.get("accepted", true))).is_false()

	var held := _campaign([{"name": "Sector Permit"}])
	var accepted_seen := false
	var refused_seen := false
	for _i in range(200):
		var r: Dictionary = OnboardRef.roll_sector_permit(held)
		assert_bool(bool(r.get("applies", false))).is_true()
		var roll: int = int(r.get("roll", 0))
		assert_bool(roll >= 1 and roll <= 6).is_true()
		# The 4+ boundary is the rule, so assert the mapping rather than the odds.
		assert_bool(bool(r.get("accepted", false))).is_equal(roll >= 4)
		if roll >= 4: accepted_seen = true
		else: refused_seen = true
	assert_bool(accepted_seen and refused_seen).is_true()


func test_teach_bot_rolls_1d6_and_is_consumed() -> void:
	## p.58: "A character engaging in the Train crew task will earn 1D6
	## additional XP. Single-use."
	assert_int(OnboardRef.consume_teach_bot(_campaign())).is_equal(0)
	var c := _campaign([{"name": "Teach-bot"}])
	var xp: int = OnboardRef.consume_teach_bot(c)
	assert_bool(xp >= 1 and xp <= 6) \
		.override_failure_message("Teach-bot XP out of 1D6 range: %d" % xp).is_true()
	assert_bool(OnboardRef.has_item(c, "teach_bot")) \
		.override_failure_message("single-use Teach-bot survived its own use").is_false()
	# Second call must pay nothing — the bot is gone.
	assert_int(OnboardRef.consume_teach_bot(c)).is_equal(0)


# ── Once-per-turn income (p.58) ─────────────────────────────────────────────

func test_purifier_pays_one_credit_once_per_turn() -> void:
	## p.58: "Each campaign turn... sold off for 1 credit... only one Purifier
	## may be used at a time" — so two Purifiers still pay 1, not 2.
	var c := _campaign([{"name": "Purifier"}, {"name": "Purifier"}])
	var first: Dictionary = OnboardRef.resolve_turn_income(c, 5)
	assert_int(int(first.get("credits", 0))).is_equal(1)
	# Same turn again: the stamp must suppress it, or entering Upkeep twice
	# (which the World Phase allows via back-navigation) would print money.
	var second: Dictionary = OnboardRef.resolve_turn_income(c, 5)
	assert_int(int(second.get("credits", 0))).is_equal(0)
	assert_int((second.get("lines", []) as Array).size()).is_equal(0)
	# Next turn pays again.
	assert_int(int(OnboardRef.resolve_turn_income(c, 6).get("credits", 0))).is_equal(1)


func test_lucky_dice_pays_one_credit() -> void:
	var c := _campaign([{"name": "Lucky Dice"}])
	assert_int(int(OnboardRef.resolve_turn_income(c, 1).get("credits", 0))).is_equal(1)


func test_loaded_dice_six_loses_both_sets_and_forces_injury_roll() -> void:
	## p.58: "On a 6, the locals don't take kindly to losing: The dice are lost
	## and the crew member must roll on the post-battle Injury Table." And:
	## "rolling a 6 for the Loaded dice mean you lose BOTH sets of dice."
	##
	## Seeded harnesses cannot pin a specific roll here (the service rolls
	## internally), so this drives many turns and asserts the INVARIANT: whenever
	## the injury flag fires, both dice are gone; whenever it does not, both stay.
	var saw_six := false
	var saw_survival := false
	for turn in range(1, 400):
		var c := _campaign([{"name": "Loaded Dice"}, {"name": "Lucky Dice"}])
		var out: Dictionary = OnboardRef.resolve_turn_income(c, turn)
		if bool(out.get("injury_roll_required", false)):
			saw_six = true
			assert_bool(OnboardRef.has_item(c, "loaded_dice")) \
				.override_failure_message("Loaded Dice survived a 6").is_false()
			assert_bool(OnboardRef.has_item(c, "lucky_dice")) \
				.override_failure_message("Lucky Dice survived the Loaded 6").is_false()
			# Only the Lucky credit that turn; the 6 itself pays nothing.
			assert_int(int(out.get("credits", 0))).is_equal(1)
		else:
			saw_survival = true
			assert_bool(OnboardRef.has_item(c, "loaded_dice")).is_true()
			# 1-4 pays the roll, 5 pays nothing; +1 from Lucky either way.
			var credits: int = int(out.get("credits", 0))
			assert_bool(credits >= 1 and credits <= 5) \
				.override_failure_message("income %d outside 1..5" % credits).is_true()
	assert_bool(saw_six).override_failure_message("never rolled a 6 in 399 turns").is_true()
	assert_bool(saw_survival).is_true()


# ── Species restrictions ────────────────────────────────────────────────────

func test_genetic_kit_species_restrictions() -> void:
	## p.57: "Has no effect on Bots or Soulless. K'Erin may only use this to
	## increase Toughness."
	assert_bool(OnboardRef.genetic_kit_allows("human", false, false, "combat")).is_true()
	assert_bool(OnboardRef.genetic_kit_allows("human", true, false, "combat")).is_false()
	assert_bool(OnboardRef.genetic_kit_allows("human", false, true, "combat")).is_false()
	assert_bool(OnboardRef.genetic_kit_allows("bot", false, false, "combat")).is_false()
	assert_bool(OnboardRef.genetic_kit_allows("soulless", false, false, "combat")).is_false()
	assert_bool(OnboardRef.genetic_kit_allows("kerin", false, false, "toughness")).is_true()
	assert_bool(OnboardRef.genetic_kit_allows("kerin", false, false, "combat")).is_false()


func test_stuffed_animal_species_restrictions() -> void:
	## p.58: "Give to any character that isn't Soulless, K'Erin, or a Bot."
	assert_bool(OnboardRef.stuffed_animal_allows({"species_id": "human"})).is_true()
	assert_bool(OnboardRef.stuffed_animal_allows({"species_id": "soulless"})).is_false()
	assert_bool(OnboardRef.stuffed_animal_allows({"species_id": "k'erin"})).is_false()
	assert_bool(OnboardRef.stuffed_animal_allows({"is_bot": true})).is_false()
	assert_bool(OnboardRef.stuffed_animal_allows(null)).is_false()


func test_legacy_float_origin_does_not_abort_species_checks() -> void:
	## Legacy saves persist `origin` as a numeric enum (a float). `.to_lower()`
	## on a float is an INVALID CALL that unwinds the caller, so an unguarded
	## species read would make the whole item silently do nothing on old saves.
	assert_bool(OnboardRef.stuffed_animal_allows({"origin": 7.0})).is_true()


# ── Player-chosen single-use items ──────────────────────────────────────────

func test_meditation_orb_grants_two_story_points_and_species_xp() -> void:
	## p.58: "Add +2 story points. All Swift or Precursor in the crew may also
	## add +1 XP."
	var c := _campaign([{"name": "Meditation Orb"}])
	var crew: Array = [
		{"id": "a", "species_id": "swift"},
		{"id": "b", "species_id": "human"},
		{"id": "c", "species_id": "precursor"},
	]
	var out: Dictionary = OnboardRef.use(c, "meditation_orb", null, 1, crew)
	assert_bool(bool(out.get("ok", false))).is_true()
	assert_int(int(out.get("story_points", 0))).is_equal(2)
	assert_int((out.get("xp_targets", []) as Array).size()).is_equal(2)
	assert_bool(OnboardRef.has_item(c, "meditation_orb")).is_false()


func test_transcender_awards_the_activator() -> void:
	var c := _campaign([{"name": "Transcender"}])
	var out: Dictionary = OnboardRef.use(
		c, "transcender", {"id": "hero", "character_name": "Vex"}, 1, [])
	assert_bool(bool(out.get("ok", false))).is_true()
	assert_int(int(out.get("story_points", 0))).is_equal(2)
	var targets: Array = out.get("xp_targets", [])
	assert_int(targets.size()).is_equal(1)
	assert_str(str(targets[0].get("character_id", ""))).is_equal("hero")
	assert_int(int(targets[0].get("xp", 0))).is_equal(1)


func test_stuffed_animal_refuses_an_ineligible_target_without_consuming() -> void:
	## The strongest form of the restriction: an illegal target must not burn the
	## item. A refusal that still consumed would be worse than no restriction.
	var c := _campaign([{"name": "Novelty Stuffed Animal"}])
	var out: Dictionary = OnboardRef.use(
		c, "novelty_stuffed_animal", {"id": "k", "species_id": "k'erin"}, 1, [])
	assert_bool(bool(out.get("ok", true))).is_false()
	assert_bool(OnboardRef.has_item(c, "novelty_stuffed_animal")) \
		.override_failure_message("item consumed on a refused target").is_true()


func test_duplicator_copies_an_item_but_never_itself() -> void:
	## p.57: "A Duplicator cannot copy a Duplicator."
	var c := _campaign([{"name": "Duplicator"}, {"name": "Blast Rifle"}])
	var refused: Dictionary = OnboardRef.use(
		c, "duplicator", {"name": "Duplicator"}, 1, [])
	assert_bool(bool(refused.get("ok", true))).is_false()
	assert_bool(OnboardRef.has_item(c, "duplicator")).is_true()

	var ok: Dictionary = OnboardRef.use(c, "duplicator", {"name": "Blast Rifle"}, 1, [])
	assert_bool(bool(ok.get("ok", false))).is_true()
	var names: Array = []
	for e in c.equipment_data["equipment"]:
		names.append(str(e.get("name", "")))
	assert_int(names.count("Blast Rifle")).is_equal(2)
	assert_int(names.count("Duplicator")).is_equal(0)


func test_nano_doc_arms_then_is_spent_exactly_once() -> void:
	## p.58: "Prevent ONE roll on the post-battle Injury Table, no matter the
	## source of the injury. You must decide BEFORE rolling the dice."
	var c := _campaign([{"name": "Nano-doc"}])
	assert_bool(OnboardRef.is_nano_doc_armed(c)).is_false()
	assert_bool(bool(OnboardRef.use(c, "nano_doc", null, 1, []).get("ok", false))).is_true()
	assert_bool(OnboardRef.is_nano_doc_armed(c)).is_true()
	assert_bool(OnboardRef.consume_armed_nano_doc(c)).is_true()
	assert_bool(OnboardRef.consume_armed_nano_doc(c)) \
		.override_failure_message("Nano-doc prevented a SECOND injury roll").is_false()


func test_genetic_kit_arms_then_is_spent_exactly_once() -> void:
	var c := _campaign([{"name": "Genetic Reconfiguration Kit"}])
	assert_bool(bool(OnboardRef.use(
		c, "genetic_reconfiguration_kit", null, 1, []).get("ok", false))).is_true()
	assert_bool(OnboardRef.is_genetic_kit_armed(c)).is_true()
	assert_bool(OnboardRef.consume_armed_genetic_kit(c)).is_true()
	assert_bool(OnboardRef.consume_armed_genetic_kit(c)).is_false()


func test_ration_packs_waive_upkeep_for_exactly_one_turn() -> void:
	## p.57: "Ignore Upkeep costs for ONE campaign turn. +1 story point."
	var c := _campaign([{"name": "Colonist Ration Packs"}])
	var out: Dictionary = OnboardRef.use(c, "colonist_ration_packs", null, 5, [])
	assert_bool(bool(out.get("ok", false))).is_true()
	assert_int(int(out.get("story_points", 0))).is_equal(1)
	assert_bool(OnboardRef.upkeep_is_waived(c, 5)).is_true()
	assert_bool(OnboardRef.upkeep_is_waived(c, 6)) \
		.override_failure_message("ration packs waived a SECOND turn").is_false()


func test_use_refuses_an_item_that_is_not_in_the_stash() -> void:
	var c := _campaign([])
	assert_bool(bool(OnboardRef.use(c, "meditation_orb", null, 1, []).get("ok", true))) \
		.is_false()


# ── Row 100: damaged Loot (p.131) ───────────────────────────────────────────

func test_damaged_loot_carries_the_canonical_damaged_key() -> void:
	## THE FIX. p.131 rows 26-45 are "Both items require Repair"; the resolver
	## marked them `needs_repair` only, and every rule reads `damaged`.
	var seen_damaged := false
	for _i in range(400):
		for item in LootRef.roll_loot():
			if not (item is Dictionary):
				continue
			if str(item.get("quality", "")) != "damaged":
				continue
			seen_damaged = true
			assert_bool(bool(item.get("damaged", false))) \
				.override_failure_message(
					"damaged loot '%s' lacks the canonical `damaged` key — Repair"
					% str(item.get("name", "?"))
					+ " Your Kit cannot see it").is_true()
			assert_bool(TransferRef.is_item_damaged(item)).is_true()
	assert_bool(seen_damaged) \
		.override_failure_message("no damaged loot in 400 rolls (26-45 is 20%)").is_true()


func test_is_item_damaged_reads_both_spellings() -> void:
	## `needs_repair` must still register: it is already persisted in save files
	## written before the fix, so ignoring it would silently un-break every
	## damaged item a player has already looted.
	assert_bool(TransferRef.is_item_damaged({"damaged": true})).is_true()
	assert_bool(TransferRef.is_item_damaged({"needs_repair": true})).is_true()
	assert_bool(TransferRef.is_item_damaged({"name": "Blade"})).is_false()
	assert_bool(TransferRef.is_item_damaged("a string")).is_false()
	assert_bool(TransferRef.is_item_damaged(null)).is_false()


func test_repair_your_kit_scans_damage_through_the_shared_predicate() -> void:
	## Guards the regression directly: if either stash scan goes back to reading
	## `damaged` alone, loot-damaged items become unrepairable again.
	var src: String = _code_only(CTC_SRC)
	assert_int(src.count("EquipmentTransferService.is_item_damaged")) \
		.override_failure_message(
			"Repair Your Kit must resolve damage through the shared predicate at"
			+ " BOTH stash scan sites").is_greater_equal(2)


# ── Row 98 wiring: the calls exist on the live paths ────────────────────────

func test_nano_doc_gate_precedes_both_injury_tables() -> void:
	## "No matter the source of the injury" — so the gate must sit above the bot
	## routing and above the detailed-injuries opt-in, not inside either branch.
	var src: String = _code_only(INJURY_SRC)
	var gate: int = src.find("consume_armed_nano_doc")
	var bot_route: int = src.find("return _process_bot_injury(ctx, injury_data, crew_id)")
	var detailed: int = src.find("roll_detailed_injury()")
	assert_int(gate).override_failure_message("Nano-doc gate missing").is_greater(0)
	assert_int(gate).override_failure_message(
		"Nano-doc gate sits AFTER the bot routing — Bots and Soulless would be"
		+ " excluded from an item the book says applies to any source").is_less(bot_route)
	assert_int(gate).override_failure_message(
		"Nano-doc gate sits AFTER the detailed-injuries opt-in — the item would"
		+ " depend on a DLC toggle").is_less(detailed)


func test_armed_nano_doc_actually_prevents_the_injury() -> void:
	## THE BEHAVIOURAL PROOF, and it exists because the ordering test above could
	## not fail. Reverting the fix to `if false and OnboardItemServiceRef
	## .consume_armed_nano_doc(...)` left the string in place, so the position
	## scan still passed while the gate was dead. A test that cannot fail is not
	## evidence — this one drives the real processor.
	var processor := PostBattleInjuryProcessor.new()
	var ctx := PostBattleContextRef.new()
	var c := _campaign([{"name": "Nano-doc"}])
	ctx.campaign = c
	OnboardRef.use(c, "nano_doc", null, 1, [])
	assert_bool(OnboardRef.is_nano_doc_armed(c)).is_true()

	var out: Dictionary = processor.process_single_injury(ctx, {"crew_id": "x"})
	assert_str(str(out.get("type", ""))) \
		.override_failure_message("armed Nano-doc did not prevent the Injury roll") \
		.is_equal("ignored")
	assert_bool(str(out.get("description", "")).contains("Nano-doc")).is_true()
	assert_int(int(out.get("recovery_turns", -1))).is_equal(0)
	assert_bool(bool(out.get("is_fatal", true))).is_false()
	# "Prevent ONE roll" — the next casualty is on their own.
	assert_bool(OnboardRef.is_nano_doc_armed(c)).is_false()


func test_unarmed_nano_doc_does_not_swallow_injuries() -> void:
	## The other half: without the item the gate must be invisible, or every
	## injury in the campaign would silently vanish.
	var processor := PostBattleInjuryProcessor.new()
	var ctx := PostBattleContextRef.new()
	ctx.campaign = _campaign()
	var out: Dictionary = processor.process_single_injury(ctx, {"crew_id": "x"})
	assert_str(str(out.get("type", ""))).is_not_equal("ignored")


func test_analyzer_reaches_both_quest_progress_systems() -> void:
	## Core p.120 and Compendium p.78 are two different quest systems and the
	## Analyzer modifies "Quest resolution" in both. Computing the bonus once,
	## above the branch, is what stops this being the recurring "guard applied to
	## N-1 of N sites" bug.
	var src: String = _code_only(RPR_SRC)
	assert_int(src.count("OnboardItemServiceRef.quest_roll_bonus")).is_equal(1)
	var bonus_line: int = src.find("var analyzer_bonus: int = OnboardItemServiceRef")
	var branch: int = src.find("if ExpandedQuestRef.is_enabled():")
	assert_int(bonus_line).is_greater(0)
	assert_int(bonus_line).override_failure_message(
		"Analyzer bonus computed INSIDE one branch — the other quest system"
		+ " would silently ignore it").is_less(branch)
	assert_bool(src.contains("quest_rumors + analyzer_bonus")).is_true()
	assert_bool(src.contains("var db_bonus: int = analyzer_bonus")).is_true()


func test_genetic_kit_discount_applies_where_affordability_is_checked() -> void:
	## Discounting only at deduction time would refuse a character holding
	## exactly cost-2 XP — the very case the kit exists for.
	var src: String = _code_only(ADV_SRC)
	var discount: int = src.find("_genetic_kit_discount(character, stat_lower)")
	var afford: int = src.find("Insufficient XP")
	assert_int(discount).is_greater(0)
	assert_int(discount).override_failure_message(
		"kit discount applied after the affordability check").is_less(afford)


# ── Interdiction (p.75) + the two licence items ─────────────────────────────

func test_interdiction_trait_exposes_its_licence_numbers() -> void:
	assert_bool(WorldTraitsRef.requires_stay_license(["interdiction"])).is_true()
	assert_bool(WorldTraitsRef.requires_stay_license(["fog"])).is_false()
	assert_int(WorldTraitsRef.stay_license_target(["interdiction"])).is_equal(8)


func test_interdiction_arrival_rolls_1d3_and_clears_on_a_clean_world() -> void:
	## p.75: "You are only approved to stay for 1D3 campaign turns."
	var c := _campaign()
	for _i in range(60):
		var out: Dictionary = InterdictionRef.apply_on_arrival(c, ["interdiction"], 3)
		var stay: int = int(out.get("stay_turns", 0))
		assert_bool(stay >= 1 and stay <= 3) \
			.override_failure_message("stay %d outside 1D3" % stay).is_true()
		assert_int(int(out.get("until_turn", 0))).is_equal(3 + stay)
	# Arriving somewhere without the trait must clear the record, or the licence
	# bought on the last world would keep covering the crew forever.
	InterdictionRef.apply_on_arrival(c, ["fog"], 4)
	assert_bool(InterdictionRef.is_active(c)).is_false()
	assert_bool(InterdictionRef.blocks_stay(c, 99)).is_false()


func test_interdiction_blocks_staying_past_the_approved_window() -> void:
	var c := _campaign()
	var out: Dictionary = InterdictionRef.apply_on_arrival(c, ["interdiction"], 1)
	var until: int = int(out.get("until_turn", 0))
	assert_bool(InterdictionRef.blocks_stay(c, until)) \
		.override_failure_message("blocked on the last APPROVED turn").is_false()
	assert_bool(InterdictionRef.blocks_stay(c, until + 1)).is_true()


func test_sector_permit_can_licence_the_stay_on_arrival() -> void:
	## p.58 Sector Permit is an ARRIVAL check ("Whenever you arrive at a planet
	## where a license is required"), so an accepted permit means the crew is
	## never blocked on that world.
	var licensed_seen := false
	for _i in range(120):
		var c := _campaign([{"name": "Sector Permit"}])
		var out: Dictionary = InterdictionRef.apply_on_arrival(c, ["interdiction"], 1)
		assert_bool(bool(out.get("permit_rolled", false))).is_true()
		if bool(out.get("licensed", false)):
			licensed_seen = true
			assert_bool(InterdictionRef.blocks_stay(c, 99)) \
				.override_failure_message("licensed crew still blocked").is_false()
	assert_bool(licensed_seen).is_true()


func test_fake_id_adds_one_to_the_stay_licence_roll() -> void:
	## p.57 Fake ID: "+1 to all attempts to obtain a license or other legal
	## document." This 2D6 8+ is the only licence roll in live campaign play.
	var with_id := _campaign([{"name": "Fake ID"}])
	InterdictionRef.apply_on_arrival(with_id, ["interdiction"], 1)
	var r: Dictionary = InterdictionRef.attempt_stay_license(with_id, ["interdiction"])
	assert_bool(bool(r.get("rolled", false))).is_true()
	assert_int(int(r.get("fake_id_bonus", 0))).is_equal(1)
	assert_int(int(r.get("total", 0))).is_equal(int(r.get("dice", 0)) + 1)
	assert_int(int(r.get("target", 0))).is_equal(8)

	var without := _campaign()
	InterdictionRef.apply_on_arrival(without, ["interdiction"], 1)
	var r2: Dictionary = InterdictionRef.attempt_stay_license(without, ["interdiction"])
	assert_int(int(r2.get("fake_id_bonus", -1))).is_equal(0)
	assert_int(int(r2.get("total", 0))).is_equal(int(r2.get("dice", 0)))


func test_stay_licence_is_granted_once_not_re_rollable() -> void:
	## A licence the player can re-roll every press is not a licence, it is a
	## retry button. p.75 grants one licence.
	var c := _campaign()
	InterdictionRef.apply_on_arrival(c, ["interdiction"], 1)
	var granted := false
	for _i in range(60):
		var r: Dictionary = InterdictionRef.attempt_stay_license(c, ["interdiction"])
		if granted:
			assert_bool(bool(r.get("rolled", true))) \
				.override_failure_message("re-rolled an already-granted licence").is_false()
			assert_bool(bool(r.get("success", false))).is_true()
		elif bool(r.get("success", false)):
			granted = true
	assert_bool(granted) \
		.override_failure_message("2D6 8+ never succeeded in 60 attempts").is_true()
