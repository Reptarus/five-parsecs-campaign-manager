class_name PlanetfallLifeformGenerator
extends RefCounted

## Procedural lifeform generation (4-step) and Campaign Lifeform Encounters table
## management. Also handles lifeform evolutions applied at milestones.
## Source: Planetfall pp.146-150, 159-160

var _generation_data: Dictionary = {}
var _evolution_data: Array = []
var _encounter_slots: Array = []
var _loaded: bool = false


func _init() -> void:
	_load_tables()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_tables() -> void:
	_generation_data = _load_json("res://data/planetfall/lifeform_generation.json")
	_encounter_slots = _generation_data.get("encounter_table_slots", [])

	var evo_data: Dictionary = _load_json("res://data/planetfall/lifeform_evolution.json")
	_evolution_data = evo_data.get("entries", [])

	_loaded = not _generation_data.is_empty()


func _load_json(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallLifeformGenerator: JSON not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlanetfallLifeformGenerator: JSON parse error: %s" % path)
		file.close()
		return {}
	file.close()
	if json.data is Dictionary:
		return json.data
	return {}


## ============================================================================
## ENCOUNTER TABLE
## ============================================================================

func get_encounter_table_slot(d100_roll: int) -> int:
	## Maps a D100 roll to a slot index (0-9) on the encounter table.
	for slot_entry in _encounter_slots:
		if slot_entry is Dictionary:
			if d100_roll >= slot_entry.get("min", 0) and d100_roll <= slot_entry.get("max", 0):
				return slot_entry.get("slot", -1)
	return -1


func get_lifeform_for_roll(campaign: Resource, d100_roll: int) -> Dictionary:
	## Look up the encounter table. If slot filled, return existing lifeform.
	## If blank, generate new and fill slot. Returns the lifeform profile.
	var slot: int = get_encounter_table_slot(d100_roll)
	if slot < 0:
		return {}

	if not campaign or not "lifeform_table" in campaign:
		return generate_lifeform()

	# Ensure 10 slots
	while campaign.lifeform_table.size() < 10:
		campaign.lifeform_table.append({})

	var existing: Variant = campaign.lifeform_table[slot]
	if existing is Dictionary and not existing.is_empty():
		return existing.duplicate()

	# Generate and persist
	var lifeform: Dictionary = generate_lifeform()
	lifeform["slot_index"] = slot
	campaign.lifeform_table[slot] = lifeform
	return lifeform


func fill_encounter_slot(campaign: Resource, slot_index: int) -> Dictionary:
	## Explicitly generate a lifeform for a specific slot.
	if not campaign or not "lifeform_table" in campaign:
		return {}
	while campaign.lifeform_table.size() < 10:
		campaign.lifeform_table.append({})
	var lifeform: Dictionary = generate_lifeform()
	lifeform["slot_index"] = slot_index
	campaign.lifeform_table[slot_index] = lifeform
	return lifeform


## ============================================================================
## 4-STEP GENERATION
## ============================================================================

func generate_lifeform() -> Dictionary:
	## Full 4-step procedural lifeform generation. Returns complete profile dict.
	var profile: Dictionary = {}

	# Step 1: Mobility
	var mobility_roll: int = roll_d100()
	var mobility: Dictionary = _resolve_mobility(mobility_roll)
	profile["speed"] = mobility.get("speed", 6)
	profile["partially_airborne"] = mobility.get("airborne", false)
	profile["mobility_roll"] = mobility_roll

	# Step 2a: Combat Skill
	var cs_roll: int = roll_d100()
	var cs_entry: Dictionary = _lookup_sub_table("step_2a_combat_skill", cs_roll)
	profile["combat_skill"] = cs_entry.get("combat_skill", 0)

	# Step 2b: Strike Power
	var sp_roll: int = roll_d100()
	var sp_entry: Dictionary = _lookup_sub_table("step_2b_strike_power", sp_roll)
	profile["strike_damage"] = sp_entry.get("damage", 0)

	# Step 2c: Special Attacks (triggered if CS or SP roll ends in 0 or 5)
	var cs_triggers: bool = _ends_in_0_or_5(cs_roll)
	var sp_triggers: bool = _ends_in_0_or_5(sp_roll)
	profile["special_attacks"] = []
	if cs_triggers or sp_triggers:
		var sa_roll: int = roll_d100()
		var sa_entry: Dictionary = _lookup_sub_table("step_2c_special_attacks", sa_roll)
		if not sa_entry.is_empty():
			profile["special_attacks"].append(sa_entry)
	if cs_triggers and sp_triggers:
		# Roll twice, ignore duplicate
		var sa_roll2: int = roll_d100()
		var sa_entry2: Dictionary = _lookup_sub_table("step_2c_special_attacks", sa_roll2)
		if not sa_entry2.is_empty():
			var existing_ids: Array = []
			for sa in profile["special_attacks"]:
				existing_ids.append(sa.get("id", ""))
			if sa_entry2.get("id", "") not in existing_ids:
				profile["special_attacks"].append(sa_entry2)

	# Step 3: Defensive Abilities
	var def_roll: int = roll_d100()
	var def_entry: Dictionary = _lookup_sub_table("step_3_defensive_abilities", def_roll)
	profile["toughness"] = def_entry.get("toughness", 4)
	profile["kp"] = def_entry.get("kp", 0)
	profile["defense_additional"] = def_entry.get("additional", null)

	# Step 4: Unique Ability
	var ua_roll: int = roll_d100()
	var ua_entry: Dictionary = _lookup_sub_table("step_4_unique_ability", ua_roll)
	profile["unique_ability"] = ua_entry

	# Metadata
	profile["generated"] = true

	return profile


## ============================================================================
## EVOLUTION
## ============================================================================

func get_evolution(roll: int) -> Dictionary:
	## D100 lookup on Lifeform Evolution table.
	return _lookup_d100(_evolution_data, roll)


func apply_evolution(campaign: Resource, lifeform_slot: int, evolution_roll: int) -> Dictionary:
	## Apply an evolution to a specific lifeform on the encounter table.
	## Returns the evolution entry. Appends evolution ID to campaign.lifeform_evolutions.
	var evolution: Dictionary = get_evolution(evolution_roll)
	if evolution.is_empty():
		return {}

	if not campaign or not "lifeform_table" in campaign:
		return evolution

	# Ensure table has 10 slots
	while campaign.lifeform_table.size() < 10:
		campaign.lifeform_table.append({})

	# If slot is blank, note the evolution for when it's filled
	var slot_data: Variant = campaign.lifeform_table[lifeform_slot]
	if slot_data is Dictionary and slot_data.is_empty():
		# Mark pending evolution
		campaign.lifeform_table[lifeform_slot] = {"pending_evolutions": [evolution.get("id", "")]}
	elif slot_data is Dictionary:
		# Check for duplicate evolution
		var existing_evos: Array = slot_data.get("evolutions_applied", [])
		if evolution.get("id", "") in existing_evos:
			return {}  # Same evolution cannot apply twice to same lifeform
		existing_evos.append(evolution.get("id", ""))
		slot_data["evolutions_applied"] = existing_evos

		# Apply stat changes if applicable
		var stat_changes: Dictionary = evolution.get("stat_changes", {})
		if stat_changes.has("combat_skill_min"):
			var current_cs: int = slot_data.get("combat_skill", 0)
			if current_cs < stat_changes.get("combat_skill_min", 0):
				slot_data["combat_skill"] = stat_changes.get("combat_skill_min", 0)
		if stat_changes.has("speed_bonus"):
			slot_data["speed"] = slot_data.get("speed", 6) + stat_changes.get("speed_bonus", 0)
		if stat_changes.has("damage_min"):
			var current_dmg: int = slot_data.get("strike_damage", 0)
			if current_dmg < stat_changes.get("damage_min", 0):
				slot_data["strike_damage"] = stat_changes.get("damage_min", 0)

	# Track in campaign
	if "lifeform_evolutions" in campaign:
		campaign.lifeform_evolutions.append({
			"slot": lifeform_slot,
			"evolution_id": evolution.get("id", ""),
			"evolution_roll": evolution_roll
		})

	return evolution


## ============================================================================
## PRIVATE
## ============================================================================

func _resolve_mobility(roll: int) -> Dictionary:
	var mobility_data: Dictionary = _generation_data.get("step_1_mobility", {})
	var entries: Array = mobility_data.get("entries", [])
	var result: Dictionary = {}
	for entry in entries:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				result["speed"] = entry.get("speed", 6)
				break
	result["airborne"] = _ends_in_0_or_5(roll)
	return result


func _lookup_sub_table(table_key: String, roll: int) -> Dictionary:
	var table_data: Dictionary = _generation_data.get(table_key, {})
	var entries: Array = table_data.get("entries", [])
	return _lookup_d100(entries, roll)


func _ends_in_0_or_5(roll: int) -> bool:
	var last_digit: int = roll % 10
	return last_digit == 0 or last_digit == 5


func _lookup_d100(table: Array, roll: int) -> Dictionary:
	for entry in table:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				return entry.duplicate()
	return {}


func roll_d100() -> int:
	return randi_range(1, 100)


func roll_d6() -> int:
	return randi_range(1, 6)


func is_loaded() -> bool:
	return _loaded
