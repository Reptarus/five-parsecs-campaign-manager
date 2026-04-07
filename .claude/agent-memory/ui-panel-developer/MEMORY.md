# UI Panel Developer — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Save: theme gotchas, TweenFX patterns, panel construction issues, responsive edge cases -->

## ABSOLUTE RULE: Core Rules & Compendium Are Word of God

The Core Rules and Compendium PDFs at `docs/rules/` define all game terminology, stat names, and mechanic labels displayed in UI. If a UI label doesn't match the book, the UI is wrong.

---

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

### 8. PDF Rulebooks Available

If you need to verify UI labels, stat names, or game terminology against the source material:
- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Python**: `py -c "import fitz; doc = fitz.open('path'); print(doc[PAGE].get_text())"`

### 9. UIColors Over Local Constants

World phase components should use `UIColors.COLOR_EMERALD`, `UIColors.COLOR_RED`, etc. instead of local `const COLOR_*` definitions. Base class provides `TOUCH_TARGET_MIN := 48`.

### 10. DLC UI Components (Session 33, Apr 6)

New code-built components in `src/ui/components/dlc/` and `src/ui/screens/store/`:
- **DLCContentCatalog.gd** — Marketing copy catalog (RefCounted, class_name). Use static methods: `get_pack_catalog()`, `get_pack_name()`, `get_features_for_display()`, `get_pack_for_flag()`
- **DLCPackCard.gd** — Rich card extending PanelContainer. Call `setup(dlc_id)` then `refresh(is_owned, price, enabled_count, total_count)`
- **DLCFeatureToggleRow.gd** — Atomic toggle row. `setup()` takes 7 params. Two states: owned (CheckBox) or locked (lock + upsell button)
- **ExpansionFeatureSection.gd** — Grouped toggles. `setup(mode)` with 3 modes: "campaign_creation" (shows disclaimer), "settings", "read_only"
- **DLCUpsellBanner.gd** — Static factory `DLCUpsellBanner.create_for_flag(flag_name)` returns configured PanelContainer
- **DLCActivationToast.gd** — Static helper `DLCActivationToast.show_for_dlc(dlc_id)` adds CanvasLayer toast
- **StoreScreen.gd** — Extends CampaignScreenBase. Uses DLCPackCard, BundleCard, BugHuntCard
- **MainMenu** — "Expansions" button routes to SceneRouter `"store"`. Social footer at bottom-left (code-built, hides on narrow)
