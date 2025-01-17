extends "res://addons/gut/test.gd"

# This runs before each test function
func before_each():
    print("Running a test...")

# This is a test function - must start with 'test_'
func test_simple_assertion():
    assert_true(true, "True should be true!")
    
# Another test function
func test_basic_math():
    var a = 2 + 2
    assert_eq(a, 4, "2 + 2 should equal 4")