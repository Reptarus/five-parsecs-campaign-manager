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
## Key mechanics:
##   - Tension track: starts at ceil(crew_size/2), escalates each round
##   - Contact spawning: D6 <= Tension = new Contact marker
##   - Contact resolution: D6 (nothing / bad feeling / hostiles / more contacts)
##   - Hostile types: D100 (Criminal/Hired Muscle/Interested/Roving Threats)
##   - Points of Interest: D100 table with loot and Tension modifiers
##   - Salvage units: collected loot → credits conversion post-mission
##   - Finding a job: D6 (1=nothing, 2-3=fee, 4-5=legal, 6=illegal)


## ============================================================================
## FINDING A SALVAGE JOB (D6)
## ============================================================================

const FIND_JOB_TABLE: Array[Dictionary] = [
	{"roll": 1, "id": "nothing", "instruction": "SALVAGE JOB: No jobs available this turn."},
	{"roll": 2, "id": "fee_job", "instruction": "SALVAGE JOB: Job available for 2 cr fee. Pay to accept."},
	{"roll": 3, "id": "fee_job_cheap", "instruction": "SALVAGE JOB: Job available for 2 cr fee. Pay to accept."},
	{"roll": 4, "id": "legal", "instruction": "SALVAGE JOB: Legal salvage job. No fee, no risk of criminal charges."},
	{"roll": 5, "id": "legal_good", "instruction": "SALVAGE JOB: Good legal salvage job. No fee, +1 salvage unit bonus."},
	{"roll": 6, "id": "illegal", "instruction": "SALVAGE JOB: Illegal salvage operation! No fee, but risk post-game: D6 5-6 = caught."},
]


## ============================================================================
## CONTACT RESOLUTION (D6 when Contact marker is reached)
## ============================================================================

const CONTACT_RESOLUTION: Array[Dictionary] = [
	{"roll": 1, "id": "nothing", "instruction": "CONTACT: Nothing here. Remove marker."},
	{"roll": 2, "id": "bad_feeling", "tension_mod": 1, "instruction": "CONTACT: Bad feeling... +1 Tension. Remove marker."},
	{"roll": 3, "id": "hostiles", "instruction": "CONTACT: HOSTILES! Roll D100 for enemy type. D6 enemies appear at marker."},
	{"roll": 4, "id": "hostiles", "instruction": "CONTACT: HOSTILES! Roll D100 for enemy type. D6 enemies appear at marker."},
	{"roll": 5, "id": "hostiles", "instruction": "CONTACT: HOSTILES! Roll D100 for enemy type. D6 enemies appear at marker."},
	{"roll": 6, "id": "more_contacts", "instruction": "CONTACT: Activity detected! Place 2 new Contact markers within 8\"."},
]


## ============================================================================
## HOSTILE TYPES (D100, first roll determines type for entire mission)
## ============================================================================

const HOSTILE_TYPES: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 25, "id": "criminal", "name": "Criminal Elements",
	 "profile": "Combat +0, Toughness 3, Speed 4\", Pistols and Blades",
	 "instruction": "HOSTILES: Criminal Elements. Combat +0, Toughness 3, Pistols/Blades."},
	{"roll_min": 26, "roll_max": 40, "id": "hired_muscle", "name": "Hired Muscle",
	 "profile": "Combat +1, Toughness 4, Speed 4\", Auto Rifles",
	 "instruction": "HOSTILES: Hired Muscle. Combat +1, Toughness 4, Auto Rifles."},
	{"roll_min": 41, "roll_max": 65, "id": "interested", "name": "Interested Parties",
	 "profile": "Combat +0, Toughness 3, Speed 5\", Mixed weapons",
	 "instruction": "HOSTILES: Interested Parties. Combat +0, Toughness 3, Mixed weapons."},
	{"roll_min": 66, "roll_max": 100, "id": "roving", "name": "Roving Threats",
	 "profile": "Combat +1, Toughness 4, Speed 5\", Heavy weapons possible",
	 "instruction": "HOSTILES: Roving Threats. Combat +1, Toughness 4, may have Heavy weapons."},
]


## ============================================================================
## POINTS OF INTEREST (D100)
## ============================================================================

const POINTS_OF_INTEREST: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 10, "id": "scrap", "salvage": 1, "tension_mod": 0,
	 "instruction": "FIND: Scrap metal. +1 salvage unit."},
	{"roll_min": 11, "roll_max": 20, "id": "components", "salvage": 2, "tension_mod": 0,
	 "instruction": "FIND: Useful components. +2 salvage units."},
	{"roll_min": 21, "roll_max": 30, "id": "tech_cache", "salvage": 3, "tension_mod": 1,
	 "instruction": "FIND: Tech cache! +3 salvage units. +1 Tension (noise)."},
	{"roll_min": 31, "roll_max": 40, "id": "weapon_crate", "salvage": 0, "tension_mod": 0,
	 "instruction": "FIND: Weapon crate. Roll on standard loot table."},
	{"roll_min": 41, "roll_max": 50, "id": "medical_supplies", "salvage": 1, "tension_mod": 0,
	 "instruction": "FIND: Medical supplies. +1 salvage unit. Heal 1 wound on a crew member."},
	{"roll_min": 51, "roll_max": 60, "id": "data_terminal", "salvage": 2, "tension_mod": 1,
	 "instruction": "FIND: Data terminal. +2 salvage units. +1 Tension (alarm triggered)."},
	{"roll_min": 61, "roll_max": 70, "id": "fuel_cells", "salvage": 2, "tension_mod": 0,
	 "instruction": "FIND: Fuel cells. +2 salvage units. Usable as ship fuel (1 unit)."},
	{"roll_min": 71, "roll_max": 80, "id": "personal_effects", "salvage": 1, "tension_mod": 0,
	 "instruction": "FIND: Personal effects. +1 salvage unit. D6 6 = Quest Rumor."},
	{"roll_min": 81, "roll_max": 90, "id": "structural_hazard", "salvage": 0, "tension_mod": 2,
	 "instruction": "FIND: Structural hazard! No salvage. +2 Tension. D6: 1-2 = D6 damage to nearest crew."},
	{"roll_min": 91, "roll_max": 95, "id": "rare_find", "salvage": 4, "tension_mod": 1,
	 "instruction": "FIND: Rare components! +4 salvage units. +1 Tension."},
	{"roll_min": 96, "roll_max": 100, "id": "jackpot", "salvage": 5, "tension_mod": 2,
	 "instruction": "FIND: JACKPOT! +5 salvage units. +2 Tension (major noise)."},
]


## ============================================================================
## SALVAGE TRADING (post-mission)
## ============================================================================

const SALVAGE_CONVERSION: Array[Dictionary] = [
	{"units_min": 1, "units_max": 3, "credits": 2, "instruction": "SALVAGE TRADE: 1-3 units = 2 credits."},
	{"units_min": 4, "units_max": 6, "credits": 5, "instruction": "SALVAGE TRADE: 4-6 units = 5 credits."},
	{"units_min": 7, "units_max": 10, "credits": 8, "instruction": "SALVAGE TRADE: 7-10 units = 8 credits."},
	{"units_min": 11, "units_max": 15, "credits": 12, "instruction": "SALVAGE TRADE: 11-15 units = 12 credits."},
	{"units_min": 16, "units_max": 999, "credits": 18, "instruction": "SALVAGE TRADE: 16+ units = 18 credits."},
]


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

## Enrich a const-based roll result with canonical JSON description if available.
## JSON key path: salvage_jobs -> section -> table -> [entries]
static func _enrich_from_ref(section_key: String, match_field: String,
		match_value, result: Dictionary) -> Dictionary:
	if _ref_data.is_empty():
		return result
	var section: Dictionary = _ref_data.get("salvage_jobs", {}).get(section_key, {})
	var table: Array = section.get("table", [])
	for entry in table:
		if entry.get(match_field, null) == match_value:
			# Overlay canonical text without replacing game-mechanic fields
			if entry.has("result"):
				result["canonical_text"] = entry["result"]
			if entry.has("effect"):
				result["canonical_effect"] = entry["effect"]
			if entry.has("tension_adjustment"):
				result["ref_tension_mod"] = entry["tension_adjustment"]
			break
	return result


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
## ============================================================================

static func generate_salvage_job(crew_size: int) -> Dictionary:
	if not _is_enabled():
		return {}

	_ensure_ref_loaded()
	var initial_tension := ceili(crew_size / 2.0)
	var poi_count := randi_range(3, 6)

	return {
		"type": "salvage",
		"tension": initial_tension,
		"max_tension": 12,
		"salvage_units": 0,
		"hostile_type": {},  # Rolled on first hostile encounter
		"poi_count": poi_count,
		"current_round": 0,
		"contacts_spawned": 0,
	}


static func find_salvage_job() -> Dictionary:
	if not _is_enabled():
		return {}
	_ensure_ref_loaded()
	var roll := randi_range(1, 6)
	for entry in FIND_JOB_TABLE:
		if entry.roll == roll:
			return _enrich_from_ref("finding_salvage_job", "roll", roll, entry.duplicate())
	return FIND_JOB_TABLE[0].duplicate()


static func roll_hostile_type() -> Dictionary:
	_ensure_ref_loaded()
	var roll := randi_range(1, 100)
	for h in HOSTILE_TYPES:
		if roll >= h.roll_min and roll <= h.roll_max:
			return h
	return HOSTILE_TYPES[0]


static func roll_point_of_interest() -> Dictionary:
	_ensure_ref_loaded()
	var roll := randi_range(1, 100)
	for poi in POINTS_OF_INTEREST:
		if roll >= poi.roll_min and roll <= poi.roll_max:
			return _enrich_from_ref("points_of_interest", "result",
				poi.get("id", ""), poi.duplicate())
	return POINTS_OF_INTEREST[0].duplicate()


static func resolve_contact() -> Dictionary:
	_ensure_ref_loaded()
	var roll := randi_range(1, 6)
	for c in CONTACT_RESOLUTION:
		if c.roll == roll:
			return _enrich_from_ref("contact_resolution", "roll", roll, c.duplicate())
	return CONTACT_RESOLUTION[0].duplicate()


static func get_salvage_credits(units: int) -> int:
	_ensure_ref_loaded()
	for tier in SALVAGE_CONVERSION:
		if units >= tier.units_min and units <= tier.units_max:
			return tier.credits
	return 0


## ============================================================================
## INSTRUCTION TEXT GENERATION
## ============================================================================

static func generate_setup_instructions(mission: Dictionary) -> String:
	var lines: Array[String] = [
		"[b]SALVAGE JOB SETUP[/b]",
		"",
		"[b]Starting Tension:[/b] %d" % mission.get("tension", 3),
		"",
		"[b]Table Setup:[/b]",
		"  - Ruined/industrial terrain: wreckage, debris, collapsed structures",
		"  - Place %d Points of Interest markers spread across battlefield" % mission.get("poi_count", 4),
		"  - Place 2 Contact markers at least 12\" from crew deployment",
		"",
		"[b]Crew Deployment:[/b] Within 6\" of your table edge.",
		"",
		"[b]Tension Track:[/b]",
		"  - After Round 1: Roll D6 each round",
		"  - D6 > Tension: Tension increases by 1",
		"  - D6 <= Tension: Spawn a new Contact marker (nearest POI)",
		"",
		"[b]Contact Resolution:[/b] Move within 4\", spend 1 action, roll D6:",
		"  1: Nothing | 2: Bad feeling (+1 Tension)",
		"  3-5: HOSTILES! | 6: 2 new Contacts",
		"",
		"[b]Points of Interest:[/b] Move within 2\", spend 1 action, roll D100 for loot.",
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
		lines.append("  D6 <= %d: New Contact marker spawns!" % tension)
		lines.append("")

	lines.append_array([
		"[b]Actions:[/b]",
		"  - Move + Action (standard rules)",
		"  - Search POI: Move within 2\", 1 action, roll D100",
		"  - Resolve Contact: Move within 4\", 1 action, roll D6",
		"  - Pick up salvage: 1 action (auto-success)",
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
		lines.append("  5-6: CAUGHT! Choose one:")
		lines.append("    - Pay %d cr fine" % (credits * 2))
		lines.append("    - Hand over all salvage (0 credits)")
		lines.append("    - Add Enforcer Rival")

	return "\n".join(lines)
