class_name CharacterFactory

# Utility class for creating character-related nodes and resources

# Moved from BaseCharacterResource.gd
static func create_node_character() -> Node:
	# Check if the NodeCharacterHelper exists
	if ResourceLoader.exists("res://src/core/character/utils/NodeCharacterHelper.gd"):
		var helper = load("res://src/core/character/utils/NodeCharacterHelper.gd")
		if helper and helper.has_method("create_test_character_node"):
			return helper.create_test_character_node()
	
	# Fallback implementation if helper isn't available
	if not ResourceLoader.exists("res://src/battle/character/Character.gd"):
		push_error("Battle character script not found")
		return null
	
	var battle_char_script = load("res://src/battle/character/Character.gd")
	if not battle_char_script or not battle_char_script is GDScript:
		push_error("Battle character is not a valid GDScript")
		return null
		
	var instance = battle_char_script.new()
	if not instance:
		push_error("Failed to create battle character instance")
		return null
		
	if not instance is Node:
		push_error("Battle character instance is not a Node")
		instance.free()
		return null
	
	# Create a new character resource to initialize the node
	# Note: This uses the base resource. If specific defaults are needed,
	# consider loading a template .tres file instead.
	var character_resource = load("res://src/core/character/Base/Character.gd").new()
	if character_resource and instance.has_method("initialize"):
		# Set up basic properties
		character_resource.character_name = "Test Character"
		character_resource.health = 100
		character_resource.max_health = 100
		character_resource.level = 1
		
		# Ensure the BattleCharacter has the correct type hint for initialize
		if instance.initialize(character_resource):
			pass # Initialization successful
		else:
			push_warning("Failed to initialize BattleCharacter node.")
			# Might need to free instance here depending on desired error handling
	else:
		push_warning("Character resource or initialize method not found for BattleCharacter.")
		# Might need to free instance here
		
	return instance