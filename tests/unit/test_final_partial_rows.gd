extends GdUnitTestSuite
## The last seven PARTIAL rows of docs/RULES_WIRING_AUDIT_2026-08.md.
##
## 96       Progressive Difficulty Option 2 (Compendium p.31). Option 1's Strength
##          bonus was live and Option 2 was a block of INSTRUCTION TEXT — it told
##          the player every battle from turn 3 to "Enable Strength-Adjusted
##          Enemies" and the toggle stayed off.
##
## 115      Benefits/Hazards/Conditions (Core Rules pp.83-84). 19 of 21 rows
##          applied; Private Transport (3 of the 21 Benefits rows land on it) and
##          Busy each had a correct accessor with ZERO callers.
##
## 119/157  The p.78 paid extra Trade rolls. "You can get additional rolls by
##          spending 3 credits each" had no UI at all, and the p.73 Busy Markets
##          2-credit roll had an accessor with no caller. Credits could not buy
##          anything in the World step.
##
## 153      New World Arrival step 3, the Freelancer License (p.72). Steps 1-2
##          were wired and step 3 DID NOT EXIST, so no world ever licensed Patron
##          work and the forged-licence gamble was unreachable.
##
## 162/239  The World Traits table. WorldTraitEffects was the byte-faithful SSOT
##          for all 31 campaign-side traits and ELEVEN of its accessors had zero
##          callers — implemented, correct, and reachable by nothing.

const WorldTraitEffects = preload("res://src/core/world/WorldTraitEffects.gd")
const NewWorldArrival = preload("res://src/core/campaign/NewWorldArrival.gd")
const ProgressiveTracker = preload("res://src/core/systems/ProgressiveDifficultyTracker.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

const UPKEEP_PATH := "res://src/ui/screens/world/components/UpkeepPhaseComponent.gd"
const CREW_TASK_PATH := "res://src/ui/screens/world/components/CrewTaskComponent.gd"
const PURCHASE_PATH := "res://src/ui/screens/world/components/PurchaseItemsComponent.gd"
const JOB_OFFER_PATH := "res://src/ui/screens/world/components/JobOfferComponent.gd"
const SHIP_PATH := "res://src/ui/screens/ships/ShipManager.gd"
const ADV_PATH := "res://src/core/character/advancement/AdvancementSystem.gd"
const PAYMENT_PATH := "res://src/core/campaign/phases/post_battle/PaymentProcessor.gd"
const WAR_PATH := "res://src/core/campaign/phases/post_battle/GalacticWarProcessor.gd"
const RESOLVER_PATH := "res://src/core/campaign/phases/post_battle/RivalPatronResolver.gd"
const CTC_PATH := "res://src/ui/screens/campaign/CampaignTurnController.gd"
const TOGGLES_PATH := "res://src/data/compendium_difficulty_toggles.gd"
const ENEMY_GEN_PATH := "res://src/core/systems/EnemyGenerator.gd"
const ROLLOVER_PATH := "res://src/core/campaign/CampaignPhaseManager.gd"


## Comment stripping is mandatory: every fix below is documented at its site with
## the book quote, and those quotes contain the very strings a wiring scan looks
## for — so an unstripped scan passes on the comment that explains the fix.
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
	c.patrons = []
	c.rivals = []
	return c


func _rng(seed_value: int) -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = seed_value
	return g


# ============================================================================
# ROWS 162 + 239 — every World Trait accessor now has a call site
# ============================================================================

## The heart of both rows. Each entry is (accessor, the file that must call it).
## A resolver nothing calls is the same defect as no resolver — this is the check
## that would have caught the original gap, and it is written so a NEW accessor
## added without a consumer fails here rather than shipping inert.
func test_every_world_trait_accessor_has_a_live_consumer() -> void:
	var wiring: Dictionary = {
		# p.73 "Lacks starship facilities — You cannot spend more than 3 credits
		# per campaign turn on starship Repairs."
		"repair_credit_cap": UPKEEP_PATH,
		# p.73 "Medical science — The cost for accelerated medical care is only 3
		# credits per character."
		"medical_care_cost": UPKEEP_PATH,
		# p.74 "Bot manufacturing — All Bot upgrades are 1 credit cheaper."
		"bot_upgrade_cost": ADV_PATH,
		# p.74 "Shipyards — The cost of all Ship Components is reduced by 2."
		"ship_component_cost": SHIP_PATH,
		# p.74 "Weapon licensing — Any weapon ... costs +1 credit."
		"weapon_purchase_cost": PURCHASE_PATH,
		# p.74 "Import restrictions — You cannot sell any items on this world."
		"selling_forbidden": PURCHASE_PATH,
		# p.73 "Busy markets — Each campaign turn, you may spend 2 credits once to
		# roll on the Trade Table."
		"extra_trade_roll_cost": CREW_TASK_PATH,
		# p.73 "Booming economy — ... any 1 on the dice is rerolled."
		"rerolls_credit_reward_ones": PAYMENT_PATH,
		# pp.73-74 "Imminent invasion" (-1) / "Military outpost" (+2).
		"war_progress_modifier": WAR_PATH,
		# p.74 "Corporate state — Patrons are always Corporations."
		"forced_patron_type": CREW_TASK_PATH,
		# p.74 "Adventurous population — ... roll up one additional character."
		"recruit_extra_candidates": CREW_TASK_PATH,
	}
	for accessor: String in wiring.keys():
		var src: String = _code_only(str(wiring[accessor]))
		assert_str(src).contains("%s(" % accessor)


func test_repair_credit_cap_is_the_book_number_and_resets_each_turn() -> void:
	## p.73: "no more than 3 credits per campaign turn on starship Repairs".
	assert_int(WorldTraitEffects.repair_credit_cap(
		["lacks_starship_facilities"])).is_equal(3)
	# -1 = no cap, which is what every other world must report.
	assert_int(WorldTraitEffects.repair_credit_cap(["fuel_refinery"])).is_equal(-1)
	assert_int(WorldTraitEffects.repair_credit_cap([])).is_equal(-1)

	# A per-CAMPAIGN-TURN cap with no reset silently becomes a per-CAMPAIGN cap,
	# which is a harsher rule than the book's and would look like a bug to nobody.
	var rollover: String = _code_only(ROLLOVER_PATH)
	assert_str(rollover).contains("repair_credits_spent_this_turn")
	assert_str(rollover).contains("busy_markets_roll_used_turn")


func test_medical_science_lowers_the_cost_and_never_raises_it() -> void:
	## p.73: "The cost for accelerated medical care is ONLY 3 credits" — a floor
	## replacing the p.76 default of 4, so it must never make care dearer.
	assert_int(WorldTraitEffects.medical_care_cost(4, ["medical_science"])).is_equal(3)
	assert_int(WorldTraitEffects.medical_care_cost(4, [])).is_equal(4)
	assert_int(WorldTraitEffects.medical_care_cost(2, ["medical_science"])).is_equal(2)


func test_the_three_cost_traits_move_the_right_direction() -> void:
	assert_int(WorldTraitEffects.bot_upgrade_cost(7, ["bot_manufacturing"])).is_equal(6)
	assert_int(WorldTraitEffects.ship_component_cost(10, ["shipyards"])).is_equal(8)
	assert_int(WorldTraitEffects.weapon_purchase_cost(3, ["weapon_licensing"])).is_equal(4)
	# And are inert on an ordinary world.
	assert_int(WorldTraitEffects.bot_upgrade_cost(7, [])).is_equal(7)
	assert_int(WorldTraitEffects.ship_component_cost(10, [])).is_equal(10)
	assert_int(WorldTraitEffects.weapon_purchase_cost(3, [])).is_equal(3)


func test_the_military_roll_checks_the_same_price_it_charges() -> void:
	## Weapon licensing makes the p.125 3-credit Military table roll cost 4. An
	## affordability check left on the base 3 lets a 3-credit crew add an item they
	## cannot pay for — the guard-applied-to-N-1-of-N shape.
	var src: String = _code_only(PURCHASE_PATH)
	assert_str(src).contains("if current_credits - cart_total < _weapon_cost(TABLE_ROLL_COST):")
	assert_str(src).contains("remaining_credits < _weapon_cost(TABLE_ROLL_COST)")
	# Gear and Gadget are NOT weapons and must keep the flat price.
	assert_str(src).contains("if item_type == \"weapon\" \\")


func test_import_restrictions_blocks_the_handler_not_just_the_button() -> void:
	## A gate that lives only in the widget is one rebuild away from bypassed.
	var src: String = _code_only(PURCHASE_PATH)
	assert_str(src).contains("if _selling_forbidden():\n\t\treturn")
	assert_bool(WorldTraitEffects.selling_forbidden(["import_restrictions"])).is_true()
	assert_bool(WorldTraitEffects.selling_forbidden(["busy_markets"])).is_false()


func test_booming_economy_rerolls_ones_per_die_and_cannot_hang() -> void:
	## p.73: "any 1 on the dice is rerolled UNTIL it shows a score other than 1."
	## The reroll must be bounded — Compendium p.32 "Money is Tight" rolls 1D6-1
	## with a MINIMUM OF 1, so on that toggle a 1 is a floor the reroll can never
	## escape and an unbounded loop would hang the post-battle sequence.
	assert_bool(WorldTraitEffects.rerolls_credit_reward_ones(
		["booming_economy"])).is_true()
	var src: String = _code_only(PAYMENT_PATH)
	assert_str(src).contains("func _roll_credit_die(reroll_ones: bool) -> int:")
	assert_str(src).contains("while value == 1 and guard < 12:")
	# Applied per die inside the loop, not once to the kept total.
	assert_str(src).contains("credit_roll = maxi(credit_roll, _roll_credit_die(booming))")


func test_war_progress_modifiers_are_the_book_values() -> void:
	## p.73 "Imminent invasion — ... rolls for war progress are at -1."
	## p.74 "Military outpost — Add +2 when checking for war progress."
	assert_int(WorldTraitEffects.war_progress_modifier(["imminent_invasion"])).is_equal(-1)
	assert_int(WorldTraitEffects.war_progress_modifier(["military_outpost"])).is_equal(2)
	assert_int(WorldTraitEffects.war_progress_modifier([])).is_equal(0)


func test_corporate_state_forces_the_patron_type_and_blacklists_on_failure() -> void:
	## p.74: "Patrons are always Corporations. FAILING A MISSION MEANS BEING
	## BLACKLISTED and you cannot get Patrons here again." The blacklist is the
	## clause with teeth and it had no writer at all.
	assert_str(WorldTraitEffects.forced_patron_type(["corporate_state"])).is_not_empty()
	assert_str(WorldTraitEffects.forced_patron_type([])).is_empty()

	var resolver: String = _code_only(RESOLVER_PATH)
	assert_str(resolver).contains("_apply_corporate_blacklist(ctx)")
	assert_str(resolver).contains("patron_blacklist_planets")
	# ...and a writer with no reader is the same bug in the other direction.
	var task: String = _code_only(CREW_TASK_PATH)
	assert_str(task).contains("func _patron_blacklisted() -> bool:")
	assert_str(task).contains("if _patron_blacklisted():")


func test_adventurous_population_offers_a_choice_not_a_reroll() -> void:
	## p.74: "you may roll up one additional character AND THEN CHOOSE WHO TO
	## HIRE." Auto-picking would turn the decision into a reroll.
	assert_int(WorldTraitEffects.recruit_extra_candidates(
		["adventurous_population"])).is_equal(1)
	assert_int(WorldTraitEffects.recruit_extra_candidates([])).is_equal(0)
	var src: String = _code_only(CREW_TASK_PATH)
	assert_str(src).contains("_offer_recruit_choice(campaign, candidates)")
	assert_str(src).contains("if candidates.size() == 1:")


# ============================================================================
# ROWS 119 + 157 — paid extra Trade rolls (p.78) and Busy Markets (p.73)
# ============================================================================

func test_extra_trade_rolls_cost_three_credits_and_need_a_trader() -> void:
	## p.78: "You can get additional rolls by spending 3 credits each. AT LEAST ONE
	## CREW MEMBER MUST BE TRADING to permit this expenditure."
	var src: String = _code_only(CREW_TASK_PATH)
	assert_str(src).contains("const EXTRA_TRADE_ROLL_COST := 3")
	assert_str(src).contains("func _someone_is_trading() -> bool:")
	assert_str(src).contains("and _someone_is_trading() \\")
	# The purchased rolls must resolve through the SAME pipeline as the free ones,
	# or the 100-row Trade table forks.
	assert_str(src).contains("for paid_result in _resolve_paid_trade_rolls():")
	assert_str(src).contains("_resolve_table_task(result, {\"id\": \"trade\", \"name\": \"Trade\"}, {})")


func test_busy_markets_is_two_credits_once_per_turn() -> void:
	## p.73: "Each campaign turn, you may spend 2 CREDITS ONCE to roll on the Trade
	## Table." A different price and a different limit from p.78's 3 credits, so
	## they are counted separately — merging them would let the Busy Markets roll
	## bypass p.78's someone-must-be-Trading gate.
	assert_int(WorldTraitEffects.extra_trade_roll_cost(["busy_markets"])).is_equal(2)
	# -1 = the world does not offer it at all.
	assert_int(WorldTraitEffects.extra_trade_roll_cost([])).is_equal(-1)
	var src: String = _code_only(CREW_TASK_PATH)
	assert_str(src).contains("func _busy_market_used_this_turn() -> bool:")
	assert_str(src).contains("busy_markets_roll_used_turn")


# ============================================================================
# ROW 153 — New World Arrival step 3, the Freelancer License (p.72)
# ============================================================================

func test_licence_is_required_on_a_five_or_six() -> void:
	## p.72: "Roll 1D6. On a 5-6 the world requires a Freelancer License to perform
	## Patron jobs: Roll a further 1D6 to determine how many credits this will
	## cost."
	##
	## Asserts the INVARIANT over many seeds rather than a value for one: a seed
	## fixes the RNG stream, not the number.
	assert_int(NewWorldArrival.LICENCE_REQUIRED_ON).is_equal(5)
	var required: int = 0
	for s in range(1, 60):
		var c := _campaign()
		var out: Dictionary = NewWorldArrival.roll_licensing_requirement(
			c, "planet_%d" % s, _rng(s))
		var roll: int = int(out["roll"])
		assert_int(roll).is_between(1, 6)
		assert_bool(bool(out["applies"])).is_equal(roll >= 5)
		if bool(out["applies"]):
			required += 1
			assert_int(int(out["fee"])).is_between(1, 6)
		else:
			assert_int(int(out["fee"])).is_equal(0)
	assert_int(required).is_greater(0)


func test_a_world_is_only_ever_rolled_once() -> void:
	## Re-rolling on re-entry would let a player reload until the world came up
	## unlicensed — the check is part of ARRIVING.
	var c := _campaign()
	var first: Dictionary = NewWorldArrival.roll_licensing_requirement(
		c, "gamma_9", _rng(4))
	for s in range(50, 60):
		var again: Dictionary = NewWorldArrival.roll_licensing_requirement(
			c, "gamma_9", _rng(s))
		assert_bool(bool(again["applies"])).is_equal(bool(first["applies"]))


func test_a_purchased_licence_lasts_for_perpetuity() -> void:
	## p.72: "Once purchased, it remains in effect FOR PERPETUITY, even if you
	## return to the world later on."
	var c := _campaign()
	c.progress_data["freelancer_licence_required"] = {"delta_4": true}
	c.progress_data["freelancer_licence_fees"] = {"delta_4": 5}
	assert_bool(NewWorldArrival.requires_freelancer_licence(c, "delta_4")).is_true()
	assert_int(NewWorldArrival.licence_fee(c, "delta_4")).is_equal(5)

	NewWorldArrival.grant_licence(c, "delta_4")
	assert_bool(NewWorldArrival.requires_freelancer_licence(c, "delta_4")).is_false()
	# And a fresh arrival check on that world must not re-impose it.
	var out: Dictionary = NewWorldArrival.roll_licensing_requirement(c, "delta_4", _rng(9))
	assert_bool(bool(out["already_licensed"])).is_true()


func test_forgery_is_one_attempt_and_a_natural_one_costs_a_rival() -> void:
	## p.72: "roll 1D6+Savvy. If the score is a 6+, you obtain a License for free.
	## If the roll is a 1 BEFORE MODIFIERS, you must add a Rival... ONLY ONE
	## ATTEMPT IS PERMITTED."
	##
	## "Before modifiers" is the whole shape of the gamble: a high-Savvy character
	## is no safer from being caught, so the flag must key on the natural die.
	var caught: int = 0
	var passed: int = 0
	for s in range(1, 40):
		var c := _campaign()
		var out: Dictionary = NewWorldArrival.attempt_forged_licence(
			c, "epsilon", 4, _rng(s))
		var roll: int = int(out["roll"])
		assert_bool(bool(out["natural_one"])).is_equal(roll == 1)
		assert_bool(bool(out["adds_rival"])).is_equal(roll == 1)
		assert_bool(bool(out["success"])).is_equal(roll + 4 >= 6)
		if bool(out["adds_rival"]):
			caught += 1
		if bool(out["success"]):
			passed += 1
		# "Only one attempt is permitted."
		assert_bool(NewWorldArrival.forgery_attempted(c, "epsilon")).is_true()
		var second: Dictionary = NewWorldArrival.attempt_forged_licence(
			c, "epsilon", 4, _rng(s + 1))
		assert_str(str(second["reason"])).contains("Only one attempt")
	assert_int(caught).is_greater(0)
	assert_int(passed).is_greater(0)


func test_a_successful_forgery_grants_the_licence_for_free() -> void:
	var c := _campaign()
	c.progress_data["freelancer_licence_required"] = {"zeta": true}
	# Savvy 5 + any die reaches 6+, so this cannot fail for the wrong reason.
	var out: Dictionary = NewWorldArrival.attempt_forged_licence(c, "zeta", 5, _rng(2))
	assert_bool(bool(out["success"])).is_true()
	assert_bool(NewWorldArrival.requires_freelancer_licence(c, "zeta")).is_false()


func test_the_licence_gates_patron_work_only() -> void:
	## p.72 scopes it exactly: "requires a Freelancer License TO PERFORM PATRON
	## JOBS". An Opportunity mission needs none, which is what stops this from
	## soft-locking the turn — p.85's Opportunity battle is always available.
	var src: String = _code_only(JOB_OFFER_PATH)
	assert_str(src).contains("if _is_patron_job(job) and _licence_required_here():")
	assert_str(src).contains("func _is_patron_job(job: Dictionary) -> bool:")
	# Both routes out of the requirement must be reachable.
	assert_str(src).contains("func _on_buy_licence() -> void:")
	assert_str(src).contains("func _on_forge_licence() -> void:")
	# And the roll must actually happen on arrival, or the gate never fires.
	assert_str(_code_only(UPKEEP_PATH)).contains("_roll_freelancer_licence(campaign)")


# ============================================================================
# ROW 96 — Progressive Difficulty Option 2 (Compendium p.31)
# ============================================================================

func test_option_2_unlocks_the_toggles_at_the_book_turns() -> void:
	## p.31: turn 3 Strength Adjusted Enemies; turn 5 Actually Specialized +
	## Better Leadership; turn 8 Armored Leaders + Veteran.
	assert_array(ProgressiveTracker.OPTION_2_TOGGLE_UNLOCKS[3]).contains(
		["strength_adjusted"])
	assert_array(ProgressiveTracker.OPTION_2_TOGGLE_UNLOCKS[5]).contains(
		["actually_specialized", "better_leadership"])
	assert_array(ProgressiveTracker.OPTION_2_TOGGLE_UNLOCKS[8]).contains(
		["armored_leaders", "veteran"])
	# Every unlocked id must be one the rule sites actually consult — an id that
	# matches no `is_toggle_active()` call would unlock nothing.
	var live_ids: Array = [
		"strength_adjusted", "actually_specialized", "better_leadership",
		"armored_leaders", "veteran",
	]
	for turn: Variant in ProgressiveTracker.OPTION_2_TOGGLE_UNLOCKS.keys():
		for id: Variant in ProgressiveTracker.OPTION_2_TOGGLE_UNLOCKS[turn]:
			assert_array(live_ids).contains([id])


func test_option_2_elite_thresholds_match_the_book() -> void:
	## p.31: turn 14 "elite-level enemies on a D6 roll of 4+", 16 "on a 3+",
	## 20 "always". Before 14, Option 2 has not introduced elite enemies at all.
	assert_int(ProgressiveTracker.OPTION_2_ELITE_NEVER).is_equal(7)
	assert_bool(ProgressiveTracker.option_2_selected([2])).is_true()
	assert_bool(ProgressiveTracker.option_2_selected([1, 2])).is_true()
	assert_bool(ProgressiveTracker.option_2_selected([1])).is_false()
	assert_bool(ProgressiveTracker.option_2_selected([])).is_false()


func test_option_2_unlocks_reach_the_toggle_chokepoint() -> void:
	## Merged at get_active_toggles(), the one call every rule site reads —
	## the alternative is a branch at each of the twelve is_toggle_active() sites,
	## which is the guard-applied-to-N-1-of-N shape and would recur with every new
	## toggle.
	var src: String = _code_only(TOGGLES_PATH)
	assert_str(src).contains("var progressive: Array = _progressive_unlocks()")
	assert_str(src).contains("option_2_toggle_unlocks(")
	assert_str(src).contains("_merge_ids(ids, progressive)")
	# ...and the elite D6 gate must reach the generator.
	var gen: String = _code_only(ENEMY_GEN_PATH)
	assert_str(gen).contains("if _option_2_blocks_elite():")
	assert_str(gen).contains("option_2_elite_target(")


# ============================================================================
# ROW 115 — the last two Benefits/Conditions rows (pp.83-84)
# ============================================================================

func test_private_transport_suppresses_the_p85_rival_check() -> void:
	## p.84, Benefits 8-10: "Private Transport — If you have Rivals, THEY CANNOT
	## TRACK YOU THIS CAMPAIGN TURN." Three of the 21 Benefits rows land on it,
	## making it the most common Benefit in the subtable — and its only possible
	## consumer was the p.85 check, in a different file, which never called it.
	var src: String = _code_only(CTC_PATH)
	assert_str(src).contains("PatronJobEffectsRef.blocks_rival_tracking(current_mission)")
	# Placed on the ONE suppression chokepoint, next to the Black Job clause,
	# rather than as a second guard in the encounter path.
	var suppress_at: int = src.find("func _story_rival_suppression_reason()")
	var call_at: int = src.find("blocks_rival_tracking(current_mission)")
	assert_int(suppress_at).is_greater(0)
	assert_int(call_at).is_greater(suppress_at)


func test_busy_banks_a_named_followup_offer() -> void:
	## p.84, Conditions 7-8: "Busy — If the mission is a success, the Patron offers
	## a new job next campaign turn." Banked as a NAMED patron id, not folded into
	## `patron_offers_owed` — that one draws a RANDOM existing Patron, and Busy
	## names the specific employer.
	var resolver: String = _code_only(RESOLVER_PATH)
	assert_str(resolver).contains("PatronJobEffects.offers_new_job_on_success(ctx.battle_result)")
	assert_str(resolver).contains("patron_followup_offers")
	# A producer with no consumer is the same defect as no producer.
	var offers: String = _code_only(JOB_OFFER_PATH)
	assert_str(offers).contains("func _consume_patron_followups(")
	assert_str(offers).contains("for followup: Dictionary in _consume_patron_followups(")
