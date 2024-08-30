class_name MedicalBayComponent
extends ShipComponent

@export var healing_capacity: int
@export var patients: Array[Crew] = []

func _init() -> void:
	type = ComponentType.MEDICAL_BAY

func admit_patient(crew_member: Crew) -> bool:
	if patients.size() < healing_capacity and is_active:
		patients.append(crew_member)
		return true
	return false

func discharge_patient(crew_member: Crew) -> bool:
	var index := patients.find(crew_member)
	if index != -1:
		patients.remove_at(index)
		return true
	return false

func heal_patients() -> void:
	if is_active:
		for patient in patients:
			patient.heal(1)  # Adjust healing amount as needed

func process_turn() -> void:
	heal_patients()

func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["healing_capacity"] = healing_capacity
	data["patients"] = patients.map(func(p): return p.to_dict())
	return data

static func from_dict(data: Dictionary) -> MedicalBayComponent:
	var component := MedicalBayComponent.new()
	component.healing_capacity = data["healing_capacity"]
	component.patients = data["patients"].map(func(p): return Crew.new().from_dict(p))
	return component
