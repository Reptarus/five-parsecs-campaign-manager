class_name WorldTraitEffects
extends RefCounted

## The mechanical effects of the world you are standing on (Core Rules pp.73-75).
##
## THE GAP THIS FILLS: the World Traits Table was FLAVOUR TEXT. All 42 traits
## were rolled, stored on the planet, and printed in the world briefing, and the
## 31 campaign-side ones changed nothing. Fuel refinery did not make travel cost
## 3; Fuel shortage did not raise it; Lacks starship facilities did not cap
## repairs; Restricted education did not raise the Advanced Training threshold;
## Unity safe sector did not stop an Invasion. The world you chose to travel to
## was, mechanically, the same world every time.
##
## The other 11 traits are `battlefield` ones (haze, overgrown, warzone, gloom,
## barren, frozen, flat, reflective_dust, null_zone, crystals, fog). Those ARE
## wired, in FPCM_BattlefieldGenerator, and carry no `effects` block here on
## purpose — a second implementation of them would be a second source of truth.
##
## SHAPE: pure statics over the trait-id list. No tree, no autoloads, no RNG
## (dice specs are returned as strings for the caller to roll), so every consumer
## can be unit-tested and every value traces to a page. Values live in
## data/world_traits.json `effects`; this file is the ONLY reader of that block.
##
## USAGE — always pass the trait ids, never re-derive them:
##     var traits: Array = WorldTraitEffects.traits_for_current_world(campaign)
##     cost = WorldTraitEffects.travel_cost(base_cost, traits)

const TRAITS_PATH := "res://data/world_traits.json"

static var _effects_by_id: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(TRAITS_PATH, FileAccess.READ)
	if not file:
		push_warning("WorldTraitEffects: cannot open %s" % TRAITS_PATH)
		return
	var json := JSON.new()
	var ok: int = json.parse(file.get_as_text())
	file.close()
	if ok != OK or not json.data is Dictionary:
		push_warning("WorldTraitEffects: cannot parse %s" % TRAITS_PATH)
		return
	for entry in json.data.get("world_traits", []):
		if entry is Dictionary and entry.has("id"):
			_effects_by_id[str(entry["id"])] = entry.get("effects", {})


## The effects block for one trait id ({} for battlefield traits and unknowns).
static func effects_for(trait_id: String) -> Dictionary:
	_ensure_loaded()
	var e: Variant = _effects_by_id.get(_normalize(trait_id), {})
	return e if e is Dictionary else {}


## Trait ids are stored lowercase-with-underscores. Older saves and a few
## hand-written call sites use the display name ("Fuel Refinery") or an
## upper-case id, so normalise rather than silently missing the trait — a missed
## trait is indistinguishable from a world that does not have it.
static func _normalize(trait_id: String) -> String:
	return trait_id.strip_edges().to_lower().replace(" ", "_").replace("-", "_")


## Does this world have the trait?
static func has_trait(traits: Array, trait_id: String) -> bool:
	var wanted: String = _normalize(trait_id)
	for t in traits:
		if _normalize(str(t)) == wanted:
			return true
	return false


## Sum an integer effect key across every trait the world has. Traits stack
## unless the book says otherwise; the two "override" cases (travel cost, repair
## cap) have their own accessors below because they REPLACE rather than add.
static func sum_int(traits: Array, key: String) -> int:
	var total: int = 0
	for t in traits:
		total += int(effects_for(str(t)).get(key, 0))
	return total


## True if ANY trait sets this boolean effect.
static func any_flag(traits: Array, key: String) -> bool:
	for t in traits:
		if bool(effects_for(str(t)).get(key, false)):
			return true
	return false


## The lowest of `fallback` and every value a trait sets for this key.
##
## Used for the two traits that state a flat reduced cost — "Fuel refinery —
## Traveling from this world costs only 3 credits" and "Medical science — The
## cost for accelerated medical care is only 3 credits per character". The
## fallback participates in the minimum deliberately: both are worded as
## benefits ("only"), and a crew whose base cost is already lower (commercial
## travel is 1 credit per crew member, so a 2-person crew pays 2) must not be
## CHARGED MORE for landing on a world with a fuel refinery. The book does not
## address that case because it assumes a ship; taking the minimum is the only
## reading under which the trait cannot hurt you.
static func min_int(traits: Array, key: String, fallback: int) -> int:
	var best: int = fallback
	for t in traits:
		var e: Dictionary = effects_for(str(t))
		if e.has(key):
			best = mini(best, int(e[key]))
	return best


## The highest value any trait sets for a key, or `fallback`. Used for
## thresholds a trait RAISES.
static func max_int(traits: Array, key: String, fallback: int) -> int:
	var best: int = fallback
	for t in traits:
		var e: Dictionary = effects_for(str(t))
		if e.has(key):
			best = maxi(best, int(e[key]))
	return best


# ── Trait ids for the CURRENT world ─────────────────────────────────────────

## Read the current world's trait ids off the campaign. Both homes are checked
## because PlanetDataManager owns the visited-planet records while
## campaign.world_data is what world generation stamps and what saves carry.
static func traits_for_current_world(campaign: Variant) -> Array:
	if campaign == null:
		return []
	var out: Array = []
	if campaign is Dictionary:
		var wd: Variant = campaign.get("world_data", {})
		if wd is Dictionary:
			out = wd.get("traits", [])
	elif "world_data" in campaign and campaign.world_data is Dictionary:
		out = campaign.world_data.get("traits", [])
	return out if out is Array else []


# ── Travel (Core Rules pp.74-75) ────────────────────────────────────────────

## "Fuel refinery — Traveling from this world costs only 3 credits."
## "Fuel shortage — The cost to travel from this world is raised by 1D3 credits."
##
## The refinery OVERRIDES the base cost ("costs only 3"); the shortage ADDS to
## whatever the cost then is. `surcharge_roll` is the already-rolled 1D3 — this
## function does not roll, so the caller can log the die.
static func travel_cost(base_cost: int, traits: Array, surcharge_roll: int = 0) -> int:
	var cost: int = min_int(traits, "travel_cost_override", base_cost)
	if surcharge_roll > 0 and has_trait(traits, "fuel_shortage"):
		cost += surcharge_roll
	return maxi(0, cost)

## The dice spec a trait adds to travel cost, "" if none. Roll it, then pass the
## result to travel_cost().
static func travel_surcharge_dice(traits: Array) -> String:
	for t in traits:
		var spec: String = str(effects_for(str(t)).get("travel_cost_surcharge_dice", ""))
		if spec != "":
			return spec
	return ""

## "Bureaucratic mess — When attempting to leave, you must roll 2D6. On a 2-4,
## you are delayed and cannot leave this campaign turn without a bribe equal to
## the roll in credits."
static func departure_check_required(traits: Array) -> bool:
	return has_trait(traits, "bureaucratic_mess")

static func departure_is_blocked(roll: int, traits: Array) -> bool:
	if not departure_check_required(traits):
		return false
	return roll <= max_int(traits, "departure_blocked_max", 0)

## "Travel restricted — No more than one crew member may take the Explore option
## each campaign turn." Returns -1 for "no cap".
static func explore_task_cap(traits: Array) -> int:
	for t in traits:
		var e: Dictionary = effects_for(str(t))
		if e.has("explore_task_cap"):
			return int(e["explore_task_cap"])
	return -1


# ── Upkeep, repairs and services (Core Rules pp.73-74) ──────────────────────

## "High cost — Your crew size counts as being 2 higher for the purpose of
## Upkeep costs."
static func upkeep_crew_size(base_crew_size: int, traits: Array) -> int:
	return base_crew_size + sum_int(traits, "upkeep_crew_size_bonus")

## "Technical knowledge — Add +1 to all Repair attempts."
static func repair_roll_bonus(traits: Array) -> int:
	return sum_int(traits, "repair_roll_bonus")

## "Lacks starship facilities — You cannot spend more than 3 credits per
## campaign turn on starship Repairs." Returns -1 for "no cap".
static func repair_credit_cap(traits: Array) -> int:
	for t in traits:
		var e: Dictionary = effects_for(str(t))
		if e.has("repair_credit_cap"):
			return int(e["repair_credit_cap"])
	return -1

## "Easy recruiting — Add +1 to the roll when Recruiting."
static func recruit_roll_bonus(traits: Array) -> int:
	return sum_int(traits, "recruit_roll_bonus")

## "Adventurous population — When successfully Recruiting, you may roll up one
## additional character and then choose who to hire."
static func recruit_extra_candidates(traits: Array) -> int:
	return sum_int(traits, "recruit_extra_candidate")

## "Opportunities — Add +1 to the roll when searching for Patrons."
## "Corporate state — +2 when rolling to find a Patron."
static func patron_search_bonus(traits: Array) -> int:
	return sum_int(traits, "patron_search_bonus")

## "Corporate state — Patrons are always Corporations." "" if unconstrained.
static func forced_patron_type(traits: Array) -> String:
	for t in traits:
		var forced: String = str(effects_for(str(t)).get("patron_type_forced", ""))
		if forced != "":
			return forced
	return ""

## "Medical science — The cost for accelerated medical care is only 3 credits
## per character."
static func medical_care_cost(base_cost: int, traits: Array) -> int:
	return min_int(traits, "medical_care_cost", base_cost)

## "Bot manufacturing — All Bot upgrades are 1 credit cheaper."
static func bot_upgrade_cost(base_cost: int, traits: Array) -> int:
	return maxi(0, base_cost - sum_int(traits, "bot_upgrade_discount"))

## "Shipyards — The cost of all Ship Components is reduced by 2 credits."
static func ship_component_cost(base_cost: int, traits: Array) -> int:
	return maxi(0, base_cost - sum_int(traits, "ship_component_discount"))


# ── Advanced Training (Core Rules pp.73-74) ─────────────────────────────────

## "Restricted education — You must roll 6+ to be approved for Advanced
## Training on this world." (The book's default is 4+.)
static func training_approval_threshold(base_threshold: int, traits: Array) -> int:
	return max_int(traits, "training_approval_threshold", base_threshold)

## "Expensive education — The fee to enroll in Advanced Training is 3 credits."
## (The book's default is 1.)
static func training_enrollment_fee(base_fee: int, traits: Array) -> int:
	return max_int(traits, "training_enrollment_fee", base_fee)


# ── Economy and trade (Core Rules pp.73-74) ─────────────────────────────────

## "Booming economy — When rolling for post-battle credit rewards, any 1 on the
## dice is rerolled until it shows a score other than 1."
static func rerolls_credit_reward_ones(traits: Array) -> bool:
	return any_flag(traits, "credit_reward_reroll_ones")

## "Import restrictions — You cannot sell any items on this world."
static func selling_forbidden(traits: Array) -> bool:
	return any_flag(traits, "cannot_sell_items")

## "Weapon licensing — Any weapon obtained through the Trade Table or purchased
## outright costs +1 credit."
static func weapon_purchase_cost(base_cost: int, traits: Array) -> int:
	return base_cost + sum_int(traits, "weapon_purchase_surcharge")

## "Busy markets — Each campaign turn, you may spend 2 credits once to roll on
## the Trade Table." Returns -1 when the world does not offer it.
static func extra_trade_roll_cost(traits: Array) -> int:
	for t in traits:
		var e: Dictionary = effects_for(str(t))
		if e.has("trade_extra_roll_cost"):
			return int(e["trade_extra_roll_cost"])
	return -1

## "Free trade zone — One crew member per campaign turn can roll twice when
## using the Trade Table, and choose either result."
static func free_trade_rolls_per_turn(traits: Array) -> int:
	return sum_int(traits, "trade_roll_twice_per_turn")


# ── Opposition and Rivals (Core Rules pp.73-74) ─────────────────────────────

## "Heavily enforced — When fighting opponents from the Criminal Elements
## Encounter Table, the number encountered is reduced by 1."
## "Rampant crime — ... add 1 to the number encountered."
## "Dangerous — When rolling on the Roving Threats Encounter Table, increase the
## number of opponents by +1."
##
## Keyed on the ENCOUNTER CATEGORY, so a Dangerous world does not swell a gang
## fight and a Rampant Crime world does not swell a pack of Razor Lizards.
static func enemy_count_modifier(traits: Array, enemy_category: String) -> int:
	var category: String = _normalize(enemy_category)
	var total: int = 0
	for t in traits:
		var table: Variant = effects_for(str(t)).get("enemy_count_modifier", {})
		if table is Dictionary:
			total += int(table.get(category, 0))
	return total

## "Vendetta system — Opponents become your Rivals on a roll of 1 or 2."
## (Core Rules p.119 default is a 1 on a D6.) Returns the highest roll that
## still converts.
static func rival_conversion_threshold(base_threshold: int, traits: Array) -> int:
	return max_int(traits, "rival_conversion_threshold", base_threshold)


# ── Invasion and the Galactic War (Core Rules pp.73-74) ─────────────────────

## "Invasion risk — Add +1 to all Invasion rolls."
## "Imminent invasion — Add +2 to all Invasion rolls..."
## "Military outpost — Add +2 to Invasion rolls..."
static func invasion_roll_modifier(traits: Array) -> int:
	return sum_int(traits, "invasion_roll_modifier")

## "Unity safe sector — The world cannot be Invaded."
static func invasion_immune(traits: Array) -> bool:
	return any_flag(traits, "invasion_immune")

## "Imminent invasion — ...if the world is invaded, rolls for war progress are
## at -1." / "Military outpost — Add +2 when checking for war progress."
static func war_progress_modifier(traits: Array) -> int:
	return sum_int(traits, "war_progress_modifier")
