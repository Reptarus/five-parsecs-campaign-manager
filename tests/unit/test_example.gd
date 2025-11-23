extends GdUnitTestSuite
## Example gdUnit4 Test Suite
## This shows the proper format for gdUnit4 tests

# This test will be discovered by gdUnit4!

func test_basic_assertion():
	"""Example test showing basic assertions"""
	var result = 2 + 2
	assert_that(result).is_equal(4)

func test_string_assertion():
	"""Example test showing string assertions"""
	var text = "Hello World"
	assert_that(text).contains("World")

func test_array_assertion():
	"""Example test showing array assertions"""
	var items = [1, 2, 3, 4, 5]
	assert_that(items).contains([2, 3])

func before_test():
	"""Runs before each test method"""
	pass

func after_test():
	"""Runs after each test method"""
	pass

