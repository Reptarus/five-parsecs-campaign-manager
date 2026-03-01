# Five Parsecs Campaign Manager - UI/UX Component Guide

## 📐 Introduction

This guide catalogs all UI components, screens, and user experience patterns in the Five Parsecs Campaign Manager. It serves as a reference for developers, designers, and contributors working on the interface.

**Related Documentation**:
- [UI Overview](ui_overview.md) - High-level design philosophy
- [Accessibility Automation](accessibility_automation.md) - A11y implementation
- [Architecture Guide](../technical/ARCHITECTURE.md) - UI system architecture

---

## 🖥️ Screen Catalog

### Main Menu (`MainMenu.tscn`)

**Location**: `src/ui/screens/mainmenu/MainMenu.tscn`
**Purpose**: Entry point, campaign selection, settings access

**Components**:
- Title logo and version info
- New Campaign button
- Load Campaign button
- Settings button (graphics, audio, accessibility)
- Tutorial button
- Help/Documentation button
- Exit button

**UX Flow**:
1. User launches game → Main Menu appears
2. First-time users see Tutorial prompt
3. Returning players see "Continue" quick-action
4. All options keyboard-navigable (Tab cycling)

**Accessibility Features**:
- Large, high-contrast buttons
- Screen reader compatible
- Keyboard-only navigation
- Focus indicators clear

---

### Campaign Creation UI (`CampaignCreationUI.tscn`)

**Location**: `src/ui/screens/campaign/CampaignCreationUI.tscn`
**Purpose**: Guided campaign setup wizard

**Architecture**: Coordinator Pattern with self-managing panels

**Panels (in order)**:
1. **ConfigPanel** - Name, difficulty, victory condition
2. **CrewSizePanel** - Select 4-6 crew members
3. **CharacterCreationPanel** - Create each crew member
4. **ShipPanel** - Acquire/name ship
5. **StartingSituationPanel** - World, patrons, rivals
6. **SummaryPanel** - Review before launch

**Navigation**:
- Next/Previous buttons
- Progress indicator shows current step
- Can go back to edit (within limits)
- Validation before advancing

**State Management**:
- `CampaignCreationStateManager` holds all data
- Auto-save draft every step
- Can resume interrupted creation

**Components Used**:
- Phase indicator (top bar)
- Panel container (center)
- Navigation bar (bottom)
- Validation feedback (inline and summary)

---

### Campaign Dashboard (`CampaignDashboard.tscn`)

**Location**: `src/ui/screens/campaign/CampaignDashboard.tscn`
**Purpose**: Campaign management hub between battles

**Layout (Three-Panel)**:

**Left Panel - Crew Roster**:
- Character portraits (clickable)
- HP bars
- Status icons (injured, leveled up, etc.)
- Quick equipment view

**Center Panel - Current Status**:
- Campaign name and turn number
- Phase indicator
- Current world info
- Available actions for current phase
- Event log
- Quick action buttons

**Right Panel - Resources & Info**:
- Credits, Story Points, Renown
- Ship status
- Active quests
- Known patrons/rivals
- Travel destinations

**Action Bar (Bottom)**:
- Phase-specific actions
- End Turn button
- Save/Load
- Settings

**UX Patterns**:
- Hover tooltips on all elements
- Click-through to detail screens
- Contextual help (?) icons
- Warning indicators for issues

---

### Character Creator (`CharacterCreationPanel.tscn`)

**Location**: `src/ui/screens/campaign/panels/CharacterCreationPanel.tscn`
**Purpose**: Individual character generation

**Two Modes**:

**Quick Creation**:
- Single "Generate Random" button
- Instant character creation
- Editable name and appearance
- Recommended for new players

**Manual Creation**:
- Step-by-step tables
- Roll buttons for each step
- Manual selection options
- Full customization

**Creation Steps** (Manual):
1. Species selection (roll or choose)
2. Background determination (table roll)
3. Motivation (table roll)
4. Class assignment (derived)
5. Stats generation (based on species/background)
6. Starting equipment (based on credits and background)
7. Name and appearance

**Components**:
- Dice roller widget
- Table result display
- Stat preview panel
- Equipment selector
- Portrait chooser

---

### Battle Screen (`TacticalBattleUI.tscn`)

**Location**: `src/ui/screens/battle/TacticalBattleUI.tscn`
**Purpose**: Tactical combat interface

**Layout (Four-Quadrant)**:

**Top-Left - Battlefield View**:
- Isometric or top-down tactical map
- Character sprites with HP bars
- Movement range indicators
- LOS visualization
- Cover markers

**Top-Right - Unit Panel**:
- Selected character details
- Stats and equipment
- Available actions
- Action point display

**Bottom-Left - Combat Log**:
- Scrolling text log
- Dice roll results
- Hit/miss notifications
- Damage dealt
- Special events

**Bottom-Right - Controls**:
- Action buttons (Move, Shoot, Brawl, Item)
- End turn button
- Withdraw button
- Camera controls

**Battle Flow**:
1. Initiative rolled → activation order shown
2. Character activated → controls enabled
3. Player takes actions → results shown in log
4. Turn ends → next character activates
5. Round completes → check victory

**Visual Feedback**:
- Active character highlighted (green)
- Enemy turn indicators (red pulse)
- Damage numbers float above targets
- Hit/miss visual effects
- Cover indicators (shield icons)

---

### Crew Management (`CrewManagementUI.tscn`)

**Location**: `src/ui/screens/crew/CrewManagementUI.tscn`
**Purpose**: Detailed crew overview and management

**Tabs**:
1. **Roster** - All crew members listed
2. **Equipment** - Inventory and loadouts
3. **Advancement** - XP, levels, abilities
4. **Relationships** - Inter-crew dynamics (future)

**Roster Tab**:
- Character cards with full stats
- Health and injury status
- XP progress bars
- Equipment summary
- "View Details" button per character

**Equipment Tab**:
- Drag-and-drop equipment assignment
- Crew member slots on left
- Available equipment pool on right
- Weapon/armor/gear categories
- Quick-equip presets

**Advancement Tab**:
- Level-up pending indicators
- Ability selection interface
- Stat increase choices
- Training available
- Achievement tracking

---

## 🧩 Reusable Components

### CharacterBox.tscn

**Purpose**: Compact character display card

**Shows**:
- Portrait
- Name
- HP bar
- Primary weapon icon
- Status icons (injured, stunned, etc.)

**Used In**:
- Campaign Dashboard roster
- Battle UI character list
- Crew Management screens
- Mission briefing

**Variants**:
- Small (64x96px) - for lists
- Medium (128x192px) - for rosters
- Large (256x384px) - for detail views

### ResourceDisplayItem.tscn

**Purpose**: Shows resource amount with icon

**Displays**:
- Icon (credits, story points, renown, etc.)
- Numeric value
- +/- change indicator
- Tooltip with details

**Used In**:
- Campaign Dashboard
- Post-battle results
- Shop screens
- Mission rewards

### ActionButton.tscn

**Purpose**: Standardized action button

**Features**:
- Icon + text label
- Hover state
- Disabled state
- Keyboard shortcut display
- Sound feedback

**Variants**:
- Primary (green) - main actions
- Secondary (blue) - alternative actions
- Danger (red) - risky/destructive actions
- Disabled (gray) - unavailable

### PhaseIndicator.tscn

**Purpose**: Shows current campaign phase

**Display**:
- Phase icons (Travel, World, Battle, Post-Battle)
- Current phase highlighted
- Completed phases checked
- Upcoming phases grayed

**Interaction**:
- Click to see phase details
- Hover for phase description
- Visual progress through turn

### DiceDashboard.tscn

**Purpose**: Visual dice rolling interface

**Features**:
- 3D dice animation (optional)
- Result display
- Roll history
- Context (what's being rolled for)
- Modifier breakdown

**Used In**:
- Character creation
- Combat resolution
- Random events
- Table lookups

### EventLog.tscn

**Purpose**: Scrolling event notification feed

**Displays**:
- Campaign events
- Character events
- System messages
- Combat log (in battle)

**Features**:
- Auto-scroll
- Timestamp
- Event categories (color-coded)
- Filtering options
- Export/save log

---

## 🎨 Visual Design System

### Color Palette

**Primary Colors**:
- Main: `#2C3E50` (dark blue-gray)
- Accent: `#E74C3C` (red-orange)
- Success: `#27AE60` (green)
- Warning: `#F39C12` (orange)
- Danger: `#C0392B` (dark red)
- Info: `#3498DB` (blue)

**UI Colors**:
- Background: `#1C1C1E` (near-black)
- Panel: `#2C2C2E` (dark gray)
- Border: `#3A3A3C` (medium gray)
- Text: `#FFFFFF` (white)
- Text Secondary: `#AEAEB2` (light gray)

**Semantic Colors**:
- HP Full: `#27AE60` (green)
- HP Damaged: `#F39C12` (orange)
- HP Critical: `#E74C3C` (red)
- XP: `#9B59B6` (purple)
- Credits: `#F1C40F` (gold)
- Story Points: `#3498DB` (blue)

### Typography

**Font Family**: 'JetBrains Mono' (monospace) for retro sci-fi aesthetic

**Font Sizes**:
- Heading 1: 32px
- Heading 2: 24px
- Heading 3: 18px
- Body: 14px
- Small: 12px
- Tiny: 10px

**Font Weights**:
- Bold: 700 (headings, emphasis)
- Regular: 400 (body text)
- Light: 300 (secondary text)

### Spacing System

**Base Unit**: 8px

**Spacing Scale**:
- xs: 4px (0.5× base)
- sm: 8px (1× base)
- md: 16px (2× base)
- lg: 24px (3× base)
- xl: 32px (4× base)
- xxl: 48px (6× base)

**Usage**:
- Component padding: `md` (16px)
- Section margins: `lg` (24px)
- Screen margins: `xl` (32px)
- Element spacing: `sm` (8px)

### Icons

**Icon Set**: Custom pixel art + Font Awesome for common icons

**Sizes**:
- Small: 16x16px
- Medium: 32x32px
- Large: 64x64px

**Categories**:
- Actions (move, shoot, brawl)
- Resources (credits, story points)
- Status (injured, stunned, down)
- Equipment (weapons, armor, gear)
- Navigation (next, previous, close)

---

## 📱 Responsive Design

### Breakpoints

- **Small**: < 1280px (minimum supported)
- **Medium**: 1280-1920px (standard)
- **Large**: > 1920px (4K displays)

### Adaptive Layouts

**Small Screens** (1280x720):
- Single-column layouts
- Collapsible side panels
- Tabbed navigation
- Reduced spacing

**Medium Screens** (1920x1080):
- Standard two/three-column layouts
- Full side panels visible
- Default spacing

**Large Screens** (2560x1440+):
- Wider content areas
- Additional info panels
- Increased spacing
- Larger fonts (optional setting)

---

## ♿ Accessibility Features

### Keyboard Navigation

**Global Shortcuts**:
- `Tab` - Cycle focus forward
- `Shift+Tab` - Cycle focus backward
- `Enter`/`Space` - Activate focused element
- `Escape` - Cancel/Go back
- `F1` - Help
- `F5` - Quick save
- `F6` - Cycle UI sections

**Focus Indicators**:
- Visible 2px outline
- Color: Accent color (`#E74C3C`)
- Clear contrast against background

### Screen Reader Support

**ARIA Labels** on all interactive elements:
- Buttons describe action
- Form fields have labels
- Status messages announced
- Dynamic content updates announced

**Semantic HTML/UI Structure**:
- Headings hierarchy preserved
- Lists for navigation
- Regions defined (header, main, aside)

### Visual Accessibility

**High Contrast Mode**:
- Toggle in settings
- Increased contrast ratios (7:1 minimum)
- Thicker borders
- No reliance on color alone

**Colorblind Modes**:
- Protanopia
- Deuteranopia
- Tritanopia
- Different icon shapes, not just colors

**Text Scaling**:
- 50% to 200% of base size
- Layouts adapt automatically
- No content cut off

**Reduced Motion**:
- Disable animations
- Instant transitions
- Static UI elements

---

## 🖱️ Interaction Patterns

### Drag and Drop

**Equipment Assignment**:
- Drag equipment from pool to character
- Visual feedback (ghost image follows cursor)
- Drop zones highlight when valid
- Snap to slot when released
- Cancel with `Escape`

**Restrictions**:
- Only compatible equipment can be dropped
- Occupied slots show swap preview
- Invalid drops show red X

### Context Menus

**Right-Click Menus** on:
- Character portraits (view details, assign equipment, dismiss)
- Equipment items (equip, sell, details)
- Mission listings (accept, details, decline)

**Menu Structure**:
- Most common action at top
- Destructive actions at bottom (with confirmation)
- Keyboard shortcuts shown

### Tooltips

**Hover Tooltips**:
- Delay: 500ms
- Position: Near cursor, avoiding edges
- Content: Name, description, stats
- Keyboard access: Focus + `?` key

**Complex Tooltips**:
- Rich formatting (headers, lists)
- Comparison stats (for equipment)
- Calculations shown (dice rolls, modifiers)

### Modal Dialogs

**Usage**:
- Critical confirmations (delete save, dismiss crew)
- Complex forms (character creation)
- Help screens
- Settings

**Behavior**:
- Dim background
- Focus trapped in modal
- `Escape` closes (if safe)
- Keyboard navigation within

---

## 🎮 UI State Management

### Loading States

**Indicators**:
- Spinner for short operations (< 3 seconds)
- Progress bar for longer operations
- Skeleton screens for content loading
- "Loading..." text with context

**User Feedback**:
- Disable interactable elements during load
- Show cancel button if applicable
- Estimate time remaining (if known)

### Error States

**Display**:
- Error icon (red triangle with !)
- Clear error message (user-friendly language)
- Suggested actions (retry, cancel, contact support)
- Technical details (collapsible)

**Examples**:
- Save failed: "Could not save campaign. Check disk space."
- Load failed: "Save file corrupted. Try loading backup."
- Network error: "Cannot connect to server. Check connection."

### Empty States

**When No Data**:
- Helpful illustration or icon
- Explanatory text
- Primary action button (create, import, etc.)

**Examples**:
- No saves: "No campaigns found. Start a new campaign!"
- No equipment: "No items in inventory. Visit the market."
- No battles: "No missions available. Assign crew to find patrons."

---

## 🧪 Component Testing

### UI Testing Patterns

**Unit Tests** (for complex components):
```gdscript
func test_character_box_displays_correct_hp():
    var character = create_test_character()
    character.current_hp = 3
    var box = CharacterBox.instantiate()
    box.set_character(character)
    assert_eq(box.get_hp_display(), "3/3")
```

**Integration Tests** (for screens):
```gdscript
func test_campaign_dashboard_loads():
    var campaign = create_test_campaign()
    var dashboard = CampaignDashboard.instantiate()
    dashboard.load_campaign(campaign)
    assert_not_null(dashboard.get_crew_roster())
```

### Accessibility Testing

**Automated Checks**:
- All buttons have accessible labels
- Focus order is logical
- Color contrast meets WCAG AA
- No reliance on color alone

**Manual Testing**:
- Keyboard-only navigation
- Screen reader compatibility (NVDA, JAWS)
- High contrast mode usability
- Text scaling (50%, 100%, 200%)

---

## 📐 UI Development Guidelines

### Creating New Components

**Component Template**:
```gdscript
extends Control
class_name MyComponent

## Component purpose and usage
## 
## Example:
## var component = MyComponent.new()
## component.set_data(my_data)

signal data_changed(new_data: Variant)

@export var label_text: String = "":
    set(value):
        label_text = value
        if label:
            label.text = value

@onload var label: Label

func _ready() -> void:
    _setup_ui()
    _connect_signals()

func _setup_ui() -> void:
    # Initialize UI elements
    pass

func _connect_signals() -> void:
    # Connect internal signals
    pass

func set_data(data: Variant) -> void:
    # Update component with new data
    emit_signal("data_changed", data)
```

**Best Practices**:
- Single responsibility
- Emit signals for data changes
- Accept data via `set_data()` method
- Self-contained (no external dependencies)
- Documented with comments
- Accessible by default

### Theme Customization

**Using Theme**:
```gdscript
# Access theme colors
var primary_color = get_theme_color("primary", "Button")

# Apply theme font
var heading_font = get_theme_font("heading", "Label")
label.add_theme_font_override("font", heading_font)

# Use theme spacing
var margin = get_theme_constant("margin", "Container")
```

**Custom Theme Values**:
Defined in `res://assets/ui/theme.tres`

---

*Last Updated: January 2025*  
*UI Component Count: 45+*  
*Screen Count: 12*