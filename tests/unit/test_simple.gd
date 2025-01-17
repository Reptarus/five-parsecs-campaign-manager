extends Node

signal test_completed(test_name: String, passed: bool, message: String)
signal all_tests_completed(total: int, passed: int)

var _current_test_name: String
var _total_tests := 0
var _passed_tests := 0

func _ready():
	# Connect to our own signals for reporting
	test_completed.connect(_on_test_completed)
	all_tests_completed.connect(_on_all_tests_completed)
	
	print("\n=== Starting Test Suite ===")
	run_all_tests()

func run_all_tests():
	var methods = get_method_list()
	
	for method in methods:
		if method.name.begins_with("test_"):
			_current_test_name = method.name
			_total_tests += 1
			
			print("\nRunning: " + method.name)
			run_test(method.name)
	
	all_tests_completed.emit(_total_tests, _passed_tests)

func run_test(test_name: String):
	var success := true
	var message := "Test passed"
	
	push_warning("Running test: " + test_name) # This will show in debugger
	
	if has_method("setup"):
		setup()
	
	# Run the actual test
	var error = null
	if call(test_name) != null:
		success = false
		message = "Test failed with error"
		push_error("Test failed: " + test_name + " - " + message)
	
	if has_method("teardown"):
		teardown()
	
	test_completed.emit(test_name, success, message)

func _on_test_completed(test_name: String, passed: bool, message: String):
	if passed:
		_passed_tests += 1
		print("  ✓ PASS: " + test_name)
	else:
		print("  × FAIL: " + test_name)
		print("    Error: " + message)

func _on_all_tests_completed(total: int, passed: int):
	print("\n=== Test Results ===")
	print("Total Tests: " + str(total))
	print("Passed: " + str(passed))
	print("Failed: " + str(total - passed))
	print("Success Rate: " + str(float(passed) / float(total) * 100) + "%")

# Helper assertion functions
func assert_eq(actual, expected, message := ""):
	if actual != expected:
		var error = "Assertion failed: Expected %s but got %s. %s" % [str(expected), str(actual), message]
		push_error(error)
		assert(false, error)

func assert_true(condition: bool, message := ""):
	if not condition:
		push_error("Assertion failed: " + message)
		assert(false, message)

func assert_false(condition: bool, message := ""):
	if condition:
		push_error("Assertion failed: " + message)
		assert(false, message)

# Optional setup/teardown methods
func setup():
	# Override this in your test class if needed
	pass

func teardown():
	# Override this in your test class if needed
	pass

# Example test methods
func test_assert_true():
	assert_true(true, "This test should pass")

func test_math():
	assert_eq(2 + 2, 4, "Basic math should work")

func test_string_operations():
	var test_string := "Hello"
	assert_eq(test_string.length(), 5, "String length should be correct")
	assert_eq(test_string.to_upper(), "HELLO", "String to upper should work")

func test_array_operations():
	var test_array := [1, 2, 3]
	assert_eq(test_array.size(), 3, "Array size should be correct")
	assert_eq(test_array[0], 1, "Array indexing should work")
	test_array.append(4)
	assert_eq(test_array.size(), 4, "Array append should work")
