# Scripts/ShipAndCrew/MedicalBayComponent.gd
class_name MedicalBayComponent
extends ShipComponent

@export var healing_capacity: int
var patients: Array[Character] = []

func _init(p_name: String, p_description: String, p_power_usage: int, p_health: int, p_weight: float = 1.0, p_healing_capacity: int = 0):
	super(p_name, p_description, GlobalEnums.ComponentType.MEDICAL_BAY, p_power_usage, p_health, p_weight)
	healing_capacity = p_healing_capacity

func process_turn() -> void:
	heal_patients()

func heal_patients() -> void:
	for patient in patients:
		patient.health = min(patient.health + 20, patient.max_health)
		patient.stress = max(patient.stress - 10, 0)
		if patient.health == patient.max_health and patient.stress == 0:
			discharge_patient(patient)

func admit_patient(crew_member: Character) -> bool:
	if patients.size() < healing_capacity and not is_damaged:
		patients.append(crew_member)
		return true
	return false

func discharge_patient(crew_member: Character) -> bool:
	var index := patients.find(crew_member)
	if index != -1:
		patients.remove_at(index)
		return true
	return false

func get_available_beds() -> int:
	return healing_capacity - patients.size()

func serialize() -> Dictionary:
	var data = super.serialize()
	data["healing_capacity"] = healing_capacity
	data["patients"] = patients.map(func(p): return p.serialize())
	return data

static func deserialize(data: Dictionary) -> MedicalBayComponent:
	var component = MedicalBayComponent.new(
		data["name"],
		data["description"],
		data["power_usage"],
		data["health"],
		data["weight"],
		data["healing_capacity"]
	)
	component.max_health = data["max_health"]
	component.is_damaged = data["is_damaged"]
	component.patients = data["patients"].map(func(p): return Character.deserialize(p))
	return component

func _to_string() -> String:
	return "Medical Bay (Capacity: %d, Patients: %d)" % [healing_capacity, patients.size()]
