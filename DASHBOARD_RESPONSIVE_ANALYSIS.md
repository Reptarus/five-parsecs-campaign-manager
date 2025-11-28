# Campaign Dashboard & Turn Phase Screens - Responsive Design Analysis

**Date**: 2025-11-27
**Context**: Sprint 3 completed responsive layouts for all 7 campaign wizard panels. This analysis evaluates responsive requirements for the campaign turn phase screens.

---

## Executive Summary

### Current State
The campaign turn phase screens (CampaignDashboard, WorldPhaseController, TravelPhaseUI, PostBattleSequence) currently use **fixed desktop layouts** with no responsive breakpoint handling. All screens extend `Control` directly and do not inherit from the design system base class.

### Gap Analysis
- **Zero responsive behavior**: No breakpoint detection, layout switching, or touch target adjustments
- **No design system integration**: Screens do not use BaseCampaignPanel's constants, factory methods, or responsive helpers
- **Inconsistent styling**: Each screen uses ad-hoc spacing, colors, and sizing instead of the unified design system
- **Touch-unfriendly**: Many buttons below 48dp minimum, no mobile layout optimization

### Recommended Approach
**Refactor all 4 screens** to extend `FiveParsecsCampaignPanel` (which includes BaseCampaignPanel's responsive system). This provides:
- Automatic breakpoint detection (MOBILE <480px, TABLET 480-768px, DESKTOP >1024px)
- Design system constants (SPACING_*, TOUCH_TARGET_*, COLOR_*, FONT_SIZE_*)
- Responsive helper methods (get_responsive_font_size, should_use_single_column, etc.)
- Factory methods for consistent UI components

### Total Effort Estimate
**16-24 hours** across all 4 screens, plus 2-4 hours for testing/refinement.

---

## Per-Screen Analysis

### 1. CampaignDashboard

**Location**: `src/ui/screens/campaign/CampaignDashboard.gd` + `.tscn`
**Current Base Class**: `Control` (class_name FPCM_CampaignDashboardUI)
**Priority**: **HIGH** (main hub for campaign interaction)

#### Current State
- **Lines of Code**: 990 (GDScript), 294 (scene nodes)
- **Layout**: Fixed two-column layout using ResponsiveContainer (line 107)
  - Left panel: Crew list (CharacterBox cards), ship info, battle history
  - Right panel: Quest info, world info, victory progress, patrons, rivals
- **Touch Targets**: Buttons have `custom_minimum_size = Vector2(120, 48)` (line 267) - **meets minimum but not comfortable for mobile**
- **Responsive Elements**: Uses ResponsiveContainer with `min_width_for_horizontal = 800` (line 108) - basic horizontal/vertical switch only
- **Design System Usage**: None (uses ad-hoc node structure)

#### Elements Needing Responsive Treatment

| Element | Current State | Mobile Requirement | Tablet Requirement | Desktop Requirement |
|---------|---------------|-------------------|-------------------|-------------------|
| HeaderPanel labels | Fixed 16-20px font | 14px (FONT_SIZE_SM) | 16px (FONT_SIZE_MD) | 20px (FONT_SIZE_LG) |
| Resource labels (Credits, SP) | Fixed layout | Single row, compact icons | Two rows | Two rows, full text |
| Crew list (CrewList) | Vertical ScrollContainer | 1 column, 56dp cards | 2 columns, 48dp cards | 2-3 columns, 48dp cards |
| Ship info panel | Fixed text display | Compact stats (icons only) | Detailed stats | Full info + debt warning |
| Battle history | ScrollContainer 120px min | Hide on mobile, show count badge | Collapsed list (5 max) | Full list (10 max) |
| Victory progress panel | Nested instanced scene | Collapsed progress bar | Mini-panel | Full panel with descriptions |
| Patron/Rival lists | ItemList fixed height | Hide, show count badges | Mini-list (3 max) | Full list |
| Action buttons | 48dp height, 120-140px width | 56dp height, full width | 48dp, half width | 48dp, auto width |

#### Recommended Approach
**Refactor to extend FiveParsecsCampaignPanel**

1. Change base class from `Control` to `FiveParsecsCampaignPanel`
2. Remove ResponsiveContainer in favor of programmatic layout switching
3. Implement three responsive layout methods:

```gdscript
func _apply_mobile_layout() -> void:
	# Single column, essential data only
	# Hide: Battle history list, patron/rival lists (show count badges)
	# Show: Compact crew cards (1 column), collapsed victory progress
	# Touch targets: 56dp for all buttons

func _apply_tablet_layout() -> void:
	# Two columns (left: crew/ship, right: world/quest/victory)
	# Show: Partial battle history (5 max), mini patron/rival lists (3 max)
	# Touch targets: 48dp

func _apply_desktop_layout() -> void:
	# Two/three columns based on viewport width
	# Show: Full data, all lists expanded
	# Touch targets: 48dp
```

#### Specific Implementation Details

**Mobile Layout (Portrait <480px)**:
```gdscript
# Header: Single row with credits + SP only
# Crew section: Single column, CharacterBox in "compact" mode (already implemented)
# Ship: Icon + hull/fuel only (hide debt unless critical)
# Battle history: Hide list, show "Last battle: Victory/Defeat" label
# Patrons/Rivals: Hide lists, show count badges: "2 Patrons, 1 Rival"
# Victory: Collapsed progress bar only (no description)
# Action buttons: Full width, 56dp height, stacked vertically
```

**Tablet Layout (480-768px)**:
```gdscript
# Header: Two rows (top: credits/SP, bottom: patrons/rivals/rumors/events)
# Crew section: Two columns of CharacterBox cards
# Ship: Full stats visible
# Battle history: Collapsed list (show last 5)
# Patrons/Rivals: Mini-lists (3 max, "+ N more" label)
# Victory: Mini-panel with progress bar + current condition
# Action buttons: Half width, 48dp height
```

**Desktop Layout (>1024px)**:
```gdscript
# Header: Full layout (all labels visible)
# Crew section: 2-3 columns based on crew count
# Ship: Full info + debt warning
# Battle history: Full list (10 max)
# Patrons/Rivals: Full lists with scrolling
# Victory: Full panel with all conditions
# Action buttons: Auto width, horizontal layout
```

#### Estimated Effort
- **Refactor to FiveParsecsCampaignPanel**: 2 hours
- **Implement mobile layout**: 3 hours (most complex due to hiding/showing logic)
- **Implement tablet layout**: 2 hours
- **Implement desktop layout**: 1 hour (mostly current behavior)
- **Testing & refinement**: 1 hour
- **Total**: **9 hours**

---

### 2. WorldPhaseController

**Location**: `src/ui/screens/world/WorldPhaseController.gd` + `.tscn`
**Current Base Class**: `Control` (class_name WorldPhaseController)
**Priority**: **HIGH** (core gameplay loop)

#### Current State
- **Lines of Code**: 1068 (GDScript), 275 (scene nodes)
- **Layout**: Single column with phase container switching (9 different component containers)
  - Header: Title, current step label, progress bar
  - Phase container: Holds 9 instanced components (UpkeepPhaseComponent, CrewTaskComponent, JobOfferComponent, etc.)
  - Controls: Automation toggle, back/next buttons
- **Touch Targets**: Buttons have `custom_minimum_size = Vector2(120, 40)` (lines 263, 273) - **BELOW 48dp minimum**
- **Responsive Elements**: None (fixed layout)
- **Design System Usage**: None

#### Elements Needing Responsive Treatment

| Element | Current State | Mobile Requirement | Tablet Requirement | Desktop Requirement |
|---------|---------------|-------------------|-------------------|-------------------|
| Header title | 24px fixed | 20px (FONT_SIZE_LG) | 24px (FONT_SIZE_XL) | 24px (FONT_SIZE_XL) |
| Current step label | 18px fixed | 16px (FONT_SIZE_MD) | 18px (FONT_SIZE_LG) | 18px (FONT_SIZE_LG) |
| Progress bar | Fixed height | 12px height | 8px height | 8px height |
| Phase containers | Full screen | Full screen (hide header on scroll) | Full screen | Full screen with sidebar |
| Back/Next buttons | 40dp height ❌ | 56dp height, full width | 48dp height, half width | 48dp height, auto width |
| Automation toggle | Standard CheckBox | Large touch area (56dp) | Standard (48dp) | Standard (48dp) |

#### Recommended Approach
**Refactor to extend FiveParsecsCampaignPanel**

This is simpler than CampaignDashboard because it's primarily a navigation wrapper. The 9 phase components (UpkeepPhaseComponent, CrewTaskComponent, etc.) are **separate analysis targets** - they should ALSO be refactored to use the design system independently.

1. Change base class to `FiveParsecsCampaignPanel`
2. Adjust button sizes to meet touch target minimums
3. Implement responsive layouts for header/controls only (phase containers are self-contained)

```gdscript
func _apply_mobile_layout() -> void:
	# Header: Collapse title on scroll (auto-hide behavior)
	# Progress bar: 12px height for visibility
	# Buttons: 56dp, full width, stacked
	# Automation toggle: 56dp touch area

func _apply_tablet_layout() -> void:
	# Header: Always visible
	# Progress bar: 8px height
	# Buttons: 48dp, half width, side-by-side
	# Automation toggle: Standard

func _apply_desktop_layout() -> void:
	# Header: Always visible with sidebar navigation
	# Progress bar: 8px height
	# Buttons: 48dp, auto width
	# Optional: Add step sidebar for quick navigation
```

#### Specific Implementation Details

**Mobile Layout**:
```gdscript
# Auto-hide header on scroll down (show on scroll up)
# Full-screen phase containers
# Bottom navigation bar with Back/Next (floating above content)
# Automation toggle in top-right corner (floating button)
```

**Tablet/Desktop Layout**:
```gdscript
# Persistent header
# Optional sidebar showing all 9 steps with completion checkmarks (desktop only)
# Standard bottom controls
```

#### Estimated Effort
- **Refactor to FiveParsecsCampaignPanel**: 1 hour
- **Implement mobile layout** (header auto-hide + button sizing): 2 hours
- **Implement tablet layout**: 1 hour
- **Implement desktop layout** (with optional sidebar): 2 hours
- **Testing & refinement**: 1 hour
- **Total**: **7 hours**

**Note**: This does NOT include refactoring the 9 phase components (UpkeepPhaseComponent, CrewTaskComponent, etc.). Those components should be analyzed separately as they each have their own complex layouts.

---

### 3. TravelPhaseUI

**Location**: `src/ui/screens/travel/TravelPhaseUI.tscn` (no .gd script found, likely inline)
**Current Base Class**: `Control`
**Priority**: **MEDIUM** (less frequently used than World/Dashboard)

#### Current State
- **Lines of Code**: 128 (scene nodes only)
- **Layout**: Centered PanelContainer (600×400 min size) with TabContainer
  - Upkeep tab: Label + button
  - Travel tab: Two buttons (stay/travel) + event details + generate event button
  - Bottom: Back/Next buttons
  - LogBook: Bottom 30% of screen (RichTextLabel)
- **Touch Targets**: Buttons have no explicit sizing - **likely below minimum**
- **Responsive Elements**: CenterContainer (only centers, no breakpoint handling)
- **Design System Usage**: None

#### Elements Needing Responsive Treatment

| Element | Current State | Mobile Requirement | Tablet Requirement | Desktop Requirement |
|---------|---------------|-------------------|-------------------|-------------------|
| PanelContainer | 600×400 fixed | Full screen (no padding) | 600×500 | 700×500 |
| TabContainer | Fixed tabs | Single tab visible, swipe navigation | Standard tabs | Standard tabs |
| Upkeep button | Standard | 56dp height, full width | 48dp height | 48dp height |
| Stay/Travel buttons | Standard | 56dp height, stacked | 48dp height, side-by-side | 48dp height |
| LogBook | 30% screen height | Hidden, show via modal | 30% screen height | 30% screen height |
| Back/Next buttons | Standard | 56dp, full width, stacked | 48dp, side-by-side | 48dp |

#### Recommended Approach
**Create TravelPhaseUI.gd script extending FiveParsecsCampaignPanel**

This screen currently has NO script - it's entirely scene-based. Needs a GDScript class to handle responsive logic.

1. Create `TravelPhaseUI.gd` extending `FiveParsecsCampaignPanel`
2. Attach script to TravelPhaseUI root node
3. Implement responsive layouts:

```gdscript
class_name TravelPhaseUI
extends FiveParsecsCampaignPanel

func _apply_mobile_layout() -> void:
	# Full-screen panel (no margin)
	# Hide LogBook, add "View Log" button → modal dialog
	# TabContainer: Hide tabs, show current step only
	# All buttons: 56dp, full width, stacked

func _apply_tablet_layout() -> void:
	# 600×500 centered panel
	# Show LogBook at bottom (30%)
	# Standard tabs
	# Buttons: 48dp, side-by-side

func _apply_desktop_layout() -> void:
	# 700×500 centered panel
	# Show LogBook at bottom
	# Standard tabs
```

#### Specific Implementation Details

**Mobile Layout**:
```gdscript
# Remove CenterContainer, use full screen MarginContainer (8dp edges)
# LogBook becomes modal dialog (triggered by "View Log" button)
# TabContainer: Custom navigation (Back/Next between Upkeep/Travel tabs)
# Buttons: VBoxContainer with 56dp buttons, SPACING_SM gaps
```

**Tablet/Desktop Layout**:
```gdscript
# Keep CenterContainer
# LogBook visible at bottom 30%
# Standard tab navigation
```

#### Estimated Effort
- **Create TravelPhaseUI.gd script**: 1 hour
- **Refactor to FiveParsecsCampaignPanel**: 1 hour
- **Implement mobile layout** (full-screen + LogBook modal): 2 hours
- **Implement tablet layout**: 1 hour
- **Implement desktop layout**: 0.5 hours
- **Testing & refinement**: 1 hour
- **Total**: **6.5 hours**

---

### 4. PostBattleSequence

**Location**: `src/ui/screens/postbattle/PostBattleSequence.gd` + `.tscn`
**Current Base Class**: `Control` (class_name PostBattleSequenceUI)
**Priority**: **MEDIUM** (important but used less frequently than World/Dashboard)

#### Current State
- **Lines of Code**: 924 (GDScript), 149 (scene nodes)
- **Layout**: Three-column layout
  - Left column: Steps list (300px fixed width, scrollable)
  - Center column: Current step content (expandable)
  - Right column: Results log (250px fixed width, scrollable)
  - Bottom: Previous/Next/Roll/Finish buttons
- **Touch Targets**: Buttons have no explicit sizing - **likely standard ~40dp (below minimum)**
- **Responsive Elements**: None (fixed layout)
- **Design System Usage**: None

#### Elements Needing Responsive Treatment

| Element | Current State | Mobile Requirement | Tablet Requirement | Desktop Requirement |
|---------|---------------|-------------------|-------------------|-------------------|
| Steps list (left panel) | 300px fixed width | Hidden, show as bottom sheet | 200px width | 300px width |
| Current step content | Expandable | Full screen | 50% width | 50-60% width |
| Results log (right panel) | 250px fixed width | Hidden, show as modal | 250px width | 250px width |
| Previous/Next buttons | Standard | 56dp, full width | 48dp, half width | 48dp, auto width |
| Roll button | Standard | 56dp, full width (primary action) | 48dp | 48dp |
| Finish button | Standard | 56dp, full width | 48dp | 48dp |

#### Recommended Approach
**Refactor to extend FiveParsecsCampaignPanel**

This screen has complex three-column layout that needs significant mobile adaptation.

1. Change base class to `FiveParsecsCampaignPanel`
2. Implement responsive layouts with conditional visibility:

```gdscript
func _apply_mobile_layout() -> void:
	# Hide steps list, add hamburger menu → bottom sheet modal
	# Hide results log, add "View Results" button → modal dialog
	# Current step: Full screen
	# Buttons: 56dp, full width, stacked (Roll button primary color)

func _apply_tablet_layout() -> void:
	# Two columns: Steps list (200px) + current step (expand)
	# Hide results log, add "Results" button → slide-in panel
	# Buttons: 48dp, side-by-side

func _apply_desktop_layout() -> void:
	# Three columns: Steps (300px) + current step (expand) + results (250px)
	# All buttons visible, 48dp
```

#### Specific Implementation Details

**Mobile Layout**:
```gdscript
# Steps list: Hidden, replaced by:
#   - Top-left hamburger button → bottom sheet with all 14 steps
#   - Top-center: "Step X of 14: [Name]" label
# Results log: Hidden, replaced by:
#   - Top-right "Results" button → modal dialog showing full log
# Current step content: Full screen with vertical scrolling
# Buttons: Bottom navigation bar with Back/Next/Roll (stacked if >3 buttons)
```

**Tablet Layout**:
```gdscript
# Two-column: Steps sidebar (200px) + current step
# Results: Slide-in panel from right (triggered by button)
# Buttons: Bottom bar, side-by-side
```

**Desktop Layout**:
```gdscript
# Keep current three-column layout
# Ensure buttons meet 48dp minimum
```

#### Estimated Effort
- **Refactor to FiveParsecsCampaignPanel**: 1.5 hours
- **Implement mobile layout** (bottom sheet + modal): 3 hours
- **Implement tablet layout** (slide-in panel): 2 hours
- **Implement desktop layout**: 0.5 hours
- **Testing & refinement**: 1.5 hours
- **Total**: **8.5 hours**

---

## Shared Implementation Patterns

### Pattern 1: Conditional Panel Visibility

All four screens need to hide/show panels based on layout mode. Standardize this pattern:

```gdscript
func _apply_responsive_visibility() -> void:
	# Mobile: Hide secondary panels
	if is_mobile_layout():
		patrol_list.visible = false
		rival_list.visible = false
		battle_history_panel.visible = false
	# Tablet: Show mini panels
	elif is_tablet_layout():
		patrol_list.visible = true
		patrol_list.max_items = 3  # Mini-list
		rival_list.visible = true
		battle_history_panel.visible = true
		battle_history_panel.max_items = 5
	# Desktop: Show all
	else:
		patrol_list.visible = true
		rival_list.visible = true
		battle_history_panel.visible = true
```

### Pattern 2: Button Sizing

All screens have buttons below 48dp minimum. Standardize:

```gdscript
func _apply_responsive_button_sizing() -> void:
	var target_height = get_responsive_touch_target()  # 56dp mobile, 48dp tablet/desktop

	for button in [back_button, next_button, action_button, roll_button]:
		button.custom_minimum_size.y = target_height

		# Mobile: Full width buttons
		if is_mobile_layout():
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Tablet/Desktop: Auto width
		else:
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
```

### Pattern 3: Layout Switching

All screens need to switch between single-column (mobile) and multi-column (tablet/desktop):

```gdscript
func _apply_responsive_column_layout(container: HBoxContainer, content_nodes: Array) -> void:
	# Mobile: Stack vertically
	if should_use_single_column():
		# Replace HBoxContainer with VBoxContainer
		var vbox = VBoxContainer.new()
		for node in content_nodes:
			node.reparent(vbox)
		container.replace_by(vbox)
	# Tablet/Desktop: Side-by-side
	else:
		# Restore HBoxContainer if needed
		pass
```

---

## Implementation Roadmap

### Phase 1: Foundation (4 hours)
**Goal**: Get all screens extending FiveParsecsCampaignPanel with basic responsive detection

1. CampaignDashboard: Refactor base class (2 hours)
2. WorldPhaseController: Refactor base class (1 hour)
3. TravelPhaseUI: Create script + refactor (1 hour)
4. PostBattleSequence: Refactor base class (1.5 hours)

**Validation**: All screens detect breakpoints and log layout mode changes

### Phase 2: Mobile Layouts (10 hours)
**Goal**: Optimize for mobile portrait (<480px) with 56dp touch targets

1. CampaignDashboard mobile layout (3 hours)
   - Single column crew list
   - Hide battle history/patron/rival lists
   - Compact resource display
   - Full-width 56dp buttons
2. WorldPhaseController mobile layout (2 hours)
   - Auto-hide header on scroll
   - 56dp navigation buttons
   - Large automation toggle
3. TravelPhaseUI mobile layout (2 hours)
   - Full-screen panel
   - LogBook as modal
   - Tab navigation via buttons
4. PostBattleSequence mobile layout (3 hours)
   - Steps list as bottom sheet
   - Results as modal
   - Full-screen content

**Validation**: Test on 360×640 viewport (standard mobile), all touch targets ≥56dp

### Phase 3: Tablet Layouts (6 hours)
**Goal**: Optimize for tablet (480-768px) with 48dp touch targets

1. CampaignDashboard tablet layout (2 hours)
   - Two-column layout
   - Mini patron/rival lists
   - Collapsed battle history
2. WorldPhaseController tablet layout (1 hour)
   - Standard header
   - Side-by-side buttons
3. TravelPhaseUI tablet layout (1 hour)
   - Centered panel
   - Visible LogBook
4. PostBattleSequence tablet layout (2 hours)
   - Two-column layout
   - Slide-in results panel

**Validation**: Test on 768×1024 viewport (iPad), all touch targets ≥48dp

### Phase 4: Desktop Layouts (4 hours)
**Goal**: Optimize for desktop (>1024px) with full data visibility

1. CampaignDashboard desktop layout (1 hour)
   - Two/three-column layout
   - Full lists visible
2. WorldPhaseController desktop layout (2 hours)
   - Optional sidebar navigation
   - Full header
3. TravelPhaseUI desktop layout (0.5 hours)
   - Larger centered panel
4. PostBattleSequence desktop layout (0.5 hours)
   - Three-column layout

**Validation**: Test on 1920×1080 viewport, ensure no wasted space

### Phase 5: Testing & Refinement (4 hours)
1. Cross-screen navigation testing (1 hour)
2. Viewport resize stress testing (1 hour)
3. Touch target validation (1 hour)
4. Visual consistency audit (1 hour)

---

## Total Effort Summary

| Screen | Refactor | Mobile | Tablet | Desktop | Testing | Total |
|--------|---------|--------|--------|---------|---------|-------|
| CampaignDashboard | 2h | 3h | 2h | 1h | 1h | **9h** |
| WorldPhaseController | 1h | 2h | 1h | 2h | 1h | **7h** |
| TravelPhaseUI | 2h | 2h | 1h | 0.5h | 1h | **6.5h** |
| PostBattleSequence | 1.5h | 3h | 2h | 0.5h | 1.5h | **8.5h** |
| **Total** | **6.5h** | **10h** | **6h** | **4h** | **4.5h** | **31h** |

**Revised Total**: ~31 hours (including testing/refinement)

**Risk Buffer**: Add 20% for unforeseen issues = **+6.2 hours**

**Final Estimate**: **37 hours** (~5 working days)

---

## Code Snippet: CampaignDashboard Responsive Layout

Here's how CampaignDashboard would implement responsive layouts:

```gdscript
# CampaignDashboard.gd
extends FiveParsecsCampaignPanel  # Changed from Control
class_name FPCM_CampaignDashboardUI

# ... existing code ...

func _ready() -> void:
	super._ready()  # Call parent to setup responsive system

	# ... existing initialization ...

# ============ RESPONSIVE LAYOUT IMPLEMENTATION ============

func _apply_mobile_layout() -> void:
	"""Mobile portrait layout: Single column, essential data only"""
	print("CampaignDashboard: Applying mobile layout (<480px)")

	# === HEADER ===
	# Show only credits and story points (hide patrons/rivals/rumors/events)
	patrons_label.visible = false
	rivals_label.visible = false
	rumors_label.visible = false
	pending_events_label.visible = false

	# === MAIN CONTENT ===
	# Force single column layout
	var main_content = %MainContent
	if main_content is ResponsiveContainer:
		main_content.force_vertical = true

	# Crew list: Single column, compact cards
	crew_list.columns = 1
	for character_box in crew_list.get_children():
		if character_box.has_method("set_size_mode"):
			character_box.set_size_mode("compact")

	# Ship info: Compact display (hull + fuel only, hide debt unless critical)
	_update_ship_info_compact()

	# Battle history: Hide list, show summary label only
	if battle_history_list:
		battle_history_list.visible = false
		resume_battle_button.visible = false
		current_battle_status.text = _get_battle_summary_compact()

	# Victory progress: Collapsed (progress bar only)
	if victory_progress_panel and victory_progress_panel.has_method("set_compact_mode"):
		victory_progress_panel.set_compact_mode(true)

	# Patrons/Rivals: Hide lists, show count badges
	patron_list.visible = false
	rival_list.visible = false
	_add_patron_rival_badges()  # Add "2 Patrons, 1 Rival" badges

	# === BUTTONS ===
	# Stack vertically, full width, 56dp height
	var button_container = %ButtonContainer
	if button_container is HBoxContainer:
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", SPACING_SM)
		for button in button_container.get_children():
			button.custom_minimum_size.y = TOUCH_TARGET_COMFORT  # 56dp
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.reparent(vbox)
		button_container.replace_by(vbox)

func _apply_tablet_layout() -> void:
	"""Tablet layout: Two columns, partial data visibility"""
	print("CampaignDashboard: Applying tablet layout (480-768px)")

	# === HEADER ===
	# Show all labels in two rows
	patrons_label.visible = true
	rivals_label.visible = true
	rumors_label.visible = true
	pending_events_label.visible = true

	# === MAIN CONTENT ===
	# Two-column layout
	var main_content = %MainContent
	if main_content is ResponsiveContainer:
		main_content.force_vertical = false

	# Crew list: Two columns
	crew_list.columns = 2
	for character_box in crew_list.get_children():
		if character_box.has_method("set_size_mode"):
			character_box.set_size_mode("standard")

	# Ship info: Full stats
	_update_ship_info_full()

	# Battle history: Show last 5 battles
	if battle_history_list:
		battle_history_list.visible = true
		battle_history_list.max_items = 5

	# Victory progress: Mini-panel (progress + current condition)
	if victory_progress_panel and victory_progress_panel.has_method("set_compact_mode"):
		victory_progress_panel.set_compact_mode(false)
		victory_progress_panel.max_conditions_visible = 1

	# Patrons/Rivals: Mini-lists (3 max)
	patron_list.visible = true
	patron_list.max_items = 3
	rival_list.visible = true
	rival_list.max_items = 3

	# === BUTTONS ===
	# Side-by-side, half width, 48dp height
	var button_container = %ButtonContainer
	if button_container is VBoxContainer:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", SPACING_SM)
		for button in button_container.get_children():
			button.custom_minimum_size.y = TOUCH_TARGET_MIN  # 48dp
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.reparent(hbox)
		button_container.replace_by(hbox)

func _apply_desktop_layout() -> void:
	"""Desktop layout: Multi-column, full data visibility"""
	print("CampaignDashboard: Applying desktop layout (>1024px)")

	# === HEADER ===
	# All labels visible (same as tablet)

	# === MAIN CONTENT ===
	# Two-column layout (or three-column if viewport >1400px)
	var viewport_width = get_viewport().get_visible_rect().size.x
	var use_three_columns = viewport_width > 1400

	if use_three_columns:
		# Left: Crew, Middle: Ship + Battle History, Right: World + Victory + Patrons/Rivals
		_apply_three_column_layout()
	else:
		# Left: Crew + Ship + Battle History, Right: World + Victory + Patrons/Rivals
		_apply_two_column_layout()

	# Crew list: 2-3 columns based on crew count
	var crew_count = crew_list.get_child_count()
	crew_list.columns = 3 if crew_count > 6 else 2

	# Ship info: Full info + debt warning
	_update_ship_info_full()

	# Battle history: Full list (10 max)
	if battle_history_list:
		battle_history_list.visible = true
		battle_history_list.max_items = 10

	# Victory progress: Full panel
	if victory_progress_panel and victory_progress_panel.has_method("set_compact_mode"):
		victory_progress_panel.set_compact_mode(false)
		victory_progress_panel.max_conditions_visible = -1  # All

	# Patrons/Rivals: Full lists
	patron_list.visible = true
	patron_list.max_items = -1  # All
	rival_list.visible = true
	rival_list.max_items = -1

	# === BUTTONS ===
	# Auto width, 48dp height
	var button_container = %ButtonContainer
	for button in button_container.get_children():
		button.custom_minimum_size.y = TOUCH_TARGET_MIN
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

# === HELPER METHODS ===

func _update_ship_info_compact() -> void:
	"""Update ship info for mobile (hull + fuel only)"""
	if not ship_info:
		return
	var ship = GameStateManager.get_player_ship()
	if not ship:
		return
	var hull = ship.get("hull_integrity", 100)
	var fuel = ship.get("fuel", 100)
	ship_info.text = "🛡️ %d%% | ⛽ %d%%" % [hull, fuel]

func _update_ship_info_full() -> void:
	"""Update ship info for tablet/desktop (full details)"""
	# ... existing _update_ship_info logic ...

func _get_battle_summary_compact() -> String:
	"""Get compact battle summary for mobile"""
	if battle_history.is_empty():
		return "No battles yet"
	var last_battle = battle_history[battle_history.size() - 1]
	var result = "✅" if last_battle.get("victory", false) else "❌"
	return "Last battle: %s" % result

func _add_patron_rival_badges() -> void:
	"""Add compact patron/rival count badges for mobile"""
	var patrons = GameStateManager.get_patrons()
	var rivals = GameStateManager.get_rivals()
	# Add badges to header (implementation depends on scene structure)

func _apply_two_column_layout() -> void:
	"""Apply two-column desktop layout"""
	# ... implementation ...

func _apply_three_column_layout() -> void:
	"""Apply three-column desktop layout"""
	# ... implementation ...
```

---

## Next Steps

1. **Prioritize CampaignDashboard** (highest impact, most visible screen)
2. **Implement Phase 1** (foundation refactoring) for all 4 screens
3. **Test Phase 1** before proceeding to mobile layouts
4. **Iterate Phase 2-4** screen-by-screen with continuous testing
5. **Final validation** across all breakpoints

---

## Conclusion

All four campaign turn phase screens require responsive design refactoring to match the campaign wizard panels. The primary challenge is adapting complex multi-column layouts (especially CampaignDashboard and PostBattleSequence) to single-column mobile displays without losing critical information.

**Key Success Metrics**:
- All touch targets ≥56dp on mobile, ≥48dp on tablet/desktop
- Essential campaign data visible on mobile without scrolling
- Smooth transitions between breakpoints
- Consistent use of design system (colors, spacing, typography)
- No layout breaking on viewport resize

**Total effort**: ~37 hours (~5 working days) with 20% risk buffer included.
