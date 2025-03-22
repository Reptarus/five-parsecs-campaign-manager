@tool
extends "res://addons/gut/test.gd"

func test_simple_assertion():
	assert_true(true, "True is true")
	
func test_math():
	assert_eq(2 + 2, 4, "Basic math works")
	
func test_pending_test():
	pending("This test is pending implementation")
