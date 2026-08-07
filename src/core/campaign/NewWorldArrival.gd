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

## Compendium p.49 Elite-level Rivals, verbatim: "Elite-level enemies are more
## persistent. When traveling to a new world, roll 1D6 for each Elite Rival you
## have: On a 4+ they opt to follow you to the new world."
##
## `CompendiumEliteEnemies.rival_follows_to_new_world()` implemented this and had
## ZERO callers, so an Elite Rival shook off exactly as easily as an ordinary one
## and the whole "more persistent" clause was decoration.
const ELITE_FOLLOW_TARGET := 4


## True when a Rival was born from a Compendium pp.48-65 elite force. Tagged at
## creation by RivalPatronResolver._append_rival(); a bare String Rival predates
## the tag and is treated as ordinary, which is the safe direction (it keeps the
## harder-to-follow 5+ rather than inventing persistence for legacy saves).
static func is_elite_rival(rival: Variant) -> bool:
	if not (rival is Dictionary):
		return false
	return bool(rival.get("is_elite", false))


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
			# Compendium p.49 lowers the target to 4+ for an Elite Rival.
			var target: int = ELITE_FOLLOW_TARGET if is_elite_rival(rival) \
				else FOLLOW_TARGET
			if gen.randi_range(1, 6) >= target:
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
				kept_patron_ids.append(patron_key(patron))
			else:
				out["patrons_left"].append(display_name(patron, "A Patron"))
		campaign.patrons = kept

	# A Patron who did not follow cannot still be holding work open for you. Job
	# offers persist across turns now (Core Rules p.83 Time Frame), so without
	# this the offer list would keep serving jobs from Patrons the crew left a
	# world behind — and an "Any time" offer would outlive them forever.
	out["offers_dropped"] = drop_orphaned_offers(campaign, kept_patron_ids)

	return out


## Identity as JobOfferComponent stamps it on an offer: the Patron's id when
## there is one, else their display name (campaign.patrons is a MIXED array of
## Strings and Dictionaries, so some entries have no id at all).
## ── Step 3: Check for Licensing Requirements (Core Rules p.72) ──────────────
##
## Verbatim: "Roll 1D6. On a 5-6 the world requires a Freelancer License to
## perform Patron jobs: Roll a further 1D6 to determine how many credits this
## will cost. Once purchased, it remains in effect for perpetuity, even if you
## return to the world later on.
##  You may attempt to obtain a forged License. Select a crew member and roll
##  1D6+Savvy. If the score is a 6+, you obtain a License for free. If the roll is
##  a 1 BEFORE MODIFIERS, you must add a Rival on this world... Only one attempt
##  is permitted."
##
## THE GAP: `apply()` implemented steps 1-2 and stopped. Step 3 did not exist, so
## no world ever required a licence and Patron jobs were free everywhere — which
## also made the forged-licence gamble, one of the few pure risk/reward decisions
## in the World step, unreachable.
##
## Per-world and permanent ("for perpetuity"), so the record is keyed by planet id
## on progress_data rather than being a single campaign flag.
const LICENCE_REQUIRED_ON := 5      # "On a 5-6 the world requires a..."
const FORGED_LICENCE_TARGET := 6    # "If the score is a 6+..."

static func roll_licensing_requirement(
	campaign: Resource, planet_id: String, rng: RandomNumberGenerator = null
) -> Dictionary:
	var out: Dictionary = {
		"applies": false, "roll": 0, "fee": 0, "already_licensed": false,
	}
	if campaign == null or planet_id.is_empty():
		return out
	if not ("progress_data" in campaign) or not (campaign.progress_data is Dictionary):
		return out

	# "it remains in effect for perpetuity, even if you return to the world later
	# on" — so a world already paid for is never re-rolled.
	if planet_id in _licence_list(campaign, "freelancer_licences_held"):
		out["already_licensed"] = true
		return out
	# Nor is a world whose requirement has already been rolled: the check is part
	# of ARRIVING, and re-rolling it would let a player reload until the world came
	# up unlicensed.
	var known: Dictionary = campaign.progress_data.get(
		"freelancer_licence_required", {})
	if known is Dictionary and known.has(planet_id):
		out["applies"] = bool(known[planet_id])
		out["fee"] = int(campaign.progress_data.get(
			"freelancer_licence_fees", {}).get(planet_id, 0))
		return out

	var gen: RandomNumberGenerator = rng
	if gen == null:
		gen = RandomNumberGenerator.new()
		gen.randomize()

	var roll: int = gen.randi_range(1, 6)
	out["roll"] = roll
	out["applies"] = roll >= LICENCE_REQUIRED_ON
	if out["applies"]:
		out["fee"] = gen.randi_range(1, 6)

	var req: Dictionary = known if known is Dictionary else {}
	req[planet_id] = out["applies"]
	campaign.progress_data["freelancer_licence_required"] = req
	if out["applies"]:
		var fees: Variant = campaign.progress_data.get("freelancer_licence_fees", {})
		var fee_map: Dictionary = fees if fees is Dictionary else {}
		fee_map[planet_id] = out["fee"]
		campaign.progress_data["freelancer_licence_fees"] = fee_map
	return out


static func requires_freelancer_licence(campaign: Resource, planet_id: String) -> bool:
	if campaign == null or planet_id.is_empty():
		return false
	if not ("progress_data" in campaign) or not (campaign.progress_data is Dictionary):
		return false
	if planet_id in _licence_list(campaign, "freelancer_licences_held"):
		return false
	var known: Variant = campaign.progress_data.get("freelancer_licence_required", {})
	return known is Dictionary and bool((known as Dictionary).get(planet_id, false))


static func licence_fee(campaign: Resource, planet_id: String) -> int:
	if campaign == null or not ("progress_data" in campaign):
		return 0
	if not (campaign.progress_data is Dictionary):
		return 0
	var fees: Variant = campaign.progress_data.get("freelancer_licence_fees", {})
	return int((fees as Dictionary).get(planet_id, 0)) if fees is Dictionary else 0


static func grant_licence(campaign: Resource, planet_id: String) -> void:
	if campaign == null or planet_id.is_empty():
		return
	if not ("progress_data" in campaign) or not (campaign.progress_data is Dictionary):
		return
	var held: Array = _licence_list(campaign, "freelancer_licences_held")
	if planet_id in held:
		return
	held.append(planet_id)
	campaign.progress_data["freelancer_licences_held"] = held


## "Only one attempt is permitted" — per world, since the licence itself is.
static func forgery_attempted(campaign: Resource, planet_id: String) -> bool:
	if campaign == null or not ("progress_data" in campaign):
		return true
	if not (campaign.progress_data is Dictionary):
		return true
	return planet_id in _licence_list(campaign, "freelancer_forgery_attempts")


## The forged-licence gamble. `savvy` is the chosen crew member's Savvy.
## Returns {roll, natural_one, total, success, adds_rival}.
static func attempt_forged_licence(
	campaign: Resource, planet_id: String, savvy: int,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var out: Dictionary = {
		"roll": 0, "natural_one": false, "total": 0,
		"success": false, "adds_rival": false, "reason": "",
	}
	if campaign == null or planet_id.is_empty():
		out["reason"] = "No world to forge a licence for."
		return out
	if forgery_attempted(campaign, planet_id):
		out["reason"] = "Only one attempt is permitted (Core Rules p.72)."
		return out

	var gen: RandomNumberGenerator = rng
	if gen == null:
		gen = RandomNumberGenerator.new()
		gen.randomize()

	var roll: int = gen.randi_range(1, 6)
	out["roll"] = roll
	# "If the roll is a 1 BEFORE MODIFIERS" — the natural die, not the total. A
	# high-Savvy character is no safer from being caught, which is the whole shape
	# of the gamble.
	out["natural_one"] = roll == 1
	out["total"] = roll + maxi(0, savvy)
	out["success"] = out["total"] >= FORGED_LICENCE_TARGET
	out["adds_rival"] = out["natural_one"]

	var attempts: Array = _licence_list(campaign, "freelancer_forgery_attempts")
	attempts.append(planet_id)
	campaign.progress_data["freelancer_forgery_attempts"] = attempts

	if out["success"]:
		grant_licence(campaign, planet_id)
	return out


static func _licence_list(campaign: Resource, key: String) -> Array:
	var raw: Variant = campaign.progress_data.get(key, [])
	return raw if raw is Array else []


## PUBLIC — also called by InvasionFlight, which drops contacts under the p.69
## flee rule rather than the p.72 travel rule but must key offers identically.
static func patron_key(patron: Variant) -> String:
	if patron is Dictionary:
		var pid: String = str(patron.get("id", patron.get("patron_id", "")))
		if pid != "":
			return pid
		return str(patron.get("name", patron.get("patron_name", "")))
	return str(patron)


## PUBLIC — shared with InvasionFlight (see patron_key above).
static func drop_orphaned_offers(campaign: Resource, kept_ids: Array[String]) -> int:
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
