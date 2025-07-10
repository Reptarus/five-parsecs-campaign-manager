class_name InjuryRecoverySystem
extends Resource

## Advanced Injury and Recovery System for Five Parsecs Campaign Manager
## Implements detailed injury mechanics from Five Parsecs Core Rules

signal injury_sustained(character: Resource, injury: InjuryType)
signal recovery_progress(character: Resource, progress: Dictionary)
signal full_recovery(character: Resource)
signal medical_treatment_applied(character: Resource, treatment: Dictionary)
signal injury_complication(character: Resource, complication: String)

# Injury types based on Five Parsecs rules
enum InjuryType {
	LIGHT_INJURY,
	SERIOUS_INJURY,
	CRITICAL_INJURY,
	PERMANENT_INJURY,
	LUCKY_ESCAPE
}

# Injury severity levels
enum InjurySeverity {
	MINOR, # 1-2 recovery turns
	MODERATE, # 3-4 recovery turns
	SEVERE, # 5-6 recovery turns
	CRITICAL, # 7+ recovery turns
	PERMANENT # Never fully heals
}

# Treatment types available
enum TreatmentType {
	FIELD_MEDICINE,
	BASIC_MEDICAL,
	ADVANCED_MEDICAL,
	SURGERY,
	CYBERNETIC_TREATMENT,
	STIM_PACK
}

# Medical equipment effects
var medical_equipment_bonuses = {
	"med_kit": {"healing_bonus": 1, "complication_reduction": 0.1},
	"auto_doc": {"healing_bonus": 2, "complication_reduction": 0.2},
	"nano_doc": {"healing_bonus": 3, "complication_reduction": 0.3},
	"surgical_kit": {"surgery_bonus": 2, "infection_resistance": 0.5}
}

# Injury definitions with Five Parsecs flavor
var injury_catalog = {
	InjuryType.LIGHT_INJURY: {
		"types": ["Bruised", "Winded", "Shaken", "Minor Cut", "Scraped"],
		"recovery_time": [1, 2],
		"stat_penalties": {"speed": - 1},
		"description_templates": [
			"%s took a hard knock and is moving slower.",

			"%s has some bruising but should recover quickly.",
			"%s is shaken but still combat effective."
		]
	},
	InjuryType.SERIOUS_INJURY: {
		"types": ["Wounded", "Stunned", "Bleeding", "Concussion", "Strained"],
		"recovery_time": [3, 5],
		"stat_penalties": {"combat": - 1, "speed": - 1},
		"description_templates": [
			"%s sustained a serious wound requiring medical attention.",
			"%s is badly hurt and needs time to recover.",
			"%s took a nasty hit and is struggling to focus."
		]
	},
	InjuryType.CRITICAL_INJURY: {
		"types": ["Crippled", "Unconscious", "Severe Trauma", "Internal Bleeding", "Fractured"],
		"recovery_time": [6, 10],
		"stat_penalties": {"combat": - 2, "speed": - 2, "reaction": - 1},
		"description_templates": [
			"%s is critically injured and may not survive without treatment.",
			"%s sustained life-threatening injuries.",
			"%s is in critical condition and needs immediate medical care."
		]
	},
	InjuryType.PERMANENT_INJURY: {
		"types": ["Scarred", "Cybernetic Limb", "Neural Damage", "Chronic Pain", "Prosthetic"],
		"recovery_time": [999], # Never fully recovers
		"stat_penalties": {"varies": - 1},
		"description_templates": [
			"%s sustained permanent injuries that will affect them for life.",

			"%s's injury has left lasting damage.",
			"%s bears the scars of battle permanently."
		]
	}
}

# Character injury tracking
var character_injuries: Dictionary = {} # character_id -> Array[InjuryData]
var active_treatments: Dictionary = {} # character_id -> Array[TreatmentData]
var medical_facilities: Array[Dictionary] = [] # Available medical facilities

func _init() -> void:
	_initialize_medical_facilities()

## ===== INJURY SYSTEM =====
func sustain_injury(character: Resource, damage_amount: int, damage_source: String = "combat") -> Dictionary:
	"""Apply injury based on damage taken and character stats"""
	if not character:
		return {"injury_type": null, "success": false}

	var character_id: String = _get_character_id(character)

	var toughness: int = character.get("toughness") if character and character.has_method("get") else 0

	# Determine injury severity based on damage vs toughness
	var injury_severity = _calculate_injury_severity(damage_amount, toughness)
	var injury_type = _determine_injury_type(injury_severity, damage_source)

	# Create injury data
	var injury_data = _create_injury_data(injury_type, damage_source, character)

	# Apply the injury
	_apply_injury_to_character(character, injury_data)

	# Track the injury
	if not character_injuries.has(character_id):
		character_injuries[character_id] = []
	character_injuries[character_id].append(injury_data)

	injury_sustained.emit(character, injury_type)

	return {
		"injury_type": injury_type,
		"injury_data": injury_data,
		"success": true,
		"description": injury_data.description
	}

func _calculate_injury_severity(damage: int, toughness: int) -> InjurySeverity:
	"""Calculate injury severity based on damage and toughness"""
	var damage_ratio = float(damage) / max(1, toughness)

	if damage_ratio <= 0.5:
		return InjurySeverity.MINOR
	elif damage_ratio <= 1.0:
		return InjurySeverity.MODERATE
	elif damage_ratio <= 2.0:
		return InjurySeverity.SEVERE
	elif damage_ratio <= 3.0:
		return InjurySeverity.CRITICAL
	else:
		return InjurySeverity.PERMANENT

func _determine_injury_type(severity: InjurySeverity, source: String) -> InjuryType:
	"""Determine specific injury type based on severity and source"""
	# Roll for luck - chance to reduce severity
	var luck_roll = randi_range(1, 6)
	if luck_roll == 6: # Lucky escape
		return InjuryType.LUCKY_ESCAPE

	match severity:
		InjurySeverity.MINOR:
			return InjuryType.LIGHT_INJURY
		InjurySeverity.MODERATE:
			return InjuryType.SERIOUS_INJURY
		InjurySeverity.SEVERE:
			return InjuryType.CRITICAL_INJURY
		InjurySeverity.CRITICAL, InjurySeverity.PERMANENT:
			# Roll to see if it becomes permanent
			var permanent_roll = randi_range(1, 6)
			if permanent_roll >= 5:
				return InjuryType.PERMANENT_INJURY
			else:
				return InjuryType.CRITICAL_INJURY
		_:
			return InjuryType.LIGHT_INJURY

func _create_injury_data(injury_type: InjuryType, source: String, character: Resource) -> Dictionary:
	"""Create detailed injury data"""

	var injury_info = injury_catalog.get(injury_type, injury_catalog[InjuryType.LIGHT_INJURY])
	var specific_injury = injury_info.types.pick_random()
	var recovery_range = injury_info.recovery_time
	var recovery_time = randi_range(recovery_range[0], recovery_range[-1])

	var character_name = "Unknown"
	if character and character.has_method("get") and character.has("character_name"):
		character_name = character.get("character_name")
	
	var description_template = injury_info.description_templates.pick_random()
	var description = description_template % character_name

	return {
		"injury_id": _generate_injury_id(),
		"injury_type": injury_type,
		"specific_injury": specific_injury,
		"source": source,
		"recovery_time": recovery_time,
		"current_recovery": 0,
		"stat_penalties": injury_info.stat_penalties.duplicate(),
		"description": description,
		"timestamp": Time.get_unix_time_from_system(),
		"complications": [],
		"treated": false,
		"treatment_history": []
	}

func _apply_injury_to_character(character: Resource, injury_data: Dictionary) -> void:
	"""Apply injury effects to character"""
	if not character or not character.has_method("set"):
		return

	# Apply stat penalties
	for stat in injury_data.stat_penalties.keys():
		if stat == "varies":
			# For permanent injuries, randomly select a stat to penalize
			var stats = ["combat", "speed", "reaction", "toughness"]
			stat = stats.pick_random()

		var current_value: int = character.get(stat) if character and character.has_method("get") else 0
		var penalty = injury_data.stat_penalties[stat]
		if character and character.has_method("set"): character.set(stat, max(0, current_value + penalty))

	# Set wounded status
	if injury_data.injury_type >= InjuryType.SERIOUS_INJURY:
		if character and character.has_method("set"): character.set("is_wounded", true)

## ===== MEDICAL TREATMENT SYSTEM =====

func apply_medical_treatment(character: Resource, treatment_type: TreatmentType, medical_equipment: Array = []) -> Dictionary:
	"""Apply medical treatment to an injured character"""
	var character_id: String = _get_character_id(character)

	var injuries = character_injuries.get(character_id, [])

	if injuries.is_empty():
		return {"success": false, "message": "No injuries to treat"}

	# Calculate treatment effectiveness
	var treatment_effectiveness = _calculate_treatment_effectiveness(treatment_type, medical_equipment)
	var complications_risk = _calculate_complications_risk(treatment_type, medical_equipment)

	var treatment_results: Array = []

	# Apply treatment to all active injuries
	for injury in injuries:
		if injury.current_recovery >= injury.recovery_time:
			continue # Already recovered

		var treatment_result = _apply_treatment_to_injury(injury, treatment_effectiveness, complications_risk)

		treatment_results.append(treatment_result)

		# Record treatment in injury history
		injury.treatment_history.append({
			"treatment_type": treatment_type,
			"effectiveness": treatment_effectiveness,
			"timestamp": Time.get_unix_time_from_system(),
			"equipment_used": medical_equipment
		})
		injury.treated = true

	# Create treatment record
	var treatment_data = {
		"treatment_type": treatment_type,
		"effectiveness": treatment_effectiveness,
		"results": treatment_results,
		"timestamp": Time.get_unix_time_from_system()
	}

	if not active_treatments.has(character_id):
		active_treatments[character_id] = []
	active_treatments[character_id].append(treatment_data)

	medical_treatment_applied.emit(character, treatment_data)

	return {"success": true, "treatment_data": treatment_data}

func _calculate_treatment_effectiveness(treatment_type: TreatmentType, equipment: Array) -> float:
	"""Calculate how effective a treatment will be"""
	var base_effectiveness: int = 1

	match treatment_type:
		TreatmentType.FIELD_MEDICINE:
			base_effectiveness = 0.5
		TreatmentType.BASIC_MEDICAL:
			base_effectiveness = 1.0
		TreatmentType.ADVANCED_MEDICAL:
			base_effectiveness = 1.5
		TreatmentType.SURGERY:
			base_effectiveness = 2.0
		TreatmentType.CYBERNETIC_TREATMENT:
			base_effectiveness = 2.5
		TreatmentType.STIM_PACK:
			base_effectiveness = 0.8

	# Apply equipment bonuses
	for item in equipment:
		var equipment_name = item.get("name", "") if item and item.has_method("get") else str(item)
		if equipment_name in medical_equipment_bonuses:
			var bonus = medical_equipment_bonuses[equipment_name].get("healing_bonus", 0)
			base_effectiveness += bonus * 0.2

	return base_effectiveness

func _calculate_complications_risk(treatment_type: TreatmentType, equipment: Array) -> float:
	"""Calculate risk of treatment complications"""
	var base_risk: int = 0

	match treatment_type:
		TreatmentType.FIELD_MEDICINE:
			base_risk = 0.3
		TreatmentType.BASIC_MEDICAL:
			base_risk = 0.15
		TreatmentType.ADVANCED_MEDICAL:
			base_risk = 0.05
		TreatmentType.SURGERY:
			base_risk = 0.2
		TreatmentType.CYBERNETIC_TREATMENT:
			base_risk = 0.1
		TreatmentType.STIM_PACK:
			base_risk = 0.25

	# Reduce risk with proper equipment
	for item in equipment:
		var equipment_name = item.get("name", "") if item and item.has_method("get") else str(item)
		if equipment_name in medical_equipment_bonuses:
			var reduction = medical_equipment_bonuses[equipment_name].get("complication_reduction", 0)
			base_risk -= reduction

	return max(0.01, base_risk)

func _apply_treatment_to_injury(injury: Dictionary, effectiveness: float, complication_risk: float) -> Dictionary:
	"""Apply treatment effects to a specific injury"""
	var recovery_boost = int(effectiveness * 2)
	injury.current_recovery += recovery_boost

	# Check for complications
	var complication_occurred: bool = false
	if randf() < complication_risk:
		complication_occurred = true
		var complication = _generate_complication(injury)
		injury.complications.append(complication)
		injury_complication.emit(null, complication) # Would need character reference  # warning: return value discarded (intentional)

	return {
		"injury_id": injury.injury_id,
		"recovery_boost": recovery_boost,
		"complication": complication_occurred,
		"new_recovery_progress": injury.current_recovery,
		"total_recovery_needed": injury.recovery_time
	}

## ===== RECOVERY PROCESSING =====

func process_natural_recovery(character: Resource, turns_passed: int = 1) -> Dictionary:
	"""Process natural recovery over time"""
	var character_id: String = _get_character_id(character)

	var injuries = character_injuries.get(character_id, [])

	if injuries.is_empty():
		return {"recovered_injuries": [], "active_injuries": 0}

	var recovered_injuries: Array = []
	var updated_injuries: Array = []

	for injury in injuries:
		# Natural recovery is slower than medical treatment
		injury.current_recovery += turns_passed * 0.5

		# Check if fully recovered
		if injury.current_recovery >= injury.recovery_time:
			recovered_injuries.append(injury)
			_remove_injury_effects(character, injury)
		else:
			updated_injuries.append(injury)

	# Update the injuries list
	character_injuries[character_id] = updated_injuries

	# Emit recovery signals
	if not recovered_injuries.is_empty():
		for injury in recovered_injuries:
			recovery_progress.emit(character, {"injury": injury, "status": "recovered"})

		if updated_injuries.is_empty():
			full_recovery.emit(character)

	return {
		"recovered_injuries": recovered_injuries,
		"active_injuries": updated_injuries.size(),
		"recovery_progress": _calculate_total_recovery_progress(updated_injuries)
	}

func _remove_injury_effects(character: Resource, injury: Dictionary) -> void:
	"""Remove injury effects when recovered"""
	if not character or not character.has_method("set") or not character.has_method("get"):
		return

	# Restore stat penalties (careful not to exceed original values)
	for stat in injury.stat_penalties.keys():
		if stat == "varies":
			continue # Can't automatically restore varied penalties

		var penalty = injury.stat_penalties[stat]

		var current_value: int = character.get(stat) if character and character.has_method("get") else 0
		if character and character.has_method("set"): character.set(stat, current_value - penalty) # Remove the penalty

	# Check if character should no longer be wounded
	var character_id: String = _get_character_id(character)

	var remaining_injuries = character_injuries.get(character_id, [])
	var has_serious_injuries: bool = false

	for remaining_injury in remaining_injuries:
		if remaining_injury.injury_type >= InjuryType.SERIOUS_INJURY:
			has_serious_injuries = true
			break

	if not has_serious_injuries:
		if character and character.has_method("set"): character.set("is_wounded", false)

## ===== MEDICAL FACILITIES =====

func _initialize_medical_facilities() -> void:
	"""Initialize available medical facility types"""
	medical_facilities = [
		{
			"name": "Ship Medical Bay",
			"type": "basic",
			"treatment_bonus": 1.2,
			"available_treatments": [TreatmentType.BASIC_MEDICAL, TreatmentType.STIM_PACK],
			"cost_per_treatment": 50
		},
		{
			"name": "Planet Medical Center",
			"type": "advanced",
			"treatment_bonus": 1.5,
			"available_treatments": [TreatmentType.BASIC_MEDICAL, TreatmentType.ADVANCED_MEDICAL, TreatmentType.SURGERY],
			"cost_per_treatment": 200
		},
		{
			"name": "Core World Hospital",
			"type": "cutting_edge",
			"treatment_bonus": 2.0,
			"available_treatments": [TreatmentType.ADVANCED_MEDICAL, TreatmentType.SURGERY, TreatmentType.CYBERNETIC_TREATMENT],
			"cost_per_treatment": 500
		}
	]

## ===== UTILITY FUNCTIONS =====
func get_character_injury_status(character: Resource) -> Dictionary:
	"""Get comprehensive injury status for a character"""
	var character_id: String = _get_character_id(character)

	var injuries = character_injuries.get(character_id, [])

	var treatments = active_treatments.get(character_id, [])

	var active_injuries = injuries.filter(func(injury): return injury.current_recovery < injury.recovery_time)
	var total_recovery_progress = _calculate_total_recovery_progress(active_injuries)

	return {
		"character_id": character_id,
		"total_injuries": injuries.size(),
		"active_injuries": active_injuries.size(),
		"recovery_progress": total_recovery_progress,
		"is_critically_injured": _has_critical_injuries(active_injuries),
		"estimated_recovery_time": _estimate_recovery_time(active_injuries),
		"recent_treatments": treatments.slice(-3) # Last 3 treatments
	}

func _generate_complication(injury: Dictionary) -> String:
	"""Generate a random medical complication"""
	var complications = [
		"Infection risk increased",
		"Slow healing response",
		"Nerve damage detected",
		"Scarring likely",
		"Requires follow-up treatment",
		"Allergic reaction to treatment",
		"Secondary injury from treatment"
	]
	return complications.pick_random()

func _has_critical_injuries(injuries: Array) -> bool:
	"""Check if character has any critical injuries"""
	for injury in injuries:
		if injury.injury_type >= InjuryType.CRITICAL_INJURY:
			return true
	return false

func _estimate_recovery_time(injuries: Array) -> int:
	"""Estimate total recovery time for all injuries"""
	var max_time: int = 0
	for injury in injuries:
		var remaining_time = injury.recovery_time - injury.current_recovery
		max_time = max(max_time, remaining_time)
	return max_time

func _calculate_total_recovery_progress(injuries: Array) -> float:
	"""Calculate overall recovery progress as percentage"""
	if injuries.is_empty():
		return 1.0

	var total_progress: int = 0
	for injury in injuries:
		var progress = float(injury.current_recovery) / injury.recovery_time
		total_progress += min(1.0, progress)

	return total_progress / injuries.size()

func _get_character_id(character: Resource) -> String:
	"""Get unique identifier for character"""
	if character and character.has_method("get") and character.has("character_id"):
		return character.get("character_id")
	return str(character.get_instance_id())

func _generate_injury_id() -> String:
	"""Generate unique injury ID"""
	return "injury_" + str(Time.get_unix_time_from_system()) + "_" + str(randi_range(1000, 9999))

## ===== SERIALIZATION =====

func serialize() -> Dictionary:
	"""Serialize injury system state"""
	return {
		"character_injuries": character_injuries,
		"active_treatments": active_treatments,
		"medical_facilities": medical_facilities
	}

func deserialize(data: Dictionary) -> void:
	"""Restore injury system state"""

	character_injuries = data.get("character_injuries", {})

	active_treatments = data.get("active_treatments", {})

	medical_facilities = data.get("medical_facilities", [])
	if medical_facilities.is_empty():
		_initialize_medical_facilities()

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:

	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(obj):
		return default_value
	if obj and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	return default_value

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null