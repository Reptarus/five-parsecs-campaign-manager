class_name PlanetfallLifeformGenerator
extends RefCounted

## Procedural lifeform generation (4-step) and Campaign Lifeform Encounters table
## management. Also handles lifeform evolutions applied at milestones.
## Source: Planetfall pp.146-150; evolutions p.158 (rules) and pp.159-160 (table)

## Rerolls before evolve_random gives up. Reached only when a slot already carries
## nearly every evolution, since each reroll hits a fresh one 1 time in 10 or better.
const EVOLUTION_REROLL_LIMIT := 200

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


func fill_encounter_slot(campaign: Resource, slot_index: int) -> Dictionary:
	## Explicitly generate a lifeform for a specific slot.
	if not campaign or not "lifeform_table" in campaign:
		return {}
	while campaign.lifeform_table.size() < 10:
		campaign.lifeform_table.append({})
	return _materialise(campaign, slot_index)


## A slot holds a creature only once one has been generated. A blank slot can still carry
## a note of the evolutions waiting for it (p.158), and that note is NOT a creature: it
## was read as one until 2026-10-27, so an encounter on an evolved blank slot returned a
## profile with no stats.
static func is_slot_filled(entry: Variant) -> bool:
	if entry is not Dictionary:
		return false
	for key in (entry as Dictionary).keys():
		if key != "pending_evolutions":
			return true
	return false


## p.64 Animal migrations: "Erase a random existing entry from your Lifeform Encounter
## Table and leave it blank. It is filled again when you roll that entry again." A D10
## names the entry and is rerolled until it lands on a filled one, so every existing
## entry is equally likely and QA can force which. Returns the slot erased, or -1.
## The Colony Events panel printed "has been erased" and erased nothing until 2026-10-27.
func erase_random_entry(campaign: Resource) -> int:
	if not campaign or not "lifeform_table" in campaign:
		return -1
	var filled: Array = []
	for i in range(campaign.lifeform_table.size()):
		if is_slot_filled(campaign.lifeform_table[i]):
			filled.append(i)
	if filled.is_empty():
		return -1
	var slot: int = filled[0]
	for _try in range(100):
		var pick: int = _d10("Planetfall Erase Lifeform") - 1
		if filled.has(pick):
			slot = pick
			break
	campaign.lifeform_table[slot] = {}
	return slot


## Generate the creature for a blank slot, then apply the evolutions noted against it
## (p.158: "When you fill this entry, the creature will already be evolved").
func _materialise(campaign: Resource, slot: int) -> Dictionary:
	var note: Variant = campaign.lifeform_table[slot]
	var pending: Array = note.get("pending_evolutions", []) if note is Dictionary else []
	var lifeform: Dictionary = generate_lifeform()
	lifeform["slot_index"] = slot
	for evo_id in pending:
		_apply_to_profile(lifeform, _evolution_by_id(str(evo_id)))
	campaign.lifeform_table[slot] = lifeform
	return lifeform


## ============================================================================
## 4-STEP GENERATION
## ============================================================================

func generate_lifeform() -> Dictionary:
	## Full 4-step procedural lifeform generation (pp.146-150). Returns the profile.
	## Every die goes through DiceManager so the QA seam can force a creature; these were
	## raw randi_range calls until 2026-10-27.
	var profile: Dictionary = {}

	# Step 1: Mobility
	var mobility_roll: int = _d100("Planetfall Lifeform Mobility")
	var mobility: Dictionary = _resolve_mobility(mobility_roll)
	profile["speed"] = mobility.get("speed", 6)
	profile["partially_airborne"] = mobility.get("airborne", false)
	profile["mobility_roll"] = mobility_roll

	# Step 2a: Combat Skill
	var cs_roll: int = _d100("Planetfall Lifeform Combat Skill")
	var cs_entry: Dictionary = _lookup_sub_table("step_2a_combat_skill", cs_roll)
	profile["combat_skill"] = cs_entry.get("combat_skill", 0)

	# Step 2b: Strike Power
	var sp_roll: int = _d100("Planetfall Lifeform Strike Power")
	var sp_entry: Dictionary = _lookup_sub_table("step_2b_strike_power", sp_roll)
	profile["strike_damage"] = sp_entry.get("damage", 0)

	# Step 2c: Special Attacks (triggered if CS or SP roll ends in 0 or 5)
	var cs_triggers: bool = _ends_in_0_or_5(cs_roll)
	var sp_triggers: bool = _ends_in_0_or_5(sp_roll)
	profile["special_attacks"] = []
	if cs_triggers or sp_triggers:
		var sa_roll: int = _d100("Planetfall Lifeform Special Attack")
		var sa_entry: Dictionary = _lookup_sub_table("step_2c_special_attacks", sa_roll)
		if not sa_entry.is_empty():
			profile["special_attacks"].append(sa_entry)
	if cs_triggers and sp_triggers:
		# Roll twice, ignore duplicate
		var sa_roll2: int = _d100("Planetfall Lifeform Special Attack")
		var sa_entry2: Dictionary = _lookup_sub_table("step_2c_special_attacks", sa_roll2)
		if not sa_entry2.is_empty():
			var existing_ids: Array = []
			for sa in profile["special_attacks"]:
				existing_ids.append(sa.get("id", ""))
			if sa_entry2.get("id", "") not in existing_ids:
				profile["special_attacks"].append(sa_entry2)

	# Step 3: Defensive Abilities
	var def_roll: int = _d100("Planetfall Lifeform Defense")
	var def_entry: Dictionary = _lookup_sub_table("step_3_defensive_abilities", def_roll)
	profile["toughness"] = def_entry.get("toughness", 4)
	profile["kp"] = def_entry.get("kp", 0)
	profile["defense_additional"] = def_entry.get("additional", null)

	# Step 4: Unique Ability
	profile["unique_ability"] = roll_unique_ability()

	# Metadata
	profile["generated"] = true

	return profile


## Step 4, alone: also rolled afresh "each battle where the creature is encountered" once
## a lifeform has Dramatic transformations (p.159).
func roll_unique_ability(context: String = "Planetfall Lifeform Unique Ability") -> Dictionary:
	return _lookup_sub_table("step_4_unique_ability", _d100(context))


## ============================================================================
## EVOLUTION
## ============================================================================

func get_evolution(roll: int) -> Dictionary:
	## D100 lookup on Lifeform Evolution table.
	return _lookup_d100(_evolution_data, roll)


func apply_evolution(campaign: Resource, lifeform_slot: int, evolution_roll: int) -> Dictionary:
	## Apply an evolution to a specific lifeform on the encounter table.
	## Returns the evolution entry, or {} when that lifeform already has (or is waiting
	## for) this evolution: p.158 "exact duplicates require a reroll". A blank slot gets a
	## note, ADDED to any earlier one; a second evolution used to overwrite the first.
	var evolution: Dictionary = get_evolution(evolution_roll)
	if evolution.is_empty():
		return {}

	if not campaign or not "lifeform_table" in campaign:
		return evolution

	# Ensure table has 10 slots
	while campaign.lifeform_table.size() < 10:
		campaign.lifeform_table.append({})

	var evo_id: String = str(evolution.get("id", ""))
	var slot_data: Variant = campaign.lifeform_table[lifeform_slot]
	if evo_id in evolutions_on(slot_data):
		return {}
	if is_slot_filled(slot_data):
		_apply_to_profile(slot_data, evolution)
		# p.92: "If the profile of the Lifeform ever changes for any reason, including
		# evolution, any Bio-Analysis benefits are lost", and the new form is analyzed
		# "by following the same process again", which starts with a fresh sample.
		(slot_data as Dictionary).erase("bio_analysis")
		(slot_data as Dictionary).erase("sampled")
	else:
		var note: Dictionary = slot_data if slot_data is Dictionary else {}
		var pending: Array = note.get("pending_evolutions", [])
		pending.append(evo_id)
		note["pending_evolutions"] = pending
		campaign.lifeform_table[lifeform_slot] = note

	# Track in campaign
	if "lifeform_evolutions" in campaign:
		campaign.lifeform_evolutions.append({
			"slot": lifeform_slot,
			"evolution_id": evo_id,
			"evolution_roll": evolution_roll
		})

	return evolution


## Every evolution a slot has or is waiting for.
static func evolutions_on(entry: Variant) -> Array:
	if entry is not Dictionary:
		return []
	return (entry.get("evolutions_applied", []) as Array) \
			+ (entry.get("pending_evolutions", []) as Array)


## p.158: "Randomly select an entry on your Colony Tracking Sheet to evolve" (one of the
## ten), then roll D100, rerolling an exact duplicate. Both dice go through DiceManager so
## the QA seam can arm them ("Planetfall Evolution Slot", "Planetfall Lifeform Evolution").
func evolve_random(campaign: Resource) -> Dictionary:
	var slot: int = clampi(_d10("Planetfall Evolution Slot") - 1, 0, 9)
	var result: Dictionary = {"slot": slot, "rolls": [], "evolution": {}}
	if not campaign or not "lifeform_table" in campaign:
		return result
	while campaign.lifeform_table.size() < 10:
		campaign.lifeform_table.append({})
	if evolutions_on(campaign.lifeform_table[slot]).size() >= _evolution_data.size():
		result["exhausted"] = true
		return result
	for _i in range(EVOLUTION_REROLL_LIMIT):
		var roll: int = _d100("Planetfall Lifeform Evolution")
		result.rolls.append(roll)
		var evo: Dictionary = apply_evolution(campaign, slot, roll)
		if not evo.is_empty():
			result["evolution"] = evo
			result["pending"] = not is_slot_filled(campaign.lifeform_table[slot])
			return result
	return result


## The two evolutions that change the PROFILE (p.159); every other is a battle rule,
## recorded by id and shown at the table from the evolution's own text.
func _apply_to_profile(profile: Dictionary, evolution: Dictionary) -> void:
	if evolution.is_empty():
		return
	var applied: Array = profile.get("evolutions_applied", [])
	applied.append(str(evolution.get("id", "")))
	profile["evolutions_applied"] = applied
	var stat_changes: Dictionary = evolution.get("stat_changes", {}) \
			if evolution.get("stat_changes") is Dictionary else {}
	if stat_changes.has("combat_skill_min"):
		profile["combat_skill"] = maxi(int(profile.get("combat_skill", 0)),
				int(stat_changes.combat_skill_min))
	if stat_changes.has("speed_bonus"):
		profile["speed"] = int(profile.get("speed", 6)) + int(stat_changes.speed_bonus)
	if stat_changes.has("damage_min"):
		profile["strike_damage"] = maxi(int(profile.get("strike_damage", 0)),
				int(stat_changes.damage_min))
	# Dramatic Transformations: "Delete any Unique Ability ... each battle where the
	# creature is encountered, roll on the Unique Abilities table again".
	if str(evolution.get("id", "")) == "dramatic_transformations":
		profile["unique_ability"] = {}
		profile["unique_ability_each_battle"] = true


## The p.159-160 entry for an evolution id, so the battle card can print its rule text.
func evolution_entry(evo_id: String) -> Dictionary:
	return _evolution_by_id(evo_id)


## The p.148 Step 3 text for an additional defence code ("armor_save_5plus", "dodge"). A
## stored creature keeps only the code.
func defense_description(code: String) -> String:
	var table: Dictionary = _generation_data.get("step_3_defensive_abilities", {})
	for e in table.get("entries", []):
		if e is Dictionary and str(e.get("additional", "")) == code and e.has("description"):
			return str(e.description)
	return ""


## p.146: "the 6th one encountered during the mission will be a pack leader. Add +2 KP".
func pack_leader_threshold() -> int:
	return int(_generation_data.get("pack_leader_threshold", 6))


func pack_leader_bonus_kp() -> int:
	return int(_generation_data.get("pack_leader_bonus_kp", 2))


func _evolution_by_id(evo_id: String) -> Dictionary:
	for entry in _evolution_data:
		if entry is Dictionary and str(entry.get("id", "")) == evo_id:
			return entry.duplicate(true)
	return {}


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


static func _dice() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("/root/DiceManager") \
		if loop is SceneTree else null


func _d10(context: String) -> int:
	var dm := _dice()
	return int(dm.roll_d10(context)) if dm else randi_range(1, 10)


func _d100(context: String) -> int:
	var dm := _dice()
	return int(dm.roll_d100(context)) if dm else randi_range(1, 100)


func is_loaded() -> bool:
	return _loaded
