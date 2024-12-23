# Scripts/ShipAndCrew/MedicalBayComponent.gd
class_name MedicalBayComponent
extends ShipComponent

@export var healing_rate: float = 1.0
@export var capacity: int = 2
@export var treatment_quality: float = 1.0
@export var supplies_efficiency: float = 1.0

var current_patients: Array = []
var treatment_progress: Dictionary = {}

func _init() -> void:
	super()
	name = "Medical Bay"
	description = "Standard medical facility"
	cost = 300
	power_draw = 2

func _apply_upgrade_effects() -> void:
	super()
	healing_rate += 0.2
	capacity += 1
	treatment_quality += 0.1
	supplies_efficiency += 0.1

func get_healing_rate() -> float:
	return healing_rate * get_efficiency()

func get_treatment_quality() -> float:
	return treatment_quality * get_efficiency()

func get_supplies_efficiency() -> float:
	return supplies_efficiency * get_efficiency()

func get_available_beds() -> int:
	return capacity - current_patients.size()

func can_admit_patient(patient: Dictionary) -> bool:
	return is_active and get_available_beds() > 0

func admit_patient(patient: Dictionary) -> bool:
	if not can_admit_patient(patient):
		return false
		
	current_patients.append(patient)
	treatment_progress[patient.id] = 0.0
	return true

func discharge_patient(patient: Dictionary) -> void:
	current_patients.erase(patient)
	treatment_progress.erase(patient.id)

func update_treatment(delta: float) -> void:
	if not is_active:
		return
		
	for patient in current_patients:
		var progress = treatment_progress[patient.id]
		progress += get_healing_rate() * delta
		
		if progress >= 100.0:
			_complete_treatment(patient)
		else:
			treatment_progress[patient.id] = progress

func get_treatment_progress(patient: Dictionary) -> float:
	return treatment_progress.get(patient.id, 0.0)

func _complete_treatment(patient: Dictionary) -> void:
	patient.health = patient.max_health
	discharge_patient(patient)

func serialize() -> Dictionary:
	var data = super()
	data["healing_rate"] = healing_rate
	data["capacity"] = capacity
	data["treatment_quality"] = treatment_quality
	data["supplies_efficiency"] = supplies_efficiency
	data["current_patients"] = current_patients.duplicate()
	data["treatment_progress"] = treatment_progress.duplicate()
	return data

static func deserialize(data: Dictionary) -> MedicalBayComponent:
	var component = MedicalBayComponent.new()
	var base_data = super.deserialize(data)
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
	
	component.healing_rate = data.get("healing_rate", 1.0)
	component.capacity = data.get("capacity", 2)
	component.treatment_quality = data.get("treatment_quality", 1.0)
	component.supplies_efficiency = data.get("supplies_efficiency", 1.0)
	component.current_patients = data.get("current_patients", [])
	component.treatment_progress = data.get("treatment_progress", {})
	return component
