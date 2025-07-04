extends SceneTree

## Test script for MCPBridge integration
## Run with: godot -s scripts/examples/test_mcp_bridge.gd

const MCPBridge = preload("res://src/utils/MCPBridge.gd")

func _init():
	print("Testing MCPBridge integration...")
	
	# Test 1: Document a character system implementation
	print("\n1. Testing character system documentation...")
	MCPBridge.document_character_system(
		"Attribute Generation",
		"Implemented Five Parsecs attribute generation using 2d6÷3 (rounded up) method. Attributes range from 1-4 with racial modifiers. Located in CharacterCreationSystem.gd with full test coverage in test_character_creation.gd"
	)
	
	# Test 2: Document a combat system implementation  
	print("\n2. Testing combat system documentation...")
	MCPBridge.document_combat_system(
		"Attack Resolution",
		"Implemented Five Parsecs attack resolution: d10 + Combat skill vs target number 4+ with range and cover modifiers. Critical hits on natural 10. Located in CombatResolver.gd"
	)
	
	# Test 3: Document a campaign system implementation
	print("\n3. Testing campaign system documentation...")
	MCPBridge.document_campaign_system(
		"Four-Phase Turn Structure",
		"Implemented official Five Parsecs campaign turn: Travel Phase, World Phase, Battle Phase, Post-Battle Phase. Each phase has proper sub-steps and validation. Located in CampaignTurnManager.gd"
	)
	
	# Test 4: Create bridge instance for dynamic operations
	print("\n4. Testing dynamic MCP operations...")
	var mcp_bridge = MCPBridge.new()
	
	# Connect signals for async operations
	mcp_bridge.obsidian_search_completed.connect(_on_search_completed)
	mcp_bridge.rule_documented.connect(_on_rule_documented)
	mcp_bridge.desktop_command_completed.connect(_on_command_completed)
	
	# Test search
	print("Searching Obsidian vault for Five Parsecs content...")
	mcp_bridge.search_obsidian_vault("Five Parsecs character creation")
	
	# Test build command
	print("Testing build command...")
	mcp_bridge.build_project()
	
	# Wait a moment for operations to complete
	await self.create_timer(2.0).timeout
	
	print("\nMCPBridge testing completed!")
	print("Check your Obsidian vault for new documentation notes.")
	quit(0)

func _on_search_completed(results: Dictionary):
	print("Search completed: ", results)

func _on_rule_documented(success: bool, rule_name: String):
	print("Rule documentation ", "succeeded" if success else "failed", " for: ", rule_name)

func _on_command_completed(result: Dictionary):
	print("Command completed: ", result)