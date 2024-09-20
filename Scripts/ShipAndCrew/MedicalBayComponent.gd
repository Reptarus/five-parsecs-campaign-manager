class_name MedicalBayComponent
extends ShipComponent

var healing_capacity: int
var patients: Array[Character] = []

func _init(p_name: String, p_power_usage: int, p_durability: int, p_healing_capacity: int, p_weight: float) -> void:
	super._init(p_name, "Medical Bay", GlobalEnums.ComponentType.MEDICAL_BAY, p_power_usage, p_durability, p_weight)
	healing_capacity = p_healing_capacity
	weight = p_weight

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

func take_damage(amount: int) -> void:
	super.take_damage(amount)
	if health <= 0:
		is_damaged = true
		# Discharge all patients when the medical bay is damaged
		for patient in patients:
			discharge_patient(patient)

func repair() -> void:
	super.repair()
	is_damaged = false

func serialize() -> Dictionary:
	var data := super.serialize()
	data["healing_capacity"] = healing_capacity
	data["patients"] = patients.map(func(p): return p.serialize())
	data["weight"] = weight
	return data

static func deserialize(data: Dictionary) -> MedicalBayComponent:
	var component := MedicalBayComponent.new(
		data["name"],
		data["power_usage"],
		data["max_health"],
		data["healing_capacity"],
		data["weight"]
	)
	component.health = data["health"]
	component.is_damaged = data["is_damaged"]
	component.patients = data["patients"].map(func(p): return Character.deserialize(p))
	return component
