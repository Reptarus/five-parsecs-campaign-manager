## An assertion tool to verify GDUnit asserts.
## This assert is for internal use only, to verify that failed asserts work as expected.
class_name GdUnitFailureAssert
extends GdUnitAssert


## Verifies if the executed assert was successful
func is_success() -> GdUnitFailureAssert:
	return self

## Verifies if the executed assert has failed
func is_failed() -> GdUnitFailureAssert:
	return self


## Verifies the failure line is equal to expected one.
func has_line(expected :int) -> GdUnitFailureAssert:
	return self


## Verifies the failure message is equal to expected one.
func has_message(expected: String) -> GdUnitFailureAssert:
	return self


## Verifies that the failure message starts with the expected message.
func starts_with_message(expected: String) -> GdUnitFailureAssert:
	return self


## Verifies that the failure message contains the expected message.
func contains_message(expected: String) -> GdUnitFailureAssert:
	return self
