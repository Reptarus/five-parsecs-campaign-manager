class_name PlanetfallMissionRewards
extends RefCounted

## Each Planetfall mission's Rewards (pp.115-133), and the Pitched Battle's Campaign
## Consequences (p.127). Pure: returns {lines, ops}, and PlanetfallPhaseManager applies the
## ops at Step 12 beside the mission's map Campaign Factors (PlanetfallMap).
##
## Until 2026-10-28 every one of these was printed in the debrief and applied by nothing:
## a Science mission's samples were never rolled for Research Points, a Patrol never
## raised Morale, a Delve "acquired" its Artifact in a log line and added none, and a Hunt
## authorised a Bio-Analysis nobody could start. Worse, `objectives_completed` had no
## producer at all, so every objective-based factor read 0 on a real return.
##
## Dice, all through DiceManager so the QA seam can force them:
##   "Planetfall Science Sample" (D6 per sample, p.119)
##   "Planetfall Artifact" (D100, p.135)
##   "Planetfall Campaign Consequence" (D100, p.127)
##   "Planetfall Consequence Severity" (the 1D6 of a 1D6+2, p.127)
##   "Planetfall Colony Defenses" (D6 per point, 4+ negates; the p.62 Raid's die)
##   "Planetfall Post-Mission Find" (D100, p.134; an Investigation's Rewards result)

const EventResolverScript := preload("res://src/core/systems/PlanetfallEventResolver.gd")
const ColonyCrisisScript := preload("res://src/core/systems/PlanetfallColonyCrisis.gd")
const PostMissionScript := preload("res://src/core/systems/PlanetfallPostMissionSystem.gd")

const SAMPLE_DIE := "Planetfall Science Sample"
const ARTIFACT_DIE := "Planetfall Artifact"
const CONSEQUENCE_DIE := "Planetfall Campaign Consequence"
const SEVERITY_DIE := "Planetfall Consequence Severity"
const DEFENSES_DIE := "Planetfall Colony Defenses"
const SLYN_DEPARTURE_DIE := "Planetfall Slyn Departure"

## p.133 Delve: "You also receive 2 Research Points and 2 Build Points for completing the
## Delve." p.133 prints the same sentence twice; it is one award.
const DELVE_RP := 2
const DELVE_BP := 2
## p.121 Hunt: "a sample from two Lifeforms".
const HUNT_SAMPLES := 2
## p.115 Investigation: "Place a Discovery marker in the center of each table quarter."
const DISCOVERY_MARKERS := 4
const FIND_DIE := "Planetfall Post-Mission Find"
## What only the table knows about a mission's rewards, asked by the post-battle
## debrief as [key, cap, prompt]. The resolver clamps each answer to its cap.
const DEBRIEF_ASKS := {
	"investigation": [
		["investigation_finds", DISCOVERY_MARKERS,
			"Discovery markers that rolled Rewards (a 2): one Post-Mission Finds roll each, "
			+ "win or lose (pp.115-116):"],
		["investigation_raw_materials", DISCOVERY_MARKERS,
			"Action required (a 4) passed on 1D6+Savvy 5+: 1 Raw Materials each (p.115):"],
	],
}


## `result` is the normalized battle result (mission_id, won, objectives_completed,
## lifeform_slot, casualties). `roster` is the phase manager's roster snapshot.
static func resolve(campaign: Resource, result: Dictionary, roster: Array) -> Dictionary:
	var out: Dictionary = {"lines": [], "ops": []}
	if campaign == null:
		return out
	var won: bool = bool(result.get("won", false))
	var objectives: int = maxi(int(result.get("objectives_completed", 0)), 0)
	var dice := EventResolverScript.new()
	match str(result.get("mission_id", "")):
		"science":
			_science(objectives, dice, out)
		"hunt":
			_hunt(objectives, int(result.get("lifeform_slot", -1)), out)
		"patrol":
			# p.122: "If you complete at least 1 Objective, increase Colony Morale by 1."
			if objectives >= 1:
				out.ops.append({"op": "morale_adjust", "amount": 1})
				out.lines.append("Patrol: %d Objective(s) completed, Colony Morale +1 (p.122)."
						% objectives)
		"pitched_battle":
			if not won and not campaign.get_mission_offer("pitched_battle").is_empty():
				_campaign_consequence(campaign, result, roster, dice, out)
		"delve":
			_delve(campaign, objectives, dice, out)
		"investigation":
			_investigation(result, dice, out)
	_slyn_victory(campaign, result, won, dice, out)
	return out


## p.157, 4th Milestone: "Track how many times you beat the Slyn from this point onwards.
## Each time you do, roll 2D6 and, if the roll is equal to or below the tracked victories,
## the Slyn decide to leave you alone. They will no longer attack for the rest of this
## campaign. Victories prior to this point are not counted."
## ⚠ Before 2026-10-28 the 4th Milestone reset the count and nothing ever raised it, so the
## Slyn could never leave. Any mission that fought them counts, whatever its own id.
static func _slyn_victory(campaign: Resource, result: Dictionary, won: bool, dice,
		out: Dictionary) -> void:
	if not won or str(result.get("opposition_type", "")) != "slyn":
		return
	if not bool(campaign.get_milestone_flag("slyn_tracking", false)) or campaign.slyn_departed:
		return
	var victories: int = int(campaign.slyn_victories) + 1
	var roll: int = dice.roll_2d6(SLYN_DEPARTURE_DIE)
	var leaving: bool = roll <= victories
	out.ops.append({"op": "slyn_victory", "departed": leaving})
	out.lines.append("The Slyn were beaten: %d tracked victor%s since the 4th Milestone. "
			% [victories, "y" if victories == 1 else "ies"]
			+ ("2D6 %d is at or below it: the Slyn leave you alone for the rest of the "
			% roll + "campaign (p.157)." if leaving else
			"2D6 %d is above it: the Slyn will keep attacking (p.157)." % roll))


## p.119: "For each sample collected, roll 1D6. On 4-6, you receive 1 Research Point. If
## you roll more than a single 6 when doing this, you also receive 1 unit of Mission Data."
static func _science(samples: int, dice, out: Dictionary) -> void:
	if samples <= 0:
		return
	var rolls: Array = []
	var rp: int = 0
	var sixes: int = 0
	for _i in range(samples):
		var d: int = dice.roll_d6(SAMPLE_DIE)
		rolls.append(d)
		if d >= 4:
			rp += 1
		if d == 6:
			sixes += 1
	out.lines.append("Science: %d sample(s), 1D6 each: %s -> %d Research Point(s) (p.119)."
			% [samples, ", ".join(rolls.map(func(x): return str(x))), rp])
	if rp > 0:
		out.ops.append({"op": "rp_gain", "amount": rp})
	if sixes > 1:
		out.ops.append({"op": "mission_data", "amount": 1,
				"source": "the samples (more than one 6, p.119)"})


## p.115 Investigation, paid per p.116: "You receive any rewards you acquired during the
## mission", so neither waits on a win. A 2 (Rewards): "You may roll once on the
## Post-Mission Finds table (see page 134) after the mission is over." A 4 (Action
## required) passed on 1D6+Savvy 5+: "1 unit of Raw Materials". A 5-6 (Data) is noted with
## the debrief's Mission Data. Until 2026-10-28 nothing asked for either, so both were lost.
static func _investigation(result: Dictionary, dice, out: Dictionary) -> void:
	var given: Dictionary = result.get("mission_rewards", {}) \
			if result.get("mission_rewards") is Dictionary else {}
	var finds: int = clampi(int(given.get("investigation_finds", 0)), 0, DISCOVERY_MARKERS)
	var rm: int = clampi(int(given.get("investigation_raw_materials", 0)), 0,
			DISCOVERY_MARKERS)
	if finds > 0:
		out.lines.append("Investigation: %d tagged location(s), one Post-Mission Finds roll "
				% finds + "each (p.115).")
	for _i in range(finds):
		out.ops.append({"op": "post_mission_find", "roll": dice.roll_d100(FIND_DIE)})
	if rm > 0:
		out.ops.append({"op": "rm_gain", "amount": rm})
		out.lines.append("Investigation: %d Action required result(s) passed (p.115)." % rm)


## p.121: two Lifeforms sampled authorise Bio-Analysis of that creature (p.92). The
## battle screen records which encounter entry the mission met (`lifeform_slot`).
static func _hunt(samples: int, slot: int, out: Dictionary) -> void:
	if samples < HUNT_SAMPLES:
		if samples > 0:
			out.lines.append("Hunt: %d sample(s); two are needed to authorize Bio-Analysis "
					% samples + "(p.121).")
		return
	if slot < 0:
		out.lines.append("Hunt: samples taken, but the battle recorded no Lifeform encounter "
				+ "entry to analyze (p.121).")
		return
	out.ops.append({"op": "lifeform_sample", "slot": slot})


## p.133: "You receive a random Alien Artifact if you find the Artifact during the
## mission ... You also receive 2 Research Points and 2 Build Points for completing the
## Delve." p.135: "Only one roll is made per Ancient Site you successfully investigate."
static func _delve(campaign: Resource, found: int, dice, out: Dictionary) -> void:
	if found < 1:
		return
	var pms := PostMissionScript.new()
	var roll: int = dice.roll_d100(ARTIFACT_DIE)
	var ids: Array = []
	for a in campaign.artifacts_found:
		if a is Dictionary:
			ids.append(str(a.get("id", "")))
	var artifact: Dictionary = pms.roll_artifact(roll, ids)
	if not artifact.is_empty() and str(artifact.get("id", "")) in ids:
		artifact = {}
	out.lines.append("Delve: Artifacts table D100 %d (p.135)." % roll)
	out.ops.append({"op": "artifact", "artifact": artifact})
	out.ops.append({"op": "rp_gain", "amount": DELVE_RP})
	out.ops.append({"op": "bp_gain", "amount": DELVE_BP})
	out.lines.append("Delve completed: +%d Research Points and +%d Build Points (p.133)."
			% [DELVE_RP, DELVE_BP])


## p.127 Pitched Battle Campaign Factors: "If you fail, roll D100 and consult the Campaign
## Consequences table above." ⚠ p.62's Attack row says a lost Pitched Battle takes
## "damage as per Raid". The two pages disagree; the mission's own Campaign Factors are
## the procedure Step 12 resolves, and the table exists for nothing else, so p.127 wins.
## Applying both would charge one defeat twice.
static func _campaign_consequence(campaign: Resource, result: Dictionary, roster: Array,
		dice, out: Dictionary) -> void:
	var roll: int = dice.roll_d100(CONSEQUENCE_DIE)
	var head: String = "The Attack succeeds. Campaign Consequences D100 %d: " % roll
	if roll <= 20:
		var hit: Dictionary = _defended(campaign, dice)
		out.lines.append(head + "Colony damage, 1D6+2 = %d, %d negated by Colony Defenses "
				% [int(hit.base), int(hit.negated)] + "(p.127).")
		out.ops.append({"op": "colony_damage", "amount": int(hit.damage), "mitigable": true})
	elif roll <= 40:
		out.lines.append(head + "Interruption (p.127).")
		out.ops.append({"op": "lose_project_progress"})
	elif roll <= 60:
		var hit: Dictionary = _defended(campaign, dice)
		out.lines.append(head + "Morale loss, 1D6+2 = %d, %d negated by Colony Defenses "
				% [int(hit.base), int(hit.negated)] + "(p.127).")
		if int(hit.damage) > 0:
			out.ops.append({"op": "morale_adjust", "amount": -int(hit.damage)})
	elif roll <= 80:
		out.lines.append(head + "Attrition: 2 grunts are removed (p.127).")
		out.ops.append({"op": "grunt_lost"})
		out.ops.append({"op": "grunt_lost"})
	else:
		out.lines.append(head + "Prolonged battle: 2 random characters roll on the Injury "
				+ "table; none injured in the mission may be chosen (p.127).")
		_prolonged_battle(result, roster, dice, out)


## p.127: 1D6+2 points, and "If you have Colony Defenses, roll 1D6 for each point, with a
## 4+ negating it."
static func _defended(campaign: Resource, dice) -> Dictionary:
	var base: int = dice.roll_d6(SEVERITY_DIE) + 2
	var negated: int = 0
	if int(campaign.colony_defenses) > 0:
		for _i in range(base):
			if dice.roll_d6(DEFENSES_DIE) >= 4:
				negated += 1
	return {"base": base, "negated": negated, "damage": base - negated}


static func _prolonged_battle(result: Dictionary, roster: Array, dice, out: Dictionary) -> void:
	var hurt: Array = []
	for cid in result.get("casualties", []):
		hurt.append(str(cid))
	var pool: Array = []
	for c in roster:
		if c is Dictionary and str(c.get("id", "")) not in hurt:
			pool.append(c)
	if pool.is_empty():
		out.lines.append("No character outside the mission's casualties can be chosen.")
		return
	var crisis := ColonyCrisisScript.new()
	for _i in range(mini(2, pool.size())):
		var c: Dictionary = pool[dice.pick_index(pool.size())]
		pool.erase(c)
		var r: Dictionary = crisis.injury_roll_receipt(c)
		out.lines.append_array(r.get("lines", []))
		out.ops.append_array(r.get("ops", []))
