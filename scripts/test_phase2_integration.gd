@tool
extends SceneTree

## Phase 2 Integration Testing Script
## Tests the crew creation integrations implemented in Phase 2
## Can be run without conflicting with existing debug sessions

func _init():
	print("\n" + "=".repeat(60))
	print("PHASE 2 INTEGRATION TESTING")
	print("Testing crew creation system integrations")
	print("=".repeat(60))
	
	test_character_generation()
	test_manager_registration()
	test_ui_integration()
	test_universal_safety()
	
	print("\n" + "=".repeat(60))
	print("PHASE 2 INTEGRATION TESTING COMPLETE")
	print("=".repeat(60))
	
	quit(0)

func test_character_generation():
	print("\n[TEST 1] Character Generation System")
	print("-".repeat(40))
	
	# Test FiveParsecsCharacterGeneration
	var char_gen_script = preload("res://src/core/character/CharacterGeneration.gd")
	if char_gen_script:
		print("✅ FiveParsecsCharacterGeneration loaded successfully")
		
		# Test static method access
		var character = char_gen_script.generate_random_character()
		if character:
			print("✅ Character generation successful")
			print("   Name: ", character.character_name if character.character_name else "Unknown")
			print("   Class: ", character.character_class if character.character_class else "Unknown")
			print("   Reaction: ", character.reaction if character.reaction else "Unknown")
			print("   Combat: ", character.combat if character.combat else "Unknown")
		else:
			print("❌ Character generation failed")
	else:
		print("❌ FiveParsecsCharacterGeneration not found")

func test_manager_registration():
	print("\n[TEST 2] Manager Registration System")
	print("-".repeat(40))
	
	# Test GameStateManager
	var game_state_script = preload("res://src/core/managers/GameStateManager.gd")
	if game_state_script:
		print("✅ GameStateManager loaded successfully")
		
		# Create instance to test registration methods
		var game_state = game_state_script.new()
		
		# Test registration methods
		if game_state.has_method("register_manager"):
			print("✅ register_manager method available")
		else:
			print("❌ register_manager method missing")
			
		if game_state.has_method("get_manager"):
			print("✅ get_manager method available")
		else:
			print("❌ get_manager method missing")
			
		if game_state.has_method("get_registered_managers"):
			print("✅ get_registered_managers method available")
		else:
			print("❌ get_registered_managers method missing")
			
		# Test CharacterManager registration capability
		var char_manager_script = preload("res://src/core/character/Management/CharacterManager.gd")
		if char_manager_script:
			print("✅ CharacterManager loaded successfully")
			var char_manager = char_manager_script.new()
			
			if char_manager.has_method("_register_with_game_state"):
				print("✅ CharacterManager has registration method")
			else:
				print("❌ CharacterManager missing registration method")
		else:
			print("❌ CharacterManager not found")
	else:
		print("❌ GameStateManager not found")

func test_ui_integration():
	print("\n[TEST 3] UI Integration System")
	print("-".repeat(40))
	
	# Test InitialCrewCreation UI
	var crew_ui_script = preload("res://src/ui/screens/crew/InitialCrewCreation.gd")
	if crew_ui_script:
		print("✅ InitialCrewCreation UI loaded successfully")
		
		# Check for enhanced methods
		var crew_ui = crew_ui_script.new()
		
		if crew_ui.has_method("_initialize_character_system"):
			print("✅ _initialize_character_system method available")
		else:
			print("❌ _initialize_character_system method missing")
			
		if crew_ui.has_method("_on_generate_character"):
			print("✅ _on_generate_character method available")
		else:
			print("❌ _on_generate_character method missing")
			
		if crew_ui.has_method("_character_to_dict"):
			print("✅ _character_to_dict method available")
		else:
			print("❌ _character_to_dict method missing")
			
		# Check properties
		if "generated_characters" in crew_ui:
			print("✅ generated_characters property available")
		else:
			print("❌ generated_characters property missing")
	else:
		print("❌ InitialCrewCreation UI not found")
		
	# Test CrewPanel
	var crew_panel_script = preload("res://src/ui/screens/campaign/panels/CrewPanel.gd")
	if crew_panel_script:
		print("✅ CrewPanel loaded successfully")
		
		var crew_panel = crew_panel_script.new()
		
		if crew_panel.has_method("_create_five_parsecs_character"):
			print("✅ _create_five_parsecs_character method available")
		else:
			print("❌ _create_five_parsecs_character method missing")
	else:
		print("❌ CrewPanel not found")

func test_universal_safety():
	print("\n[TEST 4] Universal Safety System")
	print("-".repeat(40))
	
	# Test Universal Safety components
	var components = [
		"UniversalResourceLoader",
		"UniversalSignalManager", 
		"UniversalNodeAccess",
		"UniversalDataAccess"
	]
	
	for component in components:
		var script_path = "res://src/utils/" + component + ".gd"
		var script = load(script_path)
		if script:
			print("✅ ", component, " loaded successfully")
		else:
			print("❌ ", component, " not found")
	
	# Test MCPBridge integration
	var mcp_bridge_script = preload("res://src/utils/MCPBridge.gd")
	if mcp_bridge_script:
		print("✅ MCPBridge loaded successfully")
		
		var mcp_bridge = mcp_bridge_script.new()
		if mcp_bridge.has_method("connect_to_debug_session"):
			print("✅ Debug session connection method available")
		else:
			print("❌ Debug session connection method missing")
	else:
		print("❌ MCPBridge not found")
	
	# Test GodotDebugBridge
	var debug_bridge_script = preload("res://src/utils/GodotDebugBridge.gd")
	if debug_bridge_script:
		print("✅ GodotDebugBridge loaded successfully")
		
		var debug_bridge = debug_bridge_script.new()
		if debug_bridge.has_method("connect_to_debug_port"):
			print("✅ Debug port connection method available")
		else:
			print("❌ Debug port connection method missing")
	else:
		print("❌ GodotDebugBridge not found")