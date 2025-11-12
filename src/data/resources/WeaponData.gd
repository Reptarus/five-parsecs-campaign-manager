@tool
class_name WeaponData
extends Resource

## Individual weapon data for Five Parsecs

@export var id: String = ""
@export var name: String = ""
@export var category: String = ""
@export var description: String = ""
@export var damage: String = ""
@export var range: String = ""
@export var shots: int = 1
@export var traits: Array[String] = []
@export var cost: int = 0
@export var availability: String = ""
@export var weight: float = 0.0
@export var ammo_type: String = ""
@export var special_rules: Array[String] = []