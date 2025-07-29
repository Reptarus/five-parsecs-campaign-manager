extends GdUnitTestSuite

const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")

func test_validate_character_name_valid():
	# Test valid character names
	var valid_names = ["John", "Mary Smith", "Captain Jack", "Dr. Elena-99"]
	
	for name in valid_names:
		var result = SecurityValidator.validate_character_name(name)
		assert_that(result.valid).is_true()
		assert_that(result.error).is_equal("")
		assert_that(result.sanitized_value).is_equal(name.strip_edges())

func test_validate_character_name_too_short():
	var result = SecurityValidator.validate_character_name("A")
	assert_that(result.valid).is_false()
	assert_that(result.error).contains("at least 2 characters")

func test_validate_character_name_too_long():
	var long_name = "A".repeat(51)
	var result = SecurityValidator.validate_character_name(long_name)
	assert_that(result.valid).is_false()
	assert_that(result.error).contains("cannot exceed 50 characters")

func test_validate_character_name_xss_prevention():
	var malicious_names = ["<script>alert('xss')</script>", "John<>Smith", "<div>Name</div>"]
	
	for name in malicious_names:
		var result = SecurityValidator.validate_character_name(name)
		assert_that(result.valid).is_false()
		assert_that(result.error).contains("Invalid characters")

func test_validate_character_name_control_chars():
	var name_with_null = "John\0Smith"
	var result = SecurityValidator.validate_character_name(name_with_null)
	assert_that(result.valid).is_false()
	assert_that(result.error).contains("Invalid control characters")

func test_validate_character_name_dangerous_patterns():
	var suspicious_names = ["ScriptKiddie", "JavaScriptNinja", "EvalMaster"]
	
	for name in suspicious_names:
		var result = SecurityValidator.validate_character_name(name)
		# Should be valid but with warnings
		assert_that(result.valid).is_true()
		assert_that(result.has_warnings()).is_true()

func test_validate_campaign_name_valid():
	var valid_names = ["My Campaign", "Five Parsecs Adventure", "Campaign-2024"]
	
	for name in valid_names:
		var result = SecurityValidator.validate_campaign_name(name)
		assert_that(result.valid).is_true()
		assert_that(result.error).is_equal("")

func test_validate_campaign_name_too_short():
	var result = SecurityValidator.validate_campaign_name("AB")
	assert_that(result.valid).is_false()
	assert_that(result.error).contains("at least 3 characters")

func test_validate_campaign_name_path_traversal():
	var malicious_names = ["../../../system", "campaign/../../etc", "camp\\..\\data"]
	
	for name in malicious_names:
		var result = SecurityValidator.validate_campaign_name(name)
		assert_that(result.valid).is_false()
		assert_that(result.error).contains("invalid path characters")

func test_validate_campaign_name_reserved():
	var reserved_names = ["CON", "prn", "AUX", "nul"]
	
	for name in reserved_names:
		var result = SecurityValidator.validate_campaign_name(name)
		assert_that(result.valid).is_false()
		assert_that(result.error).contains("reserved system name")

func test_validate_save_path_valid():
	var valid_paths = ["campaign.save", "data/campaign.json", "backup.save"]
	
	for path in valid_paths:
		var result = SecurityValidator.validate_save_path(path)
		assert_that(result.valid).is_true()

func test_validate_save_path_empty():
	var result = SecurityValidator.validate_save_path("")
	assert_that(result.valid).is_false()
	assert_that(result.error).contains("cannot be empty")

func test_validate_save_path_traversal():
	var result = SecurityValidator.validate_save_path("../../../system.save")
	assert_that(result.valid).is_false()
	assert_that(result.error).contains("Path traversal not allowed")

func test_validate_save_path_invalid_extension():
	var result = SecurityValidator.validate_save_path("campaign.exe")
	assert_that(result.valid).is_false()
	assert_that(result.error).contains("Invalid file extension")

func test_validate_numeric_input_valid():
	var result = SecurityValidator.validate_numeric_input(5, 1, 10, "Test Value")
	assert_that(result.valid).is_true()
	assert_that(result.sanitized_value).is_equal(5)

func test_validate_numeric_input_too_low():
	var result = SecurityValidator.validate_numeric_input(0, 1, 10, "Test Value")
	assert_that(result.valid).is_false()
	assert_that(result.error).contains("must be at least 1")

func test_validate_numeric_input_too_high():
	var result = SecurityValidator.validate_numeric_input(15, 1, 10, "Test Value")
	assert_that(result.valid).is_false()
	assert_that(result.error).contains("cannot exceed 10")

func test_validate_text_input_valid():
	var result = SecurityValidator.validate_text_input("This is a valid description.", 100, "Description")
	assert_that(result.valid).is_true()

func test_validate_text_input_too_long():
	var long_text = "A".repeat(1001)
	var result = SecurityValidator.validate_text_input(long_text, 1000, "Description")
	assert_that(result.valid).is_false()
	assert_that(result.error).contains("cannot exceed 1000 characters")

func test_validate_text_input_html_stripping():
	var html_text = "Description with <script>alert('xss')</script> content"
	var result = SecurityValidator.validate_text_input(html_text, 1000, "Description")
	assert_that(result.valid).is_true()
	assert_that(result.sanitized_value).does_not_contain("<script>")

func test_validate_batch_mixed():
	var validations = [
		{"type": "character_name", "value": "John Smith"},
		{"type": "campaign_name", "value": "My Campaign"},
		{"type": "character_name", "value": "A"}  # Invalid - too short
	]
	
	var results = SecurityValidator.validate_batch(validations)
	assert_that(results.size()).is_equal(3)
	assert_that(results[0].valid).is_true()
	assert_that(results[1].valid).is_true()
	assert_that(results[2].valid).is_false()