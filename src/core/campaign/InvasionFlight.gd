extends RefCounted
## Core Rules p.69 "Flee Invasion" — everything that happens BECAUSE the crew
## left an invaded world, as opposed to the 2D6 8+ roll that decides whether
## they got out at all (that lives in `UpkeepPhaseComponent._attempt_invasion_escape`).
##
## THE GAP THIS FILLS. The escape ROLL was implemented and the consequences were
## not, so fleeing an Invasion was strictly better than any other departure:
##   - every Rival and every Patron built up on that world came with you, while
##     an ordinary p.72 departure makes Rivals roll 1D6 to follow and drops all
##     non-Persistent Patrons;
##   - a crew without the 5 credits for fuel simply could not leave — the book's
##     two escape routes (sell gear at a loss, or abandon the ship) did not exist;
##   - a crew with no ship at all had no evacuation route.
##
## The book, verbatim (p.69):
##   "If you don't have the 5 credits needed for fuel, you can sell off gear at a
##    loss (receiving 1 credit per two items sold), or abandon the ship and take
##    evacuation passage, as below.
##    If you lack a ship, you flee on an evacuation ship. You lose all credits you
##    do have, plus 1D6 items from your Stash and equipment (chosen by you), used
##    to pay for bribes, losses, and things left behind.
##    Regardless of how you leave, all Rivals, Patrons, and other people known to
##    your crew on this world are lost. You're not the only ones who needed to
##    relocate in a hurry."
##
## Credits are NEVER written here. Every function returns the delta and the
## caller applies it through GameStateManager, which is the canonical owner per
## the data-ownership table. Item removal DOES happen here, because the ship
## stash and character sheets are plain arrays on the campaign and there is no
## singleton that owns them.
##
## No `class_name` — preload by path, same reason as BattleResultNormalizer.

const NewWorldArrivalRef = preload("res://src/core/campaign/NewWorldArrival.gd")

## "receiving 1 credit per two items sold" (p.69).
const ITEMS_PER_SALE_CREDIT := 2

## "plus 1D6 items from your Stash and equipment" (p.69).
const EVAC_ITEM_LOSS_DIE := 6


## ── Step: who you leave behind ───────────────────────────────────────────────

## p.69: "all Rivals, Patrons, and other people known to your crew on this world
## are lost."
##
## Rivals: ALL of them, with no roll. The 1D6 follow roll (and the Compendium
## p.49 Elite Rival 4+) belongs to the p.72 New World Arrival steps — "When
## traveling to a new world, roll 1D6 for each Elite Rival you have" — and a
## flight from an Invasion does not perform those steps. Verified against the
## Compendium p.49 text, which scopes itself to ordinary travel.
##
## Patrons: all EXCEPT those carrying the p.84 Benefits Subtable "Persistent"
## mark. DOCUMENTED READING, not a silent choice: the clause is scoped to people
## known to the crew "on this world", and "Persistent" is the book's own term for
## a Patron who is explicitly NOT world-bound (the Black Zone victory reward on
## p.151 grants two of them and calls them "Persistent across worlds"). Reading
## the clause to also strip Persistent Patrons would make that reward evaporate
## the first time the crew fled a world, which no page supports.
static func lose_local_contacts(campaign: Resource) -> Dictionary:
	var out: Dictionary = {
		"rivals_lost": [],
		"patrons_lost": [],
		"patrons_kept": 0,
		"offers_dropped": 0,
	}
	if campaign == null:
		return out

	if "rivals" in campaign and campaign.rivals is Array:
		for rival: Variant in campaign.rivals:
			out["rivals_lost"].append(
				NewWorldArrivalRef.display_name(rival, "A Rival"))
		campaign.rivals = []

	var kept_patron_ids: Array[String] = []
	if "patrons" in campaign and campaign.patrons is Array:
		var kept: Array = []
		for patron: Variant in campaign.patrons:
			if NewWorldArrivalRef.is_persistent_patron(patron):
				kept.append(patron)
				kept_patron_ids.append(NewWorldArrivalRef.patron_key(patron))
			else:
				out["patrons_lost"].append(
					NewWorldArrivalRef.display_name(patron, "A Patron"))
		campaign.patrons = kept
		out["patrons_kept"] = kept.size()

	# A Patron the crew just lost cannot still be holding a job open. Same reason
	# the ordinary departure drops them (Core Rules p.83 Time Frame keeps offers
	# alive across turns, so without this an "Any time" offer outlives its Patron).
	out["offers_dropped"] = NewWorldArrivalRef.drop_orphaned_offers(
		campaign, kept_patron_ids)
	return out


## ── Escape route 1: sell gear at a loss ──────────────────────────────────────

## How many items must go to raise `credits_needed` at the p.69 rate.
static func items_needed_for_credits(credits_needed: int) -> int:
	if credits_needed <= 0:
		return 0
	return credits_needed * ITEMS_PER_SALE_CREDIT


## What `item_count` items are worth at the p.69 fire-sale rate: "1 credit per
## two items sold". Integer division — a single leftover item raises nothing,
## which is why the caller must sell in pairs.
static func sale_credits_for_items(item_count: int) -> int:
	return maxi(0, item_count) / ITEMS_PER_SALE_CREDIT


## Sell stash items to raise `credits_needed`. Returns what actually happened —
## the caller applies `credits_raised` through GameStateManager.
##
## Only whole PAIRS are sold: selling an odd item raises nothing and would be a
## pure loss the book does not ask for.
static func sell_gear_for_fuel(
	campaign: Resource, credits_needed: int
) -> Dictionary:
	var out: Dictionary = {
		"credits_raised": 0,
		"items_sold": [],
		"shortfall_remaining": maxi(0, credits_needed),
	}
	if campaign == null or credits_needed <= 0:
		return out

	var stash: Array = _stash(campaign)
	var affordable_pairs: int = mini(
		credits_needed, stash.size() / ITEMS_PER_SALE_CREDIT)
	if affordable_pairs <= 0:
		return out

	var to_sell: int = affordable_pairs * ITEMS_PER_SALE_CREDIT
	for _i in range(to_sell):
		if stash.is_empty():
			break
		out["items_sold"].append(item_display_name(stash[0]))
		stash.remove_at(0)

	out["credits_raised"] = affordable_pairs
	out["shortfall_remaining"] = maxi(0, credits_needed - affordable_pairs)
	return out


## ── Escape route 2: evacuation passage (no ship, or ship abandoned) ──────────

## p.69: "you flee on an evacuation ship. You lose all credits you do have, plus
## 1D6 items from your Stash and equipment (chosen by you)."
##
## `current_credits` is passed in rather than read, because credits are owned by
## GameStateManager; the caller applies `credits_lost` there.
##
## `chosen` lets the player exercise the book's "chosen by you". When it is empty
## the fallback takes from the ship stash first and only then from character
## sheets — the least destructive automatic choice, and the one a player picking
## by hand almost always makes.
static func evacuation_passage(
	campaign: Resource, current_credits: int,
	rng: RandomNumberGenerator = null, chosen: Array = []
) -> Dictionary:
	var gen: RandomNumberGenerator = rng
	if gen == null:
		gen = RandomNumberGenerator.new()
		gen.randomize()

	var roll: int = gen.randi_range(1, EVAC_ITEM_LOSS_DIE)
	var out: Dictionary = {
		"roll": roll,
		"credits_lost": maxi(0, current_credits),
		"items_lost": [],
		"items_owed": roll,
	}
	if campaign == null:
		return out

	out["items_lost"] = _take_items(campaign, roll, chosen)
	return out


## ── Helpers ──────────────────────────────────────────────────────────────────

## Stash entries are a MIXED array — `to_dictionary()` writes plain Strings while
## loot writes Dictionaries. Both must render.
static func item_display_name(entry: Variant) -> String:
	if entry is Dictionary:
		var d: Dictionary = entry
		return str(d.get("name", d.get("id", "Item")))
	return str(entry)


static func _stash(campaign: Resource) -> Array:
	if not ("equipment_data" in campaign):
		return []
	if not (campaign.equipment_data is Dictionary):
		return []
	if not campaign.equipment_data.has("equipment"):
		campaign.equipment_data["equipment"] = []
	var stash: Variant = campaign.equipment_data["equipment"]
	if not (stash is Array):
		campaign.equipment_data["equipment"] = []
		return campaign.equipment_data["equipment"]
	return stash


## Remove `count` items, honouring the player's picks first, then the stash, then
## character sheets. Returns the display names actually taken, which may be
## shorter than `count` when the crew owns less than the die demanded.
static func _take_items(campaign: Resource, count: int, chosen: Array) -> Array:
	var taken: Array = []
	if count <= 0:
		return taken

	var stash: Array = _stash(campaign)

	# 1. The player's explicit picks, matched by name or id against the stash.
	for pick: Variant in chosen:
		if taken.size() >= count:
			break
		var wanted: String = item_display_name(pick)
		for i in range(stash.size()):
			if item_display_name(stash[i]) == wanted:
				taken.append(wanted)
				stash.remove_at(i)
				break

	# 2. Ship stash, oldest first.
	while taken.size() < count and not stash.is_empty():
		taken.append(item_display_name(stash[0]))
		stash.remove_at(0)

	# 3. Character sheets, only once the stash is empty. "your Stash AND
	# equipment" — the book counts both toward the 1D6.
	if taken.size() < count:
		for member: Variant in _crew(campaign):
			if taken.size() >= count:
				break
			var gear: Array = _member_equipment(member)
			while taken.size() < count and not gear.is_empty():
				taken.append(item_display_name(gear[0]))
				gear.remove_at(0)
			_set_member_equipment(member, gear)

	return taken


static func _crew(campaign: Resource) -> Array:
	if campaign.has_method("get_crew_members"):
		return campaign.get_crew_members()
	if "crew_data" in campaign and campaign.crew_data is Dictionary:
		var members: Variant = campaign.crew_data.get("members", [])
		if members is Array:
			return members
	return []


static func _member_equipment(member: Variant) -> Array:
	if member is Dictionary:
		var eq: Variant = (member as Dictionary).get("equipment", [])
		return eq if eq is Array else []
	if member is Object and "equipment" in member:
		var oeq: Variant = member.get("equipment")
		return oeq if oeq is Array else []
	return []


## `member["equipment"]` is a typed `Array[String]` on a Character Resource, so a
## plain assignment of an untyped Array is rejected and the removal is silently
## LOST (the creation-wizard invariant, CLAUDE.md). Assign through `.assign()`
## when the destination is typed.
static func _set_member_equipment(member: Variant, gear: Array) -> void:
	if member is Dictionary:
		(member as Dictionary)["equipment"] = gear
		return
	if member is Object and "equipment" in member:
		var existing: Variant = member.get("equipment")
		if existing is Array:
			(existing as Array).assign(gear)
