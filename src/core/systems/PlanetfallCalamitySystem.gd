class_name PlanetfallCalamitySystem
extends RefCounted

## Calamities (Planetfall pp.165-168): the p.165 table, each Calamity's setup, its
## end-of-turn rolls (Step 18), the progress a mission makes against it (Step 12), and
## the reward when it ends. Every die goes through a DiceManager context, so QA can
## force each one.
##
## ⚠ Before 2026-10-28 only the trigger and the Super Weapon's progress existed. That
## progress was a raw randi rolled at TURN START and reached the player only as a
## push_warning. The Virus and Swarm "effects" were a line saying a check was needed.
## No Calamity had a setup, and record_resolution_progress() had no caller, so every
## progress key except the weapon's had no producer: seven of the eight Calamities could
## never end, and none ever paid its reward.
##
## Shape: the Step 12 and Step 18 resolvers return {lines, ops}. A Calamity's own state
## (its progress, and the "anomaly" / "swarm" sector flags on the map) is written here;
## everything the colony owns (damage, grunts, points, Sick Bay, Finds) goes out as an op
## for PlanetfallPhaseManager._apply_stability_ops, the one mutator. Setup runs inside
## Milestone delivery, which writes the campaign directly, so setup does too.

const MapScript := preload("res://src/core/systems/PlanetfallMap.gd")
const EventResolverScript := preload("res://src/core/systems/PlanetfallEventResolver.gd")
const ColonyCrisisScript := preload("res://src/core/systems/PlanetfallColonyCrisis.gd")

# Forcing matches a SUBSTRING of the roll's context, so no key may contain another.
const PICK_DIE := "Planetfall Calamity Pick"
const WEAPON_PROGRESS_DIE := "Planetfall Super Weapon Progress"
const WEAPON_DAMAGE_DIE := "Planetfall Super Weapon Damage"
const ANOMALY_DIE := "Planetfall Anomaly"
const FLARE_UP_DIE := "Planetfall Flare-up"
const SWARM_SPREAD_DIE := "Planetfall Swarm Spread"
const SWARM_ATTACK_DIE := "Planetfall Swarm Attack"
const VIRUS_DIE := "Planetfall Virus Exposure"
const VIRUS_PICK_DIE := "Planetfall Virus Victim"
const CURE_DIE := "Planetfall Cure Check"
const FIND_DIE := "Planetfall Post-Mission Find"

const WEAPON_LAUNCH := 15
const ANOMALY_SECTORS := 3
const ANOMALY_RAW_MATERIALS := 2
const VIRUS_SETUP_CHARACTERS := 2
const VIRUS_SPREAD_CHARACTERS := 3
const VIRUS_ILL := 6
const CURE_DATA_PER_HUNT := 2
const MEGA_KILLS := 5
const MEGA_SECTORS := 3
const SLEEPER_CHIPS := 5
const SLEEPER_CHIP_RP := 4
const SLYN_KILLS := 30
const SLYN_GRUNTS := 2
const VIRUS_RECOVERY_TURNS := 4
## p.168: "Roll 2D6+4 for the number of Swarm encountered".
const SWARM_NUMBER_DIE := "Planetfall Swarm Numbers"
const SWARM_NUMBER_BONUS := 4

## The printed page each Calamity's entry is on.
const PAGES := {
	"enemy_super_weapon": 165, "environmental_risk": 165, "mega_predators": 166,
	"robot_rampage": 166, "slyn_assault": 167, "swarm_infestation": 167, "virus": 168,
	"wildlife_aggression": 168,
}

## The Calamities that roll "at the end of each campaign turn" (Step 18).
const END_OF_TURN := ["enemy_super_weapon", "environmental_risk", "swarm_infestation", "virus"]

var _calamities: Array = []
var _loaded: bool = false


func _init() -> void:
	_load_data()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_data() -> void:
	var data: Dictionary = _load_json("res://data/planetfall/calamities.json")
	_calamities = data.get("entries", [])
	_loaded = not _calamities.is_empty()


func _load_json(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallCalamitySystem: JSON not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err == OK and json.data is Dictionary:
		return json.data
	return {}


## ============================================================================
## CALAMITY GENERATION (p.165)
## ============================================================================

## D100 lookup on the Calamity table. "If you experience a Calamity that has already
## happened to your colony, take the next option on the table (wrapping around to the
## start if needed)." Appends the record to campaign.active_calamities and runs its
## setup. Returns a copy of the record plus its setup `lines`, or {} when all 8 have
## occurred.
func trigger_calamity(campaign: Resource, roll: int) -> Dictionary:
	var initial: Dictionary = _lookup_d100(_calamities, roll)
	if initial.is_empty():
		return {}
	var occurred_ids: Array = _get_occurred_calamity_ids(campaign)
	var calamity: Dictionary = initial
	if calamity.get("id", "") in occurred_ids:
		calamity = _find_next_available(initial, occurred_ids)
		if calamity.is_empty():
			return {}

	var active_record: Dictionary = {
		"id": calamity.get("id", ""),
		"name": calamity.get("name", ""),
		"description": calamity.get("description", ""),
		"setup": calamity.get("setup", ""),
		"ongoing_effect": calamity.get("ongoing_effect", ""),
		"resolution": calamity.get("resolution", ""),
		"reward": calamity.get("reward", ""),
		"enemy_profile": calamity.get("enemy_profile", {}),
		"resolved": false,
		"progress": {},
		"triggered_turn": campaign.campaign_turn if campaign and "campaign_turn" in campaign else 0
	}
	if campaign and "active_calamities" in campaign:
		campaign.active_calamities.append(active_record)
	var lines: Array = _setup(campaign, active_record) if campaign else []
	var out: Dictionary = active_record.duplicate(true)
	out["lines"] = lines
	return out


## ============================================================================
## ACTIVE CALAMITY MANAGEMENT
## ============================================================================

## The unresolved Calamity records themselves (not copies), so progress written to one
## is the campaign's.
func get_active_calamities(campaign: Resource) -> Array:
	if not campaign or not "active_calamities" in campaign:
		return []
	var active: Array = []
	for cal in campaign.active_calamities:
		if cal is Dictionary and not cal.get("resolved", false):
			active.append(cal)
	return active


func get_calamity_count(campaign: Resource) -> int:
	return get_active_calamities(campaign).size()


func get_active(campaign: Resource, calamity_id: String) -> Dictionary:
	for cal in get_active_calamities(campaign):
		if str(cal.get("id", "")) == calamity_id:
			return cal
	return {}


func is_active(campaign: Resource, calamity_id: String) -> bool:
	return not get_active(campaign, calamity_id).is_empty()


## Whether Step 18 has anything to roll this turn.
func end_of_turn_owed(campaign: Resource) -> bool:
	for cal in get_active_calamities(campaign):
		if str(cal.get("id", "")) in END_OF_TURN:
			return true
	return false


## ============================================================================
## SETUP (each entry's opening paragraph)
## ============================================================================

func _setup(campaign: Resource, cal: Dictionary) -> Array:
	var lines: Array = []
	var md: Dictionary = campaign.map_data if "map_data" in campaign else {}
	var p: Dictionary = _progress(cal)
	var dice := EventResolverScript.new()
	match str(cal.get("id", "")):
		"enemy_super_weapon":
			# p.165: "A random Tactical Enemy is building a super weapon".
			var active: Array = MapScript.active_indices(campaign) if not md.is_empty() else []
			var idx: int = int(active[MapScript.pick_index(active.size(), PICK_DIE)]) \
					if not active.is_empty() else -1
			p["weapon_progress"] = 0
			p["enemy_index"] = idx
			p["site_sector"] = _new_site(campaign)
			if idx >= 0:
				lines.append("%s is building a super weapon aimed at your colony (p.165)."
						% MapScript.enemy_name(campaign, idx))
			else:
				lines.append("No Tactical Enemy is on the map: the weapon site in %s is open to "
						% MapScript.label(str(p.site_sector)) + "a Strike against a minor "
						+ "scouting force rolled on the Tactical Enemies table (p.165).")
		"environmental_risk":
			# p.165: "Randomly select 3 map sectors. They can be enemy held."
			for _i in range(ANOMALY_SECTORS):
				var k: String = _new_flagged_sector(campaign, "anomaly")
				if k != "":
					lines.append("Atmospheric anomalies over %s (p.165)." % MapScript.label(k))
		"swarm_infestation":
			# p.167: "Randomly select a map sector that is not enemy held. It is immediately
			# infested".
			if md.is_empty():
				return lines
			var hk: String = MapScript.home_key(md)
			var k: String = MapScript.random_sector_where(md, func(x: String) -> bool:
				return (x != hk and not MapScript.is_occupied(campaign, x)
						and not bool(MapScript.sector(md, x).get("swarm", false))))
			if k != "":
				MapScript.set_flag(campaign, k, "swarm", true)
				lines.append("The Swarm infests %s. No mission can enter it except a Skirmish "
						% MapScript.label(k) + "to clear it (p.167).")
		"virus":
			# p.168: "Randomly select two characters on your roster and roll 1D6 for each."
			for c in _pick_characters(_roster(campaign), VIRUS_SETUP_CHARACTERS, dice):
				var r: Dictionary = _expose(cal, c, dice)
				lines.append(r.line)
				if bool(r.ill) and campaign.has_method("quarantine"):
					campaign.quarantine(str(c.get("id", "")))
		"mega_predators", "robot_rampage", "slyn_assault", "wildlife_aggression":
			lines.append("Its rules apply on the battlefield from your next mission (p.%d)."
					% int(PAGES.get(str(cal.get("id", "")), 165)))
	return lines


## ============================================================================
## STEP 18: "AT THE END OF EACH CAMPAIGN TURN"
## ============================================================================

## Every active Calamity's end-of-turn rolls, in the order they occurred. {lines, ops}.
func end_of_turn(campaign: Resource) -> Dictionary:
	var out: Dictionary = {"lines": [], "ops": []}
	if campaign == null:
		return out
	var dice := EventResolverScript.new()
	for cal in get_active_calamities(campaign):
		match str(cal.get("id", "")):
			"enemy_super_weapon":
				_weapon_turn(campaign, cal, dice, out)
			"environmental_risk":
				_anomaly_turn(campaign, cal, dice, out)
			"swarm_infestation":
				_swarm_turn(campaign, cal, dice, out)
			"virus":
				_virus_turn(campaign, cal, dice, out)
	return out


## p.165: "The enemy will complete 1D6 points of progress at the end of every campaign
## turn. When the total progress reaches 15, the weapon is launched and will inflict 3D6
## damage to your colony. Every 6 rolled on the damage roll also causes a randomly
## selected character to make a roll on the Post-Battle Injury table (see page 66). When
## the weapon is launched, the enemy begins building the next one, starting again from 0."
func _weapon_turn(campaign: Resource, cal: Dictionary, dice, out: Dictionary) -> void:
	var p: Dictionary = _progress(cal)
	if not p.has("site_sector"):
		p["site_sector"] = _new_site(campaign)
	var roll: int = dice.roll_d6(WEAPON_PROGRESS_DIE)
	var total: int = int(p.get("weapon_progress", 0)) + roll
	if total < WEAPON_LAUNCH:
		p["weapon_progress"] = total
		out.lines.append("Super weapon: 1D6 %d, progress %d of %d (p.165)."
				% [roll, total, WEAPON_LAUNCH])
		return
	p["weapon_progress"] = 0
	var dmg: Array = [dice.roll_d6(WEAPON_DAMAGE_DIE), dice.roll_d6(WEAPON_DAMAGE_DIE),
			dice.roll_d6(WEAPON_DAMAGE_DIE)]
	var damage: int = int(dmg[0]) + int(dmg[1]) + int(dmg[2])
	out.lines.append("Super weapon: 1D6 %d brings progress to %d. The weapon is LAUNCHED: "
			% [roll, total] + "3D6 %d, %d, %d = %d Colony Damage. Building the next one starts "
			% [dmg[0], dmg[1], dmg[2], damage] + "from 0 (p.165).")
	out.ops.append({"op": "colony_damage", "amount": damage, "mitigable": true})
	var crisis := ColonyCrisisScript.new()
	for _i in range(dmg.count(6)):
		var who: Dictionary = _random_character(_roster(campaign), dice)
		if who.is_empty():
			break
		out.lines.append("A 6 on the damage roll: %s rolls on the Post-Battle Injury table "
				% str(who.get("name", "?")) + "(pp.66, 165).")
		var r: Dictionary = crisis.injury_roll_receipt(who)
		out.lines.append_array(r.get("lines", []))
		out.ops.append_array(r.get("ops", []))


## pp.165-166: "At the end of each campaign turn, roll a D6 for each anomalous sector on
## the map: 1-4 indicates no effect; 5-6 results in an environmental flare-up", rolled on
## the 1D6 Flare-up table.
func _anomaly_turn(campaign: Resource, _cal: Dictionary, dice, out: Dictionary) -> void:
	for k in MapScript.flagged(campaign.map_data, "anomaly"):
		var at: String = MapScript.label(str(k))
		var roll: int = dice.roll_d6(ANOMALY_DIE)
		if roll <= 4:
			out.lines.append("Anomaly at %s: 1D6 %d, no effect (p.165)." % [at, roll])
			continue
		var flare: int = dice.roll_d6(FLARE_UP_DIE)
		var head: String = "Anomaly at %s: 1D6 %d, a flare-up; 1D6 %d: " % [at, roll, flare]
		if flare <= 2:
			var who: Dictionary = _random_character(_roster(campaign), dice)
			if who.is_empty():
				out.lines.append(head + "no one is on the roster to injure (p.166).")
				continue
			out.lines.append(head + "%s is injured and spends one campaign turn in Sick Bay "
					% str(who.get("name", "?")) + "(p.166).")
			out.ops.append({"op": "injury", "character_id": str(who.get("id", "")), "turns": 1})
		elif flare <= 4:
			out.lines.append(head + "1 point of Colony Damage, bypassing defenses (p.166).")
			out.ops.append({"op": "colony_damage", "amount": 1, "mitigable": false})
		elif flare == 5:
			out.lines.append(head + "no effect (p.166).")
		else:
			var spread: String = _new_flagged_sector(campaign, "anomaly")
			out.lines.append(head + ("another sector develops an anomaly: %s (p.166)."
					% MapScript.label(spread) if spread != ""
					else "another anomaly, but every sector already has one (p.166)."))


## p.167: "After you have completed your mission for the turn, check to see if the Swarm
## is spreading: Roll a D6 for each adjacent map sector to a Swarm sector. You can choose
## the order you want to test them in. Once you roll a 6, the Swarm infests that sector as
## well, and no more rolls are made this turn." Then the perimeter attacks.
##
## The order is the player's to choose. The app tests enemy-held sectors first (the
## Swarm takes them from the enemy), then the rest farthest from the colony first, and
## the colony sector last: the order that keeps the Swarm away from the colony longest.
func _swarm_turn(campaign: Resource, _cal: Dictionary, dice, out: Dictionary) -> void:
	var md: Dictionary = campaign.map_data
	var hk: String = MapScript.home_key(md)
	var infested: Array = MapScript.flagged(md, "swarm")
	var candidates: Array = []
	for s in infested:
		for k in MapScript.adjacent_keys(md, str(s)):
			if not candidates.has(k) and not infested.has(k):
				candidates.append(k)
	candidates.sort_custom(func(a: String, b: String) -> bool:
		var ea: bool = MapScript.is_occupied(campaign, a)
		var eb: bool = MapScript.is_occupied(campaign, b)
		if ea != eb:
			return ea
		var da: int = MapScript.distance(hk, a)
		var db: int = MapScript.distance(hk, b)
		return da > db if da != db else a < b)
	var spread_to: String = ""
	var rolls: Array = []
	for k in candidates:
		var roll: int = dice.roll_d6(SWARM_SPREAD_DIE)
		rolls.append("%s %d" % [MapScript.label(str(k)), roll])
		if roll == 6:
			spread_to = str(k)
			break
	if candidates.is_empty():
		out.lines.append("The Swarm has nowhere to spread (p.167).")
	elif spread_to == "":
		out.lines.append("Swarm spread, 1D6 each (%s): no 6, the Swarm is laying low (p.167)."
				% ", ".join(rolls))
	elif spread_to == hk:
		# p.167: "If the Swarm would expand into your colony sector, you must fight a
		# Pitched Battle mission next campaign turn."
		campaign.offer_mission("pitched_battle", {"enemy_index": -1, "forced": true,
				"swarm": true}, int(campaign.campaign_turn) + 1)
		out.lines.append("Swarm spread (%s): the Swarm reaches your colony. You must fight a "
				% ", ".join(rolls) + "Pitched Battle against it next campaign turn (p.167).")
	else:
		out.lines.append("Swarm spread (%s): the Swarm infests %s (p.167)."
				% [", ".join(rolls), MapScript.label(spread_to)])
		out.lines.append_array(_infest(campaign, spread_to))
	# p.167: "If the Swarm infest one of the 8 sectors adjacent to your colony, they will
	# begin attacking your perimeter. Each campaign turn, roll 1D6 for each infested sector
	# adjacent: On 1-2, nothing occurs. On 3-5, your colony takes damage equal to the die
	# roll. On a 6, you take 6 Damage and one of your grunts is killed."
	for k in MapScript.flagged(md, "swarm"):
		if not MapScript.adjacent_keys(md, hk).has(k):
			continue
		var roll: int = dice.roll_d6(SWARM_ATTACK_DIE)
		var at: String = MapScript.label(str(k))
		if roll <= 2:
			out.lines.append("The Swarm in %s probes your perimeter: 1D6 %d, nothing occurs "
					% [at, roll] + "(p.167).")
		elif roll <= 5:
			out.lines.append("The Swarm in %s attacks your perimeter: 1D6 %d, %d Colony Damage "
					% [at, roll, roll] + "(p.167).")
			out.ops.append({"op": "colony_damage", "amount": roll, "mitigable": true})
		else:
			out.lines.append("The Swarm in %s breaks through: 1D6 6, 6 Colony Damage and a grunt "
					% at + "is killed (p.167).")
			out.ops.append({"op": "colony_damage", "amount": 6, "mitigable": true})
			out.ops.append({"op": "grunt_lost"})


## p.167: "If they infest a sector held by an enemy, the enemy loses the sector unless it
## was their final sector they held, in which case they evacuate to another random map
## sector."
func _infest(campaign: Resource, k: String) -> Array:
	var md: Dictionary = campaign.map_data
	var hk: String = MapScript.home_key(md)
	MapScript.set_flag(campaign, k, "swarm", true)
	var idx: int = MapScript.occupant(campaign, k)
	if idx < 0:
		return []
	var name: String = MapScript.enemy_name(campaign, idx)
	MapScript.release(campaign, idx, k)
	if not MapScript.held_by(campaign, idx).is_empty():
		return ["%s loses %s to the Swarm (p.167)." % [name, MapScript.label(k)]]
	var dest: String = MapScript.random_sector_where(md, func(x: String) -> bool:
		return (x != hk and not MapScript.is_occupied(campaign, x)
				and not bool(MapScript.sector(md, x).get("swarm", false))))
	if dest == "":
		return ["%s loses its last sector to the Swarm and has nowhere to go (p.167)." % name]
	MapScript.occupy(campaign, idx, dest)
	return ["%s loses its last sector to the Swarm and evacuates to %s (p.167)."
			% [name, MapScript.label(dest)]]


## p.168: "Roll 2D6 at the end of each campaign turn before rolling for the spread of the
## virus. On a roll equal to or below the total amount of Cure Data, you have enough to
## start producing the cure. The virus no longer spreads, and your characters recover
## immediately." Then: "At the end of each campaign turn, select three characters on
## your roster."
##
## "Select" is not "randomly select", but a player choosing would always pick characters
## already quarantined, and the virus could then never spread. The app picks at random
## among the healthy, as the setup does.
func _virus_turn(campaign: Resource, cal: Dictionary, dice, out: Dictionary) -> void:
	var p: Dictionary = _progress(cal)
	var cure: int = int(p.get("cure_data", 0))
	if cure >= 2:
		var roll: int = dice.roll_2d6(CURE_DIE)
		if roll <= cure:
			out.lines.append("Cure check: 2D6 %d against %d Cure Data. The cure is found: the "
					% [roll, cure] + "virus stops spreading and the sick recover (p.168).")
			out.ops.append({"op": "release_quarantine"})
			_end(campaign, cal, dice, out)
			return
		out.lines.append("Cure check: 2D6 %d against %d Cure Data: not yet (p.168)."
				% [roll, cure])
	else:
		out.lines.append("No cure check: %d Cure Data, and 2D6 cannot roll below 2. Each Hunt "
				% cure + "you complete adds 2 (p.168).")
	var healthy: Array = _roster(campaign).filter(func(c: Dictionary) -> bool:
		return not (campaign.has_method("is_quarantined")
				and campaign.is_quarantined(str(c.get("id", "")))))
	var picked: Array = _pick_characters(healthy, VIRUS_SPREAD_CHARACTERS, dice)
	if picked.is_empty():
		out.lines.append("Every character is already quarantined (p.168).")
	for c in picked:
		var r: Dictionary = _expose(cal, c, dice)
		out.lines.append(r.line)
		if bool(r.ill):
			out.ops.append({"op": "quarantine", "character_id": str(c.get("id", ""))})


## p.168: "If the roll is 1-5, this is how many Virus Points they have accumulated. If the
## roll is a 6, they immediately fall ill." Later: "If they have no Virus Points, roll as
## above. If they do have Virus Points, increase the amount by +1. A total of 6 means they
## fall ill." Writes the Virus Points; {ill, line}.
func _expose(cal: Dictionary, c: Dictionary, dice) -> Dictionary:
	var p: Dictionary = _progress(cal)
	if not p.get("virus_points") is Dictionary:
		p["virus_points"] = {}
	var points: Dictionary = p["virus_points"]
	var id: String = str(c.get("id", ""))
	var name: String = str(c.get("name", id))
	var had: int = int(points.get(id, 0))
	if had <= 0:
		var roll: int = dice.roll_d6(VIRUS_DIE)
		points[id] = VIRUS_ILL if roll == 6 else roll
		if roll == 6:
			return {"ill": true, "line": "%s: 1D6 6, falls ill and is quarantined in Sick Bay "
					% name + "(p.168)."}
		return {"ill": false, "line": "%s: 1D6 %d, %d Virus Point(s) (p.168)." % [name, roll, roll]}
	points[id] = had + 1
	if had + 1 >= VIRUS_ILL:
		return {"ill": true, "line": "%s: +1 Virus Point, 6 in all: falls ill and is "
				% name + "quarantined in Sick Bay (p.168)."}
	return {"ill": false, "line": "%s: +1 Virus Point, %d in all (p.168)." % [name, had + 1]}


## ============================================================================
## STEP 12: WHAT THE MISSION DID TO EACH CALAMITY
## ============================================================================

## `result` is the normalized battle result. Its `calamity` dictionary carries the
## debrief's answers (anomaly_cleared, marked_lifeforms_killed, sleeper_chips,
## slyn_killed, controller_killed). {lines, ops}.
func after_mission(campaign: Resource, result: Dictionary) -> Dictionary:
	var out: Dictionary = {"lines": [], "ops": []}
	if campaign == null:
		return out
	var dice := EventResolverScript.new()
	var mission_id: String = str(result.get("mission_id", ""))
	var won: bool = bool(result.get("won", false))
	var k: String = str(result.get("sector", ""))
	var objectives: int = maxi(int(result.get("objectives_completed", 0)), 0)
	var answers: Variant = result.get("calamity", {})
	var debrief: Dictionary = answers if answers is Dictionary else {}
	var md: Dictionary = campaign.map_data if "map_data" in campaign else {}
	for cal in get_active_calamities(campaign):
		var p: Dictionary = _progress(cal)
		match str(cal.get("id", "")):
			"enemy_super_weapon":
				# p.165: "Once successful, you can then play out a Strike mission, with success
				# destroying the weapon production capability. This ends the Calamity."
				var builder: int = int(p.get("enemy_index", -1))
				var struck: int = int(result.get("tactical_enemy_index", -1))
				if mission_id == "strike" and won and (bool(result.get("weapon_site", false))
						or (builder >= 0 and struck == builder)):
					out.lines.append("The Strike destroys the super weapon's production (p.165).")
					_end(campaign, cal, dice, out)
			"environmental_risk":
				# p.166: "Once all three Objectives are clear, a character must ... roll
				# 1D6+Savvy, scoring a 6 or better ... clearing it."
				if mission_id == "patrol" and k != "" \
						and bool(MapScript.sector(md, k).get("anomaly", false)) \
						and objectives >= 3 and bool(debrief.get("anomaly_cleared", false)):
					MapScript.set_flag(campaign, k, "anomaly", false)
					out.lines.append("The anomaly over %s is cleared: +%d Raw Materials (p.166)."
							% [MapScript.label(k), ANOMALY_RAW_MATERIALS])
					out.ops.append({"op": "rm_gain", "amount": ANOMALY_RAW_MATERIALS})
					if MapScript.flagged(md, "anomaly").is_empty():
						_end(campaign, cal, dice, out)
			"mega_predators":
				# p.166: "You must kill 5 such Lifeforms to end the Calamity."
				var killed: int = maxi(int(debrief.get("marked_lifeforms_killed", 0)), 0)
				if mission_id == "patrol" and killed > 0:
					p["enhanced_killed"] = int(p.get("enhanced_killed", 0)) + killed
					out.lines.append("Mega predators: %d of the nest's Lifeforms killed, %d of %d "
							% [killed, int(p.enhanced_killed), MEGA_KILLS] + "(p.166).")
					if int(p.enhanced_killed) >= MEGA_KILLS:
						_end(campaign, cal, dice, out)
			"robot_rampage":
				# p.166: "Each time you kill a Sleeper outside of a Delve mission ... A test
				# result of 5+ finds a Sleeper chip." "Once you have located 5 Sleeper chips,
				# you can send out the shut-down signal when you return to your colony".
				var chips: int = maxi(int(debrief.get("sleeper_chips", 0)), 0)
				if mission_id != "delve" and chips > 0:
					p["chips_collected"] = int(p.get("chips_collected", 0)) + chips
					out.lines.append("Robot rampage: %d Sleeper chip(s) found, %d of %d (p.166)."
							% [chips, int(p.chips_collected), SLEEPER_CHIPS])
					if int(p.chips_collected) >= SLEEPER_CHIPS:
						_end(campaign, cal, dice, out)
			"slyn_assault":
				# p.167: "Keep track of the number of Slyn you kill. Once you have killed 30,
				# they decide to step down their offensive."
				var slain: int = maxi(int(debrief.get("slyn_killed", 0)), 0)
				if str(result.get("opposition_type", "")) == "slyn" and slain > 0:
					p["slyn_killed"] = int(p.get("slyn_killed", 0)) + slain
					out.lines.append("Slyn assault: %d Slyn killed, %d of %d (p.167)."
							% [slain, int(p.slyn_killed), SLYN_KILLS])
					if int(p.slyn_killed) >= SLYN_KILLS:
						_end(campaign, cal, dice, out)
			"swarm_infestation":
				# p.167: "This uses the Skirmish mission. Victory clears out the sector (for
				# now)." p.168: "The Calamity ends when every sector has been cleared."
				if mission_id == "skirmish" and won and k != "" \
						and bool(MapScript.sector(md, k).get("swarm", false)):
					MapScript.set_flag(campaign, k, "swarm", false)
					out.lines.append("The Swarm is cleared out of %s, for now (p.167)."
							% MapScript.label(k))
					if MapScript.flagged(md, "swarm").is_empty():
						_end(campaign, cal, dice, out)
			"virus":
				# p.168: "Each time you complete the mission you receive two points of Cure
				# Data."
				if mission_id == "hunt" and won:
					p["cure_data"] = int(p.get("cure_data", 0)) + CURE_DATA_PER_HUNT
					out.lines.append("The Hunt brings back +%d Cure Data, %d in all (p.168)."
							% [CURE_DATA_PER_HUNT, int(p.cure_data)])
			"wildlife_aggression":
				# p.168: "Killing the Controller and moving into base contact with where it
				# fell to confirm it is dead ends the Calamity."
				if mission_id == "hunt" and bool(debrief.get("controller_killed", false)):
					out.lines.append("The Controller is confirmed dead (p.168).")
					_end(campaign, cal, dice, out)
	return out


## ============================================================================
## THE END OF A CALAMITY, AND ITS REWARD
## ============================================================================

func _end(campaign: Resource, cal: Dictionary, dice, out: Dictionary) -> void:
	var id: String = str(cal.get("id", ""))
	var page: int = int(PAGES.get(id, 165))
	cal["resolved"] = true
	out.lines.append("Calamity ended: %s (p.%d)." % [str(cal.get("name", id)), page])
	match id:
		"enemy_super_weapon":
			# p.165: "As you loot the enemy site, you may roll twice on the Post-Mission
			# Finds table (see page 134)."
			for _i in range(2):
				out.ops.append({"op": "post_mission_find", "roll": dice.roll_d100(FIND_DIE)})
		"mega_predators":
			# p.166: "Randomly select three map sectors and increase their Resource ratings
			# by +1 each."
			out.lines.append_array(_raise_resources(campaign, MEGA_SECTORS))
		"robot_rampage":
			# p.166: "Add 4 Research Points as your scientists dissect the chips afterwards."
			out.ops.append({"op": "rp_gain", "amount": SLEEPER_CHIP_RP})
		"slyn_assault":
			# p.167: "You may immediately add 2 grunts to your Colony Tracking Sheet".
			out.ops.append({"op": "grunt_gain", "amount": SLYN_GRUNTS})
		"swarm_infestation":
			# p.168: "recruit one trooper to your roster if you have a vacancy. You may save
			# this for a later time."
			out.ops.append({"op": "recruit_bank", "amount": 1})
		"virus":
			# p.168: "reduce any injury recovery times ... by a total of 4 turns ... You can
			# save any of this effect for later."
			out.ops.append({"op": "recovery_bank", "amount": VIRUS_RECOVERY_TURNS})
		"wildlife_aggression":
			# p.168: "You may add 1 Augmentation Point."
			out.ops.append({"op": "augmentation_gain", "amount": 1})


## `count` distinct random sectors (never the colony's) gain +1 Resource. A sector not
## yet explored keeps the bonus until it is (PlanetfallMap.explore reads it).
func _raise_resources(campaign: Resource, count: int) -> Array:
	if not "map_data" in campaign or (campaign.map_data as Dictionary).is_empty():
		return []
	var md: Dictionary = campaign.map_data
	var hk: String = MapScript.home_key(md)
	var picked: Array = []
	var lines: Array = []
	for _i in range(count):
		var k: String = MapScript.random_sector_where(md, func(x: String) -> bool:
			return x != hk and not picked.has(x))
		if k == "":
			break
		picked.append(k)
		lines.append(MapScript.raise_resource(campaign, k, 1))
	return lines


## ============================================================================
## WHAT THE BATTLE AND THE PANEL SHOW
## ============================================================================

## The rules each active Calamity adds to this battle, for the battle screen's rows, in
## the Calamity's own data text (pp.165-168) and with its progress so far. A Calamity
## whose rules do not touch this mission adds nothing.
func battle_rows(campaign: Resource, mission_id: String, sector_key: String,
		opp_type: String) -> Array:
	var rows: Array = []
	if campaign == null:
		return rows
	var md: Dictionary = campaign.map_data if "map_data" in campaign else {}
	for cal in get_active_calamities(campaign):
		var id: String = str(cal.get("id", ""))
		var parts: Array = []
		match id:
			"environmental_risk":
				# p.166: "you must carry out a Patrol Mission in the sector".
				if mission_id == "patrol" and sector_key != "" \
						and bool(MapScript.sector(md, sector_key).get("anomaly", false)):
					parts.append(str(cal.get("resolution", "")))
			"mega_predators":
				# p.166: "Each time a Lifeform is revealed"; the nest is fought on Patrols.
				if opp_type == "lifeforms":
					parts.append(str(cal.get("ongoing_effect", "")))
				if mission_id == "patrol":
					parts.append(str(cal.get("resolution", "")))
			"wildlife_aggression":
				# p.168: "Any Contact reveal that places Lifeforms"; the Controller on a Hunt.
				if opp_type == "lifeforms":
					parts.append(str(cal.get("ongoing_effect", "")))
				if mission_id == "hunt":
					parts.append(str(cal.get("resolution", "")))
			"robot_rampage":
				# p.166: "In every mission you play"; chips only "outside of a Delve mission".
				parts.append(str(cal.get("setup", "")))
				parts.append(str(cal.get("ongoing_effect", "")))
				if mission_id != "delve":
					parts.append(str(cal.get("resolution", "")))
			"slyn_assault":
				if opp_type == "slyn":
					parts.append(str(cal.get("resolution", "")))
		parts = parts.filter(func(x: Variant) -> bool: return str(x) != "")
		if parts.is_empty():
			continue
		parts.append_array(progress_lines(campaign, cal))
		rows.append({"head": "%s (Planetfall p.%d)" % [str(cal.get("name", id)),
				int(PAGES.get(id, 165))], "detail": " ".join(parts)})
	return rows


## One Calamity's progress in words. Every number is this engine's own constant or
## record: the Calamity panel printed literals, and read progress keys nothing wrote.
func progress_lines(campaign: Resource, cal: Dictionary) -> Array:
	var p: Dictionary = _progress(cal)
	var md: Dictionary = campaign.map_data if campaign and "map_data" in campaign else {}
	match str(cal.get("id", "")):
		"enemy_super_weapon":
			var weapon: Array = ["Weapon progress: %d of %d." % [
					int(p.get("weapon_progress", 0)), WEAPON_LAUNCH]]
			var site: String = MapScript.weapon_site(campaign)
			var builder: int = int(p.get("enemy_index", -1))
			if site != "":
				weapon.append("No Tactical Enemy builds it: the site in %s is open to a Strike "
						% MapScript.label(site) + "(p.165).")
			elif builder >= 0:
				weapon.append("Built by %s: track down its Boss, then win the Strike (p.165)."
						% MapScript.enemy_name(campaign, builder))
			return weapon
		"environmental_risk":
			return [_sector_list("Anomalous sectors", MapScript.flagged(md, "anomaly"))]
		"swarm_infestation":
			return [_sector_list("Infested sectors", MapScript.flagged(md, "swarm"))]
		"virus":
			var virus: Array = ["Cure Data: %d. The cure is found on 2D6 at or below it "
					% int(p.get("cure_data", 0)) + "(p.168)."]
			var ill: Array = []
			for c in _roster(campaign):
				if campaign.has_method("is_quarantined") \
						and campaign.is_quarantined(str(c.get("id", ""))):
					ill.append(str(c.get("name", "?")))
			if not ill.is_empty():
				virus.append("Quarantined: %s." % ", ".join(ill))
			return virus
		"mega_predators":
			return ["Marked Lifeforms killed: %d of %d." % [int(p.get("enhanced_killed", 0)),
					MEGA_KILLS]]
		"robot_rampage":
			return ["Sleeper chips found: %d of %d." % [int(p.get("chips_collected", 0)),
					SLEEPER_CHIPS]]
		"slyn_assault":
			return ["Slyn killed: %d of %d." % [int(p.get("slyn_killed", 0)), SLYN_KILLS]]
		"wildlife_aggression":
			return ["The Controller is still at large (p.168)."]
	return []


## The p.168 Swarm profile, from the Calamity data.
func swarm_profile() -> Dictionary:
	for c in _calamities:
		if c is Dictionary and str(c.get("id", "")) == "swarm_infestation":
			var prof: Variant = c.get("enemy_profile", {})
			return (prof as Dictionary).duplicate(true) if prof is Dictionary else {}
	return {}


static func _sector_list(what: String, keys: Array) -> String:
	if keys.is_empty():
		return "%s: none." % what
	return "%s (%d): %s." % [what, keys.size(),
			", ".join(keys.map(func(k: Variant) -> String: return MapScript.label(str(k))))]


## ============================================================================
## PRIVATE
## ============================================================================

## p.165: where the weapon site is, a random sector that is not the colony's. It is used
## only while no Tactical Enemy builds the weapon (PlanetfallMap.weapon_site).
func _new_site(campaign: Resource) -> String:
	if not "map_data" in campaign or (campaign.map_data as Dictionary).is_empty():
		return ""
	var md: Dictionary = campaign.map_data
	var hk: String = MapScript.home_key(md)
	return MapScript.random_sector_where(md, func(x: String) -> bool: return x != hk)


static func _progress(cal: Dictionary) -> Dictionary:
	if not cal.get("progress") is Dictionary:
		cal["progress"] = {}
	return cal["progress"]


static func _roster(campaign: Resource) -> Array:
	var out: Array = []
	if campaign and "roster" in campaign:
		for c in campaign.roster:
			if c is Dictionary:
				out.append(c)
	return out


func _random_character(characters: Array, dice) -> Dictionary:
	if characters.is_empty():
		return {}
	return characters[dice.pick_index(characters.size(), PICK_DIE)]


func _pick_characters(characters: Array, count: int, dice) -> Array:
	var pool: Array = characters.duplicate()
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		out.append(pool.pop_at(dice.pick_index(pool.size(), VIRUS_PICK_DIE)))
	return out


## A random sector (never the colony's) that does not already carry `flag`; "" if none.
func _new_flagged_sector(campaign: Resource, flag: String) -> String:
	if not "map_data" in campaign:
		return ""
	var md: Dictionary = campaign.map_data
	if md.is_empty():
		return ""
	var hk: String = MapScript.home_key(md)
	var k: String = MapScript.random_sector_where(md, func(x: String) -> bool:
		return x != hk and not bool(MapScript.sector(md, x).get(flag, false)))
	if k != "":
		MapScript.set_flag(campaign, k, flag, true)
	return k


func _get_occurred_calamity_ids(campaign: Resource) -> Array:
	var ids: Array = []
	if campaign and "active_calamities" in campaign:
		for cal in campaign.active_calamities:
			if cal is Dictionary:
				ids.append(cal.get("id", ""))
	return ids


func _find_next_available(initial: Dictionary, occurred_ids: Array) -> Dictionary:
	var start_index: int = -1
	for i in range(_calamities.size()):
		if _calamities[i] is Dictionary and _calamities[i].get("id", "") == initial.get("id", ""):
			start_index = i
			break
	if start_index < 0:
		return {}
	for offset in range(1, _calamities.size()):
		var idx: int = (start_index + offset) % _calamities.size()
		var candidate: Variant = _calamities[idx]
		if candidate is Dictionary and candidate.get("id", "") not in occurred_ids:
			return candidate.duplicate()
	return {}


func _lookup_d100(table: Array, roll: int) -> Dictionary:
	for entry in table:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				return entry.duplicate()
	return {}


func is_loaded() -> bool:
	return _loaded
