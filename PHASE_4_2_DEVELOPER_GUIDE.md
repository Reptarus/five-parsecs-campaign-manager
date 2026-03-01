# Phase 4.2: Post-Roll Explanation - Developer Guide

## Quick Start

### How to Use the Enhanced Combat Log

```gdscript
# 1. Get combat result from BattleCalculations
var result := BattleCalculations.resolve_ranged_attack(
    attacker_data,
    target_data,
    weapon_data,
    func(): return randi_range(1, 6)
)

# 2. Log to battle log (system handles formatting automatically)
combat_log_panel.log_combat_result(
    attacker.get_display_name(),
    target.get_display_name(),
    result
)

# 3. That's it! The system generates the full breakdown automatically
```

---

## Result Dictionary Structure

### Required Fields for Basic Explanation
```gdscript
{
    "hit": bool,              # Did attack hit?
    "hit_roll": int,          # Raw d6 roll (1-6)
    "hit_threshold": int,     # Target number needed
}
```

### Optional Fields for Enhanced Explanation
```gdscript
{
    # Modifiers (shown only if present and non-zero)
    "modified_hit_roll": int,        # Roll after modifiers
    "mod_range_bonus": int,          # Weapon mod range bonus
    "range_band": String,            # "short", "medium", "long"
    "armor_hit_bonus": int,          # Enhanced targeting
    "armor_hit_penalty": int,        # Stealth coating
    "camouflage_penalty": int,       # Target camouflage
    
    # Special rolls
    "battle_visor_used": bool,
    "battle_visor_reroll": int,
    
    # Damage (shown only if hit)
    "damage_roll": int,
    "raw_damage": int,
    "weapon_mod_damage_bonus": int,
    
    # Saves (shown only if hit)
    "armor_roll": int,
    "armor_saved": bool,
    "screen_saved": bool,
    "shield_blocked": bool,
    "save_type": String,             # "armor" or "screen"
    "reinforced_plating_bonus": int,
    "armor_reroll": int,
    
    # Results (shown only if hit and not saved)
    "target_eliminated": bool,
    "wounds_inflicted": int,
    
    # Effects array
    "effects": Array[String],  # ["stunned", "push_back", etc.]
}
```

---

## Supported Effect Types

### Status Effects (Automatically Formatted)
- `"stunned"` → "Stunned"
- `"double_stun"` → "Double Stun (Impact)"
- `"push_back"` → "Pushed 1\""
- `"suppressed"` → "Suppressed"
- `"forced_retreat"` → "Forced Retreat (Terrifying)"
- `"critical_extra_hit"` → "Critical: 2 Hits"

### Save Effects (Automatically Detected)
- `"shield_blocked"` → Shows cyan "Shield blocked!" message
- `"screen_deflected"` → Shows cyan "Screen Save!" message
- `"armor_pierced"` → Shows orange "Piercing weapon bypassed armor" message
- `"auto_medicator_negated_wound"` → Shows cyan "Auto-Medicator negated wound!" message

---

## Color Coding System

```gdscript
# Success (Green)
COLOR_SUCCESS = "#10B981"
# Use for: HIT!, Armor Save!, Screen Save!

# Failure (Red)
COLOR_DANGER = "#DC2626"
# Use for: MISS!, TARGET ELIMINATED!, Armor failed

# Warning (Orange)
COLOR_WARNING = "#D97706"
# Use for: X wound inflicted, Piercing bypassed armor

# Special (Cyan)
COLOR_FOCUS = "#4FC3F7"
# Use for: Shield blocked!, Battle Visor reroll, Auto-Medicator
```

---

## Adding New Effect Types

### Step 1: Add to BattleCalculations Result
```gdscript
# In BattleCalculations.gd
result["effects"].append("new_effect_name")
```

### Step 2: Add Display Text to log_combat_result
```gdscript
# In combat_log_panel.gd, find the match statement in SPECIAL EFFECTS section
match effect:
    "stunned": effect_descriptions.append("Stunned")
    "new_effect_name": effect_descriptions.append("Your Description Here")
```

### Example: Adding "Blinded" Effect
```gdscript
# 1. In BattleCalculations.gd
if has_trait(weapon_traits, "flash"):
    result["effects"].append("blinded")

# 2. In combat_log_panel.gd
match effect:
    "blinded": effect_descriptions.append("Blinded (-2 next attack)")
```

---

## Testing Your Changes

### Unit Test Template
```gdscript
func test_my_new_effect() -> void:
    # Arrange: Create result with your effect
    var result := {
        "hit": true,
        "hit_roll": 5,
        "modified_hit_roll": 5,
        "hit_threshold": 5,
        "damage_roll": 3,
        "raw_damage": 2,
        "wounds_inflicted": 1,
        "effects": ["my_new_effect"]
    }
    
    # Act
    log_panel.log_combat_result("Attacker", "Target", result)
    
    # Assert: Check log contains your text
    assert_int(log_panel.log_entries.size()).is_equal(1)
    var entry: Dictionary = log_panel.log_entries[0]
    assert_str(entry["message"]).contains("Your Expected Text")
```

### Run Tests
```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_combat_log_explanations.gd `
  --quit-after 60
```

---

## Performance Considerations

### ✅ DO: Use PackedStringArray
```gdscript
var log_lines: PackedStringArray = []
log_lines.append("Line 1")
log_lines.append("Line 2")
var full_message := "\n".join(log_lines)
```

### ❌ DON'T: Concatenate in Loop
```gdscript
var message := ""
for effect in effects:
    message += effect + ", "  # Creates new string each iteration!
```

### ✅ DO: Conditional Formatting
```gdscript
if result.has("mod_range_bonus") and result.mod_range_bonus != 0:
    # Only format if exists
```

### ❌ DON'T: Always Format
```gdscript
# Don't show "+0 range bonus" when there is no bonus
```

---

## Common Mistakes

### 1. Missing Color Tags
```gdscript
# ❌ WRONG
log_lines.append("HIT!")

# ✅ CORRECT
log_lines.append("[color=#10B981]HIT![/color]")
```

### 2. Showing Damage on Miss
```gdscript
# ❌ WRONG
if result.has("damage_roll"):
    # This shows damage even on miss!

# ✅ CORRECT
if result.get("hit", false) and result.has("damage_roll"):
    # Only show damage if attack hit
```

### 3. Not Checking Effect Array
```gdscript
# ❌ WRONG
if "stunned" in result["effects"]:  # Crashes if no effects key!

# ✅ CORRECT
if "stunned" in result.get("effects", []):
```

### 4. Forgetting BBCode Escaping
```gdscript
# ❌ WRONG (if character_name contains BBCode)
log_lines.append("[color=#10B981]%s[/color]" % character_name)

# ✅ CORRECT (for user input, though character names are safe in our case)
# No escaping needed for our controlled character names
```

---

## Debugging Tips

### 1. Print Result Dictionary
```gdscript
print("Result: ", JSON.stringify(result, "  "))
```

### 2. Check Log Entries
```gdscript
print("Log entries count: ", log_panel.log_entries.size())
for entry in log_panel.log_entries:
    print("Entry: ", entry["message"])
```

### 3. Validate Colors in Editor
Enable BBCode in RichTextLabel and test:
```gdscript
$RichTextLabel.bbcode_enabled = true
$RichTextLabel.text = "[color=#10B981]HIT![/color]"
```

---

## Integration Checklist

When integrating combat log into a new battle screen:

☐ Get reference to `combat_log_panel` instance
☐ Connect to combat result signal/callback
☐ Pass full result Dictionary from `BattleCalculations`
☐ Call `log_combat_result(attacker_name, target_name, result)`
☐ Ensure RichTextLabel has `bbcode_enabled = true`
☐ Test with various scenarios (hit/miss/save/eliminate)
☐ Verify colors display correctly
☐ Check log scrolls properly on mobile

---

## API Reference

### Main Function
```gdscript
func log_combat_result(attacker: String, target: String, result: Dictionary) -> void
```
**Parameters**:
- `attacker`: Display name of attacking character
- `target`: Display name of target character
- `result`: Dictionary from `BattleCalculations.resolve_ranged_attack()` or `resolve_brawl()`

**Returns**: void (adds entry to log internally)

### Helper Functions (Public)
```gdscript
func add_log_entry(entry_type: String, message: String, details: Dictionary = {}) -> void
func clear_log() -> void
```

### Legacy Functions (Still Supported)
```gdscript
func log_attack_roll(attacker: String, target: String, roll: int, modifiers: Dictionary) -> void
func log_damage(target: String, damage: int, source: String) -> void
func log_modifier(source: String, value: int, description: String) -> void
func log_critical_hit(attacker: String, target: String, multiplier: float) -> void
```

---

## Migration from Old System

### Before (Phase 4.1)
```gdscript
combat_log.log_attack_roll(attacker_name, target_name, roll, modifiers)
if hit:
    combat_log.log_damage(target_name, damage, weapon_name)
if critical:
    combat_log.log_critical_hit(attacker_name, target_name, 2.0)
```

### After (Phase 4.2)
```gdscript
# Single call, system handles everything
combat_log.log_combat_result(attacker_name, target_name, result)
```

**Benefits**:
- Fewer function calls
- Automatic formatting
- Consistent presentation
- All data in one place

---

## Troubleshooting

### Log Doesn't Show Colors
**Cause**: RichTextLabel `bbcode_enabled` is false
**Fix**: In scene editor, select log RichTextLabel, enable BBCode

### Modifiers Not Showing
**Cause**: Result dictionary missing modifier fields
**Fix**: Ensure `BattleCalculations.resolve_ranged_attack()` is passing complete result

### Effects Not Listed
**Cause**: Effect name not in match statement
**Fix**: Add effect name to `SPECIAL EFFECTS` section in `log_combat_result()`

### Log Entries Disappear
**Cause**: `max_entries` exceeded (default 100)
**Fix**: Increase `log_panel.max_entries` or implement export to file

---

## Next Steps

Ready to extend the system? Consider:

1. **Add Brawl Support**: Extend for melee combat results
2. **Area Effect Support**: Handle multi-target attacks
3. **Reaction Logging**: Track reactions (Seize Initiative, etc.)
4. **Status Change Logging**: Log when effects expire
5. **Export Functionality**: Save log to file for analysis

---

## Support

**Test File**: `/tests/unit/test_combat_log_explanations.gd`
**Implementation**: `/src/ui/components/combat/log/combat_log_panel.gd`
**Integration**: `/src/ui/components/combat/log/combat_log_controller.gd`
**Documentation**: This file + `PHASE_4_2_POST_ROLL_EXPLANATION_SUMMARY.md`

**Questions?** Check test file for working examples of every scenario.
