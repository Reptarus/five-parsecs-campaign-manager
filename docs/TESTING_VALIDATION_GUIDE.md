# Testing & Validation Guide

**Version**: 1.0
**Last Updated**: 2024-11-16
**Audience**: Content creators, modders, QA testers

---

## Table of Contents

1. [Overview](#overview)
2. [Testing Philosophy](#testing-philosophy)
3. [Validation Levels](#validation-levels)
4. [JSON Validation](#json-validation)
5. [Content Balance Validation](#content-balance-validation)
6. [Functional Testing](#functional-testing)
7. [Integration Testing](#integration-testing)
8. [Playtesting Methodology](#playtesting-methodology)
9. [Automated Testing](#automated-testing)
10. [Community Testing](#community-testing)
11. [Bug Reporting](#bug-reporting)
12. [Certification Checklist](#certification-checklist)

---

## Overview

This guide provides comprehensive testing and validation methodology for Five Parsecs Campaign Manager content. Following these practices ensures your content is high-quality, balanced, and bug-free.

### Why Test?

**Quality Assurance**:
- Prevents broken content from reaching players
- Ensures consistent player experience
- Maintains game balance

**Player Trust**:
- Professional testing builds player confidence
- Reduces negative reviews and complaints
- Increases adoption and recommendations

**Development Efficiency**:
- Catch bugs early (cheaper to fix)
- Automated tests save time long-term
- Clear testing process accelerates iteration

### Testing Pyramid

```
         /\
        /  \  Playtesting (10%)
       /----\
      /      \  Integration Testing (20%)
     /--------\
    /          \  Functional Testing (30%)
   /------------\
  /              \  Content Validation (40%)
 /________________\
```

**40% Content Validation**: Ensure data is correct and balanced
**30% Functional Testing**: Ensure features work as designed
**20% Integration Testing**: Ensure compatibility with other content
**10% Playtesting**: Ensure fun and balanced gameplay

---

## Testing Philosophy

### Core Principles

**1. Test Early, Test Often**
- Validate JSON immediately after creation
- Test each feature as you implement it
- Don't wait until "everything is done"

**2. Automate What You Can**
- JSON validation scripts
- Balance calculation checks
- Regression test suites

**3. Manual Test What Matters**
- Gameplay feel and balance
- Player experience and fun
- Edge cases and unexpected behavior

**4. Document Everything**
- Record test results
- Track known issues
- Maintain test logs

**5. Iterate Based on Feedback**
- Playtesting reveals balance issues
- Community feedback guides improvements
- Version control enables rollback

### Test-Driven Development (Optional)

For system development, consider writing tests first:

1. Write test describing desired behavior
2. Run test (it fails)
3. Implement feature
4. Run test (it passes)
5. Refactor if needed
6. Repeat

**Benefits**: Clear requirements, comprehensive coverage, confidence in changes

---

## Validation Levels

### Level 1: Syntax Validation ✓

**What**: Is the file valid?
**Tools**: JSON validators, linters
**Time**: Seconds
**Automated**: Yes

**Checks**:
- Valid JSON syntax
- UTF-8 encoding
- No trailing commas
- Properly closed brackets/braces

### Level 2: Schema Validation ✓

**What**: Does the data match the schema?
**Tools**: JSON Schema validators
**Time**: Seconds
**Automated**: Yes

**Checks**:
- Required fields present
- Field types correct
- Values within valid ranges
- Enum values valid

### Level 3: Content Validation ✓

**What**: Is the content balanced and sensible?
**Tools**: Custom validation scripts
**Time**: Minutes
**Automated**: Partially

**Checks**:
- Balance calculations (species net-zero, elite DP formula)
- Cross-references valid (weapons exist, enemies exist)
- Naming conventions followed
- Descriptions complete

### Level 4: Functional Validation ✓

**What**: Does the content work in-game?
**Tools**: Manual testing, automated tests
**Time**: Hours
**Automated**: Partially

**Checks**:
- Content loads without errors
- Features work as designed
- No crashes or errors
- Proper integration with systems

### Level 5: Balance Validation ✓

**What**: Is the content fun and fair?
**Tools**: Playtesting, statistics
**Time**: Days/Weeks
**Automated**: No

**Checks**:
- Win rates appropriate
- Power level matches cost
- Variety and interest
- Player satisfaction

---

## JSON Validation

### Syntax Validation

**Online Tools**:
- [JSONLint](https://jsonlint.com/)
- [JSON Formatter](https://jsonformatter.curiousconcept.com/)

**Command Line**:
```bash
# Using Python
python3 -m json.tool your_file.json

# Using jq
jq . your_file.json

# Using Node.js
node -e "JSON.parse(require('fs').readFileSync('your_file.json'))"
```

**Expected Output** (valid):
```
(Formatted JSON or no output)
```

**Expected Output** (invalid):
```
Expecting ',' delimiter: line 15 column 5 (char 234)
```

### Schema Validation

Create JSON Schema files for your content types:

**Example: Species Schema** (`schemas/species_schema.json`)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Species",
  "type": "object",
  "required": ["name", "playable", "description", "homeworld", "traits", "starting_bonus", "dlc_required", "source", "base_profile", "special_rules"],
  "properties": {
    "name": {
      "type": "string",
      "minLength": 1
    },
    "playable": {
      "type": "boolean"
    },
    "description": {
      "type": "string",
      "minLength": 10
    },
    "homeworld": {
      "type": "string",
      "minLength": 1
    },
    "traits": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "minItems": 1
    },
    "starting_bonus": {
      "type": "string"
    },
    "dlc_required": {
      "type": "string"
    },
    "source": {
      "type": "string"
    },
    "base_profile": {
      "type": "object",
      "required": ["reactions", "speed", "combat_skill", "toughness", "savvy"],
      "properties": {
        "reactions": {
          "type": "integer",
          "minimum": 0,
          "maximum": 3
        },
        "speed": {
          "type": "string",
          "pattern": "^[3-6]\\\"$"
        },
        "combat_skill": {
          "type": "string",
          "pattern": "^[+\\-][0-3]$"
        },
        "toughness": {
          "type": "integer",
          "minimum": 2,
          "maximum": 6
        },
        "savvy": {
          "type": "string",
          "pattern": "^[+\\-][0-3]$"
        }
      }
    },
    "special_rules": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["name", "description", "mechanical_effect"],
        "properties": {
          "name": {"type": "string"},
          "description": {"type": "string"},
          "mechanical_effect": {"type": "string"}
        }
      },
      "minItems": 1
    }
  }
}
```

**Validation Command**:
```bash
# Using ajv-cli (npm install -g ajv-cli)
ajv validate -s schemas/species_schema.json -d data/dlc/your_expansion/your_expansion_species.json
```

### Custom Validation Scripts

Create scripts for content-specific checks:

**Example: Species Balance Validator** (`scripts/validate_species_balance.py`)

```python
#!/usr/bin/env python3
import json
import sys

def parse_modifier(modifier_str):
    """Parse +/-X string to integer"""
    if modifier_str.startswith('+'):
        return int(modifier_str[1:])
    elif modifier_str.startswith('-'):
        return -int(modifier_str[1:])
    else:
        return int(modifier_str)

def parse_speed(speed_str):
    """Parse X" string to integer"""
    return int(speed_str.replace('"', ''))

def validate_species_balance(species):
    """Check if species follows net-zero balance"""
    profile = species['base_profile']

    # Human baseline
    baseline = {
        'reactions': 1,
        'speed': 4,
        'combat_skill': 0,
        'toughness': 3,
        'savvy': 0
    }

    # Calculate modifiers
    reactions_mod = profile['reactions'] - baseline['reactions']
    speed_mod = parse_speed(profile['speed']) - baseline['speed']
    combat_mod = parse_modifier(profile['combat_skill']) - baseline['combat_skill']
    toughness_mod = profile['toughness'] - baseline['toughness']
    savvy_mod = parse_modifier(profile['savvy']) - baseline['savvy']

    # Sum modifiers
    total = reactions_mod + speed_mod + combat_mod + toughness_mod + savvy_mod

    # Check balance
    if total < -2 or total > 2:
        return False, total
    return True, total

def main():
    if len(sys.argv) != 2:
        print("Usage: validate_species_balance.py <species_file.json>")
        sys.exit(1)

    filename = sys.argv[1]

    with open(filename, 'r') as f:
        data = json.load(f)

    species_list = data.get('species', [])

    print(f"Validating {len(species_list)} species...")
    all_valid = True

    for species in species_list:
        name = species['name']
        valid, total = validate_species_balance(species)

        if valid:
            print(f"✓ {name}: Balanced (total modifier: {total:+d})")
        else:
            print(f"✗ {name}: UNBALANCED (total modifier: {total:+d})")
            all_valid = False

    if all_valid:
        print("\nAll species are balanced!")
        sys.exit(0)
    else:
        print("\nSome species are unbalanced. Review and adjust.")
        sys.exit(1)

if __name__ == '__main__':
    main()
```

**Usage**:
```bash
python3 scripts/validate_species_balance.py data/dlc/void_raiders/void_raiders_species.json
```

**Output**:
```
Validating 2 species...
✓ Voidborn: Balanced (total modifier: +2)
✓ Krokar: Balanced (total modifier: +1)

All species are balanced!
```

---

## Content Balance Validation

### Species Balance

**Net-Zero Rule**: Total stat modifiers should sum to -2 to +2 (ideally 0).

**Validation Steps**:

1. **Calculate Base Modifiers**:
   - Compare to human baseline (Reactions 1, Speed 4", Combat +0, Toughness 3, Savvy +0)
   - Each stat difference = ±1 point

2. **Evaluate Special Rules**:
   - Powerful rule (armor save, damage bonus) = +1 to +2 points
   - Moderate rule (situational bonus) = +0.5 to +1 point
   - Weak rule (flavor, niche) = +0 to +0.5 points
   - Disadvantage = -0.5 to -2 points

3. **Sum Total**:
   - Base modifiers + special rules = total balance
   - Should be -2 to +2

**Example: Krag**
- Toughness +1 = +1
- Speed -1" = -1
- Natural armor (Thick Hide) = +1
- Cannot Dash (disadvantage) = -0.5
- Total = +0.5 ✓ (balanced)

### Elite Enemy Balance

**Deployment Point Formula**:

```
Base: 1 DP

Modifiers:
+ Combat Skill increase: ×1 DP per +1
+ Toughness increase: ×1 DP per +1
+ Speed increase: ×0.5 DP per +1"
+ Reactions increase: ×0.5 DP per +1
+ Special Abilities: ×0.5-1 DP per ability

Result: Round to nearest integer (2-5 DP)
```

**Validation Steps**:

1. **Identify Base Enemy**: What standard enemy is this based on?
2. **Calculate Stat Increases**: Compare elite to base
3. **Count Abilities**: How many special abilities? (Power level?)
4. **Apply Formula**: Calculate expected DP
5. **Compare to Listed DP**: Should be within ±1

**Example: Elite Mercenary**

Base Mercenary: Combat +0, Tough 3, Speed 4", Reactions 1, 0 abilities

Elite Mercenary: Combat +2, Tough 4, Speed 5", Reactions 2, 2 abilities

Calculation:
- Base: 1
- Combat +2: +2
- Tough +1: +1
- Speed +1": +0.5
- Reactions +1: +0.5
- 2 abilities: +1.5
- Total: 6.5 → **3 DP** (rounded down due to moderate abilities)

Listed: 3 DP ✓ (matches)

### Weapon Balance

**Damage Per Round (DPR) Comparison**:

```
DPR = Shots × Damage × Hit Chance × Trait Multiplier
```

**Baseline**: Military Rifle
- Range: 24"
- Shots: 1
- Damage: 2
- DPR: 1 × 2 × 0.5 = 1.0

**Example: Ripper Cannon**
- Range: 18"
- Shots: 3
- Damage: 2
- Traits: Heavy (slower), Piercing (+effective damage)
- DPR: 3 × 2 × 0.5 × 1.2 = 3.6

**Analysis**: 3.6× baseline DPR, but:
- Shorter range (18" vs 24")
- Heavy trait (-1" movement, two-handed)
- High cost (1200 vs 600 credits)

**Verdict**: Balanced (high damage offset by drawbacks and cost)

### Mission Balance

**Completion Rate Target**: 50-70% for experienced players

**Validation Metrics**:

1. **Enemy Count**: Appropriate for crew size (typically 1:1 to 1.5:1 ratio)
2. **Deployment Points**: 8-12 DP for standard crew
3. **Objectives**: Achievable within 5-8 rounds
4. **Rewards**: Match difficulty (harder = better rewards)

**Playtesting**:
- Run mission 5+ times with different crews
- Track completion rate
- Adjust enemy count/objectives if needed

---

## Functional Testing

### Loading Test

**Goal**: Verify content loads without errors

**Steps**:

1. **Start Game**: Launch with expansion enabled
2. **Check Console**: Look for error messages
3. **Check Expansion List**: Expansion appears?
4. **Check Content Filter**: Content types available?

**Test Script**:
```gdscript
# test_loading.gd
extends GutTest

func test_expansion_loads():
    var expansion_manager = get_node("/root/ExpansionManager")
    assert_not_null(expansion_manager, "ExpansionManager should exist")

    var is_loaded = expansion_manager.is_expansion_loaded("void_raiders")
    assert_true(is_loaded, "Void Raiders should be loaded")

func test_species_available():
    var content_filter = ContentFilter.new()
    var available = content_filter.is_content_type_available("species")
    assert_true(available, "Species content type should be available")

func test_species_data_loaded():
    var expansion_manager = get_node("/root/ExpansionManager")
    var data = expansion_manager.load_expansion_data("void_raiders", "void_raiders_species.json")

    assert_not_null(data, "Species data should load")
    assert_true(data.has("species"), "Data should have 'species' key")
    assert_gt(data.species.size(), 0, "Should have at least 1 species")
```

### Display Test

**Goal**: Verify content displays correctly in UI

**Steps**:

1. **Character Creation**: Check species list
   - Species names appear?
   - Descriptions display?
   - Stats show correctly?

2. **Equipment Shop**: Check weapons/gear
   - Items appear?
   - Prices correct?
   - Descriptions readable?

3. **Mission Selection**: Check missions
   - Mission names appear?
   - Objectives display?
   - Rewards shown?

4. **Battle Setup**: Check elite enemies
   - Elites can spawn?
   - Stats display correctly?
   - Abilities listed?

**Checklist**:
- [ ] All species appear in character creation
- [ ] Species stats display correctly
- [ ] Special rules are readable
- [ ] Equipment appears in shops
- [ ] Prices are correct
- [ ] Missions appear in selection
- [ ] Elite enemies can be deployed
- [ ] Abilities show in combat

### Functionality Test

**Goal**: Verify features work as designed

**Test Cases**:

**1. Species Special Rules**

Test: Krag "Thick Hide" natural armor
- Create Krag character
- Enter combat
- Take hit
- Roll armor save
- Expected: 6+ save available

**2. Elite Enemy Abilities**

Test: Elite Mercenary "Combat Veteran" re-roll
- Deploy Elite Mercenary
- Attack and miss
- Activate ability
- Re-roll attack
- Expected: Re-roll happens once per round

**3. Psionic Power Activation**

Test: Barrier power
- Create psyker character
- Learn Barrier power
- Activate in combat (1D6 + Savvy vs 4+)
- Expected: On success, target gains 4+ armor save

**4. Custom System State**

Test: Reputation tracking
- Modify reputation with faction
- Check reputation value
- Trigger tier change
- Expected: Reputation updates, tier changes at thresholds

**Test Script Example**:
```gdscript
# test_reputation_system.gd
extends GutTest

var reputation_system: ReputationSystem

func before_each():
    reputation_system = get_node("/root/ReputationSystem")

func test_initial_reputation():
    var rep = reputation_system.get_reputation("Void Raiders")
    assert_eq(rep, 0, "Initial reputation should be 0")

func test_modify_reputation():
    reputation_system.modify_reputation("Void Raiders", 10)
    var rep = reputation_system.get_reputation("Void Raiders")
    assert_eq(rep, 10, "Reputation should increase to 10")

func test_reputation_clamping():
    reputation_system.modify_reputation("Void Raiders", 200)
    var rep = reputation_system.get_reputation("Void Raiders")
    assert_eq(rep, 100, "Reputation should clamp at 100")

func test_tier_hostile():
    reputation_system.modify_reputation("Void Raiders", -60)
    var tier = reputation_system._get_tier(-60)
    assert_eq(tier, "Hostile", "Reputation -60 should be Hostile")

func test_tier_allied():
    reputation_system.modify_reputation("Void Raiders", 60)
    var tier = reputation_system._get_tier(60)
    assert_eq(tier, "Allied", "Reputation 60 should be Allied")
```

---

## Integration Testing

### Compatibility Testing

**Goal**: Ensure expansion works with other content

**Test Matrix**:

| Your Expansion | + Core | + Trailblazer's | + Freelancer's | + Fixer's | + Bug Hunt |
|----------------|--------|-----------------|----------------|-----------|------------|
| Void Raiders   | ✓      | ✓               | ✓              | ✓         | ✓          |

**Test Cases**:

**1. Multi-Expansion Species**
- Enable multiple expansions
- Create character with species from different expansions
- Expected: All species available, no conflicts

**2. Mixed Content Battles**
- Enable multiple expansions
- Generate battle with enemies from different expansions
- Deploy elite enemies from different expansions
- Expected: All content works together

**3. Stacking Systems**
- Enable multiple expansions with systems
- Test interactions (e.g., Reputation + Difficulty Scaling)
- Expected: Systems work independently or cooperate correctly

**4. Save/Load with Multiple Expansions**
- Create campaign with multiple expansions enabled
- Save game
- Load game
- Expected: All expansion state preserves

### Dependency Testing

**Goal**: Verify dependency requirements work correctly

**Test Cases**:

**1. Missing Dependency**
- Create expansion requiring another expansion
- Disable required expansion
- Try to load dependent expansion
- Expected: Error or warning, expansion doesn't load

**2. Version Mismatch**
- Create expansion requiring core version 1.0.0
- Test with core version 0.9.0
- Expected: Error or warning, expansion doesn't load

**3. Circular Dependencies**
- Create two expansions each requiring the other
- Try to load both
- Expected: Error or both load (depending on design)

### Conflict Testing

**Goal**: Identify naming conflicts and data collisions

**Test Cases**:

**1. Name Conflicts**
- Create species named "Krag"
- Enable Trailblazer's Toolkit (also has "Krag")
- Expected: Error, warning, or namespace handling

**2. ID Conflicts**
- Create expansion with ID "void_raiders"
- Create second expansion with same ID
- Expected: Error, second expansion fails to load

**3. System Conflicts**
- Create system named "ReputationSystem"
- Enable another expansion with "ReputationSystem"
- Expected: Error or one system takes precedence

### Regression Testing

**Goal**: Ensure updates don't break existing functionality

**Process**:

1. **Create Test Suite**: Tests for all features
2. **Run Before Change**: Verify all tests pass
3. **Make Change**: Update content or system
4. **Run After Change**: Verify tests still pass
5. **Fix Regressions**: If tests fail, fix or update tests

**Automation**: Use GUT (Godot Unit Test) framework for automated regression testing

---

## Playtesting Methodology

### Playtesting Goals

**Balance Validation**: Is content fair and fun?
**Experience Testing**: Is it enjoyable to play?
**Discovery**: Find edge cases and unexpected behavior

### Structured Playtesting

**Test Campaign Structure**:

1. **Session 1-2**: Character creation, first missions
   - Test: Species balance, starting equipment
   - Metrics: Character survivability, mission success rate

2. **Session 3-5**: Mid-campaign
   - Test: Elite enemies, advanced equipment, special missions
   - Metrics: Combat difficulty, reward balance

3. **Session 6-8**: Late campaign
   - Test: High-level play, system interactions
   - Metrics: Power progression, challenge scaling

**Playtest Team**:
- **Minimum**: 3 players (different playstyles)
- **Ideal**: 5-10 players (diverse strategies)
- **Mix**: Experienced + new players

### Metrics to Track

**Quantitative**:
- Win rate (target: 50-70%)
- Average mission length (target: 30-60 minutes)
- Character survival rate (target: 70-90%)
- Equipment usage (all items used? any ignored?)
- Species selection (all species chosen? any favorites?)

**Qualitative**:
- Fun factor (player feedback)
- Frustration points (what's annoying?)
- Confusion (what's unclear?)
- Desired improvements (what would players change?)

### Playtest Feedback Form

```markdown
## Playtest Feedback Form

**Date**: ___________
**Playtester**: ___________
**Session Number**: ___________
**Expansion**: Void Raiders v1.0.0

### Species Used
- [ ] Voidborn
- [ ] Krokar
- [ ] Other: ___________

### Missions Played
1. ___________
2. ___________
3. ___________

### Win/Loss Record
Wins: _____ / Losses: _____

### Rating (1-5)
- Fun Factor: [ 1 | 2 | 3 | 4 | 5 ]
- Balance: [ 1 | 2 | 3 | 4 | 5 ]
- Clarity: [ 1 | 2 | 3 | 4 | 5 ]

### What worked well?
___________________________________________

### What needs improvement?
___________________________________________

### Bugs encountered?
___________________________________________

### Suggestions?
___________________________________________
```

### Iteration Based on Feedback

**Red Flags** (fix immediately):
- Win rate < 30% or > 90%
- Frequent crashes or errors
- Consistent player confusion
- Unanimous "not fun" feedback

**Yellow Flags** (adjust):
- Win rate 30-40% or 80-90%
- Occasional errors
- Some player confusion
- Mixed fun feedback

**Green Flags** (good to go):
- Win rate 50-70%
- No errors
- Clear rules and mechanics
- Positive fun feedback

**Iteration Process**:
1. Collect feedback
2. Identify patterns (multiple players report same issue?)
3. Prioritize fixes (critical bugs first, balance second, polish last)
4. Make changes
5. Test again
6. Repeat until green flags

---

## Automated Testing

### GUT (Godot Unit Test) Setup

**Install GUT**:
1. Download from [GitHub](https://github.com/bitwes/Gut)
2. Extract to `addons/gut/`
3. Enable in Project Settings → Plugins

**Create Test Directory**:
```
tests/
├── unit/
│   ├── test_reputation_system.gd
│   ├── test_black_market_system.gd
│   └── test_species_loading.gd
├── integration/
│   ├── test_multi_expansion.gd
│   └── test_save_load.gd
└── .gutconfig.json
```

**GUT Config** (`.gutconfig.json`):
```json
{
  "dirs": ["res://tests/unit/", "res://tests/integration/"],
  "include_subdirs": true,
  "double_strategy": "partial",
  "log_level": 1
}
```

### Example Test Suite

**File**: `tests/unit/test_reputation_system.gd`

```gdscript
extends GutTest

var reputation_system: ReputationSystem

func before_each():
    reputation_system = ReputationSystem.new()
    add_child(reputation_system)
    reputation_system._ready()

func after_each():
    reputation_system.queue_free()

func test_system_initializes():
    assert_not_null(reputation_system, "System should initialize")
    assert_not_null(reputation_system.factions, "Factions should load")

func test_factions_loaded():
    var factions = reputation_system.get_all_factions()
    assert_gt(factions.size(), 0, "Should load at least 1 faction")

func test_initial_reputation_values():
    var rep = reputation_system.get_reputation("Void Raiders")
    assert_eq(rep, 0, "Initial reputation should be 0")

func test_modify_reputation_increases():
    reputation_system.modify_reputation("Void Raiders", 10)
    var rep = reputation_system.get_reputation("Void Raiders")
    assert_eq(rep, 10, "Reputation should increase to 10")

func test_modify_reputation_decreases():
    reputation_system.modify_reputation("Void Raiders", -15)
    var rep = reputation_system.get_reputation("Void Raiders")
    assert_eq(rep, -15, "Reputation should decrease to -15")

func test_reputation_clamps_at_max():
    reputation_system.modify_reputation("Void Raiders", 150)
    var rep = reputation_system.get_reputation("Void Raiders")
    assert_eq(rep, 100, "Reputation should clamp at 100")

func test_reputation_clamps_at_min():
    reputation_system.modify_reputation("Void Raiders", -150)
    var rep = reputation_system.get_reputation("Void Raiders")
    assert_eq(rep, -100, "Reputation should clamp at -100")

func test_tier_calculation_hostile():
    var tier = reputation_system._get_tier(-60)
    assert_eq(tier, "Hostile", "Reputation -60 should be Hostile tier")

func test_tier_calculation_unfriendly():
    var tier = reputation_system._get_tier(-30)
    assert_eq(tier, "Unfriendly", "Reputation -30 should be Unfriendly tier")

func test_tier_calculation_neutral():
    var tier = reputation_system._get_tier(0)
    assert_eq(tier, "Neutral", "Reputation 0 should be Neutral tier")

func test_tier_calculation_friendly():
    var tier = reputation_system._get_tier(30)
    assert_eq(tier, "Friendly", "Reputation 30 should be Friendly tier")

func test_tier_calculation_allied():
    var tier = reputation_system._get_tier(60)
    assert_eq(tier, "Allied", "Reputation 60 should be Allied tier")

func test_signal_emitted_on_change():
    watch_signals(reputation_system)
    reputation_system.modify_reputation("Void Raiders", 10)
    assert_signal_emitted(reputation_system, "reputation_changed")

func test_tier_change_signal():
    watch_signals(reputation_system)
    reputation_system.modify_reputation("Void Raiders", 50)
    assert_signal_emitted(reputation_system, "reputation_tier_changed")

func test_save_state():
    reputation_system.modify_reputation("Void Raiders", 25)
    var state = reputation_system.save_state()
    assert_not_null(state, "Should return save state")
    assert_true(state.has("reputation_values"), "State should have reputation_values")
    assert_eq(state.reputation_values["Void Raiders"], 25, "State should preserve reputation")

func test_load_state():
    var state = {
        "reputation_values": {
            "Void Raiders": 40,
            "Corporate Sector": -20
        }
    }
    reputation_system.load_state(state)
    assert_eq(reputation_system.get_reputation("Void Raiders"), 40, "Should load Void Raiders reputation")
    assert_eq(reputation_system.get_reputation("Corporate Sector"), -20, "Should load Corporate Sector reputation")
```

### Running Tests

**Command Line**:
```bash
# Run all tests
godot --path . -s addons/gut/gut_cmdln.gd

# Run specific test file
godot --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_reputation_system.gd

# Run with increased verbosity
godot --path . -s addons/gut/gut_cmdln.gd -glog=2
```

**In Editor**:
1. Open GUT panel (usually bottom panel)
2. Click "Run All"
3. View results

### Continuous Integration

**GitHub Actions Example** (`.github/workflows/test.yml`):

```yaml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2

    - name: Download Godot
      run: |
        wget https://downloads.tuxfamily.org/godotengine/4.4/Godot_v4.4-stable_linux.x86_64.zip
        unzip Godot_v4.4-stable_linux.x86_64.zip
        chmod +x Godot_v4.4-stable_linux.x86_64

    - name: Run Tests
      run: |
        ./Godot_v4.4-stable_linux.x86_64 --path . --headless -s addons/gut/gut_cmdln.gd

    - name: Upload Test Results
      uses: actions/upload-artifact@v2
      with:
        name: test-results
        path: .gut/
```

---

## Community Testing

### Beta Testing Program

**Structure**:

1. **Recruitment**: Find 10-20 testers (forums, Discord, social media)
2. **Onboarding**: Provide beta build, documentation, feedback form
3. **Testing Period**: 1-2 weeks
4. **Feedback Collection**: Surveys, bug reports, discussions
5. **Iteration**: Fix issues, release updated beta
6. **Final Release**: After 2-3 beta cycles

**Beta Tester Expectations**:
- Play 5-10 hours
- Complete feedback form
- Report bugs
- Test specific features (if assigned)

**Incentives**:
- Early access
- Credits in expansion
- Special tester badge/reward
- Free copy of expansion (if paid)

### Feedback Collection

**Survey Questions**:

1. **Overall Experience**
   - How would you rate the expansion? (1-5 stars)
   - Would you recommend it to others? (Yes/No/Maybe)

2. **Content Quality**
   - Which species did you play? Did you enjoy them?
   - Which missions did you try? Were they fun?
   - Did you use the new equipment? Was it useful?

3. **Balance**
   - Did any content feel overpowered? Underpowered?
   - Were missions too easy? Too hard? Just right?
   - Did you feel rewarded for your efforts?

4. **Technical**
   - Did you encounter any bugs? Please describe.
   - Did the expansion load correctly?
   - Any performance issues?

5. **Suggestions**
   - What would you change?
   - What would you add?
   - What did you love?

### Managing Feedback

**Categorize Feedback**:

- **Critical Bugs**: Fix immediately
- **Balance Issues**: Prioritize if multiple reports
- **Feature Requests**: Consider for future versions
- **Polish**: Nice-to-have improvements

**Communication**:
- Acknowledge all feedback
- Provide status updates
- Explain decisions (why you did/didn't implement suggestion)
- Thank testers publicly

---

## Bug Reporting

### Bug Report Template

```markdown
## Bug Report

**Expansion**: Void Raiders v1.0.0
**Core Version**: 1.0.0
**Platform**: Linux / Windows / Mac

### Description
[Brief description of the bug]

### Steps to Reproduce
1. [First step]
2. [Second step]
3. [...]

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happened]

### Screenshots
[If applicable]

### Console Output
```
[Paste error messages here]
```

### Additional Context
[Any other relevant information]
```

### Bug Tracking

**Use GitHub Issues or similar**:

- **Labels**: Bug, Enhancement, Question, Documentation
- **Milestones**: v1.0.0, v1.1.0, etc.
- **Assignees**: Who's working on it
- **Status**: Open, In Progress, Closed

**Prioritization**:

1. **P0 - Critical**: Crashes, data loss, game-breaking bugs
2. **P1 - High**: Major functionality broken, significant balance issues
3. **P2 - Medium**: Minor bugs, moderate balance issues
4. **P3 - Low**: Polish, cosmetic issues, edge cases

---

## Certification Checklist

Use this checklist before releasing your expansion:

### Pre-Release Certification

**JSON Validation** ✓
- [ ] All JSON files have valid syntax
- [ ] All JSON files pass schema validation
- [ ] All cross-references are valid (weapons exist, enemies exist, etc.)

**Content Balance** ✓
- [ ] All species are balanced (net-zero or within ±2)
- [ ] All elite enemies have correct deployment points (formula ±1)
- [ ] All weapons have reasonable DPR compared to baseline
- [ ] All missions have appropriate difficulty and rewards

**Functional Testing** ✓
- [ ] Expansion loads without errors
- [ ] All content appears in appropriate menus
- [ ] Species special rules work correctly
- [ ] Elite enemy abilities function properly
- [ ] Custom systems maintain state correctly
- [ ] Save/load preserves expansion data

**Integration Testing** ✓
- [ ] Works with core game
- [ ] Works with all official expansions
- [ ] No naming conflicts
- [ ] No system conflicts
- [ ] Dependencies resolved correctly

**Playtesting** ✓
- [ ] Completed 10+ playtest sessions
- [ ] Win rate is 50-70%
- [ ] Positive player feedback (average 3.5+/5)
- [ ] No consistent frustration points
- [ ] All content was used (no dead content)

**Documentation** ✓
- [ ] README.md complete
- [ ] INSTALL.md accurate
- [ ] CHANGELOG.md started
- [ ] LICENSE included
- [ ] All features documented

**Polish** ✓
- [ ] No spelling/grammar errors
- [ ] Consistent formatting
- [ ] All descriptions complete
- [ ] No placeholder text
- [ ] Version number finalized

### Release Readiness

- [ ] All critical bugs fixed (P0)
- [ ] All high priority bugs fixed (P1)
- [ ] Medium priority bugs documented (P2)
- [ ] Package created and tested
- [ ] Installer tested on all platforms
- [ ] Release notes written
- [ ] Community announcement drafted

**When all checked**: Ready to release! 🎉

---

## Appendix: Tool References

### JSON Validators

- **JSONLint**: https://jsonlint.com/
- **JSON Schema Validator**: https://www.jsonschemavalidator.net/
- **ajv-cli**: `npm install -g ajv-cli`

### Testing Frameworks

- **GUT (Godot Unit Test)**: https://github.com/bitwes/Gut
- **gdUnit4**: https://github.com/MikeSchulze/gdUnit4

### Version Control

- **Git**: https://git-scm.com/
- **GitHub**: https://github.com/
- **GitLab**: https://gitlab.com/

### Continuous Integration

- **GitHub Actions**: https://github.com/features/actions
- **GitLab CI**: https://docs.gitlab.com/ee/ci/

### Bug Tracking

- **GitHub Issues**: Built into GitHub
- **JIRA**: https://www.atlassian.com/software/jira
- **Trello**: https://trello.com/

---

**Document Version**: 1.0
**Last Updated**: 2024-11-16
**Maintained By**: Five Parsecs Campaign Manager Development Team

**Related Documentation**:
- [Expansion Documentation Index](./EXPANSION_DOCUMENTATION_INDEX.md)
- [Content Creation Guide](./CONTENT_CREATION_GUIDE.md)
- [Data Format Specifications](./DATA_FORMAT_SPECIFICATIONS.md)
- [Custom Expansion Creation Guide](./CUSTOM_EXPANSION_CREATION_GUIDE.md)
