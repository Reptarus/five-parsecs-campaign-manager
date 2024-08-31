# CharacterNameGenerator.gd
class_name CharacterNameGenerator
extends Object

static func get_random_name() -> String:
	var first_names = ["John", "Jane", "Alex", "Sarah", "Michael", "Emily", "Zorg", "Xyla", "Krath"]
	var last_names = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "X'tor"]
	
	var first_name = first_names[randi() % first_names.size()]
	var last_name = last_names[randi() % last_names.size()]
	
	return first_name + " " + last_name
