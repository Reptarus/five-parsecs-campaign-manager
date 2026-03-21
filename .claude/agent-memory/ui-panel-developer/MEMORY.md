# UI Panel Developer — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Save: theme gotchas, TweenFX patterns, panel construction issues, responsive edge cases -->

## Critical Gotchas — Must Remember

### 1. TweenFX pivot_offset

MUST set `node.pivot_offset = node.size / 2` before any scale or rotation animation. Without this, animations pivot from the top-left corner instead of center.

```gdscript
# CORRECT
node.pivot_offset = node.size / 2
TweenFX.pop_in(node, 0.3)

# WRONG — will scale from top-left
TweenFX.pop_in(node, 0.3)
```

### 2. TweenFX Looping Animations

These loop indefinitely and MUST be explicitly stopped:
- `alarm`, `breathe`, `attract`, `glow_pulse`

Call `TweenFX.stop(node)` or kill the tween when the node is hidden/freed. Forgetting to stop causes orphaned tweens.

### 3. TweenFX.tada() Signature

`TweenFX.tada(node, duration)` — only 2 arguments. There is no scale parameter.

### 4. Deep Space Theme Constants

Never hardcode colors or spacing. Always use the Deep Space theme system:
- Spacing: 8px grid (8, 16, 24, 32)
- Touch targets: 48-56px minimum
- Typography: 11-24px scale
- Colors: base/elevated/input/border/accent/text/status palettes
- Use `BaseCampaignPanel` factory methods for consistent panel construction

### 5. Godot 4.6 Type Inference

`var x := dict["key"]` will NOT compile — Dictionary values are always Variant.
Always use explicit type annotation: `var x: Type = dict["key"]`.
Applies to scene meta, config dicts, chart data, theme lookups. Zero exceptions.

### 6. WorldPhaseComponent Base Class Collisions

WorldPhaseComponent defines `_help_dialog` var and `_show_help_dialog()` method. Child components MUST NOT redeclare these — causes Parser Error at runtime (not caught by headless check). UpkeepPhaseComponent and CrewTaskComponent both had this bug (fixed Mar 21).

### 7. BUG-034 Selected Card Contrast Pattern

When a card changes background color on selection, update text colors too:
```gdscript
# In _set_card_selected_state():
if selected:
    desc_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)  # bright on dark bg
else:
    desc_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)  # muted on normal bg
```

### 8. UIColors Over Local Constants

World phase components should use `UIColors.COLOR_EMERALD`, `UIColors.COLOR_RED`, etc. instead of local `const COLOR_*` definitions. Base class provides `TOUCH_TARGET_MIN := 48`.
