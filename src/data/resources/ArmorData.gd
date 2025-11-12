@tool
class_name ArmorData
extends Resource

## Individual armor piece data for Five Parsecs

@export var id: String = ""
@export var name: String = ""
@export var category: String = ""
@export var description: String = ""
@export var armor_save: String = ""
@export var encumbrance: int = 0
@export var coverage: Array[String] = []
@export var traits: Array[String] = []
@export var cost: int = 0
@export var availability: String = ""
@export var weight: float = 0.0
@export var special_rules: Array[String] = []