extends RefCounted
## The Benefits of Loyalty — calling in a Faction favor (Compendium p.112).
##
## THE GAP THIS FILLS. `FactionSystem.attempt_faction_favor()` was correct and
## complete — D6 <= Loyalty, reduce Loyalty by the die roll, return the six book
## favors — and had ZERO callers, because p.112 says calling one in "REQUIRES A
## CREW TASK, and can only be done by your captain" and no such task existed. So
## every Loyalty point the crew earned was a number that could never be spent,
## and all six favors were unreachable.
##
## The book, verbatim (p.112):
##   "Having friends is important. Your captain may try to call in a favor ONCE
##    PER CAMPAIGN TURN. This requires a crew task, and can only be done by your
##    captain.
##    Roll a D6:
##    - If the roll is equal to or below the current Loyalty score, reduce the
##      Loyalty by the die roll, and select one of the favors listed below. You
##      can choose the favor AFTER ROLLING.
##    - If the roll is higher than the Loyalty score, nobody has time for you."
##
## This file is the APPLICATION half: FactionSystem rolls and spends Loyalty,
## CrewTaskComponent runs the task and shows the picker, and each favor lands
## here. Credits go through GameStateManager, which owns them.
##
## No `class_name` — preload by path.

## "once per campaign turn"
const FAVOR_TURN_KEY := "faction_favor_used_turn"
## "Provide cover — You cannot be attacked by any Rivals this turn."
const PROVIDE_COVER_KEY := "faction_favor_cover_turn"
## "Pulling strings — Can be used to cancel a Loan enforcement roll (see p.154)"
const CANCEL_ENFORCEMENT_KEY := "faction_favor_cancel_enforcement"

## p.112: "remove an Enforcer, Vigilante, or Bounty Hunter Rival." Matched on the
## Rival's type/name, because the canonical rivals array is a MIXED array of
## Strings and Dictionaries and a bare String carries nothing else.
const PULLABLE_RIVAL_TERMS := ["enforcer", "vigilante", "bounty hunter"]

## Stable ids for the six rows, so the picker and the applier cannot drift apart
## on a display string. "Contact network" is split because the book gives it an
## either/or the player must make: "You may EITHER roll up a Patron that offers a
## job OR opt to take a Salvage job."
const FAVOR_PULLING_STRINGS := "pulling_strings"
const FAVOR_MONETARY_HELP := "monetary_help"
const FAVOR_CONTACT_PATRON := "contact_network_patron"
const FAVOR_CONTACT_SALVAGE := "contact_network_salvage"
const FAVOR_ARRANGE_MEETING := "arrange_a_meeting"
const FAVOR_PROVIDE_COVER := "provide_cover"
const FAVOR_ACCESS_INFORMATION := "access_to_information"


## The picker rows for a successful call. `roll` is the D6 that succeeded — it is
## the payout for Monetary help, so it belongs in the label rather than being a
## surprise after the choice.
static func favor_options(roll: int, influence: int) -> Array:
	return [
		{
			"id": FAVOR_PULLING_STRINGS,
			"label": "Pulling strings — cancel a Loan enforcement roll, or remove an Enforcer / Vigilante / Bounty Hunter Rival",
		},
		{
			"id": FAVOR_MONETARY_HELP,
			"label": "Monetary help — gain %d credits (%d against debts or medical expenses)" % [
				roll, roll + 1],
		},
		{
			"id": FAVOR_CONTACT_PATRON,
			"label": "Contact network — roll up a Patron that offers a job",
		},
		{
			"id": FAVOR_CONTACT_SALVAGE,
			"label": "Contact network — take a Salvage job instead",
		},
		{
			"id": FAVOR_ARRANGE_MEETING,
			"label": "Arrange a meeting — a new character assists for one mission",
		},
		{
			"id": FAVOR_PROVIDE_COVER,
			"label": "Provide cover — you cannot be attacked by any Rivals this turn",
		},
		{
			"id": FAVOR_ACCESS_INFORMATION,
			"label": "Access to information — gain %d Quest Rumor(s) this turn" % maxi(0, influence),
		},
	]


## ── The once-per-campaign-turn gate ─────────────────────────────────────────

static func favor_used_this_turn(campaign: Variant, turn: int) -> bool:
	# Guarded on the CAMPAIGN, never on `pd.is_empty()`: an empty progress_data is
	# a legal state for a new campaign, and an is_empty() guard would report
	# "already used" for a crew that has never played a turn.
	if not _has_store(campaign):
		return false
	return int(_progress(campaign).get(FAVOR_TURN_KEY, -1)) == turn


static func mark_favor_used(campaign: Variant, turn: int) -> void:
	if not _has_store(campaign):
		return
	_progress(campaign)[FAVOR_TURN_KEY] = turn


## ── Applying the chosen favor ───────────────────────────────────────────────

## Returns {applied: bool, detail: String}. The caller reports `detail` rather
## than assuming what happened — several favors have a fallback branch.
static func apply_favor(
	campaign: Variant, favor_id: String, roll: int, influence: int
) -> Dictionary:
	match favor_id:
		FAVOR_PULLING_STRINGS:
			return _pulling_strings(campaign)
		FAVOR_MONETARY_HELP:
			return _monetary_help(campaign, roll)
		FAVOR_CONTACT_PATRON:
			return _contact_network(campaign, false)
		FAVOR_CONTACT_SALVAGE:
			return _contact_network(campaign, true)
		FAVOR_ARRANGE_MEETING:
			return {"applied": true, "detail":
				"A new character is rolled up and assists for one mission. If you"
				+ " Win, they offer to join permanently for 1D6 credits (p.112).",
				"spawn_temp_crew": true}
		FAVOR_PROVIDE_COVER:
			return _provide_cover(campaign)
		FAVOR_ACCESS_INFORMATION:
			return _access_to_information(campaign, influence)
	return {"applied": false, "detail": "Unknown favor '%s'." % favor_id}


## "Pulling strings — Can be used to cancel a Loan enforcement roll (see p.154)
## or remove an Enforcer, Vigilante, or Bounty Hunter Rival."
##
## An either/or where only one branch may be available. The Rival removal is
## preferred when an eligible Rival exists — it is the irreversible half, and a
## banked enforcement cancellation keeps its value until a loan actually calls
## for one. When there is no eligible Rival the cancellation is banked instead,
## so the favor is never spent for nothing.
static func _pulling_strings(campaign: Variant) -> Dictionary:
	if campaign != null and "rivals" in campaign and campaign.rivals is Array:
		var rivals: Array = campaign.rivals
		for i in range(rivals.size()):
			if _is_pullable_rival(rivals[i]):
				var removed: String = _rival_name(rivals[i])
				rivals.remove_at(i)
				return {"applied": true, "detail":
					"Strings pulled: %s is off your back (Compendium p.112)." % removed}

	if not _has_store(campaign):
		return {"applied": false, "detail": "No campaign to apply the favor to."}
	_progress(campaign)[CANCEL_ENFORCEMENT_KEY] = true
	return {"applied": true, "detail":
		"No Enforcer, Vigilante or Bounty Hunter Rival to remove — the favor is"
		+ " banked to cancel your next Loan enforcement roll (p.154)."}


static func _is_pullable_rival(rival: Variant) -> bool:
	var haystack: String = ""
	if rival is Dictionary:
		var d: Dictionary = rival
		haystack = "%s %s" % [str(d.get("name", "")), str(d.get("type", ""))]
	else:
		haystack = str(rival)
	haystack = haystack.to_lower()
	for term: String in PULLABLE_RIVAL_TERMS:
		if term in haystack:
			return true
	return false


static func _rival_name(rival: Variant) -> String:
	if rival is Dictionary:
		return str((rival as Dictionary).get("name", "A Rival"))
	return str(rival)


## "Monetary help — Gain Credits equal to the die roll. Add +1 to the score if
## the sum is used directly to pay off debts or medical expenses."
##
## Returns the credit delta for the CALLER to apply through GameStateManager,
## which owns credits. The +1 is granted when the crew actually carries ship debt,
## because that is the only way the sum can be "used directly" to pay it — paying
## the player +1 and then letting them spend it on weapons would be inventing a
## rule the book conditions on the spend.
static func _monetary_help(campaign: Variant, roll: int) -> Dictionary:
	var debt: int = 0
	if campaign != null and "ship_debt" in campaign:
		debt = int(campaign.ship_debt)

	if debt > 0:
		var paid: int = mini(debt, roll + 1)
		campaign.ship_debt = maxi(0, debt - paid)
		return {"applied": true, "credits": 0, "detail":
			"Monetary help: %d credits applied straight to the ship debt (%d -> %d),"
				% [paid, debt, campaign.ship_debt]
			+ " including the +1 for paying down debt (p.112)."}

	return {"applied": true, "credits": roll, "detail":
		"Monetary help: +%d credits (p.112)." % roll}


## "Contact network — You may either roll up a Patron that offers a job or opt to
## take a Salvage job (see p.137)."
##
## Both branches bank an ENTITLEMENT rather than generating the job here: the
## Patron offer goes through the same `patron_offers_owed` counter the p.77 task
## writes, and the salvage job through the Compendium p.137 generator, so neither
## forks its own copy of a table this codebase already owns.
static func _contact_network(campaign: Variant, salvage: bool) -> Dictionary:
	if not _has_store(campaign):
		return {"applied": false, "detail": "No campaign to apply the favor to."}
	var pd: Dictionary = _progress(campaign)
	if salvage:
		pd["faction_favor_salvage_job"] = true
		return {"applied": true, "detail":
			"Contact network: a Salvage job is waiting at Job Offers (p.137)."}
	pd["patron_offers_owed"] = int(pd.get("patron_offers_owed", 0)) + 1
	return {"applied": true, "detail":
		"Contact network: a Patron has work for you at Job Offers (p.112)."}


## "Provide cover — You cannot be attacked by any Rivals this turn."
##
## The same suppression the p.85 check already honours for Story Events, Black
## Jobs and Private Transport — one chokepoint, so this is a stamp rather than a
## fourth place that can suppress the same roll.
static func _provide_cover(campaign: Variant) -> Dictionary:
	if not _has_store(campaign):
		return {"applied": false, "detail": "No campaign to apply the favor to."}
	var pd: Dictionary = _progress(campaign)
	pd[PROVIDE_COVER_KEY] = int(pd.get("turns_played", 0))
	return {"applied": true, "detail":
		"Provide cover: your Rivals cannot attack you this campaign turn (p.112)."}


static func provide_cover_active(campaign: Variant, turn: int) -> bool:
	if not _has_store(campaign):
		return false
	return int(_progress(campaign).get(PROVIDE_COVER_KEY, -1)) == turn


## "Access to information — Gain Quest Clues equal to Influence this turn."
##
## The Core Rules call these Quest RUMORS (p.78 Track, p.121 Battlefield Finds);
## "Quest Clues" is the Compendium's word for the same token, and this codebase
## has exactly one of them. Granting Influence-many of the thing the campaign
## actually tracks is the faithful reading — inventing a second currency named
## "clue" would be the unfaithful one.
static func _access_to_information(campaign: Variant, influence: int) -> Dictionary:
	var count: int = maxi(0, influence)
	if count <= 0:
		return {"applied": true, "rumors": 0, "detail":
			"Access to information: the Faction's Influence is 0, so there is"
			+ " nothing they can tell you (p.112)."}
	return {"applied": true, "rumors": count, "detail":
		"Access to information: +%d Quest Rumor(s) (p.112)." % count}


## ── Internal ────────────────────────────────────────────────────────────────

static func _has_store(campaign: Variant) -> bool:
	if campaign == null:
		return false
	if not ("progress_data" in campaign):
		return false
	return campaign.progress_data is Dictionary


static func _progress(campaign: Variant) -> Dictionary:
	if not _has_store(campaign):
		return {}
	return campaign.progress_data
