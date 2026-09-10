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
	"models_lost_total",
	"models_lost_current",
	"current_models",
	"is_destroyed",
	"selected_upgrades",
]

## Keys written by an older build that are no longer part of the record.
## See the class docblock for the book citation retiring each one.
const RETIRED_FIELDS: PackedStringArray = [
	"campaign_points",
	"campaign_points_spent",
	"objectives_completed",
	"veteran_skills",
]


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
		selected_upgrades: Array = []) -> Dictionary:
	return {
		"unit_id": generate_id(),
		"custom_name": custom_name,
		"base_unit_id": base_unit_id,
		"species_id": species_id,
		"battles_fought": 0,
		"battles_won": 0,
		"models_lost_total": 0,
		"models_lost_current": 0,
		"current_models": model_count if model_count > 0 else 5,
		"is_destroyed": false,
		"selected_upgrades": selected_upgrades.duplicate(),
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


## Apply a battle's losses to a unit, destroying it if nothing is left standing.
static func apply_casualties(unit: Dictionary, models_lost: int) -> void:
	var lost: int = maxi(models_lost, 0)
	unit["models_lost_current"] = lost
	unit["models_lost_total"] = int(unit.get("models_lost_total", 0)) + lost
	unit["current_models"] = maxi(int(unit.get("current_models", 5)) - lost, 0)
	if int(unit["current_models"]) <= 0:
		unit["is_destroyed"] = true


## Clear the per-battle loss counter. Cumulative totals are untouched.
static func clear_battle_losses(unit: Dictionary) -> void:
	unit["models_lost_current"] = 0


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
