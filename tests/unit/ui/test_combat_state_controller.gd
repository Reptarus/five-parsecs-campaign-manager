@tool
extends GameTest

const TestedClass = preload("res://src/ui/components/combat/state/state_verification_controller.gd")

var _instance: Node
var _verification_started_signal_emitted := false
var _verification_result_ready_signal_emitted := false
var _verification_error_signal_emitted := false
var _state_mismatch_detected_signal_emitted := false
var _last_verification_type: int
var _last_verification_scope: int
var _last_verification_result: int
var _last_verification_details: Dictionary
var _last_verification_error: String
var _last_mismatch_data: Dictionary

func before_each() -> void:
	_instance = TestedClass.new()
	add_child(_instance)
	_connect_signals()
	_reset_signals()

func after_each() -> void:
	_disconnect_signals()
	_instance.queue_free()
	_instance = null

func _connect_signals() -> void:
	_instance.verification_started.connect(_on_verification_started)
	_instance.verification_result_ready.connect(_on_verification_result_ready)
	_instance.verification_error.connect(_on_verification_error)
	_instance.state_mismatch_detected.connect(_on_state_mismatch_detected)

func _disconnect_signals() -> void:
	if _instance and not _instance.is_queued_for_deletion():
		if _instance.verification_started.is_connected(_on_verification_started):
			_instance.verification_started.disconnect(_on_verification_started)
		if _instance.verification_result_ready.is_connected(_on_verification_result_ready):
			_instance.verification_result_ready.disconnect(_on_verification_result_ready)
		if _instance.verification_error.is_connected(_on_verification_error):
			_instance.verification_error.disconnect(_on_verification_error)
		if _instance.state_mismatch_detected.is_connected(_on_state_mismatch_detected):
			_instance.state_mismatch_detected.disconnect(_on_state_mismatch_detected)

func _reset_signals() -> void:
	_verification_started_signal_emitted = false
	_verification_result_ready_signal_emitted = false
	_verification_error_signal_emitted = false
	_state_mismatch_detected_signal_emitted = false
	_last_verification_type = 0
	_last_verification_scope = 0
	_last_verification_result = 0
	_last_verification_details = {}
	_last_verification_error = ""
	_last_mismatch_data = {}

func _on_verification_started(type: int, scope: int) -> void:
	_verification_started_signal_emitted = true
	_last_verification_type = type
	_last_verification_scope = scope

func _on_verification_result_ready(type: int, result: int, details: Dictionary) -> void:
	_verification_result_ready_signal_emitted = true
	_last_verification_type = type
	_last_verification_result = result
	_last_verification_details = details

func _on_verification_error(type: int, error: String) -> void:
	_verification_error_signal_emitted = true
	_last_verification_type = type
	_last_verification_error = error

func _on_state_mismatch_detected(type: int, expected: Dictionary, actual: Dictionary) -> void:
	_state_mismatch_detected_signal_emitted = true
	_last_verification_type = type
	_last_mismatch_data = {
		"expected": expected,
		"actual": actual
	}

func test_initial_state() -> void:
	assert_false(_verification_started_signal_emitted)
	assert_false(_verification_result_ready_signal_emitted)
	assert_false(_verification_error_signal_emitted)
	assert_false(_state_mismatch_detected_signal_emitted)

func test_verification_request() -> void:
	var test_type = GameEnums.VerificationType.COMBAT
	var test_scope = GameEnums.VerificationScope.ALL
	
	_instance.request_verification(test_type, test_scope)
	
	verify_signal_emitted(_instance, "verification_started")
	assert_true(_verification_started_signal_emitted)
	assert_eq(_last_verification_type, test_type)
	assert_eq(_last_verification_scope, test_scope)

func test_verification_result() -> void:
	var test_type = GameEnums.VerificationType.COMBAT
	var test_result = GameEnums.VerificationResult.SUCCESS
	var test_details = {"test": "details"}
	
	_instance._verify_state(test_type, {"phase": GameEnums.CombatPhase.NONE})
	
	verify_signal_emitted(_instance, "verification_result_ready")
	assert_true(_verification_result_ready_signal_emitted)
	assert_eq(_last_verification_type, test_type)
	assert_eq(_last_verification_result, test_result)

func test_verification_error() -> void:
	var test_type = GameEnums.VerificationType.COMBAT
	var test_error = "Test error message"
	
	_instance._verify_state(test_type, {})
	
	verify_signal_emitted(_instance, "verification_error")
	assert_true(_verification_error_signal_emitted)
	assert_eq(_last_verification_type, test_type)
	assert_true(_last_verification_error.length() > 0)

func test_state_mismatch() -> void:
	var test_type = GameEnums.VerificationType.COMBAT
	var expected_state = {"phase": GameEnums.CombatPhase.NONE}
	var actual_state = {"phase": GameEnums.CombatPhase.INITIATIVE}
	
	_instance._verify_state(test_type, actual_state)
	
	verify_signal_emitted(_instance, "state_mismatch_detected")
	assert_true(_state_mismatch_detected_signal_emitted)
	assert_eq(_last_verification_type, test_type)
	assert_true(_last_mismatch_data.size() > 0)