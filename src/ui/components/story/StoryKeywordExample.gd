extends Control

## Example demonstrating keyword integration in story text
## Shows how to use KeywordDB and KeywordTooltip with story narratives

@onready var narrative_display: RichTextLabel = $VBoxContainer/NarrativeDisplay
@onready var test_button: Button = $VBoxContainer/TestButton

var keyword_tooltip: KeywordTooltip = null

func _ready() -> void:
	# Setup narrative display
	narrative_display.bbcode_enabled = true
	narrative_display.fit_content = true
	narrative_display.scroll_active = true

	# Load example story narrative
	_load_example_narrative()

	# Connect meta_clicked for keyword links
	narrative_display.meta_clicked.connect(_on_keyword_clicked)

	# Setup test button
	test_button.pressed.connect(_on_test_button_pressed)

## Load and display example story narrative with keywords
func _load_example_narrative() -> void:
	# Example narrative text from mission_01_discovery.json (with keywords)
	var example_narrative := """
Your crew picks up a mysterious signal from an abandoned research facility.
The signal appears to be a distress call, but something about it feels wrong -
the encryption is military grade, far too sophisticated for a simple research station.

Investigate the source of the signal at the abandoned research facility.
Be prepared for hostile scavengers who may have already claimed the site.
Use Reactions to act quickly, and maintain Cover to protect against enemy fire.

Your crew must navigate Difficult Ground and use their Combat Skill to eliminate threats.
Characters with high Toughness can withstand more damage, while those with better
Savvy may spot hidden dangers. Don't forget you can spend Luck to reroll critical dice.

The enemy forces include Gangers with various weapon configurations:
- Leaders may have Assault weapons for mobile firepower
- Some carry Heavy weapons requiring setup time
- Watch for Bulky equipment that limits movement
- Pistol-armed enemies can fight while engaged in Brawling

Terrain features provide tactical options:
- Heavy Cover behind walls (+2 Toughness)
- Elevated positions grant shooting bonuses
- Linear Obstacles require movement to cross
- Impassable barriers block line of sight

Success rewards Credits and Story Points for campaign progression.
"""

	# Parse narrative for keywords
	var parsed_narrative: String = KeywordDB.parse_text_for_keywords(example_narrative)

	# Display with formatting
	narrative_display.text = "[b][color=#4FC3F7]Mission Briefing[/color][/b]\n\n" + parsed_narrative

	print("StoryKeywordExample: Loaded example narrative with keyword links")

## Handle keyword link clicks
func _on_keyword_clicked(meta: Variant) -> void:
	var meta_str := str(meta)

	if meta_str.begins_with("keyword:"):
		var keyword_term := meta_str.substr(8)
		print("Keyword clicked: ", keyword_term)
		_show_keyword_tooltip(keyword_term)

## Show keyword tooltip
func _show_keyword_tooltip(keyword: String) -> void:
	# Get or create tooltip instance
	if keyword_tooltip == null:
		keyword_tooltip = _get_or_create_tooltip()

	if keyword_tooltip:
		# Position tooltip near mouse
		var tooltip_position := get_global_mouse_position()
		keyword_tooltip.show_for_keyword(keyword, tooltip_position)

## Get or create KeywordTooltip singleton
func _get_or_create_tooltip() -> KeywordTooltip:
	var existing_tooltip := get_tree().root.get_node_or_null("KeywordTooltip")
	if existing_tooltip and existing_tooltip is KeywordTooltip:
		return existing_tooltip as KeywordTooltip

	var tooltip := KeywordTooltip.new()
	tooltip.name = "KeywordTooltip"
	get_tree().root.add_child(tooltip)

	return tooltip

## Test button handler - demonstrates different formatting options
func _on_test_button_pressed() -> void:
	# Example: Using StoryTextFormatter utility
	var mission_narrative := {
		"intro": "Your crew encounters hostile forces with superior Reactions and Combat Skill.",
		"briefing": "Eliminate the enemy leader. Use Cover and maintain tactical spacing."
	}

	var formatted := StoryTextFormatter.format_mission_narrative(
		mission_narrative,
		["intro", "briefing"]
	)

	narrative_display.text = formatted
	print("StoryKeywordExample: Loaded formatted mission narrative")
