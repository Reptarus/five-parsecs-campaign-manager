@tool
extends "res://addons/gut/test.gd"

## Ultra-minimal test file with no fancy operations
## This test file is guaranteed to run without 'in' operator issues

func test_true_is_true():
	assert_true(true, "True should be true")

func test_addition():
	assert_eq(2 + 2, 4, "Basic math should work")

func test_strings():
	var text = "hello"
	assert_eq(text.length(), 5, "String length should be correct")