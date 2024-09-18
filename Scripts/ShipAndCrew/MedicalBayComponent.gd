class_name MedicalBayComponent
extends ShipComponent

var healing_capacity: int
var patients: Array[Character] = []

func _init(p_name: String, _p_type: ComponentType, p_power_usage: int, p_durability: int, p_healing_capacity: int) -> void:
	super._init(p_name, ComponentType.MEDICAL_BAY, p_power_usage, p_durability)
	healing_capacity = p_healing_capacity

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

func heal_patients() -> void:
	for patient in patients:
		patient.recover()

func process_turn() -> void:
	heal_patients()

func serialize() -> Dictionary:
	var data := super.serialize()
	data["healing_capacity"] = healing_capacity
	data["patients"] = patients.map(func(p): return p.serialize())
	return data

static func deserialize(data: Dictionary) -> MedicalBayComponent:
	var component := MedicalBayComponent.new(
		data["name"],
		data["description"],
		data["power_usage"],
		data["max_health"],
		data["healing_capacity"]
	)
	component.health = data["health"]
	component.is_damaged = data["is_damaged"]
	component.patients = data["patients"].map(func(p): return Character.deserialize(p))
	return component
