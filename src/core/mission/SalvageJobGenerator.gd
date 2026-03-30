class_name SalvageJobGenerator
extends RefCounted
## Salvage Job Generator - Salvage mission type from the Compendium
##
## Generates salvage missions with tension track system, contact spawning,
## points of interest, and post-mission salvage trading.
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.SALVAGE_JOBS.
##
## CANONICAL DATA: CompendiumSalvageJobs (src/data/compendium_salvage_jobs.gd)
## This generator adds orchestration and text formatting on top of the compendium data layer.
##
## Key mechanics:
##   - Tension track: starts at ceil(crew_size/2), escalates each round
##   - Contact spawning: D6 vs Tension
##   - Contact resolution: D6 (nothing / bad feeling / hostiles / movement)
##   - Hostile types: D100 (Free for All / Toughs / Rival Team / Infestation)
##   - Points of Interest: 4 markers, must investigate all
##   - Salvage units: collected loot → credits conversion post-mission


## ============================================================================
## JSON DATA LOADING (RulesReference canonical, const fallback)
## ============================================================================

static var _ref_data: Dictionary = {}
static var _ref_loaded: bool = false

static func _ensure_ref_loaded() -> void:
	if _ref_loaded:
		return
	_ref_loaded = true
	var path := "res://data/RulesReference/SalvageJobs.json"
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


## ============================================================================
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.SALVAGE_JOBS)


## ============================================================================
## MISSION GENERATION
## Delegates to CompendiumSalvageJobs for canonical data tables.
## ============================================================================

static func generate_salvage_job(crew_size: int) -> Dictionary:
	if not _is_enabled():
		return {}

	_ensure_ref_loaded()
	var initial_tension := CompendiumSalvageJobs.get_initial_tension(crew_size)

	return {
		"type": "salvage",
		"tension": initial_tension,
		"max_tension": 12,
		"salvage_units": 0,
		"hostile_type": {},  # Rolled on first hostile encounter
		"poi_count": 4,  # Compendium p.141: 4 POI markers (one per quarter)
		"current_round": 0,
		"contacts_spawned": 0,
	}


static func find_salvage_job() -> Dictionary:
	if not _is_enabled():
		return {}
	var result := CompendiumSalvageJobs.roll_salvage_availability()
	if not result.is_empty():
		return result
	# Fallback
	var roll := randi_range(1, 6)
	for entry in CompendiumSalvageJobs.SALVAGE_AVAILABILITY:
		if roll >= entry.roll_min and roll <= entry.roll_max:
			return entry.duplicate()
	return CompendiumSalvageJobs.SALVAGE_AVAILABILITY[0].duplicate()


static func roll_hostile_type() -> Dictionary:
	var result := CompendiumSalvageJobs.roll_hostiles_type()
	if not result.is_empty():
		return result
	# Fallback
	var roll := randi_range(1, 100)
	for h in CompendiumSalvageJobs.HOSTILES_TABLE:
		if roll >= h.roll_min and roll <= h.roll_max:
			return h.duplicate()
	return CompendiumSalvageJobs.HOSTILES_TABLE[0].duplicate()


static func roll_point_of_interest() -> Dictionary:
	var result := CompendiumSalvageJobs.roll_poi_reveal()
	if not result.is_empty():
		return result
	# Fallback
	var roll := randi_range(1, 100)
	for poi in CompendiumSalvageJobs.POI_REVEALS:
		if roll >= poi.roll_min and roll <= poi.roll_max:
			return poi.duplicate()
	return CompendiumSalvageJobs.POI_REVEALS[0].duplicate()


static func resolve_contact() -> Dictionary:
	var result := CompendiumSalvageJobs.roll_contact_result()
	if not result.is_empty():
		return result
	# Fallback
	var roll := randi_range(1, 6)
	for c in CompendiumSalvageJobs.CONTACT_RESULTS:
		if roll >= c.roll_min and roll <= c.roll_max:
			return c.duplicate()
	return CompendiumSalvageJobs.CONTACT_RESULTS[0].duplicate()


static func get_salvage_credits(units: int) -> int:
	# Compendium pp.146-148: Salvage units are NOT directly converted to credits.
	# Instead: 1 Salvage unit = 1 Credit toward ship repairs/modules/bot upgrades ONLY.
	# Direct credit value is 0 — salvage is a special-purpose currency.
	# This method returns the equivalent credit value for UI display purposes.
	return units  # 1:1 ratio per Compendium salvage-as-currency rule


## ============================================================================
## INSTRUCTION TEXT GENERATION
## ============================================================================

static func generate_setup_instructions(mission: Dictionary) -> String:
	var lines: Array[String] = [
		"[b]SALVAGE JOB SETUP[/b]",
		"",
		"[b]Starting Tension:[/b] %d" % mission.get("tension", 3),
		"",
		CompendiumSalvageJobs.TABLE_SETUP_RULES,
		"",
		"[b]Tension Track:[/b]",
		CompendiumSalvageJobs.TENSION_RULES,
		"",
		"[b]Contact Rules:[/b]",
		CompendiumSalvageJobs.CONTACT_PLACEMENT_RULES,
		"",
		"[b]Extraction:[/b] All crew must reach table edge to end mission.",
		"  Salvage units convert to credits post-mission.",
	]
	return "\n".join(lines)


static func generate_round_instructions(round_num: int, tension: int) -> String:
	var lines: Array[String] = [
		"[b]SALVAGE ROUND %d[/b]" % round_num,
		"",
		"[b]Tension:[/b] %d / 12" % tension,
		"",
	]

	if round_num > 1:
		lines.append("[b]Tension Check:[/b] Roll D6.")
		lines.append("  D6 > %d: Tension increases to %d." % [tension, tension + 1])
		lines.append("  D6 <= %d: Tension reduced by D6 value. New Contact spawns!" % tension)
		lines.append("")

	lines.append_array([
		"[b]Actions:[/b]",
		"  - Move + Action (standard rules)",
		"  - Investigate POI: Move within 2\", 1 action, roll D100",
		"  - Resolve Contact: Move within 6\" and LoS (or 3\"), roll D6",
		"  - Pick up salvage: Move into contact (auto-success)",
		"",
		"[b]Extraction:[/b] Crew member at table edge may exit (removed from play, salvage saved).",
	])

	return "\n".join(lines)


static func generate_post_mission_text(salvage_units: int, is_illegal: bool) -> String:
	var credits := get_salvage_credits(salvage_units)
	var lines: Array[String] = [
		"[b]SALVAGE JOB COMPLETE[/b]",
		"",
		"Salvage collected: %d units" % salvage_units,
		"Credits earned: %d cr" % credits,
	]

	if is_illegal:
		lines.append("")
		lines.append("[color=#D97706]ILLEGAL OPERATION: Roll D6.[/color]")
		lines.append("  1-4: Got away with it.")
		lines.append("  5-6: Authorities on trail. Choose one:")
		lines.append("    - Pay roll value in credits")
		lines.append("    - Hand over all salvage (0 credits)")
		lines.append("    - Add Enforcer Rival")

	return "\n".join(lines)
