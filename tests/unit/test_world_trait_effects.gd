extends GdUnitTestSuite
## World Traits actually do something (Core Rules pp.73-75).
##
## WHAT WAS BROKEN: the World Traits Table was FLAVOUR TEXT. All 42 traits were
## rolled, stored on the planet and printed in the world briefing, and the 31
## campaign-side ones changed nothing. Fuel refinery did not make travel cost 3;
## Fuel shortage did not raise it; Lacks starship facilities did not cap repairs;
## Restricted education did not raise the Advanced Training threshold; Unity safe
## sector did not stop an Invasion. The world you travelled to was, mechanically,
## the same world every time.
##
## The 11 `battlefield` traits (haze, overgrown, warzone, gloom, barren, frozen,
## flat, reflective_dust, null_zone, crystals, fog) were ALREADY wired, in
## FPCM_BattlefieldGenerator. They deliberately carry no `effects` block — a
## second implementation would be a second source of truth.

const WTE = preload("res://src/core/world/WorldTraitEffects.gd")

# ── The data covers what it should, and only that ───────────────────────────

## Every campaign-side trait has an effects block; every battlefield trait does
## not. If a new trait is added without one it will silently do nothing, which
## is the exact failure this whole suite exists to prevent.
func test_every_campaign_side_trait_has_an_effects_block() -> void:
	var file := FileAccess.open("res://data/world_traits.json", FileAccess.READ)
	assert_object(file).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(file.get_as_text())).is_equal(OK)
	file.close()

	var missing: Array = []
	var battlefield_with_effects: Array = []
	for t in json.data["world_traits"]:
		var is_battlefield: bool = str(t.get("category", "")) == "battlefield"
		var has_effects: bool = t.has("effects") and not (t["effects"] as Dictionary).is_empty()
		if not is_battlefield and not has_effects:
			missing.append(t["id"])
		if is_battlefield and has_effects:
			battlefield_with_effects.append(t["id"])

	assert_array(missing).override_failure_message(
		"campaign-side traits with no effects block (they will do nothing): %s" % [missing]
	).is_empty()
	assert_array(battlefield_with_effects).override_failure_message(
		"battlefield traits must NOT carry effects — the generator owns them: %s"
			% [battlefield_with_effects]).is_empty()

## Trait ids are stored lowercase; a display name or a legacy upper-case id must
## still resolve. A missed trait is indistinguishable from a world without it.
func test_trait_ids_normalize() -> void:
	assert_bool(WTE.has_trait(["fuel_refinery"], "Fuel Refinery")).is_true()
	assert_bool(WTE.has_trait(["Fuel Refinery"], "fuel_refinery")).is_true()
	assert_bool(WTE.has_trait(["fuel-refinery"], "fuel_refinery")).is_true()
	assert_bool(WTE.has_trait(["fuel_refinery"], "fuel_shortage")).is_false()

# ── Travel (pp.74-75) ───────────────────────────────────────────────────────

## "Fuel refinery — Traveling from this world costs only 3 credits."
func test_fuel_refinery_overrides_travel_cost() -> void:
	assert_int(WTE.travel_cost(5, ["fuel_refinery"])).is_equal(3)
	# It is an OVERRIDE, not a discount: a cheaper base is not raised to 3.
	assert_int(WTE.travel_cost(2, ["fuel_refinery"])).is_equal(2)
	assert_int(WTE.travel_cost(5, [])).is_equal(5)

## "Fuel shortage — The cost to travel from this world is raised by 1D3 credits."
func test_fuel_shortage_adds_the_rolled_surcharge() -> void:
	assert_str(WTE.travel_surcharge_dice(["fuel_shortage"])).is_equal("1D3")
	assert_str(WTE.travel_surcharge_dice([])).is_equal("")
	assert_int(WTE.travel_cost(5, ["fuel_shortage"], 3)).is_equal(8)
	# A surcharge roll must not apply on a world without the trait.
	assert_int(WTE.travel_cost(5, [], 3)).is_equal(5)

## "Bureaucratic mess — ... roll 2D6. On a 2-4, you are delayed."
func test_bureaucratic_mess_blocks_departure_on_2_to_4() -> void:
	var t := ["bureaucratic_mess"]
	assert_bool(WTE.departure_check_required(t)).is_true()
	assert_bool(WTE.departure_is_blocked(4, t)).is_true()
	assert_bool(WTE.departure_is_blocked(5, t)).is_false()
	# No trait, no check — a 2 must not strand a crew on an ordinary world.
	assert_bool(WTE.departure_is_blocked(2, [])).is_false()

## "Travel restricted — No more than one crew member may take the Explore option
## each campaign turn."
func test_travel_restricted_caps_explore() -> void:
	assert_int(WTE.explore_task_cap(["travel_restricted"])).is_equal(1)
	assert_int(WTE.explore_task_cap([])).is_equal(-1)

# ── Upkeep, repairs, services (pp.73-74) ────────────────────────────────────

## "High cost — Your crew size counts as being 2 higher for the purpose of
## Upkeep costs."
func test_high_cost_raises_the_upkeep_crew_size() -> void:
	assert_int(WTE.upkeep_crew_size(5, ["high_cost"])).is_equal(7)
	assert_int(WTE.upkeep_crew_size(5, [])).is_equal(5)

## "Lacks starship facilities — You cannot spend more than 3 credits per
## campaign turn on starship Repairs."
func test_lacks_starship_facilities_caps_repair_spending() -> void:
	assert_int(WTE.repair_credit_cap(["lacks_starship_facilities"])).is_equal(3)
	assert_int(WTE.repair_credit_cap([])).is_equal(-1)

func test_service_bonuses() -> void:
	assert_int(WTE.repair_roll_bonus(["technical_knowledge"])).is_equal(1)
	assert_int(WTE.recruit_roll_bonus(["easy_recruiting"])).is_equal(1)
	assert_int(WTE.recruit_extra_candidates(["adventurous_population"])).is_equal(1)
	assert_int(WTE.patron_search_bonus(["opportunities"])).is_equal(1)
	assert_int(WTE.medical_care_cost(6, ["medical_science"])).is_equal(3)
	assert_int(WTE.bot_upgrade_cost(5, ["bot_manufacturing"])).is_equal(4)
	assert_int(WTE.ship_component_cost(10, ["shipyards"])).is_equal(8)

## "Corporate state — +2 when rolling to find a Patron. Patrons are always
## Corporations."
func test_corporate_state() -> void:
	assert_int(WTE.patron_search_bonus(["corporate_state"])).is_equal(2)
	assert_str(WTE.forced_patron_type(["corporate_state"])).is_equal("Corporation")
	assert_str(WTE.forced_patron_type([])).is_equal("")

# ── Advanced Training (pp.73-74) ────────────────────────────────────────────

## "Restricted education — You must roll 6+ to be approved for Advanced Training
## on this world." (default 4+)
func test_restricted_education_raises_the_approval_threshold() -> void:
	assert_int(WTE.training_approval_threshold(4, ["restricted_education"])).is_equal(6)
	assert_int(WTE.training_approval_threshold(4, [])).is_equal(4)

## "Expensive education — The fee to enroll in Advanced Training is 3 credits."
## (default 1)
func test_expensive_education_raises_the_fee() -> void:
	assert_int(WTE.training_enrollment_fee(1, ["expensive_education"])).is_equal(3)
	assert_int(WTE.training_enrollment_fee(1, [])).is_equal(1)

# ── Opposition and Rivals (pp.73-74) ────────────────────────────────────────

## The three opposition traits are keyed on the ENCOUNTER CATEGORY. A Dangerous
## world must not swell a gang fight, and a Rampant Crime world must not swell a
## pack of Razor Lizards.
func test_opposition_traits_only_apply_to_their_own_category() -> void:
	assert_int(WTE.enemy_count_modifier(["rampant_crime"], "criminal_elements")).is_equal(1)
	assert_int(WTE.enemy_count_modifier(["rampant_crime"], "roving_threats")).is_equal(0)
	assert_int(WTE.enemy_count_modifier(["heavily_enforced"], "criminal_elements")).is_equal(-1)
	assert_int(WTE.enemy_count_modifier(["heavily_enforced"], "hired_muscle")).is_equal(0)
	assert_int(WTE.enemy_count_modifier(["dangerous"], "roving_threats")).is_equal(1)
	assert_int(WTE.enemy_count_modifier(["dangerous"], "criminal_elements")).is_equal(0)

## "Vendetta system — Opponents become your Rivals on a roll of 1 or 2."
func test_vendetta_system_widens_the_rival_roll() -> void:
	assert_int(WTE.rival_conversion_threshold(1, ["vendetta_system"])).is_equal(2)
	assert_int(WTE.rival_conversion_threshold(1, [])).is_equal(1)

# ── Invasion and the Galactic War (pp.73-74) ────────────────────────────────

func test_invasion_modifiers_stack() -> void:
	assert_int(WTE.invasion_roll_modifier(["invasion_risk"])).is_equal(1)
	assert_int(WTE.invasion_roll_modifier(["imminent_invasion"])).is_equal(2)
	assert_int(WTE.invasion_roll_modifier(["military_outpost"])).is_equal(2)
	assert_int(WTE.invasion_roll_modifier(["invasion_risk", "military_outpost"])).is_equal(3)
	assert_int(WTE.invasion_roll_modifier([])).is_equal(0)

## "Unity safe sector — The world cannot be Invaded." Absolute: no other
## modifier can drag the world into an Invasion.
func test_unity_safe_sector_is_absolute() -> void:
	assert_bool(WTE.invasion_immune(["unity_safe_sector"])).is_true()
	assert_bool(WTE.invasion_immune(["invasion_risk"])).is_false()

## "Imminent invasion — ... rolls for war progress are at -1."
## "Military outpost — Add +2 when checking for war progress."
func test_war_progress_modifiers() -> void:
	assert_int(WTE.war_progress_modifier(["imminent_invasion"])).is_equal(-1)
	assert_int(WTE.war_progress_modifier(["military_outpost"])).is_equal(2)

# ── Economy (pp.73-74) ──────────────────────────────────────────────────────

func test_economy_traits() -> void:
	assert_bool(WTE.rerolls_credit_reward_ones(["booming_economy"])).is_true()
	assert_bool(WTE.selling_forbidden(["import_restrictions"])).is_true()
	assert_bool(WTE.selling_forbidden([])).is_false()
	assert_int(WTE.weapon_purchase_cost(3, ["weapon_licensing"])).is_equal(4)
	assert_int(WTE.extra_trade_roll_cost(["busy_markets"])).is_equal(2)
	assert_int(WTE.extra_trade_roll_cost([])).is_equal(-1)
	assert_int(WTE.free_trade_rolls_per_turn(["free_trade_zone"])).is_equal(1)

# ── Battlefield traits stay out of it ───────────────────────────────────────

## A world of nothing but battlefield traits must produce ZERO campaign-side
## effect — otherwise the generator's copy and this one would both fire.
func test_battlefield_traits_have_no_campaign_side_effect() -> void:
	var bf := ["haze", "overgrown", "warzone", "gloom", "barren", "frozen",
		"flat", "reflective_dust", "null_zone", "crystals", "fog"]
	assert_int(WTE.travel_cost(5, bf)).is_equal(5)
	assert_int(WTE.upkeep_crew_size(5, bf)).is_equal(5)
	assert_int(WTE.invasion_roll_modifier(bf)).is_equal(0)
	assert_int(WTE.training_approval_threshold(4, bf)).is_equal(4)
	assert_int(WTE.enemy_count_modifier(bf, "criminal_elements")).is_equal(0)
	assert_int(WTE.repair_credit_cap(bf)).is_equal(-1)
