# Scripts/ShipAndCrew/MedicalBayComponent.gd
@tool
extends ShipComponent
class_name MedicalBayComponent

@export var healing_rate: float = 1.0
@export var capacity: int = 2
@export var medical_tech_level: int = 1
@export var has_advanced_surgery: bool = false
@export var has_trauma_unit: bool = false
@export var current_patients: Array = []
@export var medical_supplies: int = 100

func _init() -> void:
	super()
	name = "Medical Bay"
	description = "Basic medical facility"
	cost = 350
	power_draw = 3
	
func _apply_upgrade_effects() -> void:
	super()
	healing_rate += 0.5
	capacity += 1
	medical_tech_level = min(medical_tech_level + 1, 5)
	medical_supplies += 25

func get_healing_rate() -> float:
	return healing_rate * get_efficiency()

func get_effective_capacity() -> int:
	return capacity

func is_full() -> bool:
	return current_patients.size() >= get_effective_capacity()

func has_supplies() -> bool:
	return medical_supplies > 0

# Add a patient to the medical bay
func add_patient(patient_data: Dictionary) -> bool:
	if is_full() or not is_active:
		return false
		
	if not current_patients.has(patient_data):
		current_patients.append(patient_data)
		return true
	return false

# Remove a patient from the medical bay
func remove_patient(patient_id: String) -> Dictionary:
	for i in range(current_patients.size()):
		if current_patients[i].get("id") == patient_id:
			var patient = current_patients[i]
			current_patients.remove_at(i)
			return patient
	return {}

# Process healing for all patients
func process_healing(delta: float) -> Array:
	var healed_patients = []
	
	if not is_active or not has_supplies():
		return healed_patients
		
	for patient in current_patients:
		if patient.get("current_health", 0) < patient.get("max_health", 100):
			var healing = get_healing_rate() * delta
			
			# Advanced surgery bonus for critically injured
			if has_advanced_surgery and patient.get("current_health", 0) < 25:
				healing *= 1.5
				
			# Trauma unit bonus for recently injured
			if has_trauma_unit and patient.get("turns_injured", 0) < 3:
				healing *= 1.3
				
			patient.current_health = min(patient.get("max_health", 100), patient.get("current_health", 0) + healing)
			
			# Reduce medical supplies
			medical_supplies = max(0, medical_supplies - 0.1)
			
			# If patient is fully healed, add to list
			if patient.get("current_health") >= patient.get("max_health"):
				healed_patients.append(patient)
	
	# Remove healed patients
	for patient in healed_patients:
		current_patients.erase(patient)
		
	return healed_patients

# Restock medical supplies
func restock_supplies(amount: int) -> int:
	var before = medical_supplies
	medical_supplies = min(100, medical_supplies + amount)
	return medical_supplies - before

func serialize() -> Dictionary:
	var data = super()
	data["healing_rate"] = healing_rate
	data["capacity"] = capacity
	data["medical_tech_level"] = medical_tech_level
	data["has_advanced_surgery"] = has_advanced_surgery
	data["has_trauma_unit"] = has_trauma_unit
	data["current_patients"] = current_patients
	data["medical_supplies"] = medical_supplies
	return data

# Factory method to create MedicalBayComponent from data
static func create_from_data(data: Dictionary) -> MedicalBayComponent:
	var component = MedicalBayComponent.new()
	var base_data = ShipComponent.deserialize(data)
	
	# Copy base data
	component.name = base_data.name
	component.description = base_data.description
	component.cost = base_data.cost
	component.level = base_data.level
	component.max_level = base_data.max_level
	component.is_active = base_data.is_active
	component.upgrade_cost = base_data.upgrade_cost
	component.maintenance_cost = base_data.maintenance_cost
	component.durability = base_data.durability
	component.max_durability = base_data.max_durability
	component.efficiency = base_data.efficiency
	component.power_draw = base_data.power_draw
	component.status_effects = base_data.status_effects
	
	# Medical-specific properties
	component.healing_rate = data.get("healing_rate", 1.0)
	component.capacity = data.get("capacity", 2)
	component.tech_level = data.get("tech_level", 1)
	component.has_advanced_surgery = data.get("has_advanced_surgery", false)
	component.has_trauma_unit = data.get("has_trauma_unit", false)
	component.current_patients = data.get("current_patients", [])
	component.medical_supplies = data.get("medical_supplies", 100)
	
	return component

# Return serialized data with proper medical bay type
static func deserialize(data: Dictionary) -> Dictionary:
	var base_data = ShipComponent.deserialize(data)
	base_data["component_type"] = "medical_bay"
	base_data["healing_rate"] = data.get("healing_rate", 1.0)
	base_data["capacity"] = data.get("capacity", 2)
	base_data["tech_level"] = data.get("tech_level", 1)
	base_data["has_advanced_surgery"] = data.get("has_advanced_surgery", false)
	base_data["has_trauma_unit"] = data.get("has_trauma_unit", false)
	base_data["current_patients"] = data.get("current_patients", [])
	base_data["medical_supplies"] = data.get("medical_supplies", 100)
	return base_data
