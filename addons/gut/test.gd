## This is the base class for all test scripts.  Extend this...test the world!
class_name GutTest
extends Node

# Base class for all GUT test scripts
# Provides common testing functionality

func before_all():
	await get_tree().process_frame

func after_all():
	await get_tree().process_frame

func before_each():
	await get_tree().process_frame

func after_each():
	await get_tree().process_frame

func assert_true(condition: bool, text: String = "") -> void:
	assert(condition, text)

func assert_false(condition: bool, text: String = "") -> void:
	assert(!condition, text)

func assert_eq(actual, expected, text: String = "") -> void:
	assert(actual == expected, text)

func assert_ne(actual, expected, text: String = "") -> void:
	assert(actual != expected, text)

func assert_gt(actual, expected, text: String = "") -> void:
	assert(actual > expected, text)

func assert_lt(actual, expected, text: String = "") -> void:
	assert(actual < expected, text)

func assert_ge(actual, expected, text: String = "") -> void:
	assert(actual >= expected, text)

func assert_le(actual, expected, text: String = "") -> void:
	assert(actual <= expected, text)

func assert_not_null(value, text: String = "") -> void:
	assert(value != null, text)

func assert_null(value, text: String = "") -> void:
	assert(value == null, text)

func assert_has(collection, value, text: String = "") -> void:
	assert(value in collection, text)

func assert_does_not_have(collection, value, text: String = "") -> void:
	assert(!(value in collection), text)

func assert_file_exists(path: String, text: String = "") -> void:
	assert(FileAccess.file_exists(path), text)

func assert_file_does_not_exist(path: String, text: String = "") -> void:
	assert(!FileAccess.file_exists(path), text)

func assert_is_instance(instance: Object, type: String, text: String = "") -> void:
	assert(instance.is_class(type), text)
