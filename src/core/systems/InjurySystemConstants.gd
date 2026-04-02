class_name InjurySystemConstants
## Injury System Constants for Five Parsecs Campaign Manager
## Data loaded from res://data/injury_results.json (Core Rules p.122)
##
## Usage: Reference these constants in post-battle injury processing
## Architecture: Lazy-loads JSON data, keeps enums and static helper API

## Injury type enumeration (matches Five Parsecs rulebook categories)
enum InjuryType {
	GRUESOME_FATE,      # 1-5: Dead + all carried equipment damaged
	FATAL,              # 6-15: Dead or permanently removed
	MIRACULOUS_ESCAPE,  # 16: No injury (+1 Luck, lose all items)
	EQUIPMENT_LOSS,     # 17-30: Equipment damaged/lost
	CRIPPLING_WOUND,    # 31-45: Requires surgery or long recovery
	SERIOUS_INJURY,     # 46-54: Extended recovery time
	MINOR_INJURY,       # 55-80: Short recovery
	KNOCKED_OUT,        # 81-95: Shaken but recovers
	HARD_KNOCKS         # 96-100: Learns from experience (+1 XP)
}

## Bot/Soulless injury type enumeration
enum BotInjuryType {
	OBLITERATED,       # 1-5: Destroyed + all equipment damaged
	DESTROYED,         # 6-15: Destroyed permanently
	EQUIPMENT_LOSS,    # 16-30: Random carried item damaged
	SEVERE_DAMAGE,     # 31-45: 1D6 repair turns required
	MINOR_DAMAGE,      # 46-65: 1 repair turn required
	JUST_A_FEW_DENTS   # 66-100: Cosmetic only, no repair needed
}

## Treatment types
enum TreatmentType {
	SICK_BAY,
	SURGERY,
	NATURAL,
}


## ==========================================
## JSON DATA LOADING
## ==========================================

const _DATA_PATH := "res://data/injury_results.json"

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("InjurySystemConstants: Failed to open %s" % _DATA_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	else:
		push_error("InjurySystemConstants: Failed to parse %s" % _DATA_PATH)
	file.close()


## ==========================================
## INTERNAL: Map JSON entry name → InjuryType enum
## ==========================================

const _HUMAN_NAME_MAP: Dictionary = {
	"Gruesome fate": InjuryType.GRUESOME_FATE,
	"Death or permanent injury": InjuryType.FATAL,
	"Miraculous escape": InjuryType.MIRACULOUS_ESCAPE,
	"Equipment loss": InjuryType.EQUIPMENT_LOSS,
	"Crippling wound": InjuryType.CRIPPLING_WOUND,
	"Serious injury": InjuryType.SERIOUS_INJURY,
	"Minor injuries": InjuryType.MINOR_INJURY,
	"Knocked out": InjuryType.KNOCKED_OUT,
	"School of hard knocks": InjuryType.HARD_KNOCKS,
}

const _BOT_NAME_MAP: Dictionary = {
	"Obliterated": BotInjuryType.OBLITERATED,
	"Destroyed": BotInjuryType.DESTROYED,
	"Equipment loss": BotInjuryType.EQUIPMENT_LOSS,
	"Severe damage": BotInjuryType.SEVERE_DAMAGE,
	"Minor damage": BotInjuryType.MINOR_DAMAGE,
	"Just a few dents": BotInjuryType.JUST_A_FEW_DENTS,
}

static func _get_human_entries() -> Array:
	_ensure_loaded()
	return _data.get("tables", {}).get("human", {}).get("entries", [])

static func _get_bot_entries() -> Array:
	_ensure_loaded()
	return _data.get("tables", {}).get("bot", {}).get("entries", [])


## ==========================================
## BACKWARD-COMPATIBLE PROPERTY ACCESSORS
## ==========================================

static var INJURY_ROLL_RANGES: Dictionary:
	get:
		var result := {}
		for entry in _get_human_entries():
			var injury_type: InjuryType = _HUMAN_NAME_MAP.get(entry.get("name", ""), InjuryType.MINOR_INJURY)
			var r: Array = entry.get("roll_range", [0, 0])
			result[injury_type] = {"min": r[0], "max": r[1]}
		return result

static var RECOVERY_TIMES: Dictionary:
	get:
		var result := {}
		for entry in _get_human_entries():
			var injury_type: InjuryType = _HUMAN_NAME_MAP.get(entry.get("name", ""), InjuryType.MINOR_INJURY)
			var recovery := {"min": 0, "max": 0, "description": ""}
			# Handle different recovery time formats from JSON
			if entry.has("recovery_time_roll"):
				var dice_str: String = entry["recovery_time_roll"]
				if dice_str == "1d6":
					recovery = {"min": 1, "max": 6, "dice": "1d6", "description": "1D6 turns OR surgery to instantly recover"}
				elif dice_str == "1d3+1":
					recovery = {"min": 2, "max": 4, "dice": "1d3+1", "description": "1D3+1 turns recovery time"}
			elif entry.has("recovery_time"):
				var rt: int = entry["recovery_time"]
				if rt > 0:
					recovery = {"min": rt, "max": rt, "dice": str(rt), "description": "%d turn recovery time" % rt}
				else:
					recovery["description"] = _get_recovery_description(injury_type)
			else:
				recovery["description"] = _get_recovery_description(injury_type)
			result[injury_type] = recovery
		return result

static func _get_recovery_description(injury_type: InjuryType) -> String:
	match injury_type:
		InjuryType.GRUESOME_FATE: return "Character is dead - all carried equipment damaged"
		InjuryType.FATAL: return "Character is dead - no recovery"
		InjuryType.MIRACULOUS_ESCAPE: return "No injury sustained"
		InjuryType.EQUIPMENT_LOSS: return "Equipment damaged/lost, no medical recovery needed"
		InjuryType.KNOCKED_OUT: return "Shaken but recovers immediately, no sick bay time"
		InjuryType.HARD_KNOCKS: return "Learns from experience, gains +1 XP, no recovery needed"
		_: return ""

static var INJURY_TYPE_NAMES: Dictionary:
	get:
		var result := {}
		for entry in _get_human_entries():
			var injury_type: InjuryType = _HUMAN_NAME_MAP.get(entry.get("name", ""), InjuryType.MINOR_INJURY)
			result[injury_type] = _injury_type_to_string(injury_type)
		return result

static func _injury_type_to_string(injury_type: InjuryType) -> String:
	match injury_type:
		InjuryType.GRUESOME_FATE: return "GRUESOME_FATE"
		InjuryType.FATAL: return "FATAL"
		InjuryType.MIRACULOUS_ESCAPE: return "MIRACULOUS_ESCAPE"
		InjuryType.EQUIPMENT_LOSS: return "EQUIPMENT_LOSS"
		InjuryType.CRIPPLING_WOUND: return "CRIPPLING_WOUND"
		InjuryType.SERIOUS_INJURY: return "SERIOUS_INJURY"
		InjuryType.MINOR_INJURY: return "MINOR_INJURY"
		InjuryType.KNOCKED_OUT: return "KNOCKED_OUT"
		InjuryType.HARD_KNOCKS: return "HARD_KNOCKS"
		_: return "UNKNOWN"

static var INJURY_DESCRIPTIONS: Dictionary:
	get:
		var result := {}
		for entry in _get_human_entries():
			var injury_type: InjuryType = _HUMAN_NAME_MAP.get(entry.get("name", ""), InjuryType.MINOR_INJURY)
			var effects: Array = entry.get("effects", [])
			var desc: String = entry.get("name", "Unknown")
			if effects.size() > 0:
				desc = "%s - %s" % [entry.get("name", "Unknown").to_upper(), effects[0]]
			result[injury_type] = desc
		return result

static var INJURY_PROPERTIES: Dictionary:
	get:
		var result := {}
		for entry in _get_human_entries():
			var injury_type: InjuryType = _HUMAN_NAME_MAP.get(entry.get("name", ""), InjuryType.MINOR_INJURY)
			var is_fatal: bool = entry.get("dead", false)
			var has_surgery: bool = entry.has("surgery_cost_roll") or entry.has("surgery_cost")
			var equip_lost: bool = false
			var all_equip: bool = false
			var bonus_xp: int = entry.get("xp_bonus", 0)
			# Derive equipment flags from effects text and injury type
			match injury_type:
				InjuryType.GRUESOME_FATE:
					equip_lost = true
					all_equip = true
				InjuryType.EQUIPMENT_LOSS:
					equip_lost = true
				InjuryType.CRIPPLING_WOUND:
					has_surgery = true
			result[injury_type] = {
				"is_fatal": is_fatal,
				"requires_surgery": has_surgery,
				"equipment_lost": equip_lost,
				"all_equipment": all_equip,
				"bonus_xp": bonus_xp,
			}
		return result

## Treatment options loaded from JSON
static var TREATMENT_OPTIONS: Dictionary:
	get:
		_ensure_loaded()
		var treatments := _data.get("treatment_options", {})
		var result := {}
		var type_map := {"sick_bay": TreatmentType.SICK_BAY, "surgery": TreatmentType.SURGERY, "natural": TreatmentType.NATURAL}
		for key in treatments:
			var treatment_type: TreatmentType = type_map.get(key, TreatmentType.NATURAL)
			var src: Dictionary = treatments[key]
			var entry := {
				"name": src.get("name", ""),
				"description": src.get("description", ""),
			}
			if src.has("cost_per_turn"):
				entry["cost_per_turn"] = src["cost_per_turn"]
			if src.has("cost_dice"):
				entry["cost_dice"] = src["cost_dice"]
				entry["cost_min"] = src.get("cost_min", 1)
				entry["cost_max"] = src.get("cost_max", 6)
			if src.has("effect"):
				entry["effect"] = src["effect"]
			# Map injury name strings to enums
			var applicable: Array = []
			for injury_name in src.get("applicable_injuries", []):
				match injury_name:
					"CRIPPLING_WOUND": applicable.append(InjuryType.CRIPPLING_WOUND)
					"SERIOUS_INJURY": applicable.append(InjuryType.SERIOUS_INJURY)
					"MINOR_INJURY": applicable.append(InjuryType.MINOR_INJURY)
			entry["applicable_to"] = applicable
			result[treatment_type] = entry
		return result


## ==========================================
## BOT INJURY BACKWARD-COMPATIBLE ACCESSORS
## ==========================================

static var BOT_INJURY_ROLL_RANGES: Dictionary:
	get:
		var result := {}
		for entry in _get_bot_entries():
			var injury_type: BotInjuryType = _BOT_NAME_MAP.get(entry.get("name", ""), BotInjuryType.JUST_A_FEW_DENTS)
			var r: Array = entry.get("roll_range", [0, 0])
			result[injury_type] = {"min": r[0], "max": r[1]}
		return result

static var BOT_RECOVERY_TIMES: Dictionary:
	get:
		var result := {}
		for entry in _get_bot_entries():
			var injury_type: BotInjuryType = _BOT_NAME_MAP.get(entry.get("name", ""), BotInjuryType.JUST_A_FEW_DENTS)
			var recovery := {"min": 0, "max": 0, "description": ""}
			if entry.has("recovery_time_roll"):
				var dice_str: String = entry["recovery_time_roll"]
				if dice_str == "1d6":
					recovery = {"min": 1, "max": 6, "dice": "1d6", "description": "Severe damage, 1D6 repair turns required"}
			elif entry.has("recovery_time"):
				var rt: int = entry["recovery_time"]
				if rt > 0:
					recovery = {"min": rt, "max": rt, "dice": str(rt), "description": "Minor damage, %d repair turn required" % rt}
			result[injury_type] = recovery
		return result

static var BOT_INJURY_TYPE_NAMES: Dictionary:
	get:
		var result := {}
		for entry in _get_bot_entries():
			var injury_type: BotInjuryType = _BOT_NAME_MAP.get(entry.get("name", ""), BotInjuryType.JUST_A_FEW_DENTS)
			result[injury_type] = _bot_injury_type_to_string(injury_type)
		return result

static func _bot_injury_type_to_string(injury_type: BotInjuryType) -> String:
	match injury_type:
		BotInjuryType.OBLITERATED: return "OBLITERATED"
		BotInjuryType.DESTROYED: return "DESTROYED"
		BotInjuryType.EQUIPMENT_LOSS: return "EQUIPMENT_LOSS"
		BotInjuryType.SEVERE_DAMAGE: return "SEVERE_DAMAGE"
		BotInjuryType.MINOR_DAMAGE: return "MINOR_DAMAGE"
		BotInjuryType.JUST_A_FEW_DENTS: return "JUST_A_FEW_DENTS"
		_: return "UNKNOWN"

static var BOT_INJURY_DESCRIPTIONS: Dictionary:
	get:
		var result := {}
		for entry in _get_bot_entries():
			var injury_type: BotInjuryType = _BOT_NAME_MAP.get(entry.get("name", ""), BotInjuryType.JUST_A_FEW_DENTS)
			var effects: Array = entry.get("effects", [])
			var desc: String = entry.get("name", "Unknown").to_upper()
			if effects.size() > 0:
				desc = "%s - %s" % [desc, effects[0]]
			result[injury_type] = desc
		return result

static var BOT_INJURY_PROPERTIES: Dictionary:
	get:
		var result := {}
		for entry in _get_bot_entries():
			var injury_type: BotInjuryType = _BOT_NAME_MAP.get(entry.get("name", ""), BotInjuryType.JUST_A_FEW_DENTS)
			var is_fatal: bool = entry.get("destroyed", false)
			var equip_damaged: bool = false
			var all_equip: bool = false
			match injury_type:
				BotInjuryType.OBLITERATED:
					equip_damaged = true
					all_equip = true
				BotInjuryType.EQUIPMENT_LOSS:
					equip_damaged = true
			result[injury_type] = {
				"is_fatal": is_fatal,
				"equipment_damaged": equip_damaged,
				"all_equipment": all_equip,
			}
		return result


## ==========================================
## HELPER FUNCTIONS (unchanged public API)
## ==========================================

static func get_injury_type_from_roll(roll: int) -> InjuryType:
	for entry in _get_human_entries():
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			return _HUMAN_NAME_MAP.get(entry.get("name", ""), InjuryType.MINOR_INJURY)
	return InjuryType.MINOR_INJURY

static func get_injury_description(injury_type: InjuryType) -> String:
	return INJURY_DESCRIPTIONS.get(injury_type, "Unknown injury")

static func get_recovery_time(injury_type: InjuryType) -> Dictionary:
	return RECOVERY_TIMES.get(injury_type, {"min": 0, "max": 0, "description": "Unknown injury type"})

static func is_fatal_injury(injury_type: InjuryType) -> bool:
	var properties: Dictionary = INJURY_PROPERTIES.get(injury_type, {})
	return properties.get("is_fatal", false)

static func is_fatal(injury_type: InjuryType) -> bool:
	return is_fatal_injury(injury_type)

static func requires_surgery(injury_type: InjuryType) -> bool:
	var properties: Dictionary = INJURY_PROPERTIES.get(injury_type, {})
	return properties.get("requires_surgery", false)

static func causes_equipment_loss(injury_type: InjuryType) -> bool:
	var properties: Dictionary = INJURY_PROPERTIES.get(injury_type, {})
	return properties.get("equipment_lost", false)

static func get_bonus_xp(injury_type: InjuryType) -> int:
	var properties: Dictionary = INJURY_PROPERTIES.get(injury_type, {})
	return properties.get("bonus_xp", 0)

static func get_base_recovery_turns(injury_type: InjuryType) -> int:
	var recovery_info: Dictionary = get_recovery_time(injury_type)
	return recovery_info.get("max", 0)

static func get_injury_special_effect(injury_type: InjuryType) -> String:
	match injury_type:
		InjuryType.GRUESOME_FATE:
			return "All carried equipment is damaged"
		InjuryType.HARD_KNOCKS:
			return "Character gains +1 XP from learning experience"
		InjuryType.CRIPPLING_WOUND:
			return "Can be instantly healed with surgery"
		InjuryType.EQUIPMENT_LOSS:
			return "Random equipment item damaged or destroyed"
		InjuryType.MIRACULOUS_ESCAPE:
			return "No injury sustained despite being knocked out"
		_:
			return ""

## Treatment helpers
static func get_treatment_options(injury_type: InjuryType) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for treatment_type in TREATMENT_OPTIONS.keys():
		var treatment: Dictionary = TREATMENT_OPTIONS[treatment_type]
		var applicable: Array = treatment.get("applicable_to", [])
		if injury_type in applicable:
			var option: Dictionary = treatment.duplicate()
			option["treatment_type"] = treatment_type
			options.append(option)
	return options

static func calculate_sick_bay_cost(remaining_turns: int) -> int:
	var cost_per: int = TREATMENT_OPTIONS.get(TreatmentType.SICK_BAY, {}).get("cost_per_turn", 4)
	return remaining_turns * cost_per

static func roll_surgery_cost() -> int:
	return randi_range(1, 6)

## Bot injury helpers
static func get_bot_injury_type_from_roll(roll: int) -> BotInjuryType:
	for entry in _get_bot_entries():
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			return _BOT_NAME_MAP.get(entry.get("name", ""), BotInjuryType.JUST_A_FEW_DENTS)
	return BotInjuryType.JUST_A_FEW_DENTS

static func get_bot_injury_description(injury_type: BotInjuryType) -> String:
	return BOT_INJURY_DESCRIPTIONS.get(injury_type, "Unknown bot injury")

static func get_bot_recovery_time(injury_type: BotInjuryType) -> Dictionary:
	return BOT_RECOVERY_TIMES.get(injury_type, {"min": 0, "max": 0, "description": "Unknown"})

static func is_bot_fatal_injury(injury_type: BotInjuryType) -> bool:
	var properties: Dictionary = BOT_INJURY_PROPERTIES.get(injury_type, {})
	return properties.get("is_fatal", false)

static func bot_causes_equipment_loss(injury_type: BotInjuryType) -> bool:
	var properties: Dictionary = BOT_INJURY_PROPERTIES.get(injury_type, {})
	return properties.get("equipment_damaged", false)
