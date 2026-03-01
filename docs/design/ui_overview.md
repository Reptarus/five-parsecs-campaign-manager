# UI Overview

**Last Updated**: February 2026
**Status**: Implemented and Production-Ready
**Engine**: Godot 4.6-stable

## Overview

The User Interface (UI) of the Five Parsecs Campaign Manager is designed for a streamlined and intuitive user experience, particularly for complex workflows like campaign creation. The UI architecture is built around a centralized `UIManager` and `SceneRouter` for efficient screen management and navigation.

## Design System (Feb 2026)

All UI components reference a centralized design token system for consistency across the application.

### UIColors (`src/ui/components/base/UIColors.gd`)
Canonical design token source (`class_name UIColors`, RefCounted). All UI components reference `UIColors.X` for:

- **Spacing** (8px grid): `SPACING_XS` (4) through `SPACING_XL` (32)
- **Touch targets**: `TOUCH_TARGET_MIN` (48px), `TOUCH_TARGET_COMFORT` (56px)
- **Typography**: `FONT_SIZE_XS` (11) through `FONT_SIZE_XL` (24)
- **Icon sizes**: `ICON_SIZE_XS` (16) through `ICON_SIZE_XXL` (128)
- **Deep Space color palette**: 10 colors + semantic aliases

#### Color Palette
| Token | Hex | Usage |
|-------|-----|-------|
| `COLOR_PRIMARY` | `#0a0d14` | Main background |
| `COLOR_SECONDARY` | `#111827` | Card backgrounds |
| `COLOR_TERTIARY` | `#1f2937` | Elevated elements |
| `COLOR_BORDER` | `#374151` | Borders |
| `COLOR_BLUE` | `#3b82f6` | Primary accent |
| `COLOR_PURPLE` | `#8b5cf6` | XP, story |
| `COLOR_EMERALD` | `#10b981` | Success |
| `COLOR_AMBER` | `#f59e0b` | Warning, credits |
| `COLOR_RED` | `#ef4444` | Danger, injury |
| `COLOR_CYAN` | `#06b6d4` | Save, world actions |
| `COLOR_TEXT_PRIMARY` | `#f3f4f6` | Bright text |
| `COLOR_TEXT_SECONDARY` | `#9ca3af` | Gray secondary |
| `COLOR_TEXT_MUTED` | `#6b7280` | Muted hints |

### IconRegistry (`src/ui/components/base/IconRegistry.gd`)
Static icon mapping system (`class_name IconRegistry`, RefCounted). Maps game concepts to 789 Lorc RPG icon assets (`Assets/789_Lorc_RPG_icons/`).

- **API**: `IconRegistry.get_icon(category, key) -> Texture2D`
- **Categories**: stat, status, phase, equipment, mission_type, action
- **Caching**: Static `_cache` Dictionary prevents re-loading

### ResponsiveManager (`src/autoload/ResponsiveManager.gd`)
Autoloaded breakpoint detection singleton. Provides responsive layout support.

- **Breakpoints**: MOBILE (<480), TABLET (480-768), DESKTOP (768-1024), WIDE (>1024)
- **Signals**: `breakpoint_changed(new_breakpoint)`, `viewport_resized(new_size)`
- **Helpers**: `is_mobile()`, `is_mobile_or_tablet()`, `get_touch_target_size()`, `get_optimal_columns()`, `get_font_size_multiplier()`

### Mobile Configuration
- `project.godot`: `window/stretch/mode="canvas_items"` + `window/stretch/aspect="expand"` for automatic scaling
- All battle screens respond to ResponsiveManager breakpoint changes

## Key Components

- **`UIManager` (`src/ui/screens/UIManager.gd`)**: Manages visibility and state of UI screens. Handles screen transitions, queues UI updates.

- **`SceneRouter` (`src/ui/screens/SceneRouter.gd`)**: Central navigation hub. 36 registered scene paths. All player-facing screen transitions use `navigate_to()`, `navigate_back()`, or `return_to_main_menu()`. Maintains navigation history stack (max 20 entries). Back buttons on full screens (WorldPhaseSummary, SaveLoadUI, PatronRivalManager, WorldPhaseController, etc.) use `navigate_back()`. Battle screens intentionally excluded — `end_battle_button` is the exit mechanism.

## Campaign Creation Workflow

The campaign creation process is a multi-step workflow managed by the `CampaignCreationUI` (`src/ui/screens/campaign/CampaignCreationUI.gd`). This UI integrates deeply with the `CampaignCreationStateManager` (`src/core/campaign/creation/CampaignCreationStateManager.gd`) to guide the user through the necessary steps:

1. **Configuration (`ConfigPanel`)**: Campaign parameters — name, difficulty, victory conditions.
2. **Crew Setup (`CrewPanel`)**: Crew member creation with attributes, backgrounds, motivations.
3. **Captain Creation (`CaptainPanel`)**: Captain designation.
4. **Ship Assignment (`ShipPanel`)**: Starting spaceship selection and configuration.
5. **Equipment Generation (`EquipmentPanel`)**: Starting equipment generation.
6. **Final Review (`FinalPanel`)**: Review all choices before finalizing.

## UI Components

The `src/ui/components` directory contains reusable UI elements:

- `base/` — UIColors, IconRegistry, BaseCampaignPanel (design system foundation)
- `battle/` — CharacterStatusCard, DiceDashboard, CombatCalculator, CheatSheetPanel, etc.
- `postbattle/` — InjuryResultCard, LootDisplayCard, PostBattleSummarySheet, etc.
- `campaign/` — CampaignTurnProgressTracker, StoryTrackSection, ResourcePanel, etc.
- `character/` — CharacterCard (icon-based portraits from IconRegistry)
- `history/` — CharacterHistoryPanel, CampaignTimelinePanel
- `export/` — ExportPanel, ImportPanel
- `inventory/` — EquipmentComparisonPanel
- `tooltip/` — TooltipManager
- `gesture/` — GestureManager (swipe/tap detection)

## Example Usage

```gdscript
# Design tokens
var bg := ColorRect.new()
bg.color = UIColors.COLOR_SECONDARY

var label := Label.new()
label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)

# Icons
var tex := IconRegistry.get_icon("stat", "combat")
var icon := TextureRect.new()
icon.texture = tex
icon.custom_minimum_size = Vector2(UIColors.ICON_SIZE_SM, UIColors.ICON_SIZE_SM)

# Responsive layout
var rm = get_node_or_null("/root/ResponsiveManager")
if rm:
    rm.breakpoint_changed.connect(_on_breakpoint_changed)
    if rm.is_mobile_or_tablet():
        _apply_mobile_layout()
```
