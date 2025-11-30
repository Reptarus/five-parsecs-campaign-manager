# Accessibility Themes - Quick Start Guide

## For Developers: Making UI Colorblind-Safe in 3 Steps

### Step 1: Replace Hardcoded Colors

**Before (NOT colorblind-safe):**
```gdscript
# Bad: Hardcoded red/green colors
if health > 70:
    health_bar.modulate = Color.GREEN
else:
    health_bar.modulate = Color.RED
```

**After (Colorblind-safe):**
```gdscript
# Good: Theme-aware colors
var health_percent = float(health) / 100.0
health_bar.modulate = ThemeManager.get_health_color(health_percent)
```

### Step 2: Use StatBadge Helper Methods

**Before:**
```gdscript
var badge = StatBadge.new()
badge.stat_name = "Health"
badge.stat_value = "50/100"
badge.accent_color = Color.RED  # NOT colorblind-safe
```

**After:**
```gdscript
var badge = StatBadge.new()
badge.configure_health(50, 100)  # Automatically colorblind-safe
```

### Step 3: Use Semantic Color Names

**Available semantic colors:**
- `"success"` - Positive outcomes (green → blue in deuteranopia)
- `"warning"` - Caution states (yellow/orange)
- `"danger"` - Critical states (red → purple in protanopia)
- `"health_full"` - Good health (70-100%)
- `"health_mid"` - Moderate health (30-70%)
- `"health_low"` - Critical health (0-30%)
- `"weapon"` - Weapon equipment type
- `"armor"` - Armor equipment type
- `"gear"` - General gear type

**Example:**
```gdscript
badge.use_theme_color("success")  # Adapts to current theme
```

## For Players: Enabling Accessibility Themes

1. Open Settings menu
2. Navigate to Accessibility Settings
3. Select your preferred theme:
   - **High Contrast** - Maximum contrast for low vision
   - **Colorblind (Red-Green)** - Most common colorblindness (6% of males)
   - **Colorblind (Red)** - Red colorblindness (1% of males)
   - **Colorblind (Blue-Yellow)** - Rare colorblindness (0.01%)
4. Click "Apply Theme"
5. Theme preference is saved automatically

## Quick Reference: Color Replacements

| Original | Deuteranopia | Protanopia | Tritanopia |
|----------|--------------|------------|------------|
| Green (success) | Blue | Cyan | Cyan-green |
| Yellow (warning) | Orange | Orange | Pink |
| Red (danger) | Orange-red | Purple | Red |

## Testing Your Changes

### Manual Test
1. Switch to "Colorblind (Red-Green)" theme
2. Verify no pure green or pure red colors visible
3. Switch to "High Contrast" theme
4. Verify all text/borders clearly visible

### Code Review Checklist
- [ ] No hardcoded `Color.GREEN`, `Color.RED`, `Color.YELLOW`
- [ ] Uses `ThemeManager.get_color()` or semantic helpers
- [ ] Status conveyed by text/icons, not just color
- [ ] Focus indicators visible in High Contrast mode

## Common Pitfalls

### Pitfall 1: Using Color as Only Indicator
```gdscript
# Bad: Color is the only indicator
status_icon.modulate = Color.RED if threat_high else Color.GREEN
```

**Fix:** Add text or icon shapes
```gdscript
# Good: Color + text/icon
status_icon.modulate = ThemeManager.get_threat_color(threat_level)
status_icon.texture = load("res://icons/threat_%s.png" % threat_level)
status_label.text = threat_level.capitalize()
```

### Pitfall 2: Assuming Theme Manager Exists
```gdscript
# Bad: Crashes if ThemeManager not found
var color = ThemeManager.get_color("success")
```

**Fix:** Use fallback
```gdscript
# Good: Fallback to default color
var color = Color.GREEN
if ThemeManager:
    color = ThemeManager.get_color("success")
```

### Pitfall 3: Mixing Hardcoded and Theme Colors
```gdscript
# Bad: Inconsistent approach
health_bar.modulate = ThemeManager.get_health_color(hp_percent)
shield_bar.modulate = Color.BLUE  # Hardcoded!
```

**Fix:** Use theme for all colors
```gdscript
# Good: Consistent theme usage
health_bar.modulate = ThemeManager.get_health_color(hp_percent)
shield_bar.modulate = ThemeManager.get_color("accent")
```

## Need Help?

See full documentation: `/docs/ACCESSIBILITY_THEMES_IMPLEMENTATION.md`

Key files:
- `/src/ui/themes/AccessibilityThemes.gd` - Color palettes
- `/src/ui/themes/ThemeManager.gd` - Theme management
- `/src/ui/components/base/StatBadge.gd` - Example component
