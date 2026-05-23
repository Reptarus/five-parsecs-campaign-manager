extends GdUnitTestSuite
## StepperControl baseline-mode tests
##
## Exercises the dual-column "Was: N → M" stepper rendering, which lets stat-edit
## surfaces show current → target side-by-side. Future adopters: PostBattle XP-spend,
## Advancement phase, equipment trade.
## gdUnit4 v6.0.3 compatible.

const StepperControlScript := preload("res://src/ui/components/common/StepperControl.gd")

var stepper: StepperControl

func before_test() -> void:
	stepper = auto_free(StepperControlScript.new())
	add_child(stepper)
	await get_tree().process_frame  # let _ready() build the UI


func test_setup_baseline_shows_baseline_label_and_stores_baseline_value() -> void:
	stepper.setup_with_baseline(3, 4, 0, 10, 1)
	await get_tree().process_frame
	assert_int(stepper.baseline_value).is_equal(3)
	assert_int(stepper.value).is_equal(4)
	assert_bool(stepper._show_baseline).is_true()
	assert_bool(stepper._baseline_label.visible).is_true()
	assert_str(stepper._baseline_label.text).contains("3")


func test_setup_baseline_color_shifts_up_for_improved_target() -> void:
	stepper.setup_with_baseline(3, 5, 0, 10, 1)
	await get_tree().process_frame
	# Value label gets the emerald override when target > baseline
	var color: Color = stepper._value_label.get_theme_color("font_color")
	assert_that(color).is_equal(UIColors.COLOR_EMERALD)


func test_setup_baseline_color_shifts_down_for_reduced_target() -> void:
	stepper.setup_with_baseline(5, 3, 0, 10, 1)
	await get_tree().process_frame
	var color: Color = stepper._value_label.get_theme_color("font_color")
	assert_that(color).is_equal(UIColors.COLOR_RED)


func test_setup_baseline_stays_neutral_when_target_equals_baseline() -> void:
	stepper.setup_with_baseline(4, 4, 0, 10, 1)
	await get_tree().process_frame
	var color: Color = stepper._value_label.get_theme_color("font_color")
	assert_that(color).is_equal(UIColors.COLOR_CYAN)


func test_setup_without_baseline_hides_baseline_label() -> void:
	# Regression guard: after a baseline-mode call, a follow-up plain setup()
	# must reset the widget so it doesn't keep showing a stale "Was: N →" prefix.
	stepper.setup_with_baseline(3, 5, 0, 10, 1)
	await get_tree().process_frame
	stepper.setup(7, 0, 10, 1)
	await get_tree().process_frame
	assert_bool(stepper._show_baseline).is_false()
	assert_bool(stepper._baseline_label.visible).is_false()
	assert_int(stepper.value).is_equal(7)


func test_setup_baseline_clamps_target_within_bounds() -> void:
	# Defensive: a caller passing an out-of-range target shouldn't crash.
	stepper.setup_with_baseline(3, 99, 0, 10, 1)
	await get_tree().process_frame
	assert_int(stepper.value).is_equal(10)
