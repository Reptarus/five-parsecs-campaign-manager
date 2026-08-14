extends GdUnitTestSuite
## The last four open rows of docs/RULES_WIRING_AUDIT_2026-08.md.
##
## 125  Black Jobs — the MISSION (Core Rules pp.150-151). The rewards, the
##      Roving Threats enemy source and the D10 roll were all wired; the mission
##      itself was not. `BlackZoneSystem.get_setup_rules()`,
##      `get_opposition_rules()`, `get_active_passive_rules()` and
##      `get_ending_rules()` were byte-faithful to the book and had ZERO callers
##      between them, so a Black Job rolled a Deployment Condition and a Notable
##      Sight the book forbids, fielded an ordinary 3-8 enemy force instead of
##      "4 teams of 4", forfeited its Seize the Initiative +1, cost nothing to
##      flee, and played an objective rolled off the p.89 Opportunity table
##      while the briefing promised "kill 25 enemy".
##
## 136  Salvage — the Scrapper trade and salvage-as-currency (Compendium p.147).
##      Units were counted during the mission and evaporated with the battle
##      screen: nothing banked them, `get_salvage_credits()` had zero external
##      callers, and there was no Scrapper anywhere in the codebase.
##
## 241  Fleeing an Invasion (Core Rules p.69). The 2D6 8+ roll was implemented
##      and its consequences were not, so fleeing was strictly better than any
##      other departure — you kept every Rival and Patron — and a crew short of
##      the 5-credit fuel had neither of the book's two escape routes.
##
## 243  Train resolves a Character Upgrade IMMEDIATELY (p.78). (The Find-a-Patron
##      half of this row was closed with row 205; the existing-Patron assertion
##      below pins it so it cannot regress.)

const InvasionFlight = preload("res://src/core/campaign/InvasionFlight.gd")
const SalvageLedger = preload("res://src/core/campaign/SalvageLedger.gd")
const BattleSetupRules = preload("res://src/core/battle/BattleSetupRules.gd")
const BlackZoneSystemRef = preload("res://src/core/mission/BlackZoneSystem.gd")
const FlowGuide = preload("res://src/core/battle/BattleFlowGuide.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

const CTC_PATH := "res://src/ui/screens/campaign/CampaignTurnController.gd"
const ENEMY_GEN_PATH := "res://src/core/systems/EnemyGenerator.gd"
const UPKEEP_PATH := "res://src/ui/screens/world/components/UpkeepPhaseComponent.gd"
const CREW_TASK_PATH := "res://src/ui/screens/world/components/CrewTaskComponent.gd"
const POST_BATTLE_PATH := "res://src/core/campaign/phases/PostBattlePhase.gd"
const PAYMENT_PATH := "res://src/core/campaign/phases/post_battle/PaymentProcessor.gd"
const NORMALIZER_PATH := "res://src/core/battle/BattleResultNormalizer.gd"
const PURCHASE_PATH := "res://src/ui/screens/world/components/PurchaseItemsComponent.gd"


## Source scans MUST strip comments. Every fix in this file is documented at its
## own site with the book quote, and those quotes contain the very strings an
## "is this wired" scan looks for — so an unstripped scan passes on the comment
## that explains the fix rather than on the fix.
func _code_only(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_that(f).is_not_null()
	var out: PackedStringArray = []
	for line in f.get_as_text().split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	f.close()
	return "\n".join(out)


func _campaign() -> Resource:
	var c: Resource = CampaignCore.new()
	c.progress_data = {}
	c.equipment_data = {"equipment": []}
	c.crew_data = {"members": []}
	c.patrons = []
	c.rivals = []
	return c


func _rng(seed_value: int) -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = seed_value
	return g


# ============================================================================
# ROW 241 — Flee Invasion (Core Rules p.69)
# ============================================================================

func test_fleeing_an_invasion_loses_every_rival() -> void:
	## p.69: "Regardless of how you leave, all Rivals, Patrons, and other people
	## known to your crew on this world are lost." Rivals get NO follow roll — the
	## 1D6 (and the Compendium p.49 Elite 4+) belongs to the p.72 travel steps,
	## which a flight does not perform.
	var c := _campaign()
	c.rivals = ["Roving Gang", {"id": "r2", "name": "Enforcers", "is_elite": true}]

	var lost: Dictionary = InvasionFlight.lose_local_contacts(c)

	assert_array(c.rivals).is_empty()
	assert_array(lost["rivals_lost"]).contains(["Roving Gang", "Enforcers"])


func test_fleeing_keeps_only_persistent_patrons() -> void:
	## Documented reading, recorded at the site: the clause is scoped to people
	## known "on this world", and "Persistent" is the book's own term for a Patron
	## who is not world-bound (p.151 grants two and calls them "Persistent across
	## worlds"). Stripping those would make the Black Zone reward evaporate the
	## first time the crew fled.
	var c := _campaign()
	c.patrons = [
		{"id": "p1", "name": "Local Corp"},
		{"id": "p2", "name": "Unity Contact", "is_persistent": true},
	]
	c.progress_data["patron_job_offers"] = [
		{"patron_id": "p1", "job": "a"},
		{"patron_id": "p2", "job": "b"},
	]

	var lost: Dictionary = InvasionFlight.lose_local_contacts(c)

	assert_int(c.patrons.size()).is_equal(1)
	assert_str(str(c.patrons[0]["id"])).is_equal("p2")
	assert_array(lost["patrons_lost"]).contains(["Local Corp"])
	# A Patron who is gone cannot still be holding work open.
	assert_int(int(lost["offers_dropped"])).is_equal(1)
	assert_int((c.progress_data["patron_job_offers"] as Array).size()).is_equal(1)


func test_gear_sells_at_one_credit_per_two_items() -> void:
	## p.69: "you can sell off gear at a loss (receiving 1 credit per two items
	## sold)". Only whole PAIRS sell — an odd item raises nothing, so selling it
	## would be a pure loss the book never asks for.
	assert_int(InvasionFlight.sale_credits_for_items(0)).is_equal(0)
	assert_int(InvasionFlight.sale_credits_for_items(1)).is_equal(0)
	assert_int(InvasionFlight.sale_credits_for_items(2)).is_equal(1)
	assert_int(InvasionFlight.sale_credits_for_items(5)).is_equal(2)
	assert_int(InvasionFlight.items_needed_for_credits(3)).is_equal(6)


func test_sell_gear_for_fuel_takes_two_items_per_credit_raised() -> void:
	var c := _campaign()
	c.equipment_data["equipment"] = ["A", "B", "C", "D", "E"]

	var sale: Dictionary = InvasionFlight.sell_gear_for_fuel(c, 2)

	assert_int(int(sale["credits_raised"])).is_equal(2)
	assert_int((sale["items_sold"] as Array).size()).is_equal(4)
	assert_int((c.equipment_data["equipment"] as Array).size()).is_equal(1)
	assert_int(int(sale["shortfall_remaining"])).is_equal(0)


func test_sell_gear_cannot_raise_more_than_the_stash_holds() -> void:
	var c := _campaign()
	c.equipment_data["equipment"] = ["A", "B", "C"]

	var sale: Dictionary = InvasionFlight.sell_gear_for_fuel(c, 5)

	assert_int(int(sale["credits_raised"])).is_equal(1)
	assert_int(int(sale["shortfall_remaining"])).is_equal(4)
	assert_int((c.equipment_data["equipment"] as Array).size()).is_equal(1)


func test_evacuation_passage_costs_all_credits_and_1d6_items() -> void:
	## p.69: "you flee on an evacuation ship. You lose all credits you do have,
	## plus 1D6 items from your Stash and equipment (chosen by you)."
	var c := _campaign()
	c.equipment_data["equipment"] = ["A", "B", "C", "D", "E", "F", "G", "H"]

	var evac: Dictionary = InvasionFlight.evacuation_passage(c, 7, _rng(11))

	assert_int(int(evac["credits_lost"])).is_equal(7)
	var roll: int = int(evac["roll"])
	assert_int(roll).is_between(1, 6)
	assert_int((evac["items_lost"] as Array).size()).is_equal(roll)
	assert_int((c.equipment_data["equipment"] as Array).size()).is_equal(8 - roll)


func test_evacuation_takes_from_character_sheets_once_the_stash_is_empty() -> void:
	## "1D6 items from your Stash AND equipment" — the book counts both toward
	## the die, so a crew with an empty stash is not immune.
	var c := _campaign()
	c.equipment_data["equipment"] = []
	c.crew_data = {"members": [
		{"id": "c1", "name": "Vera", "equipment": ["Blade", "Handgun", "Rifle"]},
	]}

	var evac: Dictionary = InvasionFlight.evacuation_passage(c, 0, _rng(3))
	var roll: int = int(evac["roll"])

	var taken: int = mini(roll, 3)
	assert_int((evac["items_lost"] as Array).size()).is_equal(taken)
	assert_int((c.crew_data["members"][0]["equipment"] as Array).size()) \
		.is_equal(3 - taken)


func test_upkeep_component_actually_runs_the_p69_consequences() -> void:
	## The rule is only real if the live travel handler calls it. This is the
	## "implemented but never called" class that has bitten this audit five times.
	var src: String = _code_only(UPKEEP_PATH)
	assert_str(src).contains("var fleeing: bool = _invasion_pending()")
	assert_str(src).contains("_consume_pending_invasion_flight()")
	assert_str(src).contains("_fund_invasion_flight(travel_cost)")
	assert_str(src).contains("_apply_invasion_contact_loss()")
	# Both escape routes must be reachable from the button, or the crew is
	# stranded on a world the book says they must leave.
	assert_str(src).contains("InvasionFlightRef.sell_gear_for_fuel(")
	assert_str(src).contains("InvasionFlightRef.evacuation_passage(")
	assert_str(src).contains("ShiplessSystemRef.apply_ship_destruction(campaign)")
	assert_str(src).contains("elif fleeing:")


# ============================================================================
# ROW 243 — Train resolves a Character Upgrade immediately (p.78)
# ============================================================================

func test_train_task_offers_the_upgrade_immediately() -> void:
	## p.78: "characters can also Train as a task, earning 1XP. If this means they
	## may make a Character Upgrade ... resolve that immediately." The XP award
	## already worked; the word "immediately" did not exist in code.
	var src: String = _code_only(CREW_TASK_PATH)
	assert_str(src).contains("_apply_xp_to_character(crew_member, total_xp, \"train_task\")")
	assert_str(src).contains("if _offer_immediate_upgrade(crew_member):")
	assert_str(src).contains("CharacterUpgradeDialogScript.has_upgrade_available(live)")


func test_find_a_patron_still_draws_on_an_existing_patron() -> void:
	## The other half of row 243, closed with row 205 and pinned here so it cannot
	## regress. p.77: "If one job is offered, it will always be a random, EXISTING
	## Patron. If two jobs are offered, one will be a random, existing Patron, the
	## other will be from a NEW Patron."
	var src: String = _code_only(CREW_TASK_PATH)
	assert_str(src).contains("_grant_patron_job_offers(1)")
	assert_str(src).contains("_grant_patron_job_offers(2)")
	assert_str(src).contains("new_patrons_needed = 1")
	# A single offer must NOT mint a Patron when the crew already knows some.
	assert_str(src).contains("if existing.is_empty():")


func test_upgrade_dialog_is_a_picker_not_an_auto_advance() -> void:
	## p.123 lets the PLAYER choose the ability. `auto_advance_character()` exists
	## and takes "first available", which would silently spend a character's Luck
	## savings on Speed — so it must not appear on this path.
	var src: String = _code_only(
		"res://src/ui/components/dialogs/CharacterUpgradeDialog.gd")
	assert_str(src).contains("get_available_advancements(")
	assert_str(src).contains("advance_stat(_character, stat_name)")
	assert_str(src).not_contains("auto_advance_character")
	# Banking XP toward a dearer ability is legal play, so declining is an option.
	assert_str(src).contains("Save the XP")


# ============================================================================
# ROW 125 — Black Jobs, the mission (Core Rules pp.150-151)
# ============================================================================

func test_black_job_setup_suppresses_sights_and_conditions() -> void:
	## p.151 Set-up, verbatim: "There are no Notable Sights or Deployment
	## Conditions in effect. You may still roll to Seize the Initiative, and may
	## even claim a +1 bonus."
	var rules: Dictionary = BlackZoneSystemRef.get_setup_rules()
	assert_bool(bool(rules.get("no_notable_sights", false))).is_true()
	assert_bool(bool(rules.get("no_deployment_conditions", false))).is_true()
	assert_int(int(rules.get("seize_initiative_bonus", 0))).is_equal(1)

	# ... and the turn controller must actually consume them.
	var src: String = _code_only(CTC_PATH)
	assert_str(src).contains("BlackZoneSystemClass.get_setup_rules()")
	assert_str(src).contains("suppress_sight = true")
	assert_str(src).contains("suppress_condition = true")
	assert_str(src).contains("seize_initiative_bonus")


func test_black_job_objective_replaces_the_p89_roll() -> void:
	## p.150: "Roll to determine what you are here to do." The D10 table REPLACES
	## the p.89 objective tables. The row was rolled and persisted and read by one
	## Label, so the briefing said "kill 25 enemy" and the battle tracked an
	## Opportunity objective.
	var src: String = _code_only(CTC_PATH)
	assert_str(src).contains("_stamp_black_zone_objective(mission_data)")
	assert_str(src).contains("mission_data[\"objective_details\"] = {")
	assert_str(src).contains("\"required_kills\": int(row.get(\"required_kills\", 0))")
	# Must be stamped BEFORE the p.89 roll, whose guard is `if not
	# mission_data.has("objective_details")` — stamping after it would never win.
	var stamp_at: int = src.find("_stamp_black_zone_objective(mission_data)")
	var roll_at: int = src.find("if not mission_data.has(\"objective_details\"):")
	assert_int(stamp_at).is_greater(0)
	assert_int(roll_at).is_greater(stamp_at)


func test_black_job_fields_four_teams_of_four() -> void:
	## p.151: "The opposition will operate in teams of 4 figures... set up 4 teams
	## at the midway line". 16 figures, not the 3-8 an ordinary roll produces.
	var opp: Dictionary = BlackZoneSystemRef.get_opposition_rules()
	assert_int(int(opp.get("team_size", 0))).is_equal(4)
	assert_int(int(opp.get("initial_teams", 0))).is_equal(4)
	assert_str(str(opp.get("enemy_source", ""))).is_equal("roving_threats")

	var src: String = _code_only(ENEMY_GEN_PATH)
	assert_str(src).contains("enemy_count = BLACK_ZONE_INITIAL_TEAMS * BLACK_ZONE_TEAM_SIZE")
	# "Enemies that have Specialists will have one in each team."
	assert_str(src).contains("specialist_count = BLACK_ZONE_INITIAL_TEAMS")


func test_black_job_flight_is_a_casualty_and_hold_rounds_ride_the_bundle() -> void:
	## p.151 Ending: "any crew member that flees from the battlefield automatically
	## becomes a casualty, and must test for post-battle Injuries."
	## p.150 row 3-4: "Hold against assault: You must hold out for 10 rounds."
	var mission: Dictionary = {
		"is_black_zone": true,
		"black_zone_mission": {
			"name": "Hold Against Assault",
			"description": "Hold out for 10 rounds.",
			"required_rounds": 10,
		},
	}
	var bundle: Dictionary = BattleSetupRules.compute(mission, 16, 6)

	assert_bool(bool(bundle["early_leave_is_casualty"])).is_true()
	assert_int(int(bundle["hold_rounds"])).is_equal(10)
	assert_bool(bool(bundle["can_seize_initiative"])).is_true()
	assert_int((bundle["setup_notes"] as Array).size()).is_greater(3)


func test_an_ordinary_mission_gets_no_black_job_rules() -> void:
	## Guards the applier against firing on every battle — the failure mode that
	## would make every fight a suicide mission.
	var bundle: Dictionary = BattleSetupRules.compute(
		{"mission_source": "opportunity"}, 5, 5)
	assert_bool(bool(bundle["early_leave_is_casualty"])).is_false()
	assert_int(int(bundle["hold_rounds"])).is_equal(0)


func test_black_job_reinforcements_recur_every_round() -> void:
	## p.151: "At the end of each round, another team arrives... These teams enter
	## the battlefield Passive." Plus the Passive-activation 1D6. Both are per-round
	## instructions, so a one-shot pre-battle note cannot deliver them.
	var r1: Array = FlowGuide.build_black_job_round_prompts(1, true, false)
	var r5: Array = FlowGuide.build_black_job_round_prompts(5, true, false)
	assert_int(r1.size()).is_equal(2)
	assert_int(r5.size()).is_equal(2)

	var ids: Array = []
	for p: Variant in r5:
		ids.append(str((p as Dictionary).get("id", "")))
	assert_array(ids).contains(
		["black_job_reinforcements", "black_job_passive_activation"])

	# Not a Black Job -> silence, so the prompt cannot leak into ordinary battles.
	assert_array(FlowGuide.build_black_job_round_prompts(3, false, false)).is_empty()


func test_black_job_win_still_costs_a_round_of_survival() -> void:
	## p.151: "If you have Won, you will be evac'ed out at the end of the FOLLOWING
	## round. Hang in there!"
	var won: Array = FlowGuide.build_black_job_round_prompts(6, true, true)
	var ids: Array = []
	for p: Variant in won:
		ids.append(str((p as Dictionary).get("id", "")))
	assert_array(ids).contains(["black_job_evac"])


func test_the_prep_card_reads_the_same_numbers_the_generator_uses() -> void:
	## The card used to hardcode "4 teams of 4 (16 initial enemies)" — the ONLY
	## place those numbers existed anywhere in the app, describing a battle the
	## player was never given.
	var src: String = _code_only(
		"res://src/ui/screens/world/components/MissionPrepComponent.gd")
	assert_str(src).contains("BlackZoneSystem.get_opposition_rules()")
	assert_str(src).not_contains("Roving Threats, 4 teams of 4 ")


# ============================================================================
# ROW 136 — Salvage: the ledger, the Scrapper, salvage-as-currency (Comp p.147)
# ============================================================================

func test_salvage_is_banked_at_post_battle_step_4() -> void:
	## p.147: "In Post-battle Step 4. Get paid, tally up how many units of Salvage
	## you have obtained."
	var c := _campaign()
	var result: Dictionary = {"salvage_units": 5}

	var total: int = SalvageLedger.bank_battle_salvage(c, result)

	assert_int(total).is_equal(5)
	assert_int(SalvageLedger.get_units(c)).is_equal(5)
	# Zeroed on the result so a re-run of the step cannot bank it twice.
	assert_int(int(result["salvage_units"])).is_equal(0)
	assert_int(int(result["salvage_units_banked"])).is_equal(5)

	SalvageLedger.bank_battle_salvage(c, result)
	assert_int(SalvageLedger.get_units(c)).is_equal(5)


func test_salvage_accumulates_across_battles() -> void:
	## Salvage persists — which is why the Scrapper entry point cannot be anchored
	## to the tally.
	var c := _campaign()
	SalvageLedger.bank_battle_salvage(c, {"salvage_units": 3})
	SalvageLedger.bank_battle_salvage(c, {"salvage_units": 4})
	assert_int(SalvageLedger.get_units(c)).is_equal(7)


func test_scrapper_price_treats_a_one_as_a_two() -> void:
	## p.147: "For each result, roll 1D6 to determine how many units of Salvage you
	## had to trade in. TREAT A ROLL OF A 1 AS A 2."
	##
	## Asserts the INVARIANT across many seeds rather than a value for one seed:
	## a seed fixes the RNG stream, not the number, so a value assertion would pin
	## the harness rather than the rule.
	assert_int(SalvageLedger.SCRAPPER_PRICE_FLOOR).is_equal(2)
	assert_int(SalvageLedger.SCRAPPER_OFFER_COUNT).is_equal(3)
	for seed_value in range(1, 40):
		for offer: Variant in SalvageLedger.roll_scrapper_offers(_rng(seed_value)):
			var price: int = int((offer as Dictionary).get("price", 0))
			assert_int(price).is_between(2, 6)


func test_scrapper_offers_three_rolls_on_the_loot_table() -> void:
	var offers: Array = SalvageLedger.roll_scrapper_offers(_rng(7))
	assert_int(offers.size()).is_equal(3)
	for offer: Variant in offers:
		assert_array((offer as Dictionary).get("items", [])).is_not_empty()


func test_credits_cannot_buy_salvage() -> void:
	## p.147: "Note that you cannot convert Credits to Salvage units." So a short
	## balance is simply a refusal — there must be no top-up path.
	var c := _campaign()
	SalvageLedger.add_units(c, 2)
	var result: Dictionary = SalvageLedger.buy_offer(
		c, {"price": 5, "items": [{"name": "Blast Pistol"}]})

	assert_bool(bool(result["bought"])).is_false()
	assert_int(SalvageLedger.get_units(c)).is_equal(2)
	assert_str(str(result["reason"])).contains("Not enough Salvage")


func test_buying_an_affordable_offer_spends_exactly_its_price() -> void:
	var c := _campaign()
	SalvageLedger.add_units(c, 6)
	var result: Dictionary = SalvageLedger.buy_offer(
		c, {"price": 4, "items": [{"name": "Blast Pistol"}]})

	assert_bool(bool(result["bought"])).is_true()
	assert_int(int(result["units_spent"])).is_equal(4)
	assert_int(SalvageLedger.get_units(c)).is_equal(2)


func test_the_scrapper_is_once_per_campaign_turn() -> void:
	## p.147: "You can visit the Scrappers once per campaign turn."
	var c := _campaign()
	assert_bool(SalvageLedger.can_visit_scrapper(c, 3)).is_true()
	SalvageLedger.mark_visited(c, 3)
	assert_bool(SalvageLedger.can_visit_scrapper(c, 3)).is_false()
	assert_bool(SalvageLedger.can_visit_scrapper(c, 4)).is_true()


func test_salvage_pays_for_exactly_three_things() -> void:
	## p.147: "1 unit of Salvage equals 1 Credit ONLY when purchasing: Ship repairs
	## / Ship modules / Bot upgrades." The list IS the rule.
	assert_bool(SalvageLedger.can_pay_with_salvage(
		SalvageLedger.PURPOSE_SHIP_REPAIR)).is_true()
	assert_bool(SalvageLedger.can_pay_with_salvage(
		SalvageLedger.PURPOSE_SHIP_MODULE)).is_true()
	assert_bool(SalvageLedger.can_pay_with_salvage(
		SalvageLedger.PURPOSE_BOT_UPGRADE)).is_true()
	for banned in ["weapon", "gear", "upkeep", "recruit", "ship_purchase", ""]:
		assert_bool(SalvageLedger.can_pay_with_salvage(banned)).is_false()


func test_salvage_offsets_a_cost_one_for_one_and_no_further() -> void:
	var c := _campaign()
	SalvageLedger.add_units(c, 3)

	var offset: Dictionary = SalvageLedger.apply_offset(
		c, 5, SalvageLedger.PURPOSE_SHIP_REPAIR)

	assert_int(int(offset["salvage_applied"])).is_equal(3)
	assert_int(int(offset["credits_due"])).is_equal(2)
	assert_int(SalvageLedger.get_units(c)).is_equal(0)


func test_salvage_does_not_offset_an_ineligible_purchase() -> void:
	var c := _campaign()
	SalvageLedger.add_units(c, 10)

	var offset: Dictionary = SalvageLedger.apply_offset(c, 4, "weapon_roll")

	assert_bool(bool(offset["eligible"])).is_false()
	assert_int(int(offset["credits_due"])).is_equal(4)
	assert_int(SalvageLedger.get_units(c)).is_equal(10)


func test_no_invasion_check_after_a_salvage_battle() -> void:
	## p.147: "There are no Invasion checks after a Salvage battle. It's just scrap
	## metal, right?"
	assert_bool(SalvageLedger.invasion_check_suppressed(
		{"mission_type": "salvage"})).is_true()
	assert_bool(SalvageLedger.invasion_check_suppressed(
		{"is_salvage": true})).is_true()
	assert_bool(SalvageLedger.invasion_check_suppressed(
		{"combat_mode": "salvage"})).is_true()
	assert_bool(SalvageLedger.invasion_check_suppressed(
		{"mission_type": "patrol"})).is_false()


func test_the_salvage_rules_are_wired_at_their_call_sites() -> void:
	## Each of these is a rule the book states and the code implemented with no
	## caller. A ledger that nothing calls is the same defect as no ledger.
	assert_str(_code_only(POST_BATTLE_PATH)).contains(
		"SalvageLedgerRef.bank_battle_salvage(")
	assert_str(_code_only(PAYMENT_PATH)).contains(
		"SalvageLedgerRef.invasion_check_suppressed(ctx.battle_result)")
	assert_str(_code_only(UPKEEP_PATH)).contains(
		"SalvageLedgerRef.PURPOSE_SHIP_REPAIR")
	assert_str(_code_only("res://src/ui/screens/ships/ShipManager.gd")).contains(
		"SalvageLedgerRef.PURPOSE_SHIP_MODULE")
	assert_str(_code_only(
		"res://src/core/character/advancement/AdvancementSystem.gd")).contains(
		"SalvageLedgerRef.PURPOSE_BOT_UPGRADE")
	assert_str(_code_only(PURCHASE_PATH)).contains("ScrapperTradeDialogScript.new()")


func test_the_battle_funnel_carries_the_salvage_keys() -> void:
	## THE FUNNEL RULE: anything post-battle needs must be stamped onto
	## mission_data BEFORE the battle and pass through BattleResultNormalizer, the
	## one chokepoint every exit crosses. `is_illegal` and `salvage_units` were
	## read post-battle with NO producer on battle_result — so the p.138
	## authorities roll was unreachable even after its own fix, and the tally the
	## whole chapter earns never left the battle screen.
	var src: String = _code_only(NORMALIZER_PATH)
	assert_str(src).contains("\"salvage_units\", \"is_illegal\", \"mission_type\"")

	var tac: String = _code_only("res://src/ui/screens/battle/TacticalBattleUI.gd")
	assert_str(tac).contains("salvage_mission_panel.salvage_collected.connect(")
	assert_str(tac).contains("_stored_mission_data[\"salvage_units\"] = total")


func test_a_refused_purchase_gives_the_salvage_back() -> void:
	## Salvage is spent before the credit half is checked so it can make a purchase
	## reachable at all. If the credits then fall short the purchase did not happen,
	## so the scrap was never "cashed in" — a mis-click must not cost it.
	var ship_src: String = _code_only("res://src/ui/screens/ships/ShipManager.gd")
	assert_str(ship_src).contains(
		"SalvageLedgerRef.add_units(campaign_for_salvage, salvage_paid)")
	var adv_src: String = _code_only(
		"res://src/core/character/advancement/AdvancementSystem.gd")
	assert_str(adv_src).contains(
		"SalvageLedgerRef.add_units(campaign_for_salvage, salvage_paid)")
