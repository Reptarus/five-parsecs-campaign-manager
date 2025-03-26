## Simple test for reference
@tool
extends "res://tests/fixtures/base/game_test.gd"

const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")

func test_simple_assert() -> void:
	assert_true(true, "True should be true")