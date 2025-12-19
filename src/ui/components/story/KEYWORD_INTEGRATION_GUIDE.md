# Keyword System Integration Guide

## Overview

The KeywordSystem provides tap-to-reveal definitions for game terms throughout the Five Parsecs Campaign Manager. This guide explains how to integrate keyword tooltips into story narrative text and other UI components.

## System Components

### 1. KeywordDB (Autoload Singleton)
- **Path**: `/src/qol/KeywordSystem.gd`
- **Autoload Name**: `KeywordDB`
- **Purpose**: Manages keyword database, parsing, and analytics

#### Core API
```gdscript
# Parse text for keywords (returns BBCode with [url=keyword:X] links)
var parsed_text: String = KeywordDB.parse_text_for_keywords(raw_text)

# Get keyword data
var keyword_data: Dictionary = KeywordDB.get_keyword("reactions")

# Search keywords
var results: Array[Dictionary] = KeywordDB.search_keywords("combat")
```

### 2. KeywordTooltip Component
- **Path**: `/src/ui/components/tooltips/KeywordTooltip.gd`
- **Purpose**: Displays keyword definitions in responsive dialog

#### Usage
```gdscript
# Create tooltip instance (singleton pattern recommended)
var tooltip := KeywordTooltip.new()
get_tree().root.add_child(tooltip)

# Show tooltip for keyword
tooltip.show_for_keyword("reactions", get_global_mouse_position())
```

### 3. Keyword Database
- **Path**: `/data/keywords.json`
- **Contains**: 70+ game terms including:
  - Stats (Reactions, Combat Skill, Toughness, Savvy, Speed, Luck)
  - Weapon traits (Assault, Auto, Heavy, Bulky, Piercing, etc.)
  - Terrain (Cover, Difficult Ground, Elevated, etc.)
  - Species (K'Erin, Soulless, Swift, Engineer, etc.)
  - Campaign mechanics (Story Points, Patrons, Rivals, etc.)

#### Keyword Structure
```json
{
  "reactions": {
    "term": "Reactions",
    "definition": "Determines activation order in combat...",
    "related": ["speed", "activation", "combat_skill"],
    "rule_page": 41,
    "category": "stat"
  }
}
```

## Integration Patterns

### Pattern 1: Story Narrative Text (StoryTrackPanel)

**Implementation**: `/src/ui/components/story/StoryTrackPanel.gd`

```gdscript
func _display_event(event: StoryEvent) -> void:
    # Parse description for keywords
    var parsed_text: String = KeywordDB.parse_text_for_keywords(event.description)

    # Display in RichTextLabel
    event_description.bbcode_text = parsed_text

    # Connect meta_clicked signal
    if not event_description.meta_clicked.is_connected(_on_keyword_link_clicked):
        event_description.meta_clicked.connect(_on_keyword_link_clicked)

func _on_keyword_link_clicked(meta: Variant) -> void:
    var meta_str := str(meta)
    if meta_str.begins_with("keyword:"):
        var keyword_term := meta_str.substr(8)
        _show_keyword_tooltip(keyword_term)
```

### Pattern 2: Story Mission JSON Integration

**Using StoryTextFormatter Utility**:

```gdscript
# Format mission intro with keywords
var formatted_intro := StoryTextFormatter.format_narrative_text(
    mission_data.narrative.intro
)
intro_label.bbcode_text = formatted_intro

# Format complete mission briefing
var formatted_briefing := StoryTextFormatter.format_mission_narrative(
    mission_data.narrative,
    ["intro", "briefing"]
)

# Format with objectives
var formatted_with_objectives := StoryTextFormatter.format_briefing_with_objectives(
    mission_data.narrative.briefing,
    mission_data.objectives
)
```

### Pattern 3: Character Equipment Display

**Example**: CharacterCard showing weapon traits

```gdscript
# Equipment has traits: ["Assault", "Bulky"]
var formatted_equipment := KeywordTooltip.format_equipment_with_keywords(
    "Infantry Laser",
    ["Assault", "Bulky"]
)
equipment_label.bbcode_text = formatted_equipment
equipment_label.meta_clicked.connect(_on_keyword_clicked)
```

### Pattern 4: Battle Event Descriptions

```gdscript
# Battle event text may contain terrain and combat terms
var event_text := "Enemy takes cover behind rubble. Roll for Reactions."
var parsed_text := KeywordDB.parse_text_for_keywords(event_text)
event_log.append_bbcode_text(parsed_text + "\n")
```

## StoryTextFormatter Utility

**Path**: `/src/ui/components/story/StoryTextFormatter.gd`

Provides helpers for story mission narrative formatting:

### Functions

#### `format_narrative_text(narrative_text: String, add_formatting: bool = true) -> String`
Parses narrative text for keywords and optionally adds visual formatting.

```gdscript
var formatted := StoryTextFormatter.format_narrative_text(
    mission_data.narrative.intro
)
```

#### `format_mission_narrative(narrative: Dict, sections: Array[String]) -> String`
Formats multiple narrative sections with titles and separators.

```gdscript
var formatted := StoryTextFormatter.format_mission_narrative(
    mission_data.narrative,
    ["intro", "briefing", "completion_success"]
)
```

#### `format_briefing_with_objectives(briefing: String, objectives: Dict) -> String`
Combines briefing text with formatted objectives list.

```gdscript
var formatted := StoryTextFormatter.format_briefing_with_objectives(
    mission_data.narrative.briefing,
    mission_data.objectives
)
```

#### `format_completion_narrative(narrative: Dict, success: bool) -> String`
Formats success or failure completion text with status header.

```gdscript
# Show success narrative
var formatted := StoryTextFormatter.format_completion_narrative(
    mission_data.narrative,
    true  # success = true
)
```

## Story Mission JSON Structure

### Narrative Fields (All support keyword parsing)

```json
{
  "narrative": {
    "intro": "Your crew picks up a mysterious signal...",
    "briefing": "Investigate the source of the signal...",
    "completion_success": "You've secured the facility...",
    "completion_failure": "You were forced to retreat..."
  },
  "objectives": {
    "primary": {
      "type": "investigate",
      "description": "Reach the signal source and download data"
    },
    "secondary": {
      "type": "hold_field",
      "description": "Secure the research facility"
    }
  },
  "tutorial_hints": ["BattleJournal", "DiceDashboard"],
  "tutorial_context": "This is your first Story Track mission..."
}
```

### Keywords Automatically Detected

The system automatically detects and links these terms in narrative text:

**Stats**: Reactions, Combat Skill, Toughness, Savvy, Speed, Luck
**Combat**: Brawling, Shooting, Cover, Line of Sight, Range, Damage
**Terrain**: Heavy Cover, Difficult Ground, Elevated, Impassable
**Status**: Stunned, Pinned, Out of Action, Casualty
**Weapon Traits**: Assault, Auto, Heavy, Bulky, Pistol, Melee, Piercing
**Campaign**: Story Points, Upkeep, Patron, Rival, Credits, Loot

## Testing the Integration

### Manual Testing Steps

1. **Load Story Mission**: Open StoryTrackPanel with mission_01_discovery.json
2. **Verify Keywords Highlighted**: Look for underlined terms in narrative text
3. **Tap Keyword**: Click/tap a highlighted keyword (e.g., "signal")
4. **Verify Tooltip Shows**: Dialog appears with keyword definition
5. **Test Related Keywords**: Click related keyword links in tooltip
6. **Test Mobile Layout**: Resize viewport < 600px, verify bottom sheet

### Example Test Mission Text

```gdscript
# Test text with multiple keywords
var test_narrative := """
Your crew must use Reactions to move quickly across Difficult Ground.
The enemy has Heavy Cover behind the facility walls.
Roll for Toughness to resist damage, or spend Luck to reroll.
"""

var parsed := KeywordDB.parse_text_for_keywords(test_narrative)
# Output: "Your crew must use [url=keyword:reactions]Reactions[/url] to move..."
```

### Automated Testing

```gdscript
# Unit test for keyword parsing
func test_narrative_keywords():
    var narrative := "Use Reactions to act first"
    var parsed := KeywordDB.parse_text_for_keywords(narrative)

    assert_true(parsed.contains("[url=keyword:reactions]"))
    assert_true(parsed.contains("[/url]"))
```

## Performance Considerations

### Caching
- KeywordTooltip caches formatted BBCode strings in `_formatted_cache`
- Avoid reparsing the same text multiple times

### Best Practices
```gdscript
# ✅ GOOD: Parse once, cache result
var parsed_text := KeywordDB.parse_text_for_keywords(narrative)
_narrative_cache[mission_id] = parsed_text
label.bbcode_text = parsed_text

# ❌ BAD: Reparsing every frame
func _process(delta):
    label.bbcode_text = KeywordDB.parse_text_for_keywords(narrative)
```

### Tooltip Instance Management
```gdscript
# ✅ GOOD: Singleton pattern (reuse instance)
func _get_or_create_tooltip() -> KeywordTooltip:
    var existing := get_tree().root.get_node_or_null("KeywordTooltip")
    if existing:
        return existing
    var new_tooltip := KeywordTooltip.new()
    get_tree().root.add_child(new_tooltip)
    return new_tooltip

# ❌ BAD: Creating new tooltip every click
func _on_keyword_clicked(keyword: String):
    var tooltip := KeywordTooltip.new()  # Memory leak!
    add_child(tooltip)
    tooltip.show_for_keyword(keyword, Vector2.ZERO)
```

## Adding New Keywords

### Step 1: Update keywords.json

```json
{
  "your_new_term": {
    "term": "Your New Term",
    "definition": "What this term means in gameplay",
    "related": ["related_term_1", "related_term_2"],
    "rule_page": 42,
    "category": "mechanic"
  }
}
```

### Step 2: Reload KeywordDB

KeywordDB loads on game start. For testing:

```gdscript
# Force reload in debug build
KeywordDB._load_keyword_database()
```

### Step 3: Verify Detection

```gdscript
var test_text := "This text mentions Your New Term"
var parsed := KeywordDB.parse_text_for_keywords(test_text)
print(parsed)  # Should contain [url=keyword:your_new_term]
```

## Troubleshooting

### Keywords Not Detected
1. Check keyword exists in `/data/keywords.json`
2. Verify KeywordDB autoload is active (Project Settings > Autoload)
3. Check console for parse errors during database load
4. Ensure keyword term matches exactly (case-insensitive)

### Tooltip Not Showing
1. Verify `meta_clicked` signal is connected
2. Check tooltip instance exists in scene tree
3. Ensure RichTextLabel has `bbcode_enabled = true`
4. Verify URL format is `keyword:term_name` (no spaces)

### Performance Issues
1. Check if text is being reparsed every frame
2. Verify tooltip instances are being reused (singleton pattern)
3. Use profiler to check KeywordDB.parse_text_for_keywords() call frequency

## References

- **Keyword System Source**: `/src/qol/KeywordSystem.gd`
- **Tooltip Component**: `/src/ui/components/tooltips/KeywordTooltip.gd`
- **Story Formatter**: `/src/ui/components/story/StoryTextFormatter.gd`
- **Story Panel Integration**: `/src/ui/components/story/StoryTrackPanel.gd`
- **Keyword Database**: `/data/keywords.json`
- **Story Mission Example**: `/data/story_track_missions/mission_01_discovery.json`
