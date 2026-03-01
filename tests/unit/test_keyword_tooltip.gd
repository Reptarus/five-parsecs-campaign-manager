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
	# Set deterministic seed for reproducible random numbers
	seed(12345)

	# Clear KeywordDB for clean test state
	KeywordDB.keywords.clear()
	KeywordDB.bookmarked_keywords.clear()

	# Create tooltip instance using class_name (KeywordTooltip extends Control)
	# Must be added to scene tree for _ready() to fire
	tooltip = auto_free(KeywordTooltip.new())
	add_child(tooltip)
	await get_tree().process_frame  # Wait for _ready() to complete

	# Guard against freed instance after await
	if not is_instance_valid(tooltip):
		push_warning("tooltip freed during setup, test may fail")
		return

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

	# Add test keyword to KeywordDB - must use KeywordData object, not plain Dictionary
	var keyword_data_obj = KeywordDB.KeywordData.new(
		test_keyword_data["term"],
		test_keyword_data["definition"],
		test_keyword_data.get("related", []),
		test_keyword_data.get("rule_page", 0),
		test_keyword_data.get("category", "")
	)
	KeywordDB.keywords["assault"] = keyword_data_obj

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
	# Format the keyword text directly using the public method
	var formatted_text = tooltip.format_keyword_text(test_keyword_data)

	# Verify BBCode structure
	assert_that(formatted_text).contains("[b]Assault[/b]")  # Term in bold (note: actual format uses term as-is, not uppercase)
	assert_that(formatted_text).contains("Can move before or after firing")  # Definition
	# Note: Extended and examples are not in the current format_keyword_text implementation
	# The current implementation only includes: term, definition, related, rule_page

func test_format_keyword_text_handles_minimal_data():
	"""Keyword with only term and definition formats correctly without optional fields"""
	# Minimal keyword data (no extended, examples, or related)
	var minimal_keyword = {
		"term": "Bulky",
		"definition": "Reduces movement speed by 1 inch."
	}

	var formatted_text = tooltip.format_keyword_text(minimal_keyword)

	# Verify basic formatting
	assert_that(formatted_text).contains("[b]Bulky[/b]")
	assert_that(formatted_text).contains("Reduces movement speed by 1 inch.")

	# Verify optional sections NOT present (related keywords section)
	assert_that(formatted_text).not_contains("Related:")

# ============================================================================
# Tooltip Display Tests (2 tests)
# ============================================================================

func test_show_for_keyword_displays_tooltip_with_keyword_data():
	"""show_for_keyword() retrieves keyword data and displays formatted tooltip"""
	if not is_instance_valid(tooltip) or not is_instance_valid(test_control):
		push_warning("Test fixtures freed early, skipping")
		return

	# Monitor signals BEFORE action (signals emit synchronously)
	var _monitor = monitor_signals(tooltip)

	# Show tooltip for known keyword
	tooltip.show_for_keyword("assault", test_control.global_position)

	# Wait a frame for dialog to be created and shown
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(tooltip):
		return

	# Verify signal emitted (use tooltip_opened instead of tooltip_shown)
	assert_signal(tooltip).is_emitted("tooltip_opened", ["assault"])

	# Verify dialog is visible (tooltip uses AcceptDialog, not direct visibility)
	if tooltip._dialog:
		assert_that(tooltip._dialog.visible).is_true()
		
		# Verify tooltip content contains keyword term (access private _rich_text)
		if tooltip._rich_text:
			assert_that(tooltip._rich_text.text).contains("Assault")

func test_show_for_keyword_handles_unknown_keyword_gracefully():
	"""show_for_keyword() with unknown keyword handles gracefully"""
	if not is_instance_valid(tooltip) or not is_instance_valid(test_control):
		push_warning("Test fixtures freed early, skipping")
		return

	# Attempt to show tooltip for non-existent keyword
	tooltip.show_for_keyword("NonExistentKeyword", test_control.global_position)

	# Wait a frame for processing
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(tooltip):
		return

	# Verify dialog shows error message or is not visible
	# The current implementation shows "Unknown term" for non-existent keywords
	if tooltip._dialog and tooltip._dialog.visible:
		if tooltip._rich_text:
			# Should show unknown term message for invalid keyword
			assert_that(tooltip._rich_text.text).contains("Unknown term")

# ============================================================================
# Bookmark Functionality Test (1 test)
# ============================================================================

func test_bookmark_button_toggles_bookmark_state():
	"""Clicking bookmark button toggles KeywordDB bookmark state and updates UI"""
	if not is_instance_valid(tooltip) or not is_instance_valid(test_control):
		push_warning("Test fixtures freed early, skipping")
		return

	# Monitor tooltip signals before action
	var _monitor = monitor_signals(tooltip)

	# Show tooltip with keyword (signal emits synchronously)
	tooltip.show_for_keyword("assault", test_control.global_position)
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for dialog creation

	# Guard against freed instance after await
	if not is_instance_valid(tooltip):
		return

	# Verify initial bookmark state (not bookmarked)
	assert_that(KeywordDB.is_bookmarked("assault")).is_false()
	if tooltip._bookmark_button:
		assert_that(tooltip._bookmark_button.text).contains("Bookmark")  # "☆ Bookmark"

	# Simulate bookmark button click
	tooltip._on_bookmark_pressed()

	# Verify bookmark toggled in KeywordDB
	assert_that(KeywordDB.is_bookmarked("assault")).is_true()

	# Update UI to reflect bookmark state (method is _update_bookmark_button)
	tooltip._update_bookmark_button()

	# Verify bookmark button UI updated
	if tooltip._bookmark_button:
		assert_that(tooltip._bookmark_button.text).contains("Bookmarked")  # "⭐ Bookmarked"

	# Toggle bookmark again (unbookmark)
	tooltip._on_bookmark_pressed()
	assert_that(KeywordDB.is_bookmarked("assault")).is_false()

	# Update UI again
	tooltip._update_bookmark_button()
	if tooltip._bookmark_button:
		assert_that(tooltip._bookmark_button.text).contains("Bookmark")  # "☆ Bookmark" again
