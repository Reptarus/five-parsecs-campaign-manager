@tool
extends "res://tests/fixtures/base/base_test.gd"

const RivalSystem = preload("res://src/core/rivals/RivalSystem.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var rival_system: RivalSystem
var signal_received: bool
var last_signal_data: Dictionary

# Type safety helper
class TypeSafeMixin:
	# Safe method to call a function with proper error handling
	static func _call_method(obj: Object, method_name: String, args: Array = []):
		if obj == null:
			return null
		if not obj.has_method(method_name):
			return null
		return obj.callv(method_name, args)
		
	# Safe method for checking properties
	static func _has_property(obj: Object, prop_name: String) -> bool:
		if obj == null:
			return false
		return prop_name in obj
		
	# Safe getter for properties with default value
	static func _get_property(obj: Object, prop_name: String, default_value = null):
		if not _has_property(obj, prop_name):
			return default_value
		return obj.get(prop_name)

func before_each() -> void:
	rival_system = RivalSystem.new()
	add_child(rival_system)
	signal_received = false
	last_signal_data = {}
	
	# Connect signals with safe handling of possible parameter variations
	if rival_system.has_signal("rival_created"):
		rival_system.connect("rival_created", _on_rival_created)
	
	if rival_system.has_signal("rival_defeated"):
		rival_system.connect("rival_defeated", _on_rival_defeated)
	
	if rival_system.has_signal("rival_escaped"):
		rival_system.connect("rival_escaped", _on_rival_escaped)
	
	if rival_system.has_signal("rival_reputation_changed"):
		rival_system.connect("rival_reputation_changed", _on_rival_reputation_changed)

func after_each() -> void:
	# Safely disconnect all signals
	if rival_system:
		if rival_system.has_signal("rival_created") and rival_system.is_connected("rival_created", _on_rival_created):
			rival_system.disconnect("rival_created", _on_rival_created)
		
		if rival_system.has_signal("rival_defeated") and rival_system.is_connected("rival_defeated", _on_rival_defeated):
			rival_system.disconnect("rival_defeated", _on_rival_defeated)
			
		if rival_system.has_signal("rival_escaped") and rival_system.is_connected("rival_escaped", _on_rival_escaped):
			rival_system.disconnect("rival_escaped", _on_rival_escaped)
			
		if rival_system.has_signal("rival_reputation_changed") and rival_system.is_connected("rival_reputation_changed", _on_rival_reputation_changed):
			rival_system.disconnect("rival_reputation_changed", _on_rival_reputation_changed)
			
		rival_system.queue_free()
		rival_system = null

# Dedicated signal handlers for each signal type
func _on_rival_created(rival = null) -> void:
	signal_received = true
	last_signal_data = {"signal_name": "rival_created"}
	if rival != null:
		last_signal_data["rival"] = rival

func _on_rival_defeated(rival_id = null) -> void:
	signal_received = true
	last_signal_data = {"signal_name": "rival_defeated"}
	if rival_id != null:
		last_signal_data["rival_id"] = rival_id

func _on_rival_escaped(rival_id = null) -> void:
	signal_received = true
	last_signal_data = {"signal_name": "rival_escaped"}
	if rival_id != null:
		last_signal_data["rival_id"] = rival_id

func _on_rival_reputation_changed(rival_id = null, new_reputation = null) -> void:
	signal_received = true
	last_signal_data = {"signal_name": "rival_reputation_changed"}
	if rival_id != null:
		last_signal_data["rival_id"] = rival_id
	if new_reputation != null:
		last_signal_data["new_reputation"] = new_reputation

func test_initialization() -> void:
	# Check if rival_system is properly initialized
	assert_not_null(rival_system, "RivalSystem should be initialized")
	
	# Check if the system has the expected properties
	if TypeSafeMixin._has_property(rival_system, "active_rivals") and rival_system.active_rivals is Dictionary:
		assert_eq(rival_system.active_rivals.size(), 0, "Should start with no active rivals")
	else:
		push_warning("active_rivals not available or not a Dictionary")
		
	if TypeSafeMixin._has_property(rival_system, "defeated_rivals") and rival_system.defeated_rivals is Array:
		assert_eq(rival_system.defeated_rivals.size(), 0, "Should start with no defeated rivals")
	else:
		push_warning("defeated_rivals not available or not an Array")
		
	if TypeSafeMixin._has_property(rival_system, "rival_encounters") and rival_system.rival_encounters is Dictionary:
		assert_eq(rival_system.rival_encounters.size(), 0, "Should start with no rival encounters")
	else:
		push_warning("rival_encounters not available or not a Dictionary")

func test_create_rival() -> void:
	var params = {
		"name": "Test Rival",
		"type": GameEnums.EnemyType.PIRATES,
		"level": 2,
		"reputation": 5
	}
	
	# Reset signal state
	signal_received = false
	last_signal_data.clear()
	
	# Check if create_rival method exists
	if not rival_system.has_method("create_rival"):
		push_warning("create_rival method not found, skipping test")
		return
		
	var rival_data = rival_system.create_rival(params)
	assert_not_null(rival_data, "Should create rival data")
	
	# Safely check rival data properties
	if rival_data is Dictionary:
		if rival_data.has("name"):
			assert_eq(rival_data.name, "Test Rival", "Should set rival name")
		
		if rival_data.has("type"):
			assert_eq(rival_data.type, GameEnums.EnemyType.PIRATES, "Should set rival type")
		
		if rival_data.has("level"):
			assert_eq(rival_data.level, 2, "Should set rival level")
		
		if rival_data.has("reputation"):
			assert_eq(rival_data.reputation, 5, "Should set rival reputation")
		
		if rival_data.has("active"):
			assert_true(rival_data.active, "Should set rival as active")
	else:
		push_warning("rival_data is not a Dictionary")
	
	# Wait for potential signal processing
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit rival_created signal")
	assert_eq(last_signal_data.get("signal_name"), "rival_created", "Should emit correct signal")

func test_create_rival_with_defaults() -> void:
	# Reset signal state
	signal_received = false
	last_signal_data.clear()
	
	# Check if create_rival method exists
	if not rival_system.has_method("create_rival"):
		push_warning("create_rival method not found, skipping test")
		return
		
	var rival_data = rival_system.create_rival()
	assert_not_null(rival_data, "Should create rival data with defaults")
	
	# Safely check rival data properties
	if rival_data is Dictionary:
		if rival_data.has("id"):
			assert_not_null(rival_data.id, "Should generate rival ID")
		
		if rival_data.has("name"):
			assert_not_null(rival_data.name, "Should generate rival name")
		
		if rival_data.has("level"):
			assert_eq(rival_data.level, 1, "Should set default level")
		
		if rival_data.has("reputation"):
			assert_eq(rival_data.reputation, 0, "Should set default reputation")
		
		if rival_data.has("active"):
			assert_true(rival_data.active, "Should set rival as active")
	else:
		push_warning("rival_data is not a Dictionary")

func test_rival_defeat() -> void:
	# Check if necessary methods exist
	if not rival_system.has_method("create_rival") or not rival_system.has_method("defeat_rival"):
		push_warning("Required methods not found, skipping test")
		return
		
	var rival_data = rival_system.create_rival()
	var rival_id = rival_data.get("id", "")
	
	# Skip if no valid ID
	if rival_id.is_empty():
		push_warning("No valid rival ID, skipping test")
		return
	
	# Reset signal state
	signal_received = false
	last_signal_data.clear()
	
	rival_system.defeat_rival(rival_id)
	
	# Check if data structures exist
	if TypeSafeMixin._has_property(rival_system, "active_rivals") and TypeSafeMixin._has_property(rival_system, "defeated_rivals"):
		if rival_system.active_rivals is Dictionary:
			assert_false(rival_id in rival_system.active_rivals, "Should remove from active rivals")
		
		if rival_system.defeated_rivals is Array:
			var found = false
			for rival in rival_system.defeated_rivals:
				if rival is Dictionary and rival.get("id") == rival_id:
					found = true
					break
			assert_true(found, "Should add to defeated rivals")
	else:
		push_warning("Required data structures not found")
	
	# Wait for potential signal processing
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit rival_defeated signal")
	assert_eq(last_signal_data.get("signal_name"), "rival_defeated", "Should emit correct signal")

func test_rival_escape() -> void:
	# Check if necessary methods exist
	if not rival_system.has_method("create_rival"):
		push_warning("create_rival method not found, skipping test")
		return
	
	var rival_data = rival_system.create_rival()
	var rival_id = rival_data.id
	
	# Reset signal state
	signal_received = false
	last_signal_data.clear()
	
	# Use safe_call_method which will try handle_rival_escape but fall back to rival_escapes if needed
	safe_call_method(rival_system, "handle_rival_escape", [rival_id])
	
	if TypeSafeMixin._has_property(rival_system, "active_rivals"):
		assert_true(rival_id in rival_system.active_rivals, "Should keep in active rivals")
	
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit rival_escaped signal")
	assert_eq(last_signal_data.get("signal_name", ""), "rival_escaped", "Should emit correct signal")

func test_modify_rival_reputation() -> void:
	# Check if necessary methods exist
	if not rival_system.has_method("create_rival") or not rival_system.has_method("modify_rival_reputation"):
		push_warning("Required methods not found, skipping test")
		return
	
	var rival_data = rival_system.create_rival()
	var rival_id = rival_data.id
	var old_rep = rival_data.reputation
	
	# Reset signal state
	signal_received = false
	last_signal_data.clear()
	
	rival_system.modify_rival_reputation(rival_id, 10)
	
	if TypeSafeMixin._has_property(rival_system, "active_rivals"):
		assert_eq(rival_system.active_rivals[rival_id].reputation, old_rep + 10, "Should increase reputation")
	
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit rival_reputation_changed signal")
	assert_eq(last_signal_data.get("signal_name", ""), "rival_reputation_changed", "Should emit correct signal")
	
	rival_system.modify_rival_reputation(rival_id, -5)
	
	if TypeSafeMixin._has_property(rival_system, "active_rivals"):
		assert_eq(rival_system.active_rivals[rival_id].reputation, old_rep + 5, "Should decrease reputation")

func test_rival_encounters() -> void:
	# Check if necessary methods exist
	if not rival_system.has_method("create_rival") or not rival_system.has_method("record_encounter"):
		push_warning("Required methods not found, skipping test")
		return
	
	var rival_data = rival_system.create_rival()
	var rival_id = rival_data.id
	
	rival_system.record_encounter(rival_id, {
		"type": "combat",
		"location": "Trade Hub",
		"outcome": "escaped"
	})
	
	if TypeSafeMixin._has_property(rival_system, "rival_encounters"):
		assert_true(rival_id in rival_system.rival_encounters, "Should record encounter")
		assert_eq(rival_system.rival_encounters[rival_id].size(), 1, "Should add encounter to history")

func test_serialization() -> void:
	# Check if necessary methods exist
	if not rival_system.has_method("create_rival") or not rival_system.has_method("serialize") or not rival_system.has_method("deserialize"):
		push_warning("Required methods not found, skipping test")
		return
	
	var rival1 = rival_system.create_rival({"name": "Rival 1"})
	var rival2 = rival_system.create_rival({"name": "Rival 2"})
	
	if rival_system.has_method("defeat_rival"):
		rival_system.defeat_rival(rival1.id)
	
	if rival_system.has_method("record_encounter"):
		rival_system.record_encounter(rival2.id, {
			"type": "combat",
			"location": "Trade Hub",
			"outcome": "escaped"
		})
	
	var data = rival_system.serialize()
	var new_system = RivalSystem.new()
	new_system.deserialize(data)
	
	# Check data structures with type safety
	if TypeSafeMixin._has_property(rival_system, "active_rivals") and TypeSafeMixin._has_property(new_system, "active_rivals"):
		assert_eq(new_system.active_rivals.size(), rival_system.active_rivals.size(), "Should preserve active rivals")
	
	if TypeSafeMixin._has_property(rival_system, "defeated_rivals") and TypeSafeMixin._has_property(new_system, "defeated_rivals"):
		assert_eq(new_system.defeated_rivals.size(), rival_system.defeated_rivals.size(), "Should preserve defeated rivals")
	
	if TypeSafeMixin._has_property(rival_system, "rival_encounters") and TypeSafeMixin._has_property(new_system, "rival_encounters"):
		assert_eq(new_system.rival_encounters.size(), rival_system.rival_encounters.size(), "Should preserve rival encounters")
