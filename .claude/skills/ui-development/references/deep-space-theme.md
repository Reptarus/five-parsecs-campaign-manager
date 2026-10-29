# Deep Space Theme Reference

## Source
All constants from `src/ui/screens/campaign/panels/BaseCampaignPanel.gd` (class_name `FiveParsecsCampaignPanel`), delegated to UIColors.

## Spacing (8px Grid)
```gdscript
SPACING_XS := 4   # Icon padding, label-to-input gap
SPACING_SM := 8   # Element gaps within cards
SPACING_MD := 16  # Inner card padding
SPACING_LG := 24  # Section gaps between cards
SPACING_XL := 32  # Panel edge padding
```

## Touch Targets
```gdscript
TOUCH_TARGET_MIN := 48      # Minimum interactive element height
TOUCH_TARGET_COMFORT := 56  # Comfortable input height
```

## Typography
```gdscript
FONT_SIZE_XS := 11  # Captions, limits
FONT_SIZE_SM := 14  # Descriptions, helpers
FONT_SIZE_MD := 16  # Body text, inputs
FONT_SIZE_LG := 18  # Section headers
FONT_SIZE_XL := 24  # Panel titles
```

## Color Palette

### Primary Colors (New System)
```gdscript
COLOR_PRIMARY     # Main accent
COLOR_SECONDARY   # Secondary accent
COLOR_TERTIARY    # Tertiary accent
COLOR_BORDER      # Borders
COLOR_BLUE        # Info
COLOR_PURPLE      # Special
COLOR_EMERALD     # Success
COLOR_AMBER       # Warning
COLOR_RED         # Danger/Error
COLOR_CYAN        # Focus/Highlight
COLOR_TEXT_PRIMARY   # Main text
COLOR_TEXT_SECONDARY # Descriptions
COLOR_TEXT_MUTED     # Disabled text
```

### Legacy names (aliases of the palette above)
`UIColors` keeps the old names, and each one now points at the current palette:
`COLOR_BASE` = `COLOR_PRIMARY`, `COLOR_ELEVATED` = `COLOR_SECONDARY`, `COLOR_INPUT` =
`COLOR_TERTIARY`, `COLOR_ACCENT` = `COLOR_BLUE`, `COLOR_SUCCESS` = `COLOR_EMERALD`,
`COLOR_WARNING` = `COLOR_AMBER`, `COLOR_DANGER` = `COLOR_RED`, `COLOR_TEXT_DISABLED` =
`COLOR_TEXT_MUTED`. Read `src/ui/components/base/UIColors.gd` for the values.

⚠ This block used to list the names with their OLD values (`#1A1A2E`, `#252542`,
`#1E1E36`, `#2D5A7B`, `#4FC3F7`, `#D97706`, `#DC2626`). Code copied those hexes, and by
2026-10-29 the battle screens drew 137 of them while the rest of the app had moved on.
Never write a hex in a UI script: use a token, or a named `const` for a categorical
palette. `tests/unit/test_ui_color_tokens.gd` fails on an inline hex and on a const
that restates a token's name with a hex. The avatar colours are `UIColors.avatar_color()`.

## BBCode Colors (for RichTextLabel)
Write a role and resolve it where the text reaches the label, so stored text follows
the palette:
```gdscript
label.text = UIColors.bbcode("[color=ui-success]Success[/color]")
# roles: ui-success, ui-warning, ui-danger, ui-info, ui-secondary
```

## Responsive Breakpoints
```gdscript
BREAKPOINT_MOBILE  := UIColors.BREAKPOINT_MOBILE
BREAKPOINT_TABLET  := UIColors.BREAKPOINT_TABLET
BREAKPOINT_DESKTOP := UIColors.BREAKPOINT_DESKTOP
```

Layout modes: `LayoutMode { MOBILE, TABLET, DESKTOP }`

## Project-Wide Theme (Mar 2026)

`project.godot` sets `gui/theme/custom="res://src/ui/themes/sci_fi_theme.tres"`.
All controls inherit Montserrat + Deep Space styles unless overridden via `add_theme_*_override()`.

**Fonts:**
- Default: Montserrat-Regular (`assets/fonts/Montserrat-Regular.ttf`)
- Buttons: Montserrat-SemiBold
- Bold/titles: Montserrat-Bold
- Monospace (RTL, TextEdit): CourierPrime-Regular

**Max-Width Form Constraint:**
- `BaseCampaignPanel.MAX_FORM_WIDTH := 800` — forms centered at 800px on wide screens
- `BugHuntCreationUI.MAX_FORM_WIDTH := 800` — same for Bug Hunt (extends Control, not BaseCampaignPanel)
- Dynamic margins via `_apply_content_max_width()` connected to viewport `size_changed`

**Portrait/Avatar System:**
- `CharacterCard._update_portrait()` prefers `portrait_path` (custom image), falls back to colored initials
- 8 deterministic avatar colors: `AVATAR_COLORS` array, index = `name.hash() % 8`
- Factory methods `_create_character_card()` accept optional `portrait_path` param
- `ResourceLoader.exists()` for `res://` paths, `FileAccess.file_exists()` for `user://` paths

**HFlowContainer for button bars:**
- CampaignDashboard ButtonContainer is now HFlowContainer (auto-wraps, no column management needed)

## Glass Card Styles
```gdscript
_create_glass_card_style(alpha: float = 0.8) -> StyleBoxFlat
_create_glass_card_elevated() -> StyleBoxFlat
_create_glass_card_subtle() -> StyleBoxFlat
_create_elevated_card_style() -> StyleBoxFlat
_create_accent_card_style(accent_color: Color) -> StyleBoxFlat
_create_glass_panel_style() -> StyleBoxFlat
_create_glass_panel_style_compact() -> StyleBoxFlat
```
