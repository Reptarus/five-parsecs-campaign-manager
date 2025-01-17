extends "res://addons/gut/test.gd"

func test_assert_true():
	assert_true(true, "This test should always pass")
	
func test_simple_addition():
	assert_eq(2 + 2, 4, "Basic math should work")
