class_name CompendiumSalvageJobs
extends RefCounted
## Salvage Jobs — Compendium pp.137-147
##
## Exploration-driven missions with Tension track, Contact markers, Points of
## Interest, and salvage collection. Crew explores a derelict ship, abandoned
## colony, or ruined facility looking for valuables while encountering hazards.
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.SALVAGE_JOBS.
##
## Integration notes (p.139):
##   - Enemy Deployment Variables (p.44) and Escalating Battles (p.46) CANNOT be used
##   - AI Variations (p.42) and Elite-level Enemies (p.48) CAN be used normally
##   - Normal Deployment Conditions and Notable Sights are NOT used
##   - Do NOT roll for a mission objective
##   - No roll to Seize the Initiative
##   - 3x3 ft recommended. On 2x2, reduce all movement by 1"


## ============================================================================
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.SALVAGE_JOBS)


## ============================================================================
## FINDING A SALVAGE JOB (Compendium p.139, D6)
## Requires a crew action in the campaign turn.
## ============================================================================

const SALVAGE_AVAILABILITY: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 1, "id": "no_job",
	 "instruction": "SALVAGE SEARCH: No job available this campaign turn."},
	{"roll_min": 2, "roll_max": 3, "id": "fee",
	 "instruction": "SALVAGE SEARCH: Job available, but requires 2 Credit non-refundable fee to accept."},
	{"roll_min": 4, "roll_max": 5, "id": "salvage_job",
	 "instruction": "SALVAGE SEARCH: Salvage job available! You can wait until after campaign actions before deciding."},
	{"roll_min": 6, "roll_max": 6, "id": "illegal_job",
	 "instruction": "SALVAGE SEARCH: Illegal salvage job available. After post-game Rivals roll, roll D6: 1-4 you got away with it; 5-6 authorities on trail (choose ONE: pay roll value in Credits, hand over all Salvage units, or add Enforcer Rival)."},
]


## ============================================================================
## TABLE SETUP (Compendium p.141)
## ============================================================================

const TABLE_SETUP_RULES: String = (
	"SALVAGE TABLE SETUP:\n" +
	"- Interior floor plans, ruined colony, wrecked site, or abandoned cave complex.\n" +
	"- Ensure exits toward each battlefield edge if using floor plans.\n" +
	"\n" +
	"SALVAGE MARKERS: Place 1D3+1 Salvage markers spread evenly.\n" +
	"- Any crew in contact picks up Salvage (1 unit). Set marker aside.\n" +
	"- Salvage does not need to be carried by specific character; cannot be lost.\n" +
	"\n" +
	"POINTS OF INTEREST: Place 1 marker close to center of each battlefield quarter (4 total).\n" +
	"- Must investigate all 4 to complete mission.\n" +
	"\n" +
	"DEPLOYMENT: Random edge. Split crew into 2 equal groups. Each placed:\n" +
	"- Within 2\" of edge\n" +
	"- At least 10\" between the two groups\n" +
	"- No roll to Seize the Initiative."
)


## ============================================================================
## TENSION TRACK (Compendium p.141)
## ============================================================================

const TENSION_RULES: String = (
	"TENSION TRACK:\n" +
	"- End of Round 1: Tension = ceil(crew_size / 2).\n" +
	"- Start of each round: Roll 1D6.\n" +
	"  - If roll ABOVE Tension: Tension +1.\n" +
	"  - If roll EQUAL or BELOW Tension: Tension reduced by the D6 value, " +
	"and a Contact is spawned.\n" +
	"\n" +
	"EXPLORATION ROUNDS:\n" +
	"- If no Contacts or enemies on board, it's an Exploration Round.\n" +
	"- No reaction roll. Crew moves in any order. Cannot Dash or use equipment."
)


## ============================================================================
## CONTACT MARKERS (Compendium pp.142-143)
## ============================================================================

const CONTACT_PLACEMENT_RULES: String = (
	"CONTACT SPAWNING:\n" +
	"- Randomly select crew member.\n" +
	"- Place Contact at closest point NOT within 6\" or LoS of any crew.\n" +
	"- If multiple locations tied, place closest to a Point of Interest.\n" +
	"\n" +
	"CONTACT REVEAL — when within 6\" and LoS, or within 3\" of crew:\n" +
	"Roll D6 on Contact table."
)

const CONTACT_RESULTS: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 1, "id": "nothing",
	 "instruction": "CONTACT: 'Beep, sir?' It was nothing. Remove marker."},
	{"roll_min": 2, "roll_max": 2, "id": "bad_feeling",
	 "instruction": "CONTACT: 'Are you reading it right?' Select crew member with bad feeling. Remove marker. Tension +1."},
	{"roll_min": 3, "roll_max": 5, "id": "hostiles",
	 "instruction": "CONTACT: 'Hostiles!' Encountered hostile forces. Roll on Hostiles! table if first contact."},
	{"roll_min": 6, "roll_max": 6, "id": "movement_everywhere",
	 "instruction": "CONTACT: 'We've got movement all over the place!' Scanner going haywire. Remove marker, spawn 2 new Contact markers near triggering crew member."},
]


## ============================================================================
## HOSTILES TABLE (Compendium pp.142-143, D100)
## Roll when encountering Hostiles for the first time.
## No Unique Individuals accompany salvage enemies.
## ============================================================================

const HOSTILES_TABLE: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 25, "id": "free_for_all",
	 "enemy_table": "criminal_elements",
	 "instruction": "HOSTILES: Free for All! Looters and renegades. Roll Criminal Elements table (core rules p.94). Enemies within one move of Salvage marker must move into contact, then remove BOTH marker and enemy."},
	{"roll_min": 26, "roll_max": 40, "id": "toughs",
	 "enemy_table": "hired_muscle",
	 "instruction": "HOSTILES: Toughs. Someone hired goons to guard the site. Roll Hired Muscle table (core rules p.96). Change Defensive or Cautious AI to Tactical."},
	{"roll_min": 41, "roll_max": 65, "id": "rival_team",
	 "enemy_table": "interested_parties",
	 "instruction": "HOSTILES: Rival Team. Another team is interested. Roll Interested Parties table (core rules p.99). Reduce Panic range by 1 (1-3→1-2, 1-2→1, 1→Fearless)."},
	{"roll_min": 66, "roll_max": 100, "id": "infestation",
	 "enemy_table": "roving_threats",
	 "instruction": "HOSTILES: Infestation! Worst type of job. Roll Roving Threats table (core rules p.101). Tension +6."},
]

## Enemy force sizing by encounter number (number of times Hostiles! rolled)
const ENEMY_FORCES_BY_ENCOUNTER: Array[Dictionary] = [
	{"encounter": 1, "basic": 2, "specialist": 0, "lieutenant": 0,
	 "instruction": "1st encounter: 2 basic enemies."},
	{"encounter": 2, "basic": 2, "specialist": 1, "lieutenant": 0,
	 "instruction": "2nd encounter: 2 basic enemies, 1 specialist."},
	{"encounter": 3, "basic": 2, "specialist": 0, "lieutenant": 1,
	 "instruction": "3rd encounter: 2 basic enemies, 1 lieutenant."},
	{"encounter": 4, "basic": 2, "specialist": 0, "lieutenant": 0,
	 "instruction": "4th+ encounter: 2 basic enemies."},
]

const ENEMY_PLACEMENT_RULES: String = (
	"ENEMY PLACEMENT:\n" +
	"- Place in Cover (if possible) on or within 1\" of the Contact marker.\n" +
	"- Newly placed enemies cannot act in the round they appear."
)


## ============================================================================
## CONTACT MARKER MOVEMENT — Enemy Actions Phase (Compendium pp.143-144)
## Contacts already on table move after all enemy forces acted.
## ============================================================================

const CONTACT_MOVEMENT_RULES: String = (
	"CONTACT MOVEMENT (Enemy Actions phase, after all enemies act):\n" +
	"- Roll 2D6 in separate colors (or sequentially).\n" +
	"  - Dark die = Aggression. If highest: marker moves that many inches toward nearest crew.\n" +
	"  - Light die = Chance. If highest: marker moves that many inches in random direction.\n" +
	"  - If dice equal: marker remains in place.\n" +
	"- Contacts move around terrain. Halt at battlefield edge.\n" +
	"- If moving marker would be detected (within 6\" LoS or 3\"), " +
	"resolve immediately. Enemies from that reveal cannot act this round."
)


## ============================================================================
## POINTS OF INTEREST (Compendium pp.144-147, D100)
## Investigated when crew within 3" and LoS. Remove marker after rolling.
## ============================================================================

const POI_REVEALS: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 5, "id": "obstacle",
	 "tension_adjust": -2,
	 "instruction": "POI: Obstacle. Acid, radiation, or collapsing ceilings. Hazardous area extends 2\" in every direction. All figures in area take Damage 0 hit (ignores Screens). Area remains dangerous for rest of battle. Enemies won't enter voluntarily. Tension -2."},
	{"roll_min": 6, "roll_max": 10, "id": "environmental_threat",
	 "tension_adjust": -1,
	 "instruction": "POI: Environmental Threat. Crew member rolls 1D6+Savvy. On 5+: prevented leak. Otherwise: crew member and all figures within 1D6\" take Damage 1 hit (ignores Screens). Danger does not remain. Tension -1."},
	{"roll_min": 11, "roll_max": 14, "id": "map_readouts",
	 "tension_adjust": -1,
	 "instruction": "POI: Map Readouts. Local map found. Randomly select a POI on table and move it 4\" in any direction. Tension -1."},
	{"roll_min": 15, "roll_max": 19, "id": "secure_device",
	 "tension_adjust": 0,
	 "instruction": "POI: Secure Device. Lockbox found. Place marker at POI location. Crew in contact: 1D6+Savvy (5+ opens it, grants Loot roll usable immediately). Each failed attempt: Tension +1."},
	{"roll_min": 20, "roll_max": 23, "id": "thick_air",
	 "tension_adjust": 3,
	 "instruction": "POI: The Air Is Thick In Here. You keep thinking you heard something. Tension +3."},
	{"roll_min": 24, "roll_max": 28, "id": "dead_spacer",
	 "tension_adjust": 1,
	 "instruction": "POI: Dead Spacer. Roll once on Loot table for useful kit. Can use immediately. Tension +1."},
	{"roll_min": 29, "roll_max": 32, "id": "we_need_to_hurry",
	 "tension_adjust": 0,
	 "instruction": "POI: We Need to Hurry. Best not to linger. Tension +1 for each remaining POI."},
	{"roll_min": 33, "roll_max": 36, "id": "dead_end",
	 "tension_adjust": -1,
	 "instruction": "POI: Dead End. Nothing here. Tension -1."},
	{"roll_min": 37, "roll_max": 41, "id": "information_station",
	 "tension_adjust": 0,
	 "instruction": "POI: Information Station. Computer/library/diary found. Mark location. Crew in contact: 1D6+Savvy test. Reduce Tension by the modified Savvy die roll."},
	{"roll_min": 42, "roll_max": 46, "id": "hot_find",
	 "tension_adjust": 0,
	 "instruction": "POI: Hot Find. Good salvage, but someone came through already. Receive 1D3 Salvage units. Tension +1 per Salvage unit just found."},
	{"roll_min": 47, "roll_max": 50, "id": "survivors",
	 "tension_adjust": 2,
	 "instruction": "POI: Survivors Discovered! Place 1D3 Hardened Colonists (core rules p.172). Fight alongside you. If at least 1 survives or exits, claim +1 Story Point. Tension +2."},
	{"roll_min": 51, "roll_max": 54, "id": "hornets_nest",
	 "tension_adjust": -2,
	 "instruction": "POI: Hornets' Nest. Scanner beeping like crazy. Place Contact marker near revealing crew member. Tension -2."},
	{"roll_min": 55, "roll_max": 59, "id": "lure",
	 "tension_adjust": -1,
	 "instruction": "POI: Lure? Dangerous but tempting. Place Contact randomly 6\" from crew. When crew contacts it: D6 — 1-3 place Contact markers equal to roll, 4-6 receive Salvage units equal to roll. Tension -1."},
	{"roll_min": 60, "roll_max": 64, "id": "all_clear",
	 "tension_adjust": -3,
	 "instruction": "POI: All Clear. Abandoned for some time. Tension -3."},
	{"roll_min": 65, "roll_max": 68, "id": "incursion",
	 "tension_adjust": -3,
	 "instruction": "POI: Incursion! The Converted are here. 6-figure Converted Acquisition team (core rules p.101: 4 basic, 1 specialist, 1 lieutenant) arrives from random edge at start of next round. Fights both sides. Can reveal Contacts same as you. Ignores POI. If already fighting Converted: these are reinforcements joining existing foes. Tension -3."},
	{"roll_min": 69, "roll_max": 74, "id": "cache",
	 "tension_adjust": 0,
	 "instruction": "POI: Cache. Small pile of interesting scrap. Receive 1D3 Salvage units. No Tension change."},
	{"roll_min": 75, "roll_max": 78, "id": "security_bot",
	 "tension_adjust": -2,
	 "instruction": "POI: Security Bot! Crew rolls 1D6+Savvy. 6+: shut down before activation. Natural 6: reprogram to fight on your side (AI controlled, can't keep after). Fail: place Mk II Security Bot (core rules p.107) — shoots both sides, moves first in Enemy Action phase. Tension -2."},
	{"roll_min": 79, "roll_max": 82, "id": "creature",
	 "tension_adjust": 0,
	 "instruction": "POI: Creature! Sand Runner (core rules p.107) hops out. Place on POI. Crew rolls 1D6+Savvy (5+ it likes you, fights on your side, Reaction 3. Bots/Soulless: -3 to roll. Swift: +1). Fail: hostile, attacks both sides. No Tension change."},
	{"roll_min": 83, "roll_max": 85, "id": "rival_trap",
	 "tension_adjust": 0,
	 "instruction": "POI: Rival Trap! It was all a set-up. Randomly select a Rival — 6 of them (4 basic, 1 specialist, 1 lieutenant) arrive from random edge at start of next round. Remove ALL enemy figures and Contact markers. Tension permanently set to 0. If NO Rivals: ignore event, Tension +3 instead."},
	{"roll_min": 86, "roll_max": 91, "id": "valuable_find",
	 "tension_adjust": 0,
	 "instruction": "POI: Valuable Find. Goods worth 1D3+1 Credits. No Tension change."},
	{"roll_min": 92, "roll_max": 96, "id": "interesting_find",
	 "tension_adjust": 0,
	 "instruction": "POI: Interesting Find. After mission, make a Loot roll. No Tension change."},
	{"roll_min": 97, "roll_max": 99, "id": "evac_time",
	 "tension_adjust": -10,
	 "instruction": "POI: Evac Time! Site unstable/collapsing. Danger area extends 1\" radius from POI. End of every future round: extends 1D6\" in every direction. All figures and Contact markers caught are casualties. POI caught are destroyed. Tension -10."},
	{"roll_min": 100, "roll_max": 100, "id": "doomsday_protocol",
	 "tension_adjust": -10,
	 "instruction": "POI: Doomsday Protocol! Nano-swarm doomsday device! Place Contact marker at POI location representing swarm. End of every round: moves 1D6\" toward nearest figure (crew, enemy, or Contact). If contact: target destroyed (crew become casualties) and another swarm spawns, moving immediately. Cannot be destroyed or blocked by any defensive device. Tension -10."},
]


## ============================================================================
## SALVAGE VALUE (post-mission)
## ============================================================================

const SALVAGE_VALUE_RULES: String = (
	"SALVAGE POST-MISSION (Compendium pp.146-148):\n" +
	"1. POI COMPLETION REWARD: For each POI investigated, roll 1D6:\n" +
	"   1-4: Nothing found.\n" +
	"   5: Gain 1 Salvage unit.\n" +
	"   6: Roll on Discovery D100 table.\n" +
	"2. DISCOVERY D100: 01-40 Roll on Loot table, 41-70 +1 Salvage unit,\n" +
	"   71-85 +1 Quest Rumor, 86-100 +1D3 Credits.\n" +
	"3. SCRAPPERS: Roll 3 times on the Loot table. Each item costs 1D6\n" +
	"   Salvage units (minimum 2). Pay Salvage to claim the item.\n" +
	"4. SALVAGE AS CURRENCY: 1 Salvage unit = 1 Credit toward ship repairs,\n" +
	"   ship modules, or bot upgrades ONLY (cannot be sold for cash).\n" +
	"5. Illegal job payoff check happens after normal Rival determination."
)

const DISCOVERY_TABLE: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 40, "result": "loot_roll", "description": "Roll on Loot table"},
	{"roll_min": 41, "roll_max": 70, "result": "salvage_1", "description": "+1 Salvage unit"},
	{"roll_min": 71, "roll_max": 85, "result": "quest_rumor", "description": "+1 Quest Rumor"},
	{"roll_min": 86, "roll_max": 100, "result": "credits_1d3", "description": "+1D3 Credits"},
]

const POI_REWARD_TABLE: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 4, "result": "nothing", "description": "Nothing found"},
	{"roll_min": 5, "roll_max": 5, "result": "salvage_1", "description": "Gain 1 Salvage unit"},
	{"roll_min": 6, "roll_max": 6, "result": "discovery_roll", "description": "Roll on Discovery D100 table"},
]


## ============================================================================
## QUERY METHODS
## ============================================================================

## Roll salvage job availability. Returns availability dict.
static func roll_salvage_availability() -> Dictionary:
	if not _is_enabled():
		return {}

	var roll := randi_range(1, 6)
	for avail in SALVAGE_AVAILABILITY:
		if roll >= avail.roll_min and roll <= avail.roll_max:
			var result: Dictionary = avail.duplicate()
			result["roll"] = roll
			return result
	return SALVAGE_AVAILABILITY[0]


## Roll contact result (D6 when contact revealed). Returns contact dict.
static func roll_contact_result() -> Dictionary:
	var roll := randi_range(1, 6)
	for contact in CONTACT_RESULTS:
		if roll >= contact.roll_min and roll <= contact.roll_max:
			var result: Dictionary = contact.duplicate()
			result["roll"] = roll
			return result
	return CONTACT_RESULTS[0]


## Roll hostiles type (D100, first encounter only). Returns hostiles dict.
static func roll_hostiles_type() -> Dictionary:
	var roll := randi_range(1, 100)
	for hostile in HOSTILES_TABLE:
		if roll >= hostile.roll_min and roll <= hostile.roll_max:
			var result: Dictionary = hostile.duplicate()
			result["roll"] = roll
			return result
	return HOSTILES_TABLE[0]


## Get enemy force composition for a given encounter number.
static func get_enemy_forces(encounter_number: int) -> Dictionary:
	if encounter_number <= 0:
		encounter_number = 1
	if encounter_number > ENEMY_FORCES_BY_ENCOUNTER.size():
		return ENEMY_FORCES_BY_ENCOUNTER[3] # 4th+ encounter
	return ENEMY_FORCES_BY_ENCOUNTER[encounter_number - 1]


## Roll Point of Interest reveal (D100). Returns POI dict.
static func roll_poi_reveal() -> Dictionary:
	var roll := randi_range(1, 100)
	for poi in POI_REVEALS:
		if roll >= poi.roll_min and roll <= poi.roll_max:
			var result: Dictionary = poi.duplicate()
			result["roll"] = roll
			return result
	return POI_REVEALS[0]


## Calculate initial Tension value for crew size.
static func get_initial_tension(crew_size: int) -> int:
	return ceili(crew_size / 2.0)


## Perform Tension roll. Returns {new_tension, contact_spawned, roll}.
static func roll_tension(current_tension: int) -> Dictionary:
	var roll := randi_range(1, 6)
	if roll > current_tension:
		return {"new_tension": current_tension + 1, "contact_spawned": false, "roll": roll,
			"instruction": "TENSION: Roll %d > Tension %d. Tension rises to %d." % [roll, current_tension, current_tension + 1]}
	else:
		var new_tension: int = maxi(current_tension - roll, 0)
		return {"new_tension": new_tension, "contact_spawned": true, "roll": roll,
			"instruction": "TENSION: Roll %d <= Tension %d. Contact spawned! Tension drops to %d." % [roll, current_tension, new_tension]}


## Get full salvage mission setup as instruction block.
static func generate_mission_setup() -> Dictionary:
	if not _is_enabled():
		return {}

	return {
		"table_setup": TABLE_SETUP_RULES,
		"tension_rules": TENSION_RULES,
		"contact_placement": CONTACT_PLACEMENT_RULES,
		"contact_movement": CONTACT_MOVEMENT_RULES,
		"enemy_placement": ENEMY_PLACEMENT_RULES,
		"salvage_value": SALVAGE_VALUE_RULES,
	}
