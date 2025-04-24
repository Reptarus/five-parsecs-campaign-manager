@tool
extends "res://addons/gut/test.gd"

func before_each():
	# This runs before each test
	pass
	
func after_each():
	# This runs after each test
	pass

func before_all():
	# This runs once before all tests
	print("Starting basic tests")
	
func after_all():
	# This runs once after all tests
	print("Finished basic tests")
	
func test_assert_true():
	assert_true(true, "True should be true")
	
func test_assert_false():
	assert_false(false, "False should be false")
	
func test_assert_eq():
	assert_eq(1, 1, "1 equals 1")
	
func test_assert_ne():
	assert_ne(1, 2, "1 does not equal 2")