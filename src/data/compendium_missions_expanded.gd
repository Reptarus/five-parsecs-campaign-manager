class_name CompendiumMissionsExpanded
extends RefCounted
## Expanded Missions, Quests, Connections + PvP/Co-op + Introductory Campaign
##
## Data-driven compendium additions for mission variety, quest progression,
## connection benefits, introductory campaign, PvP, and co-op play.
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
##
## Features:
##   EXPANDED_MISSIONS    - Additional objectives, deployment conditions, notable sights
##   EXPANDED_QUESTS      - Quest progression tables, more quest types
##   EXPANDED_CONNECTIONS - Enhanced opportunity mission connections
##   PVP_BATTLES          - Two-player opposed battles
##   COOP_BATTLES         - Two-player cooperative battles
##   INTRODUCTORY_CAMPAIGN - 5-mission guided campaign for new players
##   PRISON_PLANET_CHARACTER - Ex-prisoner starting option


## ============================================================================
## DLC GATING HELPER
## ============================================================================

static func _get_dlc_manager() -> Node:
	if not Engine.get_main_loop():
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


static func _is_flag_enabled(flag_name: String) -> bool:
	var dlc_mgr := _get_dlc_manager()
	if not dlc_mgr:
		return false
	var flag_value: int = dlc_mgr.ContentFlag.get(flag_name, -1)
	if flag_value < 0:
		return false
	return dlc_mgr.is_feature_enabled(flag_value)


## ============================================================================
## EXPANDED MISSION OBJECTIVES (D100, replaces/extends core table)
## ============================================================================

const EXPANDED_OBJECTIVES: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 8, "id": "patrol_and_secure",
	 "instruction": "OBJECTIVE: Patrol and Secure. Place 4 waypoint markers. Crew must move within 3\" of each. All visited = victory."},
	{"roll_min": 9, "roll_max": 16, "id": "data_extraction",
	 "instruction": "OBJECTIVE: Data Extraction. Place terminal marker in center. Crew member spends 2 actions to download. Must extract off-board."},
	{"roll_min": 17, "roll_max": 24, "id": "sabotage",
	 "instruction": "OBJECTIVE: Sabotage. Place 2 objective markers in enemy half. Crew spends 1 action at each to plant charges. Both planted = victory."},
	{"roll_min": 25, "roll_max": 32, "id": "vip_extraction",
	 "instruction": "OBJECTIVE: VIP Extraction. Place VIP in center. Crew must reach VIP (1 action) then escort to table edge. VIP: Speed 4\", Toughness 3."},
	{"roll_min": 33, "roll_max": 40, "id": "supply_raid",
	 "instruction": "OBJECTIVE: Supply Raid. 3 supply crates in enemy zone. Crew picks up (1 action) and carries to own edge. Each crate = +2 credits."},
	{"roll_min": 41, "roll_max": 48, "id": "ambush_defense",
	 "instruction": "OBJECTIVE: Ambush Defense. Crew deploys center. Enemies enter from 2 edges. Survive 6 rounds or eliminate all enemies."},
	{"roll_min": 49, "roll_max": 56, "id": "recon_mission",
	 "instruction": "OBJECTIVE: Recon Mission. 3 scan points placed by opponent. Move within 6\" with LoS to scan (1 action). All 3 scanned = victory."},
	{"roll_min": 57, "roll_max": 64, "id": "demolition",
	 "instruction": "OBJECTIVE: Demolition. Place structure in center. Crew must deal 15 damage to structure (Toughness 6, no save). Structure destroyed = victory."},
	{"roll_min": 65, "roll_max": 72, "id": "rescue_hostages",
	 "instruction": "OBJECTIVE: Rescue Hostages. 2 hostage markers in enemy zone. Reach hostage (1 action to free), escort to edge. Each rescued = +3 credits."},
	{"roll_min": 73, "roll_max": 80, "id": "hold_the_line",
	 "instruction": "OBJECTIVE: Hold the Line. Mark defensive zone (6\" square). At least 2 crew in zone at end of Round 6 = victory."},
	{"roll_min": 81, "roll_max": 88, "id": "bounty_hunt",
	 "instruction": "OBJECTIVE: Bounty Hunt. Target is enemy leader (+2 Combat, +1 Toughness). Defeat target = victory + 5 credits. Target flees at Round 5 if unwounded."},
	{"roll_min": 89, "roll_max": 94, "id": "artifact_recovery",
	 "instruction": "OBJECTIVE: Artifact Recovery. Place 3 dig sites. Crew digs (2 actions, D6: 5-6 = artifact found). Find and extract artifact = victory."},
	{"roll_min": 95, "roll_max": 100, "id": "last_stand",
	 "instruction": "OBJECTIVE: Last Stand. +50% enemies. No reinforcements. Survive 8 rounds = victory. Each surviving crew member = +1 XP bonus."},
]


## ============================================================================
## EXPANDED DEPLOYMENT CONDITIONS (D6)
## ============================================================================

const EXPANDED_DEPLOYMENT: Array[Dictionary] = [
	{"roll": 1, "id": "night_ops",
	 "instruction": "DEPLOYMENT: Night Operations. Max visibility 12\". Weapons over 12\" range fire at -1. Stealth bonus: -1 to enemy spotting."},
	{"roll": 2, "id": "hazardous_terrain",
	 "instruction": "DEPLOYMENT: Hazardous Terrain. D3 hazard zones (4\" radius). Entering = D6: 1-2 = D6 damage. Enemies also affected."},
	{"roll": 3, "id": "elevated_positions",
	 "instruction": "DEPLOYMENT: Elevated Positions. Both sides may deploy on structures. +1 to hit from elevation. Falling = D6 damage."},
	{"roll": 4, "id": "flanking_approach",
	 "instruction": "DEPLOYMENT: Flanking Approach. Split crew into 2 groups. Group A deploys normally. Group B enters from side edge on Round 2."},
	{"roll": 5, "id": "scattered_start",
	 "instruction": "DEPLOYMENT: Scattered Start. Each crew member deploys randomly: D6 for X, D6 for Y (in inches from corner). May be separated."},
	{"roll": 6, "id": "reinforced_enemy",
	 "instruction": "DEPLOYMENT: Reinforced Enemy. +2 basic enemies. They deploy in reserve, arriving at random edge Round 3."},
]


## ============================================================================
## EXPANDED NOTABLE SIGHTS (D6)
## ============================================================================

const EXPANDED_NOTABLE_SIGHTS: Array[Dictionary] = [
	{"roll": 1, "id": "crashed_shuttle",
	 "instruction": "NOTABLE SIGHT: Crashed Shuttle. Place wreck marker. Search (2 actions): D6 1-3=nothing, 4-5=D6 credits, 6=rare item (roll loot table)."},
	{"roll": 2, "id": "ancient_console",
	 "instruction": "NOTABLE SIGHT: Ancient Console. Place marker. Savvy test (D6+Savvy, 7+): Success = Quest Rumor. Fail = +1 enemy reinforcement."},
	{"roll": 3, "id": "hidden_cache",
	 "instruction": "NOTABLE SIGHT: Hidden Cache. Place marker behind terrain. Search (1 action, must be in cover): D6 3+ = 2D6 credits."},
	{"roll": 4, "id": "wounded_stranger",
	 "instruction": "NOTABLE SIGHT: Wounded Stranger. Heal (1 action, medical supply): Gain temporary ally (+0 Combat, Toughness 3) or +1 Patron lead."},
	{"roll": 5, "id": "comm_relay",
	 "instruction": "NOTABLE SIGHT: Comm Relay. Activate (1 action): Choose one - call in support (D3 militia arrive Round 4) OR intercept intel (+1 Quest Rumor)."},
	{"roll": 6, "id": "unstable_structure",
	 "instruction": "NOTABLE SIGHT: Unstable Structure. D6 at start of each round: 1 = collapse! All within 4\" take D6 damage. After collapse: clear terrain."},
]


## ============================================================================
## EXPANDED QUEST PROGRESSION (D6 when quest advances)
## ============================================================================

const QUEST_PROGRESSION: Array[Dictionary] = [
	{"roll": 1, "id": "dead_end",
	 "instruction": "QUEST: Dead End. No progress this turn. Must spend 1 crew action next turn to find new lead."},
	{"roll": 2, "id": "minor_clue",
	 "instruction": "QUEST: Minor Clue. +1 quest progress. Gain vague hint about next step."},
	{"roll": 3, "id": "significant_lead",
	 "instruction": "QUEST: Significant Lead. +2 quest progress. Next quest battle: +1 notable sight."},
	{"roll": 4, "id": "ally_contact",
	 "instruction": "QUEST: Ally Contact. +1 quest progress. Gain temporary ally for next quest battle (+1 Combat, Toughness 4)."},
	{"roll": 5, "id": "rival_interference",
	 "instruction": "QUEST: Rival Interference! +1 quest progress but add 1 Rival who also seeks the quest goal."},
	{"roll": 6, "id": "breakthrough",
	 "instruction": "QUEST: Breakthrough! +3 quest progress. May immediately attempt quest resolution if progress >= target."},
]


## ============================================================================
## EXPANDED CONNECTIONS (opportunity mission benefits)
## ============================================================================

const EXPANDED_CONNECTIONS: Array[Dictionary] = [
	{"id": "smuggler_network", "name": "Smuggler Network",
	 "instruction": "CONNECTION: Smuggler Network. Can buy contraband items (weapons +1 damage mod, 3x price). Travel to adjacent world costs 1 cr less."},
	{"id": "medical_contact", "name": "Medical Contact",
	 "instruction": "CONNECTION: Medical Contact. Injury recovery -1 turn (min 1). Once per campaign: free surgery (remove permanent injury)."},
	{"id": "info_broker", "name": "Information Broker",
	 "instruction": "CONNECTION: Information Broker. +1 to Patron search rolls. Once per 3 turns: reveal enemy composition before battle."},
	{"id": "mechanic_guild", "name": "Mechanic Guild",
	 "instruction": "CONNECTION: Mechanic Guild. Ship repairs cost 50% less. Once per campaign: free hull point repair."},
	{"id": "bounty_board", "name": "Bounty Board Access",
	 "instruction": "CONNECTION: Bounty Board. After winning battle: D6 5-6 = bounty on defeated leader (+3 credits). Stacks with normal rewards."},
	{"id": "safe_house", "name": "Safe House",
	 "instruction": "CONNECTION: Safe House. When fleeing from battle: crew that fled are safe (no casualty roll). Cannot be used 2 turns in a row."},
]


## ============================================================================
## PVP BATTLES (Freelancer's Handbook)
## ============================================================================

const PVP_RULES: Dictionary = {
	"initiative_points": {
		"instruction": "PVP INITIATIVE: Each player rolls 1D6 + crew Savvy (highest). Winner gets Initiative Points = difference (min 1). Spend 1 IP to activate 1 figure.",
	},
	"power_rating": {
		"instruction": "PVP BALANCE: Calculate Power Rating per crew.\n  Base: 1 per crew member\n  +1 per Combat Skill above 0\n  +1 per Toughness above 3\n  +1 per heavy weapon\n  +0.5 per piece of armor\n  Lower-rated crew gets bonus: +1 basic ally per 3 point difference.",
	},
	"objectives": [
		{"id": "pvp_control", "instruction": "PVP OBJECTIVE: Control. 3 objective markers. Hold (within 3\", no enemies within 3\") at end of Round 6. Most held = winner."},
		{"id": "pvp_elimination", "instruction": "PVP OBJECTIVE: Elimination. Remove all enemy crew from play. Routed crew (3+ casualties) must pass Morale check or flee."},
		{"id": "pvp_heist", "instruction": "PVP OBJECTIVE: Heist. Loot marker in center. Pick up (1 action), carry to own edge. Carrier moves -2\". If carrier hit, drop loot."},
		{"id": "pvp_king_of_hill", "instruction": "PVP OBJECTIVE: King of the Hill. Central zone (6\" radius). Score 1 VP per figure in zone at end of each round. First to 10 VP wins."},
	],
	"setup": "PVP SETUP:\n  1. Each player selects crew (max 8 figures)\n  2. Calculate Power Rating for balance\n  3. Roll for deployment sides\n  4. Alternate placing terrain (6-10 pieces)\n  5. Roll D6 for objective type\n  6. Deploy within 6\" of own edge\n  7. Roll Initiative Points each round",
}


## ============================================================================
## CO-OP BATTLES (Freelancer's Handbook)
## ============================================================================

const COOP_RULES: Dictionary = {
	"scaling": {
		"instruction": "CO-OP SCALING: Double base enemy count. +1 Specialist per crew. +1 Lieutenant if combined crew > 8. All enemies get +1 Toughness.",
	},
	"shared_objectives": {
		"instruction": "CO-OP OBJECTIVES: Both crews share objective. Only ONE crew needs to complete (e.g., reach extraction). Other crew provides support.",
	},
	"coordination": {
		"instruction": "CO-OP COORDINATION:\n  - Players alternate activating 1 figure each\n  - Adjacent friendly figures from different crews: +1 to hit (coordinated fire)\n  - One crew can spend 1 action to provide covering fire: -1 to enemy hits vs other crew this round",
	},
	"rewards": {
		"instruction": "CO-OP REWARDS:\n  - Credits split evenly (round up for primary crew)\n  - XP: each crew gets own XP (no splitting)\n  - Loot: alternate picks from loot table\n  - Quest progress: both crews advance if applicable",
	},
	"setup": "CO-OP SETUP:\n  1. Each player brings their crew (max 6 each)\n  2. Combined crew deploys on same edge (or 2 adjacent edges)\n  3. Generate enemies with co-op scaling\n  4. Roll for shared objective\n  5. Alternate activations between players\n  6. Both crews must extract to fully succeed",
}


## ============================================================================
## INTRODUCTORY CAMPAIGN (5 missions, Fixer's Guidebook)
## ============================================================================

const INTRODUCTORY_MISSIONS: Array[Dictionary] = [
	{
		"mission": 1,
		"title": "First Steps",
		"instruction": "INTRODUCTORY MISSION 1: First Steps\n\n" +
			"[b]Setup:[/b] 4 basic enemies, no specialists. Open terrain with light cover.\n" +
			"[b]Objective:[/b] Eliminate all enemies.\n" +
			"[b]Special Rules:[/b]\n" +
			"  - Crew gets +1 to all hit rolls (training bonus)\n" +
			"  - No injury rolls this battle (knocked out = miss next mission only)\n" +
			"  - Enemies do not use cover effectively\n" +
			"[b]Rewards:[/b] 3 credits, 1 XP per crew member\n" +
			"[b]Tutorial:[/b] Practice basic movement, shooting, and brawling.",
	},
	{
		"mission": 2,
		"title": "Market Day",
		"instruction": "INTRODUCTORY MISSION 2: Market Day\n\n" +
			"[b]Setup:[/b] 5 basic enemies + 1 specialist. Urban terrain.\n" +
			"[b]Objective:[/b] Retrieve package from center of map, extract to edge.\n" +
			"[b]Special Rules:[/b]\n" +
			"  - Crew training bonus reduced to +0 (normal rolls)\n" +
			"  - Standard injury rules apply\n" +
			"  - 1 Notable Sight placed on map\n" +
			"[b]Rewards:[/b] 5 credits, standard XP\n" +
			"[b]Tutorial:[/b] Practice objectives, item interaction, Notable Sights.",
	},
	{
		"mission": 3,
		"title": "Trouble Brewing",
		"instruction": "INTRODUCTORY MISSION 3: Trouble Brewing\n\n" +
			"[b]Setup:[/b] 6 basic enemies + 1 specialist + 1 lieutenant. Mixed terrain.\n" +
			"[b]Objective:[/b] Hold position (6\" zone) for 4 rounds.\n" +
			"[b]Special Rules:[/b]\n" +
			"  - D6 at Round 3: 4+ = D3 reinforcements from random edge\n" +
			"  - First Rival encounter possible (D6: 6 = gain 1 Rival)\n" +
			"[b]Rewards:[/b] 6 credits, standard XP, roll on loot table\n" +
			"[b]Tutorial:[/b] Practice defensive play, reinforcement handling.",
	},
	{
		"mission": 4,
		"title": "A Friend in Need",
		"instruction": "INTRODUCTORY MISSION 4: A Friend in Need\n\n" +
			"[b]Setup:[/b] 7 enemies (standard composition). Complex terrain.\n" +
			"[b]Objective:[/b] Rescue NPC from enemy zone, extract both NPC and crew.\n" +
			"[b]Special Rules:[/b]\n" +
			"  - Full campaign rules apply\n" +
			"  - NPC: Speed 4\", Toughness 3, unarmed\n" +
			"  - Success: NPC becomes Patron (guaranteed)\n" +
			"[b]Rewards:[/b] 7 credits, standard XP, 1 Patron\n" +
			"[b]Tutorial:[/b] Practice escort mechanics, patron system.",
	},
	{
		"mission": 5,
		"title": "Making a Name",
		"instruction": "INTRODUCTORY MISSION 5: Making a Name\n\n" +
			"[b]Setup:[/b] Standard enemy generation (full rules). Full terrain setup.\n" +
			"[b]Objective:[/b] Standard objective roll (full rules).\n" +
			"[b]Special Rules:[/b]\n" +
			"  - All campaign rules apply (no training wheels)\n" +
			"  - Quest Rumor guaranteed if not already obtained\n" +
			"  - After this mission: full campaign begins\n" +
			"[b]Rewards:[/b] Standard + 2 bonus credits for completing intro campaign\n" +
			"[b]Tutorial:[/b] Full rules confirmation. Campaign ready!",
	},
]


## ============================================================================
## PRISON PLANET CHARACTER (Fixer's Guidebook)
## ============================================================================

const PRISON_PLANET_OPTIONS: Dictionary = {
	"id": "prison_planet",
	"name": "Prison Planet Veteran",
	"dlc_flag": "PRISON_PLANET_CHARACTER",
	"instruction": "PRISON PLANET CHARACTER:\n" +
		"  One crew member may be an ex-prisoner.\n" +
		"  - KEEP: All stats (Combat, Toughness, Speed, Savvy, Reactions, Luck)\n" +
		"  - LOSE: ALL equipment and Implants (stripped on arrival)\n" +
		"  - GAIN: +3 Enforcer Rivals\n" +
		"  - GAIN: +1 Story Point\n" +
		"  - GAIN: +3 XP (survival bonus)\n" +
		"  NOTE: Cannot be a Bot or Soulless (organic beings only).",
	"effects": {
		"keep_stats": true,
		"lose_equipment": true,
		"lose_implants": true,
		"enforcer_rivals": 3,
		"story_points": 1,
		"bonus_xp": 3,
		"excluded_origins": ["BOT", "SOULLESS"],
	},
}


## ============================================================================
## QUERY METHODS
## ============================================================================

## Roll an expanded mission objective. Returns empty if DLC disabled.
static func roll_expanded_objective() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_MISSIONS"):
		return {}
	var roll := randi_range(1, 100)
	for obj in EXPANDED_OBJECTIVES:
		if roll >= obj.roll_min and roll <= obj.roll_max:
			return obj
	return EXPANDED_OBJECTIVES[0]


## Roll expanded deployment condition. Returns empty if DLC disabled.
static func roll_expanded_deployment() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_MISSIONS"):
		return {}
	var roll := randi_range(1, 6)
	for dep in EXPANDED_DEPLOYMENT:
		if dep.roll == roll:
			return dep
	return EXPANDED_DEPLOYMENT[0]


## Roll expanded notable sight. Returns empty if DLC disabled.
static func roll_expanded_notable_sight() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_MISSIONS"):
		return {}
	var roll := randi_range(1, 6)
	for sight in EXPANDED_NOTABLE_SIGHTS:
		if sight.roll == roll:
			return sight
	return EXPANDED_NOTABLE_SIGHTS[0]


## Roll quest progression. Returns empty if DLC disabled.
static func roll_quest_progression() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_QUESTS"):
		return {}
	var roll := randi_range(1, 6)
	for step in QUEST_PROGRESSION:
		if step.roll == roll:
			return step
	return QUEST_PROGRESSION[0]


## Get all available connections. Returns empty if DLC disabled.
static func get_available_connections() -> Array[Dictionary]:
	if not _is_flag_enabled("EXPANDED_CONNECTIONS"):
		return []
	return EXPANDED_CONNECTIONS.duplicate()


## Get PvP setup text. Returns empty if DLC disabled.
static func get_pvp_setup() -> String:
	if not _is_flag_enabled("PVP_BATTLES"):
		return ""
	return PVP_RULES.setup


## Roll PvP objective. Returns empty if DLC disabled.
static func roll_pvp_objective() -> Dictionary:
	if not _is_flag_enabled("PVP_BATTLES"):
		return {}
	var objectives: Array = PVP_RULES.objectives
	return objectives[randi() % objectives.size()]


## Get PvP rules text for a specific aspect.
static func get_pvp_rules(aspect: String) -> String:
	if not _is_flag_enabled("PVP_BATTLES"):
		return ""
	var rules: Dictionary = PVP_RULES.get(aspect, {})
	return rules.get("instruction", "")


## Get co-op setup text. Returns empty if DLC disabled.
static func get_coop_setup() -> String:
	if not _is_flag_enabled("COOP_BATTLES"):
		return ""
	return COOP_RULES.setup


## Get co-op rules text for a specific aspect.
static func get_coop_rules(aspect: String) -> String:
	if not _is_flag_enabled("COOP_BATTLES"):
		return ""
	var rules: Dictionary = COOP_RULES.get(aspect, {})
	return rules.get("instruction", "")


## Get introductory campaign mission. Returns empty if DLC disabled.
static func get_introductory_mission(mission_number: int) -> Dictionary:
	if not _is_flag_enabled("INTRODUCTORY_CAMPAIGN"):
		return {}
	if mission_number < 1 or mission_number > INTRODUCTORY_MISSIONS.size():
		return {}
	return INTRODUCTORY_MISSIONS[mission_number - 1]


## Get all introductory missions. Returns empty if DLC disabled.
static func get_all_introductory_missions() -> Array[Dictionary]:
	if not _is_flag_enabled("INTRODUCTORY_CAMPAIGN"):
		return []
	return INTRODUCTORY_MISSIONS.duplicate()


## Check if prison planet character option is available.
static func is_prison_planet_available() -> bool:
	return _is_flag_enabled("PRISON_PLANET_CHARACTER")


## Get prison planet character creation text.
static func get_prison_planet_text() -> String:
	if not _is_flag_enabled("PRISON_PLANET_CHARACTER"):
		return ""
	return PRISON_PLANET_OPTIONS.instruction


## Get prison planet effects dictionary.
static func get_prison_planet_effects() -> Dictionary:
	if not _is_flag_enabled("PRISON_PLANET_CHARACTER"):
		return {}
	return PRISON_PLANET_OPTIONS.effects.duplicate()
