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
## CANONICAL DATA: CompendiumStealthMissions (src/data/compendium_stealth_missions.gd)
## This generator adds orchestration and text formatting on top of the compendium data layer.
##
## Key mechanics:
##   - Crew Quick Actions: Move base speed +1" (no Dashing)
##   - Enemy patrol: Random direction per sentry
##   - Spotting check: Enemy 2D6 vs distance in inches (modifiers for cover)
##   - Finding: D6+Savvy, 6+ = located (for retrieval/contact objectives)
##   - Detection: Switches to standard combat when spotted


## ============================================================================
## SENTRY PATROL TABLE (D6 per sentry each stealth round)
## Generator-only instruction data — not in compendium const tables.
## ============================================================================

## Sentry patrol and spotting data loaded from StealthAndStreet.json
static var SENTRY_PATROL: Array: # @no-lint:variable-name
	get:
		_ensure_ref_loaded()
		var a: Array = _ref_data.get("sentry_patrol", [])
		if a.is_empty():
			return [{"roll": 1, "instruction": "Unknown"}]
		return a

static var SPOTTING_MODIFIERS: Array: # @no-lint:variable-name
	get:
		_ensure_ref_loaded()
		var a: Array = _ref_data.get("spotting_modifiers", [])
		if a.is_empty():
			return [{"id": "unknown", "modifier": 0, "description": "Unknown"}]
		return a


## ============================================================================
## JSON DATA LOADING (RulesReference canonical, const fallback)
## ============================================================================

static var _ref_data: Dictionary = {}
static var _ref_loaded: bool = false

static func _ensure_ref_loaded() -> void:
	if _ref_loaded:
		return
	_ref_loaded = true
	var path := "res://data/RulesReference/StealthAndStreet.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_ref_data = json.data
	file.close()

static func get_ref_data() -> Dictionary:
	_ensure_ref_loaded()
	return _ref_data

static func get_stealth_rules() -> Dictionary:
	_ensure_ref_loaded()
	var missions: Dictionary = _ref_data.get("special_missions", {})
	return missions.get("stealth", {})


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
## Delegates to CompendiumStealthMissions for canonical data tables.
## ============================================================================

## Generate a complete stealth mission. Returns empty dict if DLC disabled.
## campaign_crew_size: the fixed campaign setting (4/5/6), NOT roster count.
## Compendium p.124: "The initial number of enemies is equal to your
## campaign crew size +1 (so 7 in a normal game)."
static func generate_stealth_mission(campaign_crew_size: int = 6) -> Dictionary:
	if not _is_enabled():
		return {}

	_ensure_ref_loaded()
	var objective := _roll_objective()
	# Compendium p.124: initial sentries = campaign_crew_size + 1
	var sentry_count := campaign_crew_size + 1
	var individual := {}
	if objective.get("has_individual", false):
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
	# Delegate to canonical compendium data
	var result := CompendiumStealthMissions.roll_objective()
	if not result.is_empty():
		return result
	# Fallback: roll against compendium const directly (DLC might be disabled)
	var roll := randi_range(1, 100)
	for obj in CompendiumStealthMissions.STEALTH_OBJECTIVES:
		if roll >= obj.roll_min and roll <= obj.roll_max:
			return obj.duplicate()
	return CompendiumStealthMissions.STEALTH_OBJECTIVES[0].duplicate()


static func _roll_individual_type() -> Dictionary:
	# Delegate to canonical compendium data
	var result := CompendiumStealthMissions.roll_individual_type()
	if not result.is_empty():
		return result
	# Fallback
	var roll := randi_range(1, 100)
	for ind in CompendiumStealthMissions.INDIVIDUAL_TYPES:
		if roll >= ind.roll_min and roll <= ind.roll_max:
			return ind.duplicate()
	return CompendiumStealthMissions.INDIVIDUAL_TYPES[0].duplicate()


## ============================================================================
## SETUP INSTRUCTIONS
## ============================================================================

## Generate full setup text for the stealth mission.
static func generate_setup_instructions(mission: Dictionary) -> String:
	var obj: Dictionary = mission.get("objective", {})
	var obj_name: String = obj.get("id", "unknown").replace("_", " ").capitalize()
	var lines: Array[String] = [
		"[b]STEALTH MISSION SETUP[/b]",
		"",
		"[b]Objective:[/b] %s" % obj_name,
		obj.get("instruction", ""),
		"",
		"[b]Sentries:[/b] Place %d sentry markers on the battlefield." % mission.get("sentry_count", 4),
		"  - Space sentries at least 6\" apart",
		"  - Each sentry faces a random direction (roll D6 for clock position)",
		"  - Sentries have: Reactions 1, Speed 4\", Combat +0, Toughness 3",
		"",
		"[b]Deployment:[/b]",
		CompendiumStealthMissions.DEPLOYMENT_RULES,
		"",
		"[b]Finding the Target:[/b]" if obj.get("requires_finding", false) else "",
		CompendiumStealthMissions.FINDING_TARGET_RULES if obj.get("requires_finding", false) else "",
	]

	var individual: Dictionary = mission.get("individual", {})
	if not individual.is_empty():
		lines.append("")
		lines.append("[b]Target Individual:[/b] %s" % individual.get("name", "Unknown"))
		var profile: Dictionary = individual.get("profile", CompendiumStealthMissions.INDIVIDUAL_PROFILE)
		if profile is Dictionary:
			lines.append("  Profile: R:%d Sp:%d\" C:+%d T:%d Sv:+%d" % [
				profile.get("reactions", 1), profile.get("speed", 4),
				profile.get("combat_skill", 0), profile.get("toughness", 4),
				profile.get("savvy", 1)])
		else:
			lines.append("  Profile: %s" % str(profile))

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
	if obj.get("requires_finding", false):
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
	var obj_name: String = obj.get("id", "unknown").replace("_", " ").capitalize()
	return "\n".join([
		"[color=#10B981][b]MISSION COMPLETE![/b][/color]",
		"",
		"Objective achieved: %s" % obj_name,
		"",
		"[b]Rewards:[/b]",
		"  - Standard mission credits",
		"  - +1 bonus XP per crew member for stealth completion",
		"  - If undetected: +2 bonus credits (clean operation)",
	])
