@tool
extends "res://tests/fixtures/base/base_test.gd"

const RivalSystem = preload("res://src/core/rivals/RivalSystem.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var rival_system: RivalSystem
var signal_received: bool
var last_signal_data: Dictionary

func before_each() -> void:
	rival_system = RivalSystem.new()
	add_child(rival_system)
	signal_received = false
	last_signal_data = {}
	
	rival_system.rival_created.connect(_on_signal_received.bind("rival_created"))
	rival_system.rival_defeated.connect(_on_signal_received.bind("rival_defeated"))
	rival_system.rival_escaped.connect(_on_signal_received.bind("rival_escaped"))
	rival_system.rival_reputation_changed.connect(_on_signal_received.bind("rival_reputation_changed"))

func after_each() -> void:
	rival_system.queue_free()
	rival_system = null

func _on_signal_received(signal_name: String) -> void:
	signal_received = true
	last_signal_data["signal_name"] = signal_name

func test_initialization() -> void:
	assert_eq(rival_system.active_rivals.size(), 0, "Should start with no active rivals")
	assert_eq(rival_system.defeated_rivals.size(), 0, "Should start with no defeated rivals")
	assert_eq(rival_system.rival_encounters.size(), 0, "Should start with no rival encounters")

func test_create_rival() -> void:
	var params = {
		"name": "Test Rival",
		"type": GameEnums.EnemyType.PIRATES,
		"level": 2,
		"reputation": 5
	}
	
	var rival_data = rival_system.create_rival(params)
	assert_not_null(rival_data, "Should create rival data")
	assert_eq(rival_data.name, "Test Rival", "Should set rival name")
	assert_eq(rival_data.type, GameEnums.EnemyType.PIRATES, "Should set rival type")
	assert_eq(rival_data.level, 2, "Should set rival level")
	assert_eq(rival_data.reputation, 5, "Should set rival reputation")
	assert_true(rival_data.active, "Should set rival as active")
	
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit rival_created signal")
	assert_eq(last_signal_data.signal_name, "rival_created", "Should emit correct signal")

func test_create_rival_with_defaults() -> void:
	var rival_data = rival_system.create_rival()
	assert_not_null(rival_data, "Should create rival data with defaults")
	assert_not_null(rival_data.id, "Should generate rival ID")
	assert_not_null(rival_data.name, "Should generate rival name")
	assert_eq(rival_data.level, 1, "Should set default level")
	assert_eq(rival_data.reputation, 0, "Should set default reputation")
	assert_true(rival_data.active, "Should set rival as active")

func test_rival_defeat() -> void:
	var rival_data = rival_system.create_rival()
	var rival_id = rival_data.id
	
	rival_system.defeat_rival(rival_id)
	assert_false(rival_id in rival_system.active_rivals, "Should remove from active rivals")
	assert_true(rival_data in rival_system.defeated_rivals, "Should add to defeated rivals")
	
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit rival_defeated signal")
	assert_eq(last_signal_data.signal_name, "rival_defeated", "Should emit correct signal")

func test_rival_escape() -> void:
	var rival_data = rival_system.create_rival()
	var rival_id = rival_data.id
	
	rival_system.handle_rival_escape(rival_id)
	assert_true(rival_id in rival_system.active_rivals, "Should keep in active rivals")
	
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit rival_escaped signal")
	assert_eq(last_signal_data.signal_name, "rival_escaped", "Should emit correct signal")

func test_modify_rival_reputation() -> void:
	var rival_data = rival_system.create_rival()
	var rival_id = rival_data.id
	var old_rep = rival_data.reputation
	
	rival_system.modify_rival_reputation(rival_id, 10)
	assert_eq(rival_system.active_rivals[rival_id].reputation, old_rep + 10, "Should increase reputation")
	
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit rival_reputation_changed signal")
	assert_eq(last_signal_data.signal_name, "rival_reputation_changed", "Should emit correct signal")
	
	rival_system.modify_rival_reputation(rival_id, -5)
	assert_eq(rival_system.active_rivals[rival_id].reputation, old_rep + 5, "Should decrease reputation")

func test_rival_encounters() -> void:
	var rival_data = rival_system.create_rival()
	var rival_id = rival_data.id
	
	rival_system.record_encounter(rival_id, {
		"type": "combat",
		"location": "Trade Hub",
		"outcome": "escaped"
	})
	
	assert_true(rival_id in rival_system.rival_encounters, "Should record encounter")
	assert_eq(rival_system.rival_encounters[rival_id].size(), 1, "Should add encounter to history")

func test_serialization() -> void:
	var rival1 = rival_system.create_rival({"name": "Rival 1"})
	var rival2 = rival_system.create_rival({"name": "Rival 2"})
	
	rival_system.defeat_rival(rival1.id)
	rival_system.record_encounter(rival2.id, {
		"type": "combat",
		"location": "Trade Hub",
		"outcome": "escaped"
	})
	
	var data = rival_system.serialize()
	var new_system = RivalSystem.new()
	new_system.deserialize(data)
	
	assert_eq(new_system.active_rivals.size(), rival_system.active_rivals.size(), "Should preserve active rivals")
	assert_eq(new_system.defeated_rivals.size(), rival_system.defeated_rivals.size(), "Should preserve defeated rivals")
	assert_eq(new_system.rival_encounters.size(), rival_system.rival_encounters.size(), "Should preserve rival encounters")