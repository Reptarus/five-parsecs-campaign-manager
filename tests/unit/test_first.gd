extends "res://tests/test_base.gd"

func before_each():
    super.before_each()
    print("Running a test...")

func after_each():
    super.after_each()

func test_simple_assertion():
    assert_true(true, "True should be true!")
    
func test_basic_math():
    var a = 2 + 2
    assert_eq(a, 4, "2 + 2 should equal 4")