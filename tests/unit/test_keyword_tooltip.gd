extends GdUnitTestSuite
## KeywordTooltip System Tests
## Tests keyword tooltip formatting, display, and bookmark functionality
## gdUnit4 v6.0.1 compatible
## 5 tests total (well under 13-test limit)

# System under test
var tooltip: KeywordTooltip

# Test fixtures
var test_control: Control
var test_keyword_data: Dictionary

# Store original KeywordDB data to restore after tests
var original_keywords: Dictionary = {}
var original_bookmarks: Array[String] = []

func before():
	"""Suite-level setup - runs once before all tests"""
	# Backup KeywordDB state
	original_keywords = KeywordDB.keywords.duplicate(true)
	original_bookmarks = KeywordDB.bookmarked_keywords.duplicate()

func after():
	"""Suite-level cleanup - runs once after all tests"""
	# Restore original KeywordDB state
	KeywordDB.keywords = original_keywords
	KeywordDB.bookmarked_keywords = original_bookmarks

func before_test():
	"""Test-level setup - runs before EACH test"""
	# Clear KeywordDB for clean test state
	KeywordDB.keywords.clear()
	KeywordDB.bookmarked_keywords.clear()

	# Create tooltip instance using class_name (KeywordTooltip extends Control)
	# Must be added to scene tree for _ready() to fire
	tooltip = auto_free(KeywordTooltip.new())
	add_child(tooltip)
	await get_tree().process_frame  # Wait for _ready() to complete

	# Create test control for positioning
	test_control = auto_free(Control.new())
	test_control.position = Vector2(100, 100)
	test_control.size = Vector2(50, 50)
	add_child(test_control)

	# Setup test keyword data
	test_keyword_data = {
		"term": "Assault",
		"definition": "Can move before or after firing in same activation.",
		"extended": "This trait allows tactical repositioning during combat.",
		"examples": ["A soldier with Assault fires, then moves to cover."],
		"related": ["Cover", "Movement"],
		"rule_page": 42
	}

	# Add test keyword to KeywordDB
	KeywordDB.keywords["assault"] = test_keyword_data

func after_test():
	"""Test-level cleanup - runs after EACH test"""
	# auto_free() handles cleanup automatically
	tooltip = null
	test_control = null
	test_keyword_data = {}

	# Clear test data from KeywordDB
	KeywordDB.keywords.clear()
	KeywordDB.bookmarked_keywords.clear()

# ============================================================================
# BBCode Formatting Tests (2 tests)
# ============================================================================

func test_format_keyword_text_creates_correct_bbcode():
	"""Keyword data formatted as BBCode with term, definition, extended, and example"""
	# Setup tooltip with test keyword
	tooltip.current_keyword = test_keyword_data

	# Format the keyword text
	var formatted_text = tooltip._format_keyword_text()

	# Verify BBCode structure
	assert_that(formatted_text).contains("[b]ASSAULT[/b]")  # Term in bold uppercase
	assert_that(formatted_text).contains("Can move before or after firing")  # Definition
	assert_that(formatted_text).contains("This trait allows tactical repositioning")  # Extended
	assert_that(formatted_text).contains("[i]Example:")  # Example prefix
	assert_that(formatted_text).contains("A soldier with Assault fires")  # Example text

func test_format_keyword_text_handles_minimal_data():
	"""Keyword with only term and definition formats correctly without optional fields"""
	# Minimal keyword data (no extended, examples, or related)
	var minimal_keyword = {
		"term": "Bulky",
		"definition": "Reduces movement speed by 1 inch."
	}

	tooltip.current_keyword = minimal_keyword
	var formatted_text = tooltip._format_keyword_text()

	# Verify basic formatting
	assert_that(formatted_text).contains("[b]BULKY[/b]")
	assert_that(formatted_text).contains("Reduces movement speed by 1 inch.")

	# Verify optional sections NOT present
	assert_that(formatted_text).does_not_contain("[i]Example:")
	assert_that(formatted_text).does_not_contain("extended")

# ============================================================================
# Tooltip Display Tests (2 tests)
# ============================================================================

func test_show_for_keyword_displays_tooltip_with_keyword_data():
	"""show_for_keyword() retrieves keyword data and displays formatted tooltip"""
	# Create signal monitor
	var signal_monitor = monitor_signals(tooltip)

	# Show tooltip for known keyword
	tooltip.show_for_keyword("assault", test_control)

	# Wait for tooltip to show (immediate show)
	await await_signal_on(tooltip, "tooltip_shown")

	# Verify tooltip is visible
	assert_that(tooltip.visible).is_true()

	# Verify signal emitted with formatted content
	assert_signal(signal_monitor).is_emitted("tooltip_shown")

	# Verify current_keyword populated
	assert_that(tooltip.current_keyword).is_equal(test_keyword_data)

	# Verify tooltip content contains keyword term
	assert_that(tooltip.tooltip_content).contains("ASSAULT")

func test_show_for_keyword_handles_unknown_keyword_gracefully():
	"""show_for_keyword() with unknown keyword hides tooltip instead of crashing"""
	# Attempt to show tooltip for non-existent keyword
	tooltip.show_for_keyword("NonExistentKeyword", test_control)

	# Verify tooltip is NOT visible
	assert_that(tooltip.visible).is_false()

	# Verify current_keyword is empty
	assert_that(tooltip.current_keyword.is_empty()).is_true()

# ============================================================================
# Bookmark Functionality Test (1 test)
# ============================================================================

func test_bookmark_button_toggles_bookmark_state():
	"""Clicking bookmark button toggles KeywordDB bookmark state and updates UI"""
	# Show tooltip with keyword
	tooltip.show_for_keyword("assault", test_control)
	await assert_signal(tooltip).is_emitted("tooltip_shown").wait_until(500)

	# Verify initial bookmark state (not bookmarked)
	assert_that(KeywordDB.is_bookmarked("assault")).is_false()
	assert_that(tooltip.bookmark_button.text).is_equal("☆")  # Empty star

	# Simulate bookmark button click
	tooltip._on_bookmark_pressed()

	# Verify bookmark toggled in KeywordDB
	assert_that(KeywordDB.is_bookmarked("assault")).is_true()

	# Update UI to reflect bookmark state
	tooltip._update_keyword_content()

	# Verify bookmark button UI updated
	assert_that(tooltip.bookmark_button.text).is_equal("★")  # Filled star

	# Toggle bookmark again (unbookmark)
	tooltip._on_bookmark_pressed()
	assert_that(KeywordDB.is_bookmarked("assault")).is_false()

	# Update UI again
	tooltip._update_keyword_content()
	assert_that(tooltip.bookmark_button.text).is_equal("☆")  # Empty star again
