# Scripts/ShipAndCrew/MedicalBayComponent.gd
class_name MedicalBayComponent
extends Resource

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const Character = preload("res://Resources/Core/Character/Base/Character.gd")

@export var name: String = ""
@export var description: String = ""
@export var healing_capacity: int = 0
@export var power_usage: int = 0
@export var health: int = 100
@export var max_health: int = 100
@export var weight: float = 1.0
@export var is_damaged: bool = false

var patients: Array[Character] = []

func _init(p_name: String = "", 
          p_description: String = "", 
          p_power_usage: int = 0, 
          p_health: int = 0, 
          p_weight: float = 1.0, 
          p_healing_capacity: int = 0) -> void:
	name = p_name
	description = p_description
	power_usage = p_power_usage
	health = p_health
	max_health = p_health
	weight = p_weight
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
	return {
		"name": name,
		"description": description,
		"power_usage": power_usage,
		"health": health,
		"max_health": max_health,
		"weight": weight,
		"healing_capacity": healing_capacity,
		"is_damaged": is_damaged,
		"patients": patients.map(func(p): return p.serialize())
	}

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
	component.patients = []
	for patient_data in data["patients"]:
		var patient = Character.new()
		patient.deserialize(patient_data)
		component.patients.append(patient)
	return component

func _to_string() -> String:
	return "Medical Bay (Capacity: %d, Patients: %d)" % [healing_capacity, patients.size()]
