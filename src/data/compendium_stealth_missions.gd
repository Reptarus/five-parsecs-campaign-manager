class_name CompendiumStealthMissions
extends RefCounted
## Stealth Missions — Compendium pp.117-124
##
## Infiltration missions with stealth rounds, detection mechanics, and
## alarm-triggered transition to conventional combat. Crew tries to achieve
## an objective undetected; if spotted, reinforcements arrive each round.
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.STEALTH_MISSIONS.
##
## Integration notes (p.117):
##   - Enemy Deployment Variables (p.44) are NOT used
##   - Escalating Battles (p.46) do NOT apply during Stealth rounds or Round 1
##   - NOT compatible with Grid-based Movement or No-minis Combat Resolution
##   - Requires conventional miniatures rules on 3x3 ft table (halve distances for 2x2)


## ============================================================================
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.STEALTH_MISSIONS)


## ============================================================================
## STEALTH MISSION OBJECTIVES (Compendium p.120, D100)
## Unless target must be located, objective is placed at table center.
## ============================================================================

const STEALTH_OBJECTIVES: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 20, "id": "locate_and_retrieve",
	 "requires_finding": true, "has_item": true, "has_individual": false,
	 "instruction": "STEALTH OBJECTIVE: Locate and Retrieve. An item must be located using 'Finding the Target' rules. Once located, it must be picked up and exfiltrated off any table edge."},
	{"roll_min": 21, "roll_max": 35, "id": "deliver_item",
	 "requires_finding": false, "has_item": true, "has_individual": false,
	 "instruction": "STEALTH OBJECTIVE: Deliver Item. An item must be delivered to the objective (table center). Select which crew member carries it. Once delivered, crew can exfiltrate."},
	{"roll_min": 36, "roll_max": 50, "id": "locate_and_contact",
	 "requires_finding": true, "has_item": false, "has_individual": true,
	 "instruction": "STEALTH OBJECTIVE: Locate and Contact. An individual must be located using 'Finding the Target' rules. Once located, move within 3\" and Line of Sight, then exfiltrate."},
	{"roll_min": 51, "roll_max": 70, "id": "rescue_individual",
	 "requires_finding": false, "has_item": false, "has_individual": true,
	 "instruction": "STEALTH OBJECTIVE: Rescue Individual. Individual placed at table center. Reach within 3\" and LoS — they join your crew for the mission. Exfiltrate them. If individual wanders off table edge, they count as Rescued."},
	{"roll_min": 71, "roll_max": 85, "id": "transmit_message",
	 "requires_finding": false, "has_item": false, "has_individual": true,
	 "instruction": "STEALTH OBJECTIVE: Transmit Message. Individual placed at table center. Reach within 3\" and LoS to deliver message and get reply, then exfiltrate. If individual wanders off table, mission FAILS."},
	{"roll_min": 86, "roll_max": 100, "id": "retrieve_package",
	 "requires_finding": false, "has_item": true, "has_individual": false,
	 "instruction": "STEALTH OBJECTIVE: Retrieve Package. Item placed at table center. Pick it up and exfiltrate off any table edge."},
]


## ============================================================================
## INDIVIDUAL TYPES (Compendium p.121, D100)
## Profile: Reactions 1, Speed 4\", Combat +0, Toughness 4, Savvy +1.
## Moves base Speed in random direction at end of each Enemy Phase.
## Enemy ignores Individuals (strict orders / stealth equipment / psionic shielding).
## Third-party creatures (vent crawlers etc.) WILL attack Individuals.
## ============================================================================

const INDIVIDUAL_PROFILE: Dictionary = {
	"reactions": 1, "speed": 4, "combat_skill": 0, "toughness": 4, "savvy": 1,
}

const INDIVIDUAL_TYPES: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 15, "id": "criminal_kingpin", "name": "Criminal Kingpin"},
	{"roll_min": 16, "roll_max": 30, "id": "corporate_agent", "name": "Corporate Agent"},
	{"roll_min": 31, "roll_max": 45, "id": "notable_citizen", "name": "Notable Citizen"},
	{"roll_min": 46, "roll_max": 55, "id": "off_world_diplomat", "name": "Off-world Diplomat"},
	{"roll_min": 56, "roll_max": 70, "id": "leader_of_organization", "name": "Leader of Organization"},
	{"roll_min": 71, "roll_max": 80, "id": "local_govt_employee", "name": "Local Government Employee"},
	{"roll_min": 81, "roll_max": 90, "id": "wealthy_local", "name": "Wealthy Local"},
	{"roll_min": 91, "roll_max": 100, "id": "law_enforcement", "name": "Law Enforcement"},
]

const INDIVIDUAL_RULES: String = (
	"INDIVIDUAL BEHAVIOR:\n" +
	"- Moves base Speed (4\") in random direction at end of each Enemy Phase.\n" +
	"- Enemy ignores Individuals (strict orders / stealth equipment / psionic shielding).\n" +
	"- Third-party creatures (vent crawlers) WILL attack Individuals.\n" +
	"- Halt at dangerous terrain features or environmental hazards.\n" +
	"- Not armed. You can give them a weapon, but once armed, enemy treats them as normal target.\n" +
	"- If caught by Area weapon and surviving, they Dash to nearest terrain and hide for rest of game.\n" +
	"- RESCUE: If individual wanders off table edge, counts as Rescued.\n" +
	"- OTHER MISSIONS: If individual wanders off table, mission FAILS."
)


## ============================================================================
## FINDING THE TARGET (Compendium p.120)
## Used when objective says 'must be located'.
## ============================================================================

const FINDING_TARGET_RULES: String = (
	"FINDING THE TARGET:\n" +
	"1. Mark terrain features within 6\" of table center as candidates (min 3; add markers if needed).\n" +
	"2. When crew moves within 6\" and LoS of a candidate: roll 1D6+Savvy.\n" +
	"   - 6+: Target found. Place within/on feature at most distant point from discovering figure.\n" +
	"   - 5 or less: Feature does not contain target.\n" +
	"3. Last remaining candidate automatically contains the target."
)


## ============================================================================
## ITEM RULES (Compendium p.120)
## ============================================================================

const ITEM_RULES: String = (
	"ITEM RULES:\n" +
	"- Carrying does not hinder movement or fighting.\n" +
	"- Hand off during movement as free action by moving within 1\" of recipient.\n" +
	"- Can only be handed off once per battle round (no 'fire brigade' chains).\n" +
	"- If carrier becomes casualty, item drops at their location. Pick up by moving into contact.\n" +
	"- Enemies ignore items on ground. Unaffected by Area weapons.\n" +
	"- Item dropped in dangerous/hazardous terrain (acid pool etc.) is DESTROYED."
)


## ============================================================================
## DEPLOYMENT (Compendium p.122)
## ============================================================================

const DEPLOYMENT_RULES: String = (
	"STEALTH DEPLOYMENT:\n" +
	"- ENEMIES: Deploy evenly throughout table. For every 4 enemies, 1 on raised terrain " +
	"(rooftop, walkway, tower).\n" +
	"- CREW: Arrive from single randomly selected table edge in first battle round. " +
	"All arrive from same edge but pick individual arrival points as you move on.\n" +
	"- ENEMY COUNT: Campaign crew size + 1 (normally 7). Includes 1 Specialist + 1 Lieutenant. " +
	"Rest are basic troops.\n" +
	"- Roving Threats treated as Hired Muscle. Reroll Rampage AI enemies."
)


## ============================================================================
## STEALTH ROUND RULES (Compendium pp.122-123)
## ============================================================================

const STEALTH_ROUND_RULES: String = (
	"STEALTH ROUND (before alarm):\n" +
	"- Initiative dice rolled and assigned as normal.\n" +
	"- Movement rates (Dashing unavailable):\n" +
	"  Quick Actions Phase: Base move + 1\"\n" +
	"  Slow Actions Phase: Base move - 1\"\n" +
	"\n" +
	"ENEMY BEHAVIOR during stealth:\n" +
	"1. Randomly select 1 enemy: remains in place, scans 360°, then faces random direction.\n" +
	"2. All other enemies: move base-1\" in random direction, face movement direction.\n" +
	"   (They do NOT pan viewpoint when turning — only look in movement direction.)\n" +
	"3. Enemy that would move into wall/terrain/table edge: remains in place, scans 360°, " +
	"faces directly away from obstacle.\n" +
	"\n" +
	"FIELD OF VISION:\n" +
	"- Scanning enemy: 360° vision.\n" +
	"- Moving enemies: 90° in facing direction.\n" +
	"- While turning to move, enemies have NO active field of vision."
)


## ============================================================================
## DETECTION RULES (Compendium p.123)
## ============================================================================

const DETECTION_RULES: String = (
	"DETECTION:\n" +
	"Crew risks detection when:\n" +
	"- Any part of crew move is within LoS and Field of Vision of enemy.\n" +
	"- Crew is within LoS and FoV at end of enemy move.\n" +
	"- Crew is within LoS when enemy scans (scanning = every direction).\n" +
	"\n" +
	"SPOTTING ROLL: 2D6 for the enemy.\n" +
	"- Subtract 1 if enemy is scanning.\n" +
	"- Reduce by 2 if crew partially obscured by terrain (within or in contact).\n" +
	"- Reduce by 1 for each intervening terrain feature.\n" +
	"- The modified roll = spotting value for this round.\n" +
	"\n" +
	"For each crew at risk, measure distance (round fractions DOWN to whole inch):\n" +
	"- Spotting value EXCEEDS distance → SPOTTED. Alarm raised immediately.\n" +
	"- Spotting value EQUALS distance (none spotted) → SUSPICIOUS. Enemy moves 1\" toward " +
	"crew, faces them, rolls again (not scanning). Can repeat multiple times.\n" +
	"- Spotting value BELOW distance → Not spotted."
)


## ============================================================================
## TOOLS AND TRICKS (Compendium p.123)
## Each requires crew member to remain stationary.
## ============================================================================

const STEALTH_TOOLS: Array[Dictionary] = [
	{"id": "stay_down", "name": "Stay Down",
	 "instruction": "STAY DOWN: Character remains stationary. Until next activation, all spotting rolls reduced by character's Savvy bonus (must be at least partially obscured by terrain)."},
	{"id": "distraction", "name": "Distraction",
	 "instruction": "DISTRACTION: Select enemy within 6\". Roll 1D6+Savvy. On 6+: enemy turns chosen direction immediately; next activation remains in place looking that way (no other actions). Natural 1: enemy turns to face you and makes spotting roll."},
	{"id": "lure", "name": "Lure",
	 "instruction": "LURE: Every enemy within 8\" immediately moves 1D6\" toward crew member's location, then makes a spotting check. Each enemy moves individually; single spotting roll applies to all."},
]


## ============================================================================
## ATTACKING IN STEALTH (Compendium p.124)
## ============================================================================

const STEALTH_ATTACK_RULES: String = (
	"ATTACKING IN STEALTH:\n" +
	"- Crew attacking from OUTSIDE enemy FoV gets +2 to shooting or Brawling roll.\n" +
	"- Alarm is set off if:\n" +
	"  - A weapon other than handgun or needle rifle is fired.\n" +
	"  - Target of shot or Brawl is NOT knocked out.\n" +
	"  - A ripper sword is used in Brawling combat."
)


## ============================================================================
## ALARM RULES (Compendium p.124)
## ============================================================================

const ALARM_RULES: String = (
	"ALARM!\n" +
	"- Current Stealth round ends immediately. Begin new normal battle round.\n" +
	"- If alarm raised mid-round, end Stealth round without completing remaining actions.\n" +
	"- Randomly select table edge for enemy reinforcements.\n" +
	"\n" +
	"REINFORCEMENTS:\n" +
	"- Beginning of each battle round: roll 2D6.\n" +
	"- Each die showing 6 → 1 basic enemy arrives at center of enemy edge.\n" +
	"- Arriving enemies placed immediately but cannot act in arrival round."
)


## ============================================================================
## PSIONICS AND STEALTH (Compendium p.124)
## ============================================================================

const PSIONIC_RULES: String = (
	"PSIONICS IN STEALTH:\n" +
	"- Grab, Shock, Psionic Scare targeting enemy: sets off alarm UNLESS target removed from play.\n" +
	"- Predict: Roll twice for enemy spotting roll.\n" +
	"- Shroud: Counts as terrain feature (-2 to spotting), but does NOT block LoS."
)


## ============================================================================
## EXFILTRATION (Compendium p.119)
## ============================================================================

const EXFILTRATION_RULES: String = (
	"EXFILTRATION:\n" +
	"- Once objective achieved, crew must leave battlefield via any table edge.\n" +
	"- When rolling initiative each turn, you may select a single crew member assigned a 6 " +
	"and remove them from play — they have exfiltrated successfully.\n" +
	"- This can be used BEFORE objective is completed.\n" +
	"- Exfiltrated crew cannot return to the battlefield."
)


## ============================================================================
## MISSION SELECTION (Compendium p.118)
## Determines whether a mission is Conventional, Stealth, Street Fight, or Salvage.
## ============================================================================

const MISSION_TYPE_SELECTION: Dictionary = {
	"rival": {"conventional": [1, 6], "stealth": [], "street_fight": [], "salvage": [],
	 "instruction": "RIVAL MISSION: Always a Conventional battle."},
	"invasion": {"conventional": [1, 6], "stealth": [], "street_fight": [], "salvage": [],
	 "instruction": "INVASION BATTLE: Always a Conventional battle."},
	"opportunity": {"conventional": [1, 4], "stealth": [5, 5], "street_fight": [6, 6], "salvage": [],
	 "instruction": "OPPORTUNITY MISSION: Roll D6. 1-4 Conventional, 5 Stealth, 6 Street Fight."},
	"patron": {"conventional": [1, 2], "stealth": [3, 4], "street_fight": [5, 6], "salvage": [],
	 "instruction": "PATRON MISSION: Roll D6. 1-2 Conventional, 3-4 Stealth, 5-6 Street Fight."},
	"faction": {"conventional": [1, 1], "stealth": [2, 4], "street_fight": [5, 6], "salvage": [],
	 "instruction": "FACTION MISSION: Roll D6. 1 Conventional (as Patron), 2-4 Stealth, 5-6 Street Fight."},
	"quest": {"conventional": [1, 3], "stealth": [4, 4], "street_fight": [5, 5], "salvage": [6, 6],
	 "instruction": "QUEST MISSION: Roll D6. 1-3 Conventional, 4 Stealth, 5 Street Fight, 6 Salvage (or Stealth if no Freelancer's Handbook)."},
}


## ============================================================================
## QUERY METHODS
## ============================================================================

## Roll a stealth mission objective. Returns objective dict.
static func roll_objective() -> Dictionary:
	if not _is_enabled():
		return {}

	var roll := randi_range(1, 100)
	for obj in STEALTH_OBJECTIVES:
		if roll >= obj.roll_min and roll <= obj.roll_max:
			var result: Dictionary = obj.duplicate()
			result["roll"] = roll
			return result

	return STEALTH_OBJECTIVES[0]


## Roll the type of individual for objective. Returns {id, name}.
static func roll_individual_type() -> Dictionary:
	var roll := randi_range(1, 100)
	for ind in INDIVIDUAL_TYPES:
		if roll >= ind.roll_min and roll <= ind.roll_max:
			var result: Dictionary = ind.duplicate()
			result["roll"] = roll
			result["profile"] = INDIVIDUAL_PROFILE
			return result

	return INDIVIDUAL_TYPES[0]


## Determine battle type for a given mission source. Returns battle type string.
## mission_source: "rival", "invasion", "opportunity", "patron", "faction", "quest"
## Returns: "conventional", "stealth", "street_fight", or "salvage"
static func roll_battle_type(mission_source: String) -> String:
	var source_key := mission_source.to_lower()
	if not MISSION_TYPE_SELECTION.has(source_key):
		return "conventional"

	var table: Dictionary = MISSION_TYPE_SELECTION[source_key]
	var roll := randi_range(1, 6)

	if table.stealth.size() == 2 and roll >= table.stealth[0] and roll <= table.stealth[1]:
		return "stealth"
	if table.street_fight.size() == 2 and roll >= table.street_fight[0] and roll <= table.street_fight[1]:
		return "street_fight"
	if table.salvage.size() == 2 and roll >= table.salvage[0] and roll <= table.salvage[1]:
		# Salvage requires Freelancer's Handbook
		var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
		if dlc_mgr and dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.SALVAGE_JOBS):
			return "salvage"
		return "stealth" # Fallback per book rule
	return "conventional"


## Get full stealth mission setup as a single instruction block.
static func generate_mission_setup() -> Dictionary:
	if not _is_enabled():
		return {}

	var objective := roll_objective()
	var setup: Dictionary = {
		"objective": objective,
		"deployment": DEPLOYMENT_RULES,
		"stealth_rounds": STEALTH_ROUND_RULES,
		"detection": DETECTION_RULES,
		"tools": STEALTH_TOOLS,
		"attack_rules": STEALTH_ATTACK_RULES,
		"alarm": ALARM_RULES,
		"exfiltration": EXFILTRATION_RULES,
		"item_rules": ITEM_RULES,
		"psionic_rules": PSIONIC_RULES,
	}

	if objective.get("has_individual", false):
		setup["individual"] = roll_individual_type()
		setup["individual_rules"] = INDIVIDUAL_RULES

	if objective.get("requires_finding", false):
		setup["finding_target"] = FINDING_TARGET_RULES

	return setup


## Get mission type selection instruction for a given source.
static func get_mission_type_instruction(mission_source: String) -> String:
	var source_key := mission_source.to_lower()
	if MISSION_TYPE_SELECTION.has(source_key):
		return MISSION_TYPE_SELECTION[source_key].instruction
	return "MISSION TYPE: Conventional battle (default)."
