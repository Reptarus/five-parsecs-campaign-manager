## Base interface of all GdUnit asserts
class_name GdUnitAssert
extends RefCounted


## Verifies that the current value is null.
func is_null():
	return self


## Verifies that the current value is not null.
func is_not_null():
	return self


## Verifies that the current value is equal to expected one.
func is_equal(expected: Variant):
	return self


## Verifies that the current value is not equal to expected one.
func is_not_equal(expected: Variant):
	return self


func do_fail():
	return self


## Overrides the default failure message by given custom message.
func override_failure_message(message :String):
	return self


## Appends a custom message to the failure message.
## This can be used to add additional infromations to the generated failure message.
func append_failure_message(message :String):
	return self
