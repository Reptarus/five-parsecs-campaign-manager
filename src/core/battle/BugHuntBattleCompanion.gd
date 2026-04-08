class_name BugHuntBattleCompanion
extends RefCounted

## Bug Hunt Battle Companion — tabletop helper for all battle-round mechanics.
## Provides dice rollers and state tracking for:
##   - Contact marker movement (Aggression vs Chance, Compendium p.192)
##   - Contact detection (6"/3" proximity, Compendium p.192)
##   - Tactical Location activation (1D6+Savvy >= 5+, Compendium p.191)
##   - Spawn Point countdown/reveal/closing (Compendium pp.199-200)
##   - Evac request (2D6 + objectives + Savvy, Compendium p.201)
##   - Court Martial (0 objectives, Compendium p.201)
##   - Drop Ship fire support (Compendium p.201)
##
## This is a TABLETOP COMPANION — it provides dice results and tracking,
## not automated gameplay. The player executes actions on the physical table.


## ============================================================================
## CONTACT MARKER MOVEMENT (Compendium p.192)
## ============================================================================

func roll_contact_movement() -> Dictionary:
	## Roll Aggression (dark) and Chance (light) dice for a Contact marker.
	## Returns {aggression, chance, result, description}
	var aggression: int = (randi() % 6) + 1
	var chance: int = (randi() % 6) + 1

	var result: String
	var description: String

	if aggression == chance:
		result = "equal"
		description = "Dice equal (%d) — marker stays in place. Place a NEW Contact marker on top of it." % aggression
	elif aggression > chance:
		result = "aggression"
		description = "Aggression %d > Chance %d — move marker %d\" towards nearest trooper." % [aggression, chance, aggression]
	else:
		result = "chance"
		description = "Chance %d > Aggression %d — move marker %d\" in a random direction." % [chance, aggression, chance]

	return {
		"aggression": aggression,
		"chance": chance,
		"result": result,
		"move_distance": maxi(aggression, chance),
		"description": description
	}


## ============================================================================
## TACTICAL LOCATION ACTIVATION (Compendium p.191)
## ============================================================================

func roll_tactical_activation(savvy: int, failures_so_far: int) -> Dictionary:
	## Roll 1D6+Savvy, need 5+ to activate. Max 2 failures = permanently compromised.
	if failures_so_far >= 2:
		return {
			"success": false,
			"roll": 0,
			"total": 0,
			"description": "Location permanently compromised (2 failed attempts).",
			"compromised": true
		}

	var roll: int = (randi() % 6) + 1
	var total: int = roll + savvy
	var success: bool = total >= 5

	var desc: String
	if success:
		desc = "Activated! (rolled %d + Savvy %d = %d vs 5+)" % [roll, savvy, total]
	else:
		var new_failures: int = failures_so_far + 1
		if new_failures >= 2:
			desc = "Failed! (rolled %d + Savvy %d = %d vs 5+) — Location COMPROMISED (2nd failure)." % [roll, savvy, total]
		else:
			desc = "Failed! (rolled %d + Savvy %d = %d vs 5+) — 1 attempt remaining." % [roll, savvy, total]

	return {
		"success": success,
		"roll": roll,
		"savvy": savvy,
		"total": total,
		"description": desc,
		"compromised": not success and failures_so_far + 1 >= 2
	}


## ============================================================================
## SPAWN POINT MECHANICS (Compendium pp.199-200)
## ============================================================================

func roll_spawn_countdown() -> Dictionary:
	## Roll D6 for a Spawn Point without a countdown marker.
	## 1-4: place countdown marker with that value. 5-6: no marker this round.
	var roll: int = (randi() % 6) + 1
	if roll <= 4:
		return {
			"countdown": roll,
			"placed": true,
			"description": "Countdown %d placed. Will produce Contact when it reaches 0." % roll
		}
	return {
		"countdown": 0,
		"placed": false,
		"description": "Roll %d — no countdown placed. Check again next round." % roll
	}


func roll_close_spawn_point(savvy: int, has_helper: bool = false) -> Dictionary:
	## Roll 1D6+Savvy to close a Spawn Point (Compendium p.200). Need 6+.
	## A helper within 1" adds +1.
	var roll: int = (randi() % 6) + 1
	var bonus: int = savvy + (1 if has_helper else 0)
	var total: int = roll + bonus
	var success: bool = total >= 6

	var desc: String
	if success:
		desc = "Spawn Point SEALED! (rolled %d + Savvy %d%s = %d vs 6+)" % [
			roll, savvy, " + helper" if has_helper else "", total]
	else:
		desc = "Failed to close! (rolled %d + Savvy %d%s = %d vs 6+)" % [
			roll, savvy, " + helper" if has_helper else "", total]

	return {"success": success, "roll": roll, "total": total, "description": desc}


## ============================================================================
## EVAC (Compendium p.201)
## ============================================================================

func roll_evac(objectives_completed: int, packages_held: int, savvy: int) -> Dictionary:
	## Roll 2D6 + objectives + packages. Savvy +1 if >= 1. Need 10+.
	## From Round 5 onwards only.
	var die1: int = (randi() % 6) + 1
	var die2: int = (randi() % 6) + 1
	var savvy_bonus: int = 1 if savvy >= 1 else 0
	var total: int = die1 + die2 + objectives_completed + packages_held + savvy_bonus
	var success: bool = total >= 10

	var breakdown: Array = ["%d+%d" % [die1, die2]]
	if objectives_completed > 0:
		breakdown.append("+%d obj" % objectives_completed)
	if packages_held > 0:
		breakdown.append("+%d pkg" % packages_held)
	if savvy_bonus > 0:
		breakdown.append("+1 Savvy")

	var desc: String
	if success:
		desc = "EVAC INBOUND! (%s = %d vs 10+) — Drop ship arrives end of next round." % [
			", ".join(breakdown), total]
	else:
		desc = "Evac denied! (%s = %d vs 10+) — Roll again at end of each round." % [
			", ".join(breakdown), total]

	return {
		"success": success,
		"die1": die1,
		"die2": die2,
		"total": total,
		"description": desc
	}


## ============================================================================
## COURT MARTIAL (Compendium p.201)
## ============================================================================

func roll_court_martial() -> Dictionary:
	## If 0 Objectives completed, leader rolls D6. On 1, removed from campaign.
	## Pay 3 Reputation to avoid.
	var roll: int = (randi() % 6) + 1
	var guilty: bool = roll == 1

	var desc: String
	if guilty:
		desc = "Rolled %d — GUILTY! Leader removed from campaign. (Pay 3 Reputation to call in a favor and avoid this fate.)" % roll
	else:
		desc = "Rolled %d — Not guilty. No further action." % roll

	return {"roll": roll, "guilty": guilty, "description": desc}


## ============================================================================
## DROP SHIP FIRE SUPPORT (Compendium p.201)
## ============================================================================

func roll_drop_ship_fire(combat_skill_bonus: int = 1) -> Array:
	## Drop ship has 2 LMGs (Range 36", 3 shots each, +1 CS, no malfunction).
	## Returns array of shot results.
	var results: Array = []
	for gun in range(2):
		for shot in range(3):
			var roll: int = (randi() % 6) + 1
			var modified: int = roll + combat_skill_bonus
			results.append({
				"gun": gun + 1,
				"shot": shot + 1,
				"natural_roll": roll,
				"modified": modified,
				"rapid_fire": roll == 6  # Natural 6 = extra shot
			})
	return results


## ============================================================================
## SNAP FIRE CHECK (Compendium p.198)
## ============================================================================

static func can_snap_fire(reactions_roll: int, reactions_score: int) -> bool:
	## Quick Action figures (roll <= Reactions) may opt to hold for Snap Fire.
	return reactions_roll <= reactions_score


## ============================================================================
## SIGNALS (Optional Rule, Compendium p.208)
## ============================================================================

func roll_signal_investigation() -> Dictionary:
	## Roll D6 on the Signal table when a trooper investigates a Signal marker.
	var roll: int = (randi() % 6) + 1

	var results: Dictionary = {"roll": roll}
	match roll:
		1:
			var civilians: int = (randi() % 3) + 1  # 1D3
			results["type"] = "civilians"
			results["description"] = "CIVILIANS: Found %d civilian(s) with trooper profile but no weapons. Cannot act this round. +1 Reputation per civilian evacuated." % civilians
			results["civilians_count"] = civilians
		2:
			results["type"] = "evidence"
			results["description"] = "EVIDENCE: Data pointing to the origin of the attack. Counts as 1 additional Objective completed."
		3:
			results["type"] = "danger"
			results["description"] = "DANGER: Beacon warning of enemy entry point! Randomly place a new Spawn Point on the battlefield edge."
		4:
			results["type"] = "ambush"
			results["description"] = "AMBUSH! Treat as a Contact marker that rolled 3-6 (CONTACT!). Place enemies normally."
		5:
			results["type"] = "trooper"
			results["description"] = "TROOPER: SOS from a captured trooper! Place with basic profile and Service Pistol. Fights with you. +1 Reputation for rescue."
		6:
			results["type"] = "supplies"
			results["description"] = "SUPPLIES: Supply cache from a recon squad. +2 Support points for your campaign."

	return results


func roll_signal_alertness() -> Dictionary:
	## End-of-round roll for each Signal within 9" of a trooper.
	## Roll 1D6 — on a 1, place a Contact marker on the Signal.
	var roll: int = (randi() % 6) + 1
	if roll == 1:
		return {"alert": true, "roll": roll, "description": "Roll %d — Contact marker placed on Signal!" % roll}
	return {"alert": false, "roll": roll, "description": "Roll %d — No activity." % roll}


## ============================================================================
## FORMATION BONUS (Compendium p.173)
## ============================================================================

static func check_formation_bonus(team_in_formation: bool) -> int:
	## Combat teams in formation (all within 2") receive +1 Reactions.
	return 1 if team_in_formation else 0
