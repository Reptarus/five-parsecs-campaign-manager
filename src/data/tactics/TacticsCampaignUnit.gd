class_name TacticsCampaignUnit
extends RefCounted

## The campaign-unit RECORD in a Tactics roster, and the only place its shape and
## its mutations are written down.
##
## Source: Five Parsecs: Tactics **pp.106-107** — "CAMPAIGN PROGRESSION".
## ⚠ CITE CORRECTED 2026-09-04 from "pp.155-172", which spans the **Lifeforms
## bestiary** into **Items and Costs** — neither covers campaign progression.
##
## ⚠ THIS IS A STATIC HELPER OVER A `Dictionary`, NOT A `Resource` YOU INSTANTIATE.
## It used to be a Resource with ~15 `@export` fields, `to_dict()` and `from_dict()`
## — and NOTHING EVER BUILT ONE. `TacticsCampaignCore.campaign_units` is an Array of
## plain Dictionaries (its own comment at :63 says so), the creation wizard hand-built
## those Dictionaries from a literal, `TacticsDashboard` reads them with
## `Dictionary.get()`, and `TacticsPhaseManager` mutates them by key. So the Resource
## was a SECOND shape for the same concept with zero users except `generate_id()`.
##
## ⭐ That is not a tidiness complaint. Two copies of one shape is exactly what broke
## this file on 2026-09-10: three fabricated CP constants were correctly deleted, the
## three lines that USED them were left behind, GDScript failed the whole class at
## PARSE time, and `TacticsCreationCoordinator.gd:55` load()s it — so Tactics campaign
## creation was dead in product with every lint green. The shape now has one owner.
##
## ── What is NOT here, and why ────────────────────────────────────────────────
##
## **Campaign Points are not a per-unit quantity.** p.106: *"Players use Campaign
## Points (CP) to track their progression"*, and the book's own question *"Are Points
## Tied to the Player or Army?"* offers exactly two answers — player-level or
## army-level. Never unit-level. `TacticsCampaignCore` owns the pool (`earn_cp` /
## `spend_cp` / `get_available_cp`). The retired `campaign_points` /
## `campaign_points_spent` keys on the unit record could therefore never be anything
## but 0, and `TacticsDashboard` was printing that 0 in a "CP" column beside a real
## campaign-level CP figure in its own header.
##
## **`objectives_completed` is gone.** Its only writer counted a "secondary
## objective", which is not a category in this book — it was part of the same
## fabricated CP block. The book's scoring axis is Victory Points (p.73), and those
## are consumed at the campaign level by `TacticsCampaignCore.campaign_points_for()`.
##
## **`add_veteran_skill()` is gone.** It defaulted to `cost := 1` while p.107 prices
## *Gain Veteran Skill* at **4 CP**, and the live store for veteran skills is
## `TacticsCampaignCore.veteran_skills` (a Dictionary keyed by unit_id, written by
## `TacticsPhaseManager._apply_advancement_results()`). An uncalled function carrying
## a wrong book value is the most expensive kind of dead code — it reads as
## implemented, so the next person to need the rule wires it instead of reading p.107.
##
## ── What `battles_fought` is for ─────────────────────────────────────────────
##
## It is a campaign LOG value, not a mechanic — but p.106's *Weakened* result makes it
## load-bearing anyway: *"until the unit can sit out a campaign battle without being
## deployed, it must deploy with one figure fewer than normal."* That rule needs a
## per-unit record of which battles a unit was deployed into, which is precisely what
## `credit_battle()` maintains.

## Every key a campaign-unit record carries. `normalize()` is the migration:
## anything outside this set is a retired key and is erased on load, because
## `TacticsCampaignCore` round-trips these Dictionaries verbatim
## (`campaign_units.duplicate(true)` in both directions) — so a key that reaches
## disk once survives every future save unless something removes it.
const FIELDS: PackedStringArray = [
	"unit_id",
	"custom_name",
	"base_unit_id",
	"species_id",
	"battles_fought",
	"battles_won",
	"current_models",
	"is_destroyed",
	"selected_upgrades",
	"condition",
	"unusable_battles",
	# p.108 Unit Customization: [{op: "add"|"remove", weapon}] on top of the base
	# unit's weapons. Written only by TacticsAdvancement.apply_purchase().
	"weapon_changes",
	# p.138 Mechanized Infantry: the transport bought with the squad, "" for none.
	"transport_vehicle_id",
]

## Keys written by an older build that are no longer part of the record.
## See the class docblock for the book citation retiring each one.
const RETIRED_FIELDS: PackedStringArray = [
	"campaign_points",
	"campaign_points_spent",
	"objectives_completed",
	"veteran_skills",
	# p.105: "If a unit remains on the table at the end of the game, we assume it
	# recovers completely ... Casualties are replaced". A figure count that went down
	# after every battle was not the rule; the p.106 Unit Losses result replaced it.
	"models_lost_total",
	"models_lost_current",
]

## The p.106 Unit Losses conditions a unit can carry between battles. "lost" units are
## kept as a record (is_destroyed) so their history survives; they never deploy again.
const CONDITION_OK := "ok"
const CONDITION_DEVASTATED := "devastated"
const CONDITION_WEAKENED := "weakened"
const CONDITION_LOST := "lost"


## Generate a unique unit id.
static func generate_id() -> String:
	return "tcu_%d_%d" % [Time.get_unix_time_from_system(), randi() % 10000]


## Build a fresh campaign-unit record.
##
## ⚠ USE THIS instead of a dictionary literal at the call site. The creation wizard
## used to carry its own literal, which is how the record grew two definitions that
## could drift apart — and did.
static func new_unit(
		base_unit_id: String,
		species_id: String,
		custom_name: String = "",
		model_count: int = 5,
		selected_upgrades: Array = [],
		transport_vehicle_id: String = "") -> Dictionary:
	return {
		"unit_id": generate_id(),
		"custom_name": custom_name,
		"base_unit_id": base_unit_id,
		"species_id": species_id,
		"battles_fought": 0,
		"battles_won": 0,
		"current_models": model_count if model_count > 0 else 5,
		"is_destroyed": false,
		"selected_upgrades": selected_upgrades.duplicate(),
		"condition": CONDITION_OK,
		"unusable_battles": 0,
		"weapon_changes": [],
		"transport_vehicle_id": transport_vehicle_id,
	}


## Bring a record loaded from disk up to the current shape: fill missing keys with
## their defaults, drop retired ones. Mutates and returns the same Dictionary.
static func normalize(unit: Dictionary) -> Dictionary:
	var template: Dictionary = new_unit("", "")
	for key: String in FIELDS:
		if not unit.has(key):
			unit[key] = template[key]
	# `unit_id` must never be regenerated on load — a new id would orphan the
	# unit's veteran skills, which TacticsCampaignCore.veteran_skills keys by it.
	if str(unit.get("unit_id", "")).is_empty():
		unit["unit_id"] = generate_id()
	for stale: String in RETIRED_FIELDS:
		unit.erase(stale)
	return unit


## Record that this unit was deployed into a battle, and whether that battle was won.
##
## ⭐ THE MISSING PRODUCER. `battles_fought` / `battles_won` were initialised at
## creation and DISPLAYED by `TacticsDashboard.gd:414/:424`, and nothing anywhere
## incremented them — so every unit showed a permanent 0 for the life of a campaign.
## The consumer was written, the producer never was.
##
## The set of units to credit is not a judgement call: the app already computes it.
## `TacticsBattleSetupPanel._campaign_unit_ids()` lists every non-destroyed unit at
## the DEPLOYMENT phase and `TacticsPhaseManager` stamps it onto
## `campaign.current_battle["deployed_units"]` — where, until now, nothing read it.
static func credit_battle(unit: Dictionary, won: bool) -> void:
	unit["battles_fought"] = int(unit.get("battles_fought", 0)) + 1
	if won:
		unit["battles_won"] = int(unit.get("battles_won", 0)) + 1


## Apply a p.106 Unit Losses result to a unit that was completely destroyed.
##
## ⚠ This replaced `apply_casualties()`, which subtracted figures permanently after
## every battle. p.105 says a unit left on the table "recovers completely" and only a
## completely destroyed unit rolls on the p.106 table:
##   Lost       — removed from the roster (kept here as a record that never deploys)
##   Devastated — "unusable for two campaign battles"
##   Weakened   — deploys one figure fewer (a vehicle one fewer KP) "until the unit can
##                sit out a campaign battle without being deployed"
##   Okay       — no lasting effect
static func apply_unit_loss(unit: Dictionary, loss_id: String, unusable_battles: int = 0) -> void:
	match loss_id:
		CONDITION_LOST:
			unit["condition"] = CONDITION_LOST
			unit["is_destroyed"] = true
		CONDITION_DEVASTATED:
			unit["condition"] = CONDITION_DEVASTATED
			unit["unusable_battles"] = maxi(unusable_battles, 1)
		CONDITION_WEAKENED:
			unit["condition"] = CONDITION_WEAKENED
		_:
			unit["condition"] = CONDITION_OK


## Can this unit be deployed into the next battle?
static func is_deployable(unit: Dictionary) -> bool:
	return not bool(unit.get("is_destroyed", false)) \
		and int(unit.get("unusable_battles", 0)) <= 0


## Called for every unit after each campaign battle. A Devastated unit counts down
## (it cannot have been deployed); a Weakened unit that sat the battle out recovers.
static func after_campaign_battle(unit: Dictionary, deployed: bool) -> void:
	var waiting: int = int(unit.get("unusable_battles", 0))
	if waiting > 0:
		unit["unusable_battles"] = waiting - 1
		if waiting - 1 <= 0 and str(unit.get("condition", "")) == CONDITION_DEVASTATED:
			unit["condition"] = CONDITION_OK
		return
	if not deployed and str(unit.get("condition", "")) == CONDITION_WEAKENED:
		unit["condition"] = CONDITION_OK


## A one-line status for the roster, or "" for a unit with nothing to report.
static func condition_text(unit: Dictionary) -> String:
	match str(unit.get("condition", CONDITION_OK)):
		CONDITION_LOST:
			return "LOST (p.106)"
		CONDITION_DEVASTATED:
			return "DEVASTATED — unusable for %d more battle(s) (p.106)" % int(
				unit.get("unusable_battles", 0))
		CONDITION_WEAKENED:
			return "WEAKENED — deploys one figure fewer until it sits a battle out (p.106)"
	return "DESTROYED" if bool(unit.get("is_destroyed", false)) else ""


## Add replacement models, up to `base_count`. Returns how many were actually added.
static func reinforce(unit: Dictionary, models_added: int, base_count: int) -> int:
	var current: int = int(unit.get("current_models", 0))
	var added: int = mini(maxi(models_added, 0), maxi(base_count - current, 0))
	if added <= 0:
		return 0
	unit["current_models"] = current + added
	unit["is_destroyed"] = false
	return added


## The name to show for a unit record.
static func display_name(unit: Dictionary) -> String:
	var custom: String = str(unit.get("custom_name", ""))
	if not custom.is_empty():
		return custom
	return str(unit.get("base_unit_id", "Unknown")).replace("_", " ").capitalize()
