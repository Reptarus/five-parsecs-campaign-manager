class_name StealthMissionGenerator
extends RefCounted
## Stealth Mission Generator - Full stealth mission type from the Compendium
##
## Generates stealth missions with their own sub-phase flow:
##   Setup → Stealth Rounds → Detection (optional) → Combat/Extraction
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.STEALTH_MISSIONS.
##
## Key mechanics:
##   - Crew Quick Actions: Move base speed +1" (no Dashing)
##   - Enemy patrol: Random direction per sentry
##   - Spotting check: Enemy 2D6 vs distance in inches (modifiers for cover)
##   - Finding: D6+Savvy, 6+ = located (for retrieval/contact objectives)
##   - Detection: Switches to standard combat when spotted


## ============================================================================
## STEALTH OBJECTIVES (D100 table)
## ============================================================================

const STEALTH_OBJECTIVES: Array[Dictionary] = [
	{
		"roll_min": 1, "roll_max": 20,
		"id": "locate_retrieve",
		"name": "Locate and Retrieve",
		"uses_finding": true,
		"description": "Find a specific item using Finding rules, then extract.",
		"setup": "Place 3 search markers on the battlefield. Item is at one of them (determined when searched).",
		"win_condition": "Locate the item (Finding roll) and move it off your table edge.",
	},
	{
		"roll_min": 21, "roll_max": 35,
		"id": "deliver_item",
		"name": "Deliver Item",
		"uses_finding": false,
		"description": "Deliver a package to a specific location on the battlefield.",
		"setup": "One crew member carries the item. Place delivery marker at center or far edge.",
		"win_condition": "Move the carrier within 2\" of the delivery marker without being detected.",
	},
	{
		"roll_min": 36, "roll_max": 50,
		"id": "locate_contact",
		"name": "Locate and Contact",
		"uses_finding": true,
		"description": "Find a specific individual using Finding rules.",
		"setup": "Place 3 potential contact markers. Contact is at one (determined when reached).",
		"win_condition": "Locate the contact (Finding roll) and move both off your table edge.",
	},
	{
		"roll_min": 51, "roll_max": 70,
		"id": "rescue",
		"name": "Rescue Individual",
		"uses_finding": false,
		"description": "Rescue a captive held by enemies.",
		"setup": "Place captive marker in enemy deployment zone. Guarded by 2 sentries.",
		"win_condition": "Reach the captive, free them (1 action), and exit the table together.",
	},
	{
		"roll_min": 71, "roll_max": 85,
		"id": "transmit_message",
		"name": "Transmit Message",
		"uses_finding": false,
		"description": "Reach a comm relay and transmit a message.",
		"setup": "Place comm relay marker near center of enemy zone.",
		"win_condition": "Reach comm relay, spend 1 action to transmit, then extract.",
	},
	{
		"roll_min": 86, "roll_max": 100,
		"id": "retrieve_package",
		"name": "Retrieve Package",
		"uses_finding": false,
		"description": "Retrieve a package from a fixed location.",
		"setup": "Place package marker at a specific point (roll for exact location).",
		"win_condition": "Reach the package, pick it up (1 action), exit the table.",
	},
]


## ============================================================================
## INDIVIDUAL TYPES (for contact/rescue objectives, D100)
## ============================================================================

const INDIVIDUAL_TYPES: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 15, "name": "Criminal Kingpin", "profile": "Reactions 1, Speed 4\", Combat +0, Toughness 4, Savvy +1"},
	{"roll_min": 16, "roll_max": 30, "name": "Corporate Agent", "profile": "Reactions 1, Speed 4\", Combat +0, Toughness 3, Savvy +2"},
	{"roll_min": 31, "roll_max": 40, "name": "Political Dissident", "profile": "Reactions 1, Speed 4\", Combat +0, Toughness 3, Savvy +1"},
	{"roll_min": 41, "roll_max": 50, "name": "Scientist", "profile": "Reactions 1, Speed 4\", Combat +0, Toughness 3, Savvy +2"},
	{"roll_min": 51, "roll_max": 60, "name": "Informant", "profile": "Reactions 2, Speed 5\", Combat +0, Toughness 3, Savvy +1"},
	{"roll_min": 61, "roll_max": 70, "name": "Military Deserter", "profile": "Reactions 2, Speed 4\", Combat +1, Toughness 4, Savvy +0"},
	{"roll_min": 71, "roll_max": 80, "name": "Smuggler", "profile": "Reactions 1, Speed 5\", Combat +1, Toughness 3, Savvy +1"},
	{"roll_min": 81, "roll_max": 90, "name": "Diplomat", "profile": "Reactions 1, Speed 4\", Combat +0, Toughness 3, Savvy +2"},
	{"roll_min": 91, "roll_max": 95, "name": "Bounty Target", "profile": "Reactions 2, Speed 5\", Combat +1, Toughness 4, Savvy +1"},
	{"roll_min": 96, "roll_max": 100, "name": "Alien VIP", "profile": "Reactions 2, Speed 4\", Combat +0, Toughness 5, Savvy +2"},
]


## ============================================================================
## SENTRY PATROL TABLE (D6 per sentry each stealth round)
## ============================================================================

const SENTRY_PATROL: Array[Dictionary] = [
	{"roll": 1, "instruction": "Sentry turns LEFT 90 degrees, moves 2\"."},
	{"roll": 2, "instruction": "Sentry turns RIGHT 90 degrees, moves 2\"."},
	{"roll": 3, "instruction": "Sentry moves FORWARD 3\"."},
	{"roll": 4, "instruction": "Sentry moves FORWARD 2\", then turns to face nearest terrain."},
	{"roll": 5, "instruction": "Sentry HOLDS POSITION, scans area (-1 to spotting distance)."},
	{"roll": 6, "instruction": "Sentry moves to NEAREST cover, faces random direction."},
]


## ============================================================================
## SPOTTING CHECK MODIFIERS
## ============================================================================

const SPOTTING_MODIFIERS: Array[Dictionary] = [
	{"id": "partial_cover", "modifier": -2, "description": "Target behind partial cover"},
	{"id": "full_cover", "modifier": -4, "description": "Target behind full cover (edge visible)"},
	{"id": "scanning", "modifier": -1, "description": "Sentry is scanning (rolled 5 on patrol)"},
	{"id": "intervening", "modifier": -1, "description": "Per intervening terrain feature"},
	{"id": "darkness", "modifier": -2, "description": "Low light / darkness conditions"},
	{"id": "running", "modifier": 2, "description": "Target moved more than 3\" this round"},
	{"id": "fired_weapon", "modifier": 3, "description": "Target fired a weapon this round"},
]


## ============================================================================
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.STEALTH_MISSIONS)


## ============================================================================
## MISSION GENERATION
## ============================================================================

## Generate a complete stealth mission. Returns empty dict if DLC disabled.
static func generate_stealth_mission() -> Dictionary:
	if not _is_enabled():
		return {}

	var objective := _roll_objective()
	var sentry_count := randi_range(3, 6)
	var individual := {}
	if objective.id in ["locate_contact", "rescue"]:
		individual = _roll_individual_type()

	return {
		"type": "stealth",
		"objective": objective,
		"sentry_count": sentry_count,
		"individual": individual,
		"detected": false,
		"current_round": 0,
	}


static func _roll_objective() -> Dictionary:
	var roll := randi_range(1, 100)
	for obj in STEALTH_OBJECTIVES:
		if roll >= obj.roll_min and roll <= obj.roll_max:
			return obj
	return STEALTH_OBJECTIVES[0]


static func _roll_individual_type() -> Dictionary:
	var roll := randi_range(1, 100)
	for ind in INDIVIDUAL_TYPES:
		if roll >= ind.roll_min and roll <= ind.roll_max:
			return ind
	return INDIVIDUAL_TYPES[0]


## ============================================================================
## SETUP INSTRUCTIONS
## ============================================================================

## Generate full setup text for the stealth mission.
static func generate_setup_instructions(mission: Dictionary) -> String:
	var obj: Dictionary = mission.get("objective", {})
	var lines: Array[String] = [
		"[b]STEALTH MISSION SETUP[/b]",
		"",
		"[b]Objective:[/b] %s" % obj.get("name", "Unknown"),
		obj.get("description", ""),
		"",
		"[b]Table Setup:[/b]",
		obj.get("setup", "Standard deployment."),
		"",
		"[b]Sentries:[/b] Place %d sentry markers on the battlefield." % mission.get("sentry_count", 4),
		"  - Space sentries at least 6\" apart",
		"  - Each sentry faces a random direction (roll D6 for clock position)",
		"  - Sentries have: Reactions 1, Speed 4\", Combat +0, Toughness 3",
		"",
		"[b]Crew Deployment:[/b]",
		"  - Deploy within 6\" of your table edge",
		"  - All crew start in Stealth mode",
		"",
		"[b]Win Condition:[/b] %s" % obj.get("win_condition", "Complete the objective and extract."),
	]

	var individual: Dictionary = mission.get("individual", {})
	if not individual.is_empty():
		lines.append("")
		lines.append("[b]Target Individual:[/b] %s" % individual.get("name", "Unknown"))
		lines.append("  Profile: %s" % individual.get("profile", "Standard"))

	return "\n".join(lines)


## ============================================================================
## STEALTH ROUND INSTRUCTIONS
## ============================================================================

## Generate instructions for a stealth round.
static func generate_stealth_round_instructions(round_num: int, mission: Dictionary) -> String:
	var lines: Array[String] = [
		"[b]STEALTH ROUND %d[/b]" % round_num,
		"",
		"[b]1. Crew Quick Actions:[/b]",
		"  - Each crew member may Move (base speed + 1\", no Dashing)",
		"  - OR take one Quick Action (search, interact, pick lock)",
		"  - Crew may NOT fire weapons (breaks stealth immediately)",
		"",
		"[b]2. Sentry Patrol:[/b]",
		"  Roll D6 for each sentry to determine movement:",
	]

	for patrol in SENTRY_PATROL:
		lines.append("    %d: %s" % [patrol.roll, patrol.instruction])

	lines.append("")
	lines.append("[b]3. Spotting Check (per sentry):[/b]")
	lines.append("  - Sentry rolls 2D6")
	lines.append("  - If roll > distance to nearest crew (in inches): DETECTED!")
	lines.append("  - Modifiers:")
	for mod in SPOTTING_MODIFIERS:
		lines.append("    %+d: %s" % [mod.modifier, mod.description])

	var obj: Dictionary = mission.get("objective", {})
	if obj.get("uses_finding", false):
		lines.append("")
		lines.append("[b]4. Finding (if within 6\" of search marker with LoS):[/b]")
		lines.append("  - Roll D6 + Savvy")
		lines.append("  - 6+ = Located! (item/contact found at this marker)")
		lines.append("  - Otherwise: Nothing here. Remove marker.")

	return "\n".join(lines)


## Generate detection result text.
static func generate_detection_result() -> String:
	return "\n".join([
		"[color=#DC2626][b]DETECTED![/b][/color]",
		"",
		"Stealth phase ends. Switch to standard combat rules.",
		"- All sentries become active enemies",
		"- Roll D6: On 4+, D3 reinforcements arrive at enemy table edge next round",
		"- Crew members now use normal activation (full move + action)",
		"- Objective can still be completed under fire",
	])


## Generate extraction success text.
static func generate_extraction_text(mission: Dictionary) -> String:
	var obj: Dictionary = mission.get("objective", {})
	return "\n".join([
		"[color=#10B981][b]MISSION COMPLETE![/b][/color]",
		"",
		"Objective achieved: %s" % obj.get("name", ""),
		"",
		"[b]Rewards:[/b]",
		"  - Standard mission credits",
		"  - +1 bonus XP per crew member for stealth completion",
		"  - If undetected: +2 bonus credits (clean operation)",
	])
