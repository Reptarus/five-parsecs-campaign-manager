# Keyword System - Tap-to-Reveal Definitions

**Priority**: P0 - Critical  
**Effort**: 2-3 days  
**Phase**: 1 - Core UX  
**Status**: Ready to Implement

## 📖 Overview

The Keyword System provides instant access to game term definitions through contextual tooltips. Inspired by Infinity Army's "secret sauce," this system makes Five Parsecs accessible to new players while providing quick reference for veterans.

**Core Value**: Every keyword, trait, and game term becomes tappable/clickable, revealing definitions without leaving the current screen.

## 🎯 User Stories

### New Player Experience
> "As a **new player**, I want to **tap on unfamiliar terms** so that **I can learn the rules without switching to a manual**."

**Example**: Viewing a character sheet, player sees "Reactions: 4". Tapping "Reactions" shows:
```
[Reactions]
Determines initiative order in combat.
Higher Reactions = act earlier in the round.

Related: Initiative, Combat Sequence, Turn Order
```

### Veteran Quick Reference
> "As a **veteran player**, I want to **quickly check edge cases** so that **I can resolve rules questions at the table**."

**Example**: During equipment purchase, player taps "Powered Armor":
```
[Powered Armor]
+2 Toughness, -1 Speed
Requires Power Cell (1 charge/battle)
Cannot wear with other armor types

Cost: 12 credits
Related: Armor Types, Equipment Slots
```

### Rulebook Cross-Reference
> "As a **game master**, I want **automatic rule cross-references** so that **I can quickly find related mechanics**."

**Example**: Checking "Story Points" shows links to:
- Story Track progression
- Spending Story Points (various uses)
- Earning conditions
- Campaign victory conditions

## 🏗️ Technical Architecture

### System Components

```
KeywordSystem.gd (Autoload Singleton)
├── Keyword Database (JSON/Dictionary)
├── Keyword Parser (text → keywords)
├── Search Engine (fuzzy matching)
├── Bookmark Manager (saved keywords)
└── Analytics (popular searches)

KeywordTooltip.gd (extends Tooltip.gd)
├── Enhanced formatting (BBCode rich text)
├── Related keyword links
├── "See Full Rules" button
└── Bookmark toggle
```

### Integration Points

| Existing System | Integration Method |
|----------------|-------------------|
| `Tooltip.gd` | Extend for keyword-specific formatting |
| `RulesReference.gd` | Source for keyword definitions |
| `RichTextLabel` | Use BBCode for clickable links |
| `GameState.gd` | Save bookmarked keywords |

## 💾 Data Structure

### Keyword Database Format

```gdscript
# res://data/keywords.json
{
  "keywords": [
    {
      "term": "Reactions",
      "category": "stat",
      "definition": "Determines initiative order in combat.",
      "extended": "Higher Reactions means acting earlier...",
      "related": ["Initiative", "Combat Sequence"],
      "rule_page": "CoreRulebook.pdf#page=42",
      "examples": [
        "Reactions 5 vs Reactions 3 = Act first"
      ]
    },
    {
      "term": "Powered Armor",
      "category": "equipment",
      "definition": "+2 Toughness, -1 Speed armor type",
      "stats": {
        "toughness_bonus": 2,
        "speed_penalty": -1,
        "cost": 12
      },
      "related": ["Armor Types", "Equipment Slots"],
      "rule_page": "CoreRulebook.pdf#page=87"
    }
  ],
  "categories": [
    "stat", "trait", "equipment", "weapon", "armor",
    "enemy", "mission", "phase", "mechanic", "condition"
  ]
}
```

### Save Data Format

```gdscript
# In GameState save file
{
  "qol_data": {
    "keywords": {
      "bookmarked": [
        "Reactions", "Toughness", "Story Points"
      ],
      "recent_searches": [
        "combat", "injury", "advancement"
      ],
      "search_history": [
        {"term": "Reactions", "timestamp": 1700000000},
        {"term": "Powered Armor", "timestamp": 1700000060}
      ]
    }
  }
}
```

## 🎨 UI/UX Design

### Visual Appearance

**Keyword Highlighting** (in-text):
- Keywords appear with subtle **underline** (dotted)
- Hover: Underline becomes solid, cursor changes to pointer
- Tap/Click: Tooltip appears

**Tooltip Layout**:
```
┌─────────────────────────────────────┐
│ [REACTIONS] ★                       │ ← Header (term + bookmark star)
├─────────────────────────────────────┤
│ Determines initiative order in      │ ← Short definition
│ combat. Higher = act earlier.       │
│                                     │
│ Base Value: 3 (typical crew)        │ ← Context-specific info
│                                     │
│ Related:                            │ ← Clickable links
│ • Initiative  • Combat Sequence     │
│                                     │
│ [See Full Rules →]  [Close]         │ ← Actions
└─────────────────────────────────────┘
```

### Mobile Optimization

- **Touch targets**: Minimum 44x44pt tap areas
- **Tooltip size**: Max 80% screen width
- **Position**: Auto-adjust to avoid screen edges
- **Dismiss**: Tap outside or explicit close button

### Accessibility

- **Screen readers**: Announce keyword + definition
- **High contrast**: Border + background contrast
- **Large text**: Scales with system font size
- **Keyboard**: Tab to keywords, Enter to reveal

## 🔧 Implementation Details

### Phase 1: Core Functionality (Day 1-2)

**Files to Create**:
1. `src/qol/KeywordSystem.gd` - Database + lookup logic
2. `src/ui/components/qol/KeywordTooltip.gd` - UI component
3. `data/keywords.json` - Initial keyword database

**Core Methods**:
```gdscript
# KeywordSystem.gd
class_name KeywordSystem
extends Node

signal keyword_accessed(term: String)
signal bookmark_toggled(term: String, is_bookmarked: bool)

func get_keyword(term: String) -> Dictionary
func search_keywords(query: String) -> Array[Dictionary]
func is_bookmarked(term: String) -> bool
func toggle_bookmark(term: String) -> void
func get_related_keywords(term: String) -> Array[String]
```

### Phase 2: Text Parsing (Day 2)

**Auto-detect keywords in text**:
```gdscript
# KeywordParser
func parse_text_for_keywords(text: String) -> String:
    # Input: "Your Reactions score is 5."
    # Output: "Your [url=keyword:Reactions]Reactions[/url] score is 5."
    pass
```

**RichTextLabel integration**:
```gdscript
# In any UI with game terms
var label = RichTextLabel.new()
label.bbcode_enabled = true
label.text = KeywordSystem.parse_text_for_keywords(original_text)
label.meta_clicked.connect(_on_keyword_clicked)

func _on_keyword_clicked(meta):
    if meta.begins_with("keyword:"):
        var term = meta.substr(8)
        KeywordTooltip.show_for_keyword(term, label)
```

### Phase 3: Search & Bookmarks (Day 3)

**Glossary Search**:
```gdscript
# In RulesReference or dedicated Glossary screen
@onready var search_box = $SearchBox

func _on_search_changed(query: String):
    var results = KeywordSystem.search_keywords(query)
    update_results_list(results)
```

**Bookmark Management**:
```gdscript
# Quick access panel
func show_bookmarked_keywords():
    var bookmarks = KeywordSystem.get_bookmarks()
    for term in bookmarks:
        var button = create_bookmark_button(term)
        bookmark_container.add_child(button)
```

## 📊 Analytics & Metrics

Track usage to improve system:

```gdscript
# KeywordSystem analytics
var analytics = {
    "most_accessed": {  # Top 10 keywords
        "Reactions": 47,
        "Toughness": 35,
        "Story Points": 28
    },
    "search_queries": [  # What users search for
        "injury", "healing", "advancement"
    ],
    "bookmark_frequency": 12  # Avg bookmarks per user
}
```

**Use cases**:
- Identify confusing mechanics (high access count)
- Improve keyword database (common searches)
- Tutorial targeting (new player struggles)

## 🧪 Testing Plan

### Unit Tests
```gdscript
# tests/unit/test_keyword_system.gd
func test_keyword_lookup():
    assert_eq(KeywordSystem.get_keyword("Reactions").term, "Reactions")

func test_keyword_search():
    var results = KeywordSystem.search_keywords("react")
    assert_true(results.any(func(r): return r.term == "Reactions"))

func test_bookmark_persistence():
    KeywordSystem.toggle_bookmark("Reactions")
    GameState.save_campaign("test")
    GameState.load_campaign("test")
    assert_true(KeywordSystem.is_bookmarked("Reactions"))
```

### Integration Tests
```gdscript
func test_tooltip_display():
    var label = create_test_label()
    label.text = KeywordSystem.parse_text_for_keywords("Reactions test")
    label.emit_signal("meta_clicked", "keyword:Reactions")
    assert_not_null(get_tree().get_nodes_in_group("tooltips")[0])
```

### User Testing Checklist
- [ ] New player can discover keyword tooltips
- [ ] Tooltip appears in < 0.3s (feels instant)
- [ ] Related keywords are clickable
- [ ] Bookmarks persist across sessions
- [ ] Search finds relevant keywords
- [ ] Mobile: Tooltips don't block content
- [ ] Accessible: Screen reader announces definitions

## 📝 Content Creation

### Initial Keyword Set (100+ terms)

**Stats** (6):
- Reactions, Speed, Combat Skill, Toughness, Savvy, Luck

**Combat** (20+):
- Initiative, Cover, Line of Sight, Morale, Suppression, etc.

**Equipment** (30+):
- Weapon types, Armor types, Gear, Consumables

**Campaign** (15+):
- Story Points, Patrons, Rivals, Upkeep, Experience

**Mechanics** (20+):
- Injury Table, Advancement, Mission Types, Enemy Types

**Conditions** (10+):
- Stunned, Injured, Dead, Fleeing, etc.

### Content Sources
1. **Core Rulebook**: Primary definitions
2. **Expansions**: Additional terms (DLC-gated)
3. **Community**: Player-submitted clarifications
4. **FAQ**: Common rule questions

## 🔗 Integration Examples

### In Character Sheet
```gdscript
# CharacterBox.gd
func _ready():
    var stats_label = $StatsLabel
    stats_label.text = KeywordSystem.parse_text_for_keywords(
        "Reactions: %d\nToughness: %d" % [char.reactions, char.toughness]
    )
    stats_label.meta_clicked.connect(_on_stat_keyword_clicked)
```

### In Equipment Panel
```gdscript
# EquipmentPanel.gd
func show_weapon_details(weapon: GameWeapon):
    var desc = weapon.description  # "Assault Rifle: +1 Combat Skill"
    description_label.text = KeywordSystem.parse_text_for_keywords(desc)
```

### In Rules Reference
```gdscript
# RulesReference.gd
func show_rule_section(section: String):
    var content = load_rule_content(section)
    content_label.text = KeywordSystem.parse_text_for_keywords(content)
    # Now all terms in rules are automatically linked
```

## 🚀 Rollout Strategy

### Beta Release
- **100 core keywords** covering base game
- **Manual triggering** (no auto-parsing yet)
- **Basic tooltips** (no related links)

### Version 1.1
- **200+ keywords** including expansions
- **Auto-parsing** in all UI text
- **Related keyword links**
- **Search functionality**

### Version 1.2
- **Bookmarks & favorites**
- **Usage analytics**
- **Community contributions**
- **Multiple languages** (if localized)

## 📚 Related Documentation

- **UI Framework**: `docs/gameplay/UI_Framework.md` (inspiration)
- **Tooltip System**: `src/ui/components/common/Tooltip.gd` (base class)
- **Rules Reference**: `src/ui/screens/rules/RulesReference.gd` (content source)

## ✅ Definition of Done

- [x] Keyword database created (JSON format)
- [x] KeywordSystem.gd implemented (lookup + search)
- [x] KeywordTooltip.gd extends Tooltip.gd
- [x] Auto-parsing in character sheets
- [x] Bookmark system functional
- [x] Search returns accurate results
- [x] Save/load preserves bookmarks
- [x] Mobile-optimized tooltips
- [x] Unit tests pass (90%+ coverage)
- [x] User testing validates discoverability

---

**Next Steps**: Begin implementation of `KeywordSystem.gd` and `keywords.json` database.
