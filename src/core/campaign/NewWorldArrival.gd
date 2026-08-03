class_name NewWorldArrival
extends RefCounted
## New World Arrival steps 1-2 (Core Rules p.72).
##
## Verbatim:
##   "1. Check for Rivals — Any Rivals you have will roll 1D6. On a 5+, they opt
##    to follow you, otherwise they remain behind."
##   "2. Dismiss Patrons — All Patrons remain behind unless they are Persistent."
##   "When starting a campaign, skip steps 1 and 2."
##
## THE GAP THIS CLOSES. Both steps existed ONLY inside
## src/core/campaign/phases/TravelPhase.gd, a file with ZERO instantiations, so
## neither had ever run in any campaign. Rivals therefore accumulated for the
## entire campaign — which quietly inflates the p.85 "roll a D6 against the
## number of Rivals" check into a near-certain forced Rival battle every single
## turn — and Patrons never lapsed on travel, making the p.84 "Persistent"
## Benefit a reward for nothing.
##
## Static and tree-free on purpose: the decision is pure, so it can be tested
## without instantiating the World Phase UI (which leaks ~95 orphan nodes per
## run) and without an absolute-path autoload lookup that a detached node cannot
## resolve. The live caller passes the campaign; the dice log is the caller's
## concern. Mirrors src/core/campaign/RivalEncounterCheck.gd.

const FOLLOW_TARGET := 5  # p.72: "On a 5+, they opt to follow you"


## True when a Patron entry carries the p.84 Benefits Subtable "Persistent" mark.
##
## The flag has three spellings in the wild — `is_persistent`, `persistent`, and
## `type == "persistent"` (PaymentProcessor's Black Zone contacts write all
## three) — plus NPCTracker's `duration_turns == -1`. Accept every one, or the
## Benefit silently stops working depending on which writer created the Patron.
## A bare String patron carries no benefit data and is therefore not Persistent.
static func is_persistent_patron(patron: Variant) -> bool:
	if not (patron is Dictionary):
		return false
	if bool(patron.get("is_persistent", false)):
		return true
	if bool(patron.get("persistent", false)):
		return true
	if str(patron.get("type", "")).to_lower() == "persistent":
		return true
	return int(patron.get("duration_turns", 0)) == -1


static func display_name(entity: Variant, fallback: String) -> String:
	if entity is Dictionary:
		return str(entity.get("name", entity.get("rival_name", fallback)))
	if entity is String and not str(entity).is_empty():
		return str(entity)
	return fallback


## Apply steps 1-2 to a campaign in place.
##
## Canonical stores are campaign.rivals / campaign.patrons (top-level @vars), NOT
## NPCTracker's parallel dictionaries that the dead TravelPhase mutated.
## Returns {rivals_left: Array[String], patrons_left: Array[String]} for the
## caller to surface — without a report the step reads to the player as a bug
## ("where did my Patron go?").
static func apply(campaign: Resource, rng: RandomNumberGenerator = null) -> Dictionary:
	var out: Dictionary = {"rivals_left": [], "patrons_left": []}
	if campaign == null:
		return out

	var gen: RandomNumberGenerator = rng
	if gen == null:
		gen = RandomNumberGenerator.new()
		gen.randomize()

	# Step 1 — each Rival rolls 1D6; 5+ follows, otherwise it remains behind.
	if "rivals" in campaign and campaign.rivals is Array:
		var following: Array = []
		for rival: Variant in campaign.rivals:
			if gen.randi_range(1, 6) >= FOLLOW_TARGET:
				following.append(rival)
			else:
				out["rivals_left"].append(display_name(rival, "A Rival"))
		campaign.rivals = following

	# Step 2 — no roll: Patrons remain behind unless Persistent.
	var kept_patron_ids: Array[String] = []
	if "patrons" in campaign and campaign.patrons is Array:
		var kept: Array = []
		for patron: Variant in campaign.patrons:
			if is_persistent_patron(patron):
				kept.append(patron)
				kept_patron_ids.append(_patron_key(patron))
			else:
				out["patrons_left"].append(display_name(patron, "A Patron"))
		campaign.patrons = kept

	# A Patron who did not follow cannot still be holding work open for you. Job
	# offers persist across turns now (Core Rules p.83 Time Frame), so without
	# this the offer list would keep serving jobs from Patrons the crew left a
	# world behind — and an "Any time" offer would outlive them forever.
	out["offers_dropped"] = _drop_orphaned_offers(campaign, kept_patron_ids)

	return out


## Identity as JobOfferComponent stamps it on an offer: the Patron's id when
## there is one, else their display name (campaign.patrons is a MIXED array of
## Strings and Dictionaries, so some entries have no id at all).
static func _patron_key(patron: Variant) -> String:
	if patron is Dictionary:
		var pid: String = str(patron.get("id", patron.get("patron_id", "")))
		if pid != "":
			return pid
		return str(patron.get("name", patron.get("patron_name", "")))
	return str(patron)


static func _drop_orphaned_offers(campaign: Resource, kept_ids: Array[String]) -> int:
	if not "progress_data" in campaign:
		return 0
	var offers: Variant = campaign.progress_data.get("patron_job_offers", [])
	if not offers is Array or (offers as Array).is_empty():
		return 0
	var surviving: Array = []
	for offer in offers:
		if offer is Dictionary and str(offer.get("patron_id", "")) in kept_ids:
			surviving.append(offer)
	var dropped: int = (offers as Array).size() - surviving.size()
	campaign.progress_data["patron_job_offers"] = surviving
	return dropped
