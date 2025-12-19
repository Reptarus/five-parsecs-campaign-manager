class_name StoryTextFormatter
extends RefCounted

## StoryTextFormatter - Utility for formatting story text with keywords
##
## Provides helper functions for parsing story mission narrative text
## and integrating with the KeywordSystem for clickable game terms.
##
## Usage:
##   var formatted_text = StoryTextFormatter.format_narrative_text(mission_data.narrative.intro)
##   rich_text_label.bbcode_text = formatted_text
##   rich_text_label.meta_clicked.connect(_on_keyword_clicked)

## Format story narrative text with keyword links
##
## Args:
##   narrative_text: Raw narrative text from story mission JSON
##   add_formatting: If true, adds visual formatting (bold, spacing)
##
## Returns:
##   BBCode string with clickable keyword links
static func format_narrative_text(narrative_text: String, add_formatting: bool = true) -> String:
	if narrative_text.is_empty():
		return "[i]No narrative available[/i]"

	# Parse text for keywords using KeywordDB
	var parsed_text: String = KeywordDB.parse_text_for_keywords(narrative_text)

	# Add optional visual formatting
	if add_formatting:
		# Add subtle color for narrative text
		parsed_text = "[color=#E0E0E0]%s[/color]" % parsed_text

	return parsed_text

## Format complete mission narrative structure
##
## Args:
##   narrative: Dictionary with keys: intro, briefing, completion_success, completion_failure
##   sections: Array of section keys to include (default: ["intro", "briefing"])
##
## Returns:
##   BBCode string with formatted sections and keyword links
static func format_mission_narrative(narrative: Dictionary, sections: Array = ["intro", "briefing"]) -> String:
	var formatted_sections: Array[String] = []

	for section_key in sections:
		if narrative.has(section_key):
			var section_text: String = narrative[section_key]
			var section_title: String = _get_section_title(section_key)

			# Format section with title and parsed text
			var formatted_section := "[b][color=#4FC3F7]%s[/color][/b]\n\n%s" % [
				section_title,
				format_narrative_text(section_text, false)
			]
			formatted_sections.append(formatted_section)

	# Join sections with spacing
	return "\n\n[color=#3A3A5C]━━━━━━━━━━━━━━━━━━━━[/color]\n\n".join(formatted_sections)

## Format mission briefing with objective keywords
##
## Args:
##   briefing: Briefing text
##   objectives: Dictionary with primary, secondary, bonus objectives
##
## Returns:
##   BBCode string with briefing and formatted objectives
static func format_briefing_with_objectives(briefing: String, objectives: Dictionary) -> String:
	var formatted := format_narrative_text(briefing)

	# Add objectives section
	formatted += "\n\n[b][color=#4FC3F7]Objectives[/color][/b]\n"

	# Primary objective
	if objectives.has("primary"):
		var primary: Dictionary = objectives.primary
		var objective_text: String = primary.get("description", "")
		formatted += "\n[color=#10B981]▸ Primary:[/color] %s" % format_narrative_text(objective_text, false)

	# Secondary objective
	if objectives.has("secondary"):
		var secondary: Dictionary = objectives.secondary
		var objective_text: String = secondary.get("description", "")
		formatted += "\n[color=#D97706]▸ Secondary:[/color] %s" % format_narrative_text(objective_text, false)

	# Bonus objective
	if objectives.has("bonus"):
		var bonus: Dictionary = objectives.bonus
		var objective_text: String = bonus.get("description", "")
		formatted += "\n[color=#808080]▸ Bonus:[/color] %s" % format_narrative_text(objective_text, false)

	return formatted

## Format completion narrative (success or failure)
##
## Args:
##   narrative: Dictionary with completion_success and completion_failure
##   success: If true, shows success text; if false, shows failure text
##
## Returns:
##   BBCode string with formatted completion narrative
static func format_completion_narrative(narrative: Dictionary, success: bool) -> String:
	var key: String = "completion_success" if success else "completion_failure"

	if not narrative.has(key):
		return "[i]No completion narrative available[/i]"

	var completion_text: String = narrative[key]
	var status_color: String = "#10B981" if success else "#DC2626"
	var status_icon: String = "✓" if success else "✗"
	var status_label: String = "Mission Complete" if success else "Mission Failed"

	return "[center][b][color=%s]%s %s[/color][/b][/center]\n\n%s" % [
		status_color,
		status_icon,
		status_label,
		format_narrative_text(completion_text)
	]

## Get section title from key
static func _get_section_title(section_key: String) -> String:
	match section_key:
		"intro":
			return "Introduction"
		"briefing":
			return "Mission Briefing"
		"completion_success":
			return "Success"
		"completion_failure":
			return "Failure"
		_:
			return section_key.capitalize()

## Parse and highlight terrain features in narrative
##
## Args:
##   narrative_text: Raw narrative text
##   terrain_features: Array of terrain feature dictionaries
##
## Returns:
##   BBCode string with terrain features highlighted
static func highlight_terrain_in_narrative(narrative_text: String, terrain_features: Array) -> String:
	var parsed := format_narrative_text(narrative_text)

	# Highlight terrain types mentioned in narrative
	for feature in terrain_features:
		if feature is Dictionary and feature.has("description"):
			var description: String = feature.description
			# Replace terrain descriptions with colored versions
			if parsed.contains(description):
				parsed = parsed.replace(description, "[color=#4FC3F7]%s[/color]" % description)

	return parsed

## Extract tutorial hints from mission and format
##
## Args:
##   tutorial_hints: Array of hint keys (e.g., ["BattleJournal", "DiceDashboard"])
##   tutorial_context: Context string explaining the hints
##
## Returns:
##   BBCode string with formatted tutorial section
static func format_tutorial_section(tutorial_hints: Array, tutorial_context: String = "") -> String:
	if tutorial_hints.is_empty():
		return ""

	var formatted := "\n\n[b][color=#D97706]📖 Tutorial Hint[/color][/b]\n"

	if not tutorial_context.is_empty():
		formatted += format_narrative_text(tutorial_context, false) + "\n"

	formatted += "\n[color=#808080]Referenced systems: %s[/color]" % ", ".join(tutorial_hints)

	return formatted
