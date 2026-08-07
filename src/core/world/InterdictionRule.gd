class_name InterdictionRule
extends RefCounted
## Interdiction World Trait (Core Rules p.75), verbatim:
##
##   "90-91 Interdiction — You are only approved to stay for 1D3 campaign turns.
##    To extend your stay, you must obtain a license. Roll 2D6, requiring an 8+."
##
## THE GAP THIS CLOSES. The trait shipped in `data/world_traits.json` with a real
## roll range, and the ONLY file in the repo that named it was
## `src/core/campaign/phases/TravelPhase.gd` — zero instantiations. So the stay
## limit never counted down, the licence roll never happened, and landing on an
## interdicted world was identical to landing anywhere else.
##
## It matters twice over, because this is the ONLY licence roll in live campaign
## play. Two On-board Items (Core Rules pp.57-58) exist solely to modify it:
##   Fake ID       "Add +1 to all attempts to obtain a license or other legal
##                  document."
##   Sector permit "Whenever you arrive at a planet where a license is required,
##                  roll 1D6. On a 4+, the Sector Permit is accepted. You must
##                  roll for each license type, on each planet."
## With no licence attempt in the game, both were inert by construction — not
## missing features, just rules with nothing to attach to.
##
## Static and tree-free, matching NewWorldArrival / RivalEncounterCheck: the
## decision is pure, so it tests without instantiating the World Phase UI.

const OnboardItemServiceRef = preload("res://src/core/equipment/OnboardItemService.gd")
const WorldTraitEffectsRef = preload("res://src/core/world/WorldTraitEffects.gd")

## progress_data key. One dict rather than three loose keys so a new world
## arrival can replace the whole record atomically — a half-cleared record is how
## an old world's licence ends up covering a new one.
const STATE_KEY := "interdiction"


static func _progress(campaign: Variant) -> Dictionary:
	if campaign == null or not ("progress_data" in campaign):
		return {}
	var pd: Variant = campaign.progress_data
	return pd if pd is Dictionary else {}


static func state(campaign: Variant) -> Dictionary:
	var pd: Dictionary = _progress(campaign)
	if pd.is_empty():
		return {}
	var s: Variant = pd.get(STATE_KEY, {})
	return s if s is Dictionary else {}


static func is_active(campaign: Variant) -> bool:
	return bool(state(campaign).get("active", false))


## Called once on arrival at a new world, AFTER the world's traits are set.
##
## Rolls the 1D3 approved stay and, if the crew has a Sector Permit, rolls its
## 1D6 straight away — the item's wording is "whenever you ARRIVE at a planet
## where a license is required", so it is an arrival check, not something the
## player elects into later.
##
## Always writes the state record, including on a non-interdicted world, so the
## previous world's licence cannot leak forward.
static func apply_on_arrival(
	campaign: Variant, traits: Array, turn: int,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var pd: Dictionary = _progress(campaign)
	var out: Dictionary = {
		"active": false, "stay_turns": 0, "until_turn": 0,
		"permit_rolled": false, "permit_roll": 0, "licensed": false,
		"lines": [],
	}
	if pd.is_empty():
		return out

	if not WorldTraitEffectsRef.requires_stay_license(traits):
		pd[STATE_KEY] = {"active": false}
		return out

	var gen: RandomNumberGenerator = rng
	if gen == null:
		gen = RandomNumberGenerator.new()
		gen.randomize()

	var lines: Array[String] = []
	var stay: int = gen.randi_range(1, 3)  # p.75: "1D3 campaign turns"
	out["active"] = true
	out["stay_turns"] = stay
	out["until_turn"] = turn + stay
	lines.append("Interdiction: approved to stay %d campaign turn%s (p.75)."
		% [stay, "" if stay == 1 else "s"])

	# Sector Permit (p.58) — rolled here because this is the arrival.
	var permit: Dictionary = OnboardItemServiceRef.roll_sector_permit(campaign)
	if bool(permit.get("applies", false)):
		out["permit_rolled"] = true
		out["permit_roll"] = int(permit.get("roll", 0))
		if bool(permit.get("accepted", false)):
			out["licensed"] = true
			lines.append("Sector Permit: rolled %d — accepted. Your stay is licensed."
				% int(permit.get("roll", 0)))
		else:
			lines.append("Sector Permit: rolled %d — not accepted here."
				% int(permit.get("roll", 0)))

	pd[STATE_KEY] = {
		"active": true,
		"until_turn": out["until_turn"],
		"licensed": out["licensed"],
	}
	out["lines"] = lines
	return out


## True when the crew's approved stay has run out and they are not licensed, so
## p.75 no longer permits Staying on this world.
static func blocks_stay(campaign: Variant, turn: int) -> bool:
	var s: Dictionary = state(campaign)
	if not bool(s.get("active", false)):
		return false
	if bool(s.get("licensed", false)):
		return false
	return turn > int(s.get("until_turn", 0))


## Turns of approved stay remaining (0 once expired; -1 when not interdicted or
## already licensed, meaning "no limit").
static func turns_remaining(campaign: Variant, turn: int) -> int:
	var s: Dictionary = state(campaign)
	if not bool(s.get("active", false)) or bool(s.get("licensed", false)):
		return -1
	return maxi(0, int(s.get("until_turn", 0)) - turn)


## The p.75 extend-your-stay roll: "Roll 2D6, requiring an 8+."
##
## Fake ID (p.58) adds +1 — this is the "attempt to obtain a license" the item
## names. Success is persisted, so the roll is not repeatable within a stay: the
## book gives one licence, not one attempt per press.
##
## Returns {rolled, dice, fake_id_bonus, total, target, success, line}.
static func attempt_stay_license(
	campaign: Variant, traits: Array, rng: RandomNumberGenerator = null
) -> Dictionary:
	var s: Dictionary = state(campaign)
	if not bool(s.get("active", false)) or bool(s.get("licensed", false)):
		return {"rolled": false, "success": bool(s.get("licensed", false)), "line": ""}

	var gen: RandomNumberGenerator = rng
	if gen == null:
		gen = RandomNumberGenerator.new()
		gen.randomize()

	var dice: int = gen.randi_range(1, 6) + gen.randi_range(1, 6)
	var bonus: int = OnboardItemServiceRef.license_bonus(campaign)
	var total: int = dice + bonus
	var target: int = WorldTraitEffectsRef.stay_license_target(traits)
	var success: bool = total >= target

	if success:
		var pd: Dictionary = _progress(campaign)
		if not pd.is_empty():
			s["licensed"] = true
			pd[STATE_KEY] = s

	var line: String = "License roll 2D6 = %d%s = %d vs %d+ — %s" % [
		dice,
		(" +%d Fake ID" % bonus) if bonus > 0 else "",
		total, target,
		"GRANTED" if success else "REFUSED",
	]
	return {
		"rolled": true, "dice": dice, "fake_id_bonus": bonus, "total": total,
		"target": target, "success": success, "line": line,
	}
