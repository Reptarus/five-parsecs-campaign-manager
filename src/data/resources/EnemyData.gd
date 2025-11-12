@tool
class_name EnemyData  
extends Resource

## Individual enemy type data for Five Parsecs

@export var id: String = ""
@export var name: String = ""
@export var category: String = ""
@export var description: String = ""
@export var reactions: int = 1
@export var speed: int = 4
@export var combat_skill: int = 0
@export var toughness: int = 3
@export var savvy: int = 0
@export var armor_save: String = ""
@export var weapons: Array[String] = []
@export var special_rules: Array[String] = []
@export var ai_type: String = ""
@export var deployment_notes: String = ""
@export var loot_chance: int = 0