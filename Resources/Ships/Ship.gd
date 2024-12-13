# Scripts/ShipAndCrew/Ship.gd
class_name Ship
extends Node

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const ShipComponent = preload("res://Resources/Ships/ShipComponent.gd")
const EngineComponent = preload("res://Resources/Ships/EngineComponent.gd")
const MedicalBayComponent = preload("res://Resources/Ships/MedicalBayComponent.gd")

signal component_added(component: ShipComponent)
signal component_removed(component: ShipComponent)
signal component_damaged(component: ShipComponent)
signal component_repaired(component: ShipComponent)

var components: Array[ShipComponent] = []

func get_component_by_type(type: int) -> ShipComponent:  # GameEnums.ShipComponentType
	var matching = components.filter(func(c): return c.component_type == type)
	return matching[0] if not matching.is_empty() else null

func get_engine() -> EngineComponent:
	var component = get_component_by_type(GameEnums.ShipComponentType.ENGINE)
	if component and component is EngineComponent:
		return component as EngineComponent
	return null

func get_medical_bay() -> MedicalBayComponent:
	var component = get_component_by_type(GameEnums.ShipComponentType.MEDICAL_BAY)
	if component and component is MedicalBayComponent:
		return component as MedicalBayComponent
	return null
