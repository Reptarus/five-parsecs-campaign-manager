class_name GodotDebugBridge
extends RefCounted

## Debug Port Communication Bridge
## Connects to existing Godot debug session instead of launching new instances

const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")

signal debug_command_completed(result: Dictionary)
signal debug_data_received(data: Dictionary)

var debug_client: StreamPeerTCP = null
var debug_port: int = 6008
var debug_host: String = "127.0.0.1"
var is_connected: bool = false

## Connect to existing debug port
func connect_to_debug_port() -> bool:
	debug_client = StreamPeerTCP.new()
	var error = debug_client.connect_to_host(debug_host, debug_port)
	
	if error == OK:
		is_connected = true
		print("GodotDebugBridge: Connected to debug port ", debug_port)
		return true
	else:
		push_warning("GodotDebugBridge: Failed to connect to debug port: " + str(error))
		return false

## Send debug command to running Godot instance  
func send_debug_command(command: String, params: Dictionary = {}) -> void:
	if not is_connected:
		if not connect_to_debug_port():
			return
	
	var debug_packet = {
		"type": "command",
		"command": command,
		"params": params,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var json_string = JSON.stringify(debug_packet)
	var packet_data = json_string.to_utf8_buffer()
	
	if debug_client and debug_client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		debug_client.put_data(packet_data)
		print("GodotDebugBridge: Sent command: ", command)
	else:
		push_error("GodotDebugBridge: Not connected to debug port")

## Execute GDScript in running instance
func execute_script_remotely(script_content: String) -> void:
	send_debug_command("execute_script", {"script": script_content})

## Get project information from running instance
func get_running_project_info() -> void:
	send_debug_command("get_project_info", {})

## Trigger character generation test in running instance
func test_character_generation() -> void:
	var test_script = """
	# Test character generation in running instance
	var char_gen = FiveParsecsCharacterGeneration.new()
	var character = char_gen.generate_random_character()
	
	print("Generated character: ", character.character_name)
	print("Character class: ", character.character_class)
	print("Character attributes: ")
	print("  Reaction: ", character.reaction)
	print("  Speed: ", character.speed)
	print("  Combat: ", character.combat)
	print("  Toughness: ", character.toughness) 
	print("  Savvy: ", character.savvy)
	"""
	
	execute_script_remotely(test_script)

## Test crew creation integration in running instance
func test_crew_creation_integration() -> void:
	var test_script = """
	# Test crew creation integration
	var crew_ui = preload("res://src/ui/screens/crew/InitialCrewCreation.gd").new()
	
	# Test the updated integration
	crew_ui._initialize_character_system()
	print("Crew creation system initialized")
	
	# Generate test characters
	for i in range(3):
		crew_ui._on_generate_character()
		print("Generated character ", i + 1)
	
	print("Crew creation test completed: ", crew_ui.generated_characters.size(), " characters")
	"""
	
	execute_script_remotely(test_script)

## Test manager registration system
func test_manager_registration() -> void:
	var test_script = """
	# Test manager registration system
	var game_state = get_node("/root/GameStateManagerAutoload")
	if game_state:
		print("GameStateManager found")
		print("Registered managers: ", game_state.get_registered_managers())
		
		var char_manager = game_state.get_manager("CharacterManager")
		if char_manager:
			print("CharacterManager registered and accessible")
		else:
			print("CharacterManager not found in registry")
	else:
		print("GameStateManager not found")
	"""
	
	execute_script_remotely(test_script)

## Disconnect from debug port
func disconnect_from_debug() -> void:
	if debug_client:
		debug_client.disconnect_from_host()
		is_connected = false
		print("GodotDebugBridge: Disconnected from debug port")

## Static convenience method for quick testing
static func quick_test_integration() -> void:
	var bridge = GodotDebugBridge.new()
	
	# Test our Phase 2 integrations
	bridge.test_manager_registration()
	bridge.test_character_generation()
	bridge.test_crew_creation_integration()
	
	# Cleanup
	bridge.disconnect_from_debug()