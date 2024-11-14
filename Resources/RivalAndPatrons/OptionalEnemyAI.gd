class_name OptionalEnemyAI
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const Character = preload("res://Resources/CrewAndCharacters/Character.gd")

var ai_controller: AIController

func setup(controller: AIController) -> void:
	ai_controller = controller

func determine_action(enemy: Character) -> Dictionary:
	# Check for special rules that affect behavior
	if enemy.has_special_rule(GlobalEnums.EnemySpecialRule.FEROCIOUS):
		ai_controller.set_ai_behavior(GlobalEnums.AIBehavior.RAMPAGE)
		return _get_action(enemy)
		
	elif enemy.has_special_rule(GlobalEnums.EnemySpecialRule.QUICK_FEET):
		ai_controller.set_ai_behavior(GlobalEnums.AIBehavior.TACTICAL) 
		return _get_action(enemy)
	
	# Default behavior based on enemy category and compendium rules
	match enemy.enemy_category:
		GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS:
			# Criminal elements tend to be aggressive per compendium
			ai_controller.set_ai_behavior(GlobalEnums.AIBehavior.AGGRESSIVE)
			return _get_action(enemy)
			
		GlobalEnums.EnemyCategory.HIRED_MUSCLE:
			# Hired muscle uses tactical behavior per compendium
			ai_controller.set_ai_behavior(GlobalEnums.AIBehavior.TACTICAL)
			return _get_action(enemy)
			
		GlobalEnums.EnemyCategory.INTERESTED_PARTIES:
			# Interested parties are more cautious per compendium
			ai_controller.set_ai_behavior(GlobalEnums.AIBehavior.CAUTIOUS)
			return _get_action(enemy)
			
		_:
			ai_controller.set_ai_behavior(GlobalEnums.AIBehavior.AGGRESSIVE)
			return _get_action(enemy)

func _get_action(enemy: Character) -> Dictionary:
	var action := {}
	ai_controller.perform_ai_turn(enemy)
	return action
