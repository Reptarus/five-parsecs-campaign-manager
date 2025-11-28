# UI/UX Equipment & Inventory Design - Mobile-First Tabletop Companion

**Document Version**: 1.0
**Created**: 2025-11-27
**Design Philosophy**: Enhance physical tabletop gameplay, not replace it

---

## EXECUTIVE SUMMARY

This document addresses critical UI/UX gaps identified in the Five Parsecs Campaign Manager, focusing on **equipment visibility**, **ship debt management**, **phase transitions**, and **mobile-first interaction patterns**.

**Key Deliverables**:
1. Unified Inventory System (stash visibility across phases)
2. Ship Debt UI Integration (upkeep panel enhancement)
3. Equipment Assignment UX Patterns (mobile-friendly drag-less design)
4. Phase Transition Feedback System (loading states, data summaries)
5. Information Architecture (progressive disclosure, thumb zones)

---

## PART 1: INVENTORY VISIBILITY SYSTEM

### Problem Statement
**Current State**: Equipment generated during campaign creation is invisible to players. No unified stash view exists across World Phase, Pre-Battle, or Dashboard.

**Impact**: Players don't know what equipment they own, breaking core gameplay loop.

### Solution: Unified Equipment Drawer Component

**Design Pattern**: Persistent bottom drawer (mobile) / sidebar (desktop) accessible from Dashboard, World Phase, and Pre-Battle screens.

---

### 1.1 Mobile Layout (Portrait <480px)

```
┌─────────────────────────────────────┐
│ [Campaign Dashboard Header]         │ Top 20% - Display Only
├─────────────────────────────────────┤
│                                     │
│ [Main Content Area]                 │ Middle 40% - Scrollable
│ - Crew roster                       │
│ - Ship status                       │
│ - Victory progress                  │
│                                     │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │ Bottom 40% - Thumb Zone
│ │ [Equipment Drawer Handle]        │ │
│ │ "📦 Stash: 8/10 items" [↑]       │ │ <- 56dp touch target
│ └─────────────────────────────────┘ │
│ [Crew] [Ship] [World] [Battle]      │ <- Tab navigation (56dp each)
└─────────────────────────────────────┘
```

**Interaction Model**:
- **Level 1 (Always Visible)**: Collapsed drawer handle showing item count
- **Level 2 (One Tap)**: Drawer slides up 60% viewport, shows equipment list
- **Level 3 (Two Taps)**: Item detail view (stats, description, equipped status)

**Container Hierarchy**:
```gdscript
VBoxContainer (SIZE_EXPAND_FILL)
├── MarginContainer (SPACING_XL = 32px padding)
│   └── VBoxContainer (main content)
│       ├── [Dashboard content...]
│       └── EquipmentDrawer (custom Control)
│           ├── DrawerHandle (Button - 56dp height)
│           │   ├── HBoxContainer
│           │   │   ├── TextureRect (📦 icon - 24×24dp)
│           │   │   ├── Label ("Stash: 8/10")
│           │   │   └── TextureRect (↑ chevron - 16×16dp)
│           └── DrawerContent (PanelContainer - slides from bottom)
│               └── ScrollContainer
│                   └── VBoxContainer
│                       └── [Equipment items...]
```

---

### 1.2 Equipment Item Card (Mobile)

```
┌─────────────────────────────────────────────┐
│ ┌──┐ Infantry Laser              ⚡ EQUIPPED │ 48dp height
│ │🔫│ Military Weapon • 2 damage               │
│ └──┘ [Assign] [Details]                      │
└─────────────────────────────────────────────┘
```

**Design System Application**:
- **Background**: `COLOR_ELEVATED` (#252542)
- **Border**: `COLOR_BORDER` (#3A3A5C) - 1px
- **Icon**: 32×32dp placeholder
- **Title**: `FONT_SIZE_MD` (16px) - `COLOR_TEXT_PRIMARY`
- **Subtitle**: `FONT_SIZE_SM` (14px) - `COLOR_TEXT_SECONDARY`
- **Status Badge**: "EQUIPPED" uses `COLOR_ACCENT` (#2D5A7B)

**State Indicators**:
- **In Stash**: Gray border, no badge
- **Equipped**: Cyan accent border (#4FC3F7), "EQUIPPED" badge
- **Damaged**: Red border (#DC2626), "DAMAGED" badge

**Touch Targets**:
- **[Assign] Button**: 48dp × 44dp minimum
- **[Details] Button**: 48dp × 44dp minimum
- **Card Tap**: Entire card is 48dp height tappable area

---

### 1.3 Desktop Layout (>1024px)

```
┌──────────────────────────────────────────────────────────┐
│ Campaign Dashboard                                        │
├─────────────────────┬────────────────────────────────────┤
│ [Main Content]      │ ┌──────────────────────────────┐   │
│                     │ │ SHIP STASH (8/10)            │   │
│ - Victory Progress  │ ├──────────────────────────────┤   │
│ - Crew Roster       │ │ 🔫 Infantry Laser            │   │
│ - Ship Status       │ │    Military • Equipped       │   │
│                     │ ├──────────────────────────────┤   │
│                     │ │ 🔫 Auto Rifle                │   │
│                     │ │    Military • Available      │   │
│                     │ ├──────────────────────────────┤   │
│                     │ │ 🛡️ Frag Vest                 │   │
│                     │ │    Armor • Available         │   │
│                     │ └──────────────────────────────┘   │
│                     │ [Filter: All ▼] [Sort: Name ▼]    │
├─────────────────────┴────────────────────────────────────┤
│ [Dashboard Tabs]                                          │
└──────────────────────────────────────────────────────────┘
```

**Responsive Behavior**:
- **480-768px (Tablet)**: Drawer expands to 40% width sidebar (left edge)
- **>1024px (Desktop)**: Persistent 300px fixed sidebar (right edge)
- **Filters/Sort**: Desktop-only features (hidden on mobile)

---

### 1.4 Equipment Drawer Component Implementation

**File**: `/src/ui/components/inventory/EquipmentDrawer.gd`

```gdscript
class_name EquipmentDrawer
extends Control

# Design system constants (inherited from BaseCampaignPanel)
const DRAWER_COLLAPSED_HEIGHT := 56  # Touch target minimum
const DRAWER_EXPANDED_HEIGHT_MOBILE := 0.6  # 60% of viewport
const DRAWER_SIDEBAR_WIDTH_DESKTOP := 300  # Fixed width

# State
enum DrawerState { COLLAPSED, EXPANDED }
var current_state: DrawerState = DrawerState.COLLAPSED

# Responsive layout
var layout_mode: LayoutMode = LayoutMode.MOBILE

# Nodes
@onready var drawer_handle: Button = %DrawerHandle
@onready var drawer_content: PanelContainer = %DrawerContent
@onready var equipment_list: VBoxContainer = %EquipmentList
@onready var capacity_label: Label = %CapacityLabel

# Data
var equipment_items: Array[Dictionary] = []
var max_capacity: int = 10

signal equipment_selected(equipment: Dictionary)
signal equipment_assigned_requested(equipment: Dictionary)

func _ready() -> void:
    _setup_responsive_layout()
    _connect_signals()
    _update_display()

func _setup_responsive_layout() -> void:
    var viewport_width := get_viewport().get_visible_rect().size.x

    if viewport_width < 480:
        layout_mode = LayoutMode.MOBILE
        _apply_mobile_layout()
    elif viewport_width < 1024:
        layout_mode = LayoutMode.TABLET
        _apply_tablet_layout()
    else:
        layout_mode = LayoutMode.DESKTOP
        _apply_desktop_layout()

func _apply_mobile_layout() -> void:
    # Bottom drawer - collapsed by default
    drawer_content.position = Vector2(0, get_viewport_rect().size.y - DRAWER_COLLAPSED_HEIGHT)
    drawer_content.size = Vector2(get_viewport_rect().size.x, DRAWER_COLLAPSED_HEIGHT)

func _apply_desktop_layout() -> void:
    # Right sidebar - always visible
    current_state = DrawerState.EXPANDED
    drawer_handle.hide()  # No handle needed on desktop
    drawer_content.position = Vector2(get_viewport_rect().size.x - DRAWER_SIDEBAR_WIDTH_DESKTOP, 0)
    drawer_content.size = Vector2(DRAWER_SIDEBAR_WIDTH_DESKTOP, get_viewport_rect().size.y)

func toggle_drawer() -> void:
    if layout_mode == LayoutMode.DESKTOP:
        return  # Always expanded on desktop

    if current_state == DrawerState.COLLAPSED:
        _expand_drawer()
    else:
        _collapse_drawer()

func _expand_drawer() -> void:
    var target_height := get_viewport_rect().size.y * DRAWER_EXPANDED_HEIGHT_MOBILE
    var tween := create_tween()
    tween.tween_property(drawer_content, "size:y", target_height, 0.3).set_ease(Tween.EASE_OUT)
    current_state = DrawerState.EXPANDED

func _collapse_drawer() -> void:
    var tween := create_tween()
    tween.tween_property(drawer_content, "size:y", DRAWER_COLLAPSED_HEIGHT, 0.3).set_ease(Tween.EASE_IN)
    current_state = DrawerState.COLLAPSED

func update_equipment_list(items: Array[Dictionary]) -> void:
    equipment_items = items
    _populate_list()
    _update_capacity_display()

func _populate_list() -> void:
    # Clear existing items
    for child in equipment_list.get_children():
        child.queue_free()

    # Create equipment cards
    for item in equipment_items:
        var card := _create_equipment_card(item)
        equipment_list.add_child(card)

func _create_equipment_card(item: Dictionary) -> Control:
    # Use BaseCampaignPanel design system
    var card := PanelContainer.new()
    card.custom_minimum_size.y = 48  # TOUCH_TARGET_MIN

    # Apply styling
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#252542")  # COLOR_ELEVATED
    style.border_color = Color("#3A3A5C")  # COLOR_BORDER
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.set_content_margin_all(8)  # SPACING_SM
    card.add_theme_stylebox_override("panel", style)

    # Build content
    var hbox := HBoxContainer.new()

    # Icon
    var icon := TextureRect.new()
    icon.custom_minimum_size = Vector2(32, 32)
    icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    hbox.add_child(icon)

    # Info
    var vbox := VBoxContainer.new()
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var name_label := Label.new()
    name_label.text = item.get("name", "Unknown")
    name_label.add_theme_font_size_override("font_size", 16)  # FONT_SIZE_MD
    name_label.add_theme_color_override("font_color", Color("#E0E0E0"))  # COLOR_TEXT_PRIMARY
    vbox.add_child(name_label)

    var category_label := Label.new()
    category_label.text = item.get("category", "Gear")
    category_label.add_theme_font_size_override("font_size", 14)  # FONT_SIZE_SM
    category_label.add_theme_color_override("font_color", Color("#808080"))  # COLOR_TEXT_SECONDARY
    vbox.add_child(category_label)

    hbox.add_child(vbox)

    # Status badge
    if item.get("equipped_by", "") != "":
        var badge := Label.new()
        badge.text = "EQUIPPED"
        badge.add_theme_font_size_override("font_size", 11)  # FONT_SIZE_XS
        badge.add_theme_color_override("font_color", Color("#4FC3F7"))  # COLOR_FOCUS
        hbox.add_child(badge)

    card.add_child(hbox)

    # Connect signals
    card.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed:
            equipment_selected.emit(item)
    )

    return card

func _update_capacity_display() -> void:
    if capacity_label:
        capacity_label.text = "📦 Stash: %d/%d items" % [equipment_items.size(), max_capacity]

        # Color-code capacity
        if equipment_items.size() >= max_capacity:
            capacity_label.modulate = Color("#DC2626")  # COLOR_DANGER (full)
        elif equipment_items.size() >= max_capacity * 0.8:
            capacity_label.modulate = Color("#D97706")  # COLOR_WARNING (80%+)
        else:
            capacity_label.modulate = Color("#E0E0E0")  # COLOR_TEXT_PRIMARY
```

---

## PART 2: SHIP DEBT UI INTEGRATION

### Problem Statement
**Current State**: TravelPhaseUI has upkeep panel but no debt display, interest tracking, or payment interface.

**Impact**: Players can't manage ship debt (Core Rules p.121), critical economy mechanic invisible.

### Solution: Enhanced Upkeep Panel with Debt Management

---

### 2.1 Mobile Upkeep Panel Layout

```
┌─────────────────────────────────────────────────┐
│ UPKEEP PHASE                                    │
├─────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────┐ │
│ │ SHIP COSTS                                  │ │
│ │ ┌─────────────────────────────────────────┐ │ │
│ │ │ ⛽ Fuel Cost:           -4 credits       │ │ │ 48dp height
│ │ └─────────────────────────────────────────┘ │ │
│ │ ┌─────────────────────────────────────────┐ │ │
│ │ │ 🔧 Repairs:            -0 credits       │ │ │
│ │ └─────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ ┌─────────────────────────────────────────────┐ │
│ │ 💰 SHIP DEBT                                │ │
│ │ ┌─────────────────────────────────────────┐ │ │
│ │ │ Current Debt:      1,200 credits        │ │ │
│ │ │ Interest Rate:     10% per turn         │ │ │
│ │ │ Minimum Payment:   120 credits          │ │ │
│ │ └─────────────────────────────────────────┘ │ │
│ │                                             │ │
│ │ Payment Amount:                             │ │
│ │ ┌─────────────────────────────────────────┐ │ │
│ │ │ [────●──────────────] 120 cr            │ │ │ 56dp touch
│ │ └─────────────────────────────────────────┘ │ │
│ │                                             │ │
│ │ ┌───────┐ ┌───────┐ ┌────────┐            │ │
│ │ │ Min   │ │ Half  │ │ Full   │            │ │ 56dp buttons
│ │ │ (120) │ │ (600) │ │ (1200) │            │ │
│ │ └───────┘ └───────┘ └────────┘            │ │
│ │                                             │ │
│ │ [Confirm Payment (120 cr)]                 │ │ 56dp button
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ ⚠️ WARNING: Cannot pay minimum - ship at risk! │
│                                                 │
│ [Confirm Upkeep]                                │ 56dp button
└─────────────────────────────────────────────────┘
```

**Visual Hierarchy**:
1. **Critical Warning** (if can't pay): `COLOR_DANGER` (#DC2626) background
2. **Debt Amount**: Large `FONT_SIZE_XL` (24px) - `COLOR_TEXT_PRIMARY`
3. **Payment Controls**: Grouped in elevated card (`COLOR_ELEVATED`)
4. **Quick Buttons**: Horizontal button group (equal width, 56dp height)

**Interaction Flow**:
1. **Slider Drag** (primary): Continuous value selection (120 - 1200)
2. **Quick Buttons** (secondary): Tap for preset amounts (Min/Half/Full)
3. **Confirm Payment**: Bottom action (disabled if amount < minimum)

---

### 2.2 Debt Payment Component

**File**: `/src/ui/components/campaign/DebtPaymentPanel.gd`

```gdscript
class_name DebtPaymentPanel
extends PanelContainer

# Design system constants
const FONT_SIZE_XL := 24
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const COLOR_DANGER := Color("#DC2626")
const COLOR_WARNING := Color("#D97706")
const COLOR_SUCCESS := Color("#10B981")

# Debt data
var current_debt: int = 0
var interest_rate: float = 0.1  # 10%
var minimum_payment: int = 0
var available_credits: int = 0

# UI Nodes
@onready var debt_label: Label = %DebtLabel
@onready var interest_label: Label = %InterestLabel
@onready var minimum_label: Label = %MinimumLabel
@onready var payment_slider: HSlider = %PaymentSlider
@onready var payment_amount_label: Label = %PaymentAmountLabel
@onready var quick_min_button: Button = %QuickMinButton
@onready var quick_half_button: Button = %QuickHalfButton
@onready var quick_full_button: Button = %QuickFullButton
@onready var confirm_button: Button = %ConfirmPaymentButton
@onready var warning_label: Label = %WarningLabel

signal payment_confirmed(amount: int)

func _ready() -> void:
    _connect_signals()
    _update_display()

func _connect_signals() -> void:
    if payment_slider:
        payment_slider.value_changed.connect(_on_slider_changed)
    if quick_min_button:
        quick_min_button.pressed.connect(func(): _set_payment_amount(minimum_payment))
    if quick_half_button:
        quick_half_button.pressed.connect(func(): _set_payment_amount(current_debt / 2))
    if quick_full_button:
        quick_full_button.pressed.connect(func(): _set_payment_amount(current_debt))
    if confirm_button:
        confirm_button.pressed.connect(_on_confirm_pressed)

func initialize(debt: int, credits: int) -> void:
    current_debt = debt
    available_credits = credits
    minimum_payment = int(current_debt * interest_rate)

    if payment_slider:
        payment_slider.min_value = minimum_payment
        payment_slider.max_value = min(current_debt, available_credits)
        payment_slider.value = minimum_payment

    _update_display()

func _update_display() -> void:
    if debt_label:
        debt_label.text = "Current Debt: %d credits" % current_debt

    if interest_label:
        interest_label.text = "Interest Rate: %d%% per turn" % int(interest_rate * 100)

    if minimum_label:
        minimum_label.text = "Minimum Payment: %d credits" % minimum_payment

        # Color-code minimum payment affordability
        if available_credits < minimum_payment:
            minimum_label.modulate = COLOR_DANGER
        else:
            minimum_label.modulate = COLOR_SUCCESS

    # Update quick buttons
    if quick_min_button:
        quick_min_button.text = "Min (%d)" % minimum_payment
        quick_min_button.disabled = available_credits < minimum_payment

    if quick_half_button:
        var half_payment := current_debt / 2
        quick_half_button.text = "Half (%d)" % half_payment
        quick_half_button.disabled = available_credits < half_payment

    if quick_full_button:
        quick_full_button.text = "Full (%d)" % current_debt
        quick_full_button.disabled = available_credits < current_debt

    # Warning message
    if warning_label:
        if available_credits < minimum_payment:
            warning_label.text = "⚠️ WARNING: Cannot pay minimum - ship at risk!"
            warning_label.modulate = COLOR_DANGER
            warning_label.show()
        else:
            warning_label.hide()

    # Confirm button state
    if confirm_button:
        var current_value := int(payment_slider.value) if payment_slider else 0
        confirm_button.disabled = current_value < minimum_payment or current_value > available_credits
        confirm_button.text = "Confirm Payment (%d cr)" % current_value

func _on_slider_changed(value: float) -> void:
    if payment_amount_label:
        payment_amount_label.text = "%d cr" % int(value)
    _update_display()

func _set_payment_amount(amount: int) -> void:
    if payment_slider:
        payment_slider.value = clamp(amount, minimum_payment, min(current_debt, available_credits))

func _on_confirm_pressed() -> void:
    var amount := int(payment_slider.value) if payment_slider else 0
    if amount >= minimum_payment and amount <= available_credits:
        payment_confirmed.emit(amount)
        print("DebtPaymentPanel: Payment confirmed - %d credits" % amount)
```

---

## PART 3: EQUIPMENT ASSIGNMENT UX PATTERN

### Problem Statement
**Current State**: AssignEquipmentComponent exists but interaction model unclear. Needs mobile-friendly pattern (no drag-and-drop, thumb-accessible).

**Impact**: Players can't easily manage crew loadouts before battle.

### Solution: Two-Panel Transfer System (Drag-Less Design)

---

### 3.1 Mobile Equipment Assignment Layout

```
┌─────────────────────────────────────────────────┐
│ ASSIGN EQUIPMENT                                │
├─────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────┐ │
│ │ CREW MEMBER: Sarah Chen                     │ │ Selected crew
│ │ Current Load: 3/6 items                     │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ [Current Equipment ▼]                           │ Tab selector
│ ┌─────────────────────────────────────────────┐ │
│ │ ✓ Infantry Laser                   [Remove] │ │ 48dp item
│ │   Military Weapon • 2 damage                │ │
│ ├─────────────────────────────────────────────┤ │
│ │ ✓ Frag Vest                        [Remove] │ │
│ │   Armor • +1 Toughness                      │ │
│ ├─────────────────────────────────────────────┤ │
│ │ ✓ Med-patch                        [Remove] │ │
│ │   Consumable • Heal 1 wound                 │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ [Available in Stash ▼]                          │ Tab selector
│ ┌─────────────────────────────────────────────┐ │
│ │ Auto Rifle                         [Assign] │ │ 48dp item
│ │ Military Weapon • 3 damage                  │ │
│ ├─────────────────────────────────────────────┤ │
│ │ Boarding Saber                     [Assign] │ │
│ │ Melee • 2 damage                            │ │
│ ├─────────────────────────────────────────────┤ │
│ │ Battle Visor                       [Assign] │ │
│ │ Gadget • +1 Savvy                           │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ ┌─────────────────────────────────────────────┐ │
│ │ QUICK ACTIONS                               │ │
│ │ [Auto-Equip Best] [Clear All]               │ │ 56dp buttons
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ [Confirm Loadout]                               │ 56dp button
└─────────────────────────────────────────────────┘
```

**Interaction Model** (No Drag-and-Drop):
1. **Select Crew Member**: Dropdown at top (56dp touch target)
2. **View Equipment**: Tabs for "Current" vs "Available"
3. **Transfer Actions**:
   - **[Assign]** button: Moves item from stash → crew
   - **[Remove]** button: Moves item from crew → stash
4. **Quick Actions**:
   - **Auto-Equip Best**: AI selects optimal loadout
   - **Clear All**: Returns all equipment to stash

**Visual States**:
- **Current Equipment**: Green checkmark (✓), elevated background
- **Available Stash**: Gray, lower elevation
- **Over Capacity**: Red warning, [Assign] disabled
- **Empty Slots**: Dashed border placeholder

---

### 3.2 Desktop Equipment Assignment (Multi-Panel)

```
┌────────────────────────────────────────────────────────────────┐
│ ASSIGN EQUIPMENT                                               │
├──────────────────────┬─────────────────────┬───────────────────┤
│ CREW ROSTER          │ CURRENT EQUIPMENT   │ AVAILABLE STASH   │
│                      │                     │                   │
│ ○ Sarah Chen         │ ✓ Infantry Laser    │ Auto Rifle        │
│   3/6 items          │   [Remove]          │ [Assign]          │
│                      │                     │                   │
│ ○ Marcus Liu         │ ✓ Frag Vest         │ Boarding Saber    │
│   2/6 items          │   [Remove]          │ [Assign]          │
│                      │                     │                   │
│ ○ Elena Volkov       │ ✓ Med-patch         │ Battle Visor      │
│   4/6 items          │   [Remove]          │ [Assign]          │
│                      │                     │                   │
│ ○ Jak Porter         │                     │ Scanner Bot       │
│   1/6 items          │                     │ [Assign]          │
│                      │                     │                   │
├──────────────────────┴─────────────────────┴───────────────────┤
│ [Auto-Equip All] [Clear All] [Optimize for Battle] [Confirm]  │
└────────────────────────────────────────────────────────────────┘
```

**Responsive Breakpoints**:
- **<480px**: Single column, tabs for Current/Available
- **480-768px**: Two columns (Current + Available), crew dropdown
- **>1024px**: Three columns (Crew list + Current + Available)

---

### 3.3 Equipment Comparison Modal

**Trigger**: Tap equipment item for detailed comparison

```
┌─────────────────────────────────────────────────┐
│ COMPARE EQUIPMENT                          [×]  │
├─────────────────────────────────────────────────┤
│ ┌───────────────────┐   ┌──────────────────┐   │
│ │ CURRENT           │   │ SELECTED         │   │
│ │ Infantry Laser    │   │ Auto Rifle       │   │
│ ├───────────────────┤   ├──────────────────┤   │
│ │ Damage: 2         │   │ Damage: 3  ✅    │   │
│ │ Range: 24"        │   │ Range: 18" ⚠️    │   │
│ │ Shots: 3          │   │ Shots: 5   ✅    │   │
│ │ Trait: -          │   │ Trait: Auto 2 ✅ │   │
│ └───────────────────┘   └──────────────────┘   │
│                                                 │
│ [Keep Current] [Switch to Auto Rifle]           │ 56dp buttons
└─────────────────────────────────────────────────┘
```

**Design Features**:
- **Side-by-Side Comparison**: Stats aligned vertically
- **Better/Worse Indicators**: ✅ green, ⚠️ yellow, ❌ red
- **Clear Actions**: Two buttons (keep vs switch)

---

## PART 4: PHASE TRANSITION FEEDBACK SYSTEM

### Problem Statement
**Current State**: No visual feedback when transitioning between phases. Users don't know what data is being carried forward or if the transition succeeded.

**Impact**: Breaks immersion, creates uncertainty about game state.

### Solution: Transition Animation + Data Summary

---

### 4.1 Phase Transition Loading State

```
┌─────────────────────────────────────────────────┐
│                                                 │
│             ┌─────────────────┐                 │
│             │                 │                 │
│             │   [⏳ Spinner]  │                 │
│             │                 │                 │
│             │ ENTERING WORLD  │                 │
│             │     PHASE       │                 │
│             │                 │                 │
│             └─────────────────┘                 │
│                                                 │
│ ━━━━━━━━●━━━━━━━━━━━━━━━━━━  50%               │ Progress bar
│                                                 │
│ ✅ Travel costs paid (-4 credits)               │
│ ✅ Crew health verified (5 active)              │
│ ⏳ Loading world data...                        │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Animation Sequence** (1.5 seconds total):
1. **Fade out current screen** (0.3s)
2. **Show transition card** with spinner (0.9s)
   - Display phase name
   - Show progress bar (indeterminate)
   - List data operations
3. **Fade in new screen** (0.3s)

**Container Hierarchy**:
```gdscript
PhaseTransitionOverlay (CanvasLayer - layer 100)
└── ColorRect (semi-transparent black - 0.7 alpha)
    └── CenterContainer
        └── PanelContainer
            └── VBoxContainer
                ├── Label (Phase Name - FONT_SIZE_XL)
                ├── TextureRect (Spinner animation)
                ├── ProgressBar
                └── VBoxContainer (Operation checklist)
```

---

### 4.2 Pre-Battle Data Summary

```
┌─────────────────────────────────────────────────┐
│ ENTERING BATTLE                                 │
├─────────────────────────────────────────────────┤
│ CREW DEPLOYMENT                                 │
│ ✅ Sarah Chen - Infantry Laser, Frag Vest       │
│ ✅ Marcus Liu - Auto Rifle, Med-patch           │
│ ✅ Elena Volkov - Boarding Saber, Battle Visor  │
│ ✅ Jak Porter - Handgun                         │
│ ⚠️ Zara Khan - INJURED (bench)                  │
│                                                 │
│ MISSION BRIEF                                   │
│ Type: Opportunity Mission                       │
│ Objective: Secure the Area                      │
│ Enemy: Converted Acquisition Crew               │
│                                                 │
│ BATTLEFIELD CONDITIONS                          │
│ Terrain: Urban Ruins                            │
│ Deployment: Standard (12" from edge)            │
│ Special: Low visibility (-1 to hit)             │
│                                                 │
│ [Ready for Battle]                              │ 56dp button
└─────────────────────────────────────────────────┘
```

**Key Information**:
- **Crew Loadouts**: Shows equipped items per character
- **Mission Details**: Type, objective, enemy
- **Battlefield Setup**: Terrain, deployment, modifiers
- **Warnings**: Injured crew, missing equipment

---

## PART 5: INFORMATION ARCHITECTURE

### 5.1 Progressive Disclosure Hierarchy

**Level 1 (Always Visible - Glanceable)**:
- Turn number
- Current phase name
- Credits (numeric)
- Story points (numeric)
- Crew count (5 active / 1 injured)
- Ship status icon (✅ healthy, ⚠️ damaged, ❌ critical)
- Equipment count (8/10 stash)

**Level 2 (One Tap - Quick Actions)**:
- Equipment drawer (slide up from bottom)
- Crew member stats (tap character card)
- Ship details (tap ship icon)
- Victory progress (tap victory icon)
- Patron/Rival lists (tap count badge)

**Level 3 (Two Taps - Deep Dive)**:
- Individual equipment details
- Full character sheet
- Ship upgrade options
- Victory condition descriptions
- Battle history

---

### 5.2 Thumb Zone Optimization (Mobile Portrait)

```
┌─────────────────────────────────────┐
│ TOP 20% - DISPLAY ONLY              │ <- Unreachable
│ - Turn/Phase header                 │
│ - Victory progress                  │
│                                     │
├─────────────────────────────────────┤
│ MIDDLE 40% - SCROLLABLE CONTENT     │ <- Two-handed reach
│ - Crew roster cards                 │
│ - Ship status                       │
│ - World info                        │
│                                     │
├─────────────────────────────────────┤
│ BOTTOM 40% - PRIMARY ACTIONS        │ <- One-handed thumb
│ ┌─────────────────────────────────┐ │
│ │ Equipment Drawer Handle [↑]     │ │ <- 56dp touch
│ └─────────────────────────────────┘ │
│ [Crew] [Ship] [World] [Battle]      │ <- 56dp tabs
└─────────────────────────────────────┘
```

**Critical Actions in Thumb Zone** (bottom 40%):
- Tab navigation (56dp height)
- Equipment drawer toggle
- Phase transition button
- Quick actions (Auto-Equip, Confirm, etc.)

**Display-Only in Top Zone**:
- Turn counter
- Phase name
- Victory progress
- Warnings/alerts

---

### 5.3 Component State Diagrams

**Equipment Item States**:
```
┌──────────┐    [Assign]     ┌──────────┐
│ IN STASH │ ───────────────>│ EQUIPPED │
│          │<───────────────│          │
└──────────┘    [Remove]     └──────────┘
     │                            │
     │ [Sell]                     │ [Battle]
     ▼                            ▼
┌──────────┐                ┌──────────┐
│   SOLD   │                │ IN COMBAT│
│          │                │          │
└──────────┘                └──────────┘
                                 │
                                 │ [Damaged]
                                 ▼
                            ┌──────────┐
                            │ DAMAGED  │
                            │ IN STASH │
                            └──────────┘
```

**Phase Transition States**:
```
┌────────┐  [Next Phase]  ┌────────────┐  [Load Data]  ┌────────┐
│ TRAVEL │ ──────────────>│ TRANSITION │──────────────>│ WORLD  │
└────────┘                └────────────┘               └────────┘
                               │
                               │ [Show Summary]
                               ▼
                          ┌──────────┐
                          │ SUMMARY  │
                          │ OVERLAY  │
                          └──────────┘
```

---

## PART 6: RECOMMENDED COLOR & TYPOGRAPHY

### 6.1 Color Semantic Usage

**Equipment Status Colors**:
- **Available**: `COLOR_TEXT_SECONDARY` (#808080)
- **Equipped**: `COLOR_FOCUS` (#4FC3F7) - cyan accent
- **Damaged**: `COLOR_DANGER` (#DC2626) - red
- **Optimal**: `COLOR_SUCCESS` (#10B981) - green (comparison indicators)

**Debt Warning Colors**:
- **Can Pay**: `COLOR_SUCCESS` (#10B981)
- **Near Limit**: `COLOR_WARNING` (#D97706)
- **Can't Pay Minimum**: `COLOR_DANGER` (#DC2626) - full card background

**Phase Transition Colors**:
- **Background Overlay**: `COLOR_BASE` (#1A1A2E) with 0.7 alpha
- **Progress Bar Fill**: `COLOR_FOCUS` (#4FC3F7)
- **Checklist Complete**: `COLOR_SUCCESS` (#10B981)
- **Checklist Pending**: `COLOR_TEXT_SECONDARY` (#808080)

### 6.2 Typography Scale Application

**Dashboard Headers**:
- **Turn/Phase**: `FONT_SIZE_XL` (24px) - `COLOR_TEXT_PRIMARY`
- **Section Titles**: `FONT_SIZE_LG` (18px) - `COLOR_TEXT_SECONDARY`
- **Crew Names**: `FONT_SIZE_MD` (16px) - `COLOR_TEXT_PRIMARY`
- **Stats/Subtitles**: `FONT_SIZE_SM` (14px) - `COLOR_TEXT_SECONDARY`
- **Captions**: `FONT_SIZE_XS` (11px) - `COLOR_TEXT_DISABLED`

**Equipment Cards**:
- **Item Name**: `FONT_SIZE_MD` (16px) - `COLOR_TEXT_PRIMARY`
- **Category**: `FONT_SIZE_SM` (14px) - `COLOR_TEXT_SECONDARY`
- **Status Badge**: `FONT_SIZE_XS` (11px) - `COLOR_FOCUS`

---

## PART 7: IMPLEMENTATION PRIORITIES

### Phase 1: Critical Visibility (Week 5)
1. **EquipmentDrawer Component** - Unified stash view
2. **DebtPaymentPanel** - Ship debt UI
3. **Enhanced AssignEquipmentComponent** - Mobile-friendly transfers

**Estimated Effort**: 8-12 hours

### Phase 2: User Feedback (Week 6)
4. **PhaseTransitionOverlay** - Loading states
5. **PreBattleDataSummary** - Equipment confirmation
6. **Equipment Comparison Modal** - Stat comparison

**Estimated Effort**: 6-8 hours

### Phase 3: Polish (Week 7)
7. **Auto-Equip AI** - Optimal loadout suggestions
8. **Capacity Warnings** - Visual indicators
9. **Filter/Sort** - Desktop-only features

**Estimated Effort**: 4-6 hours

---

## APPENDIX A: RESPONSIVE TESTING CHECKLIST

### Mobile Portrait (<480px)
- [ ] Equipment drawer slides from bottom (60% height)
- [ ] Debt slider fills width (min 48dp touch target)
- [ ] Tab navigation fits in single row (4 tabs × 56dp)
- [ ] All buttons 56dp height minimum
- [ ] Text readable at 16px base size

### Tablet (480-768px)
- [ ] Equipment drawer becomes left sidebar (40% width)
- [ ] Debt panel uses two-column layout
- [ ] Assignment uses side-by-side Current/Available
- [ ] Touch targets remain 48dp minimum
- [ ] Text scales to 16-18px

### Desktop (>1024px)
- [ ] Equipment drawer fixed right sidebar (300px)
- [ ] Debt panel horizontal layout
- [ ] Assignment three-column (Crew/Current/Available)
- [ ] Hover states visible
- [ ] Text comfortable at 16-18px

---

## APPENDIX B: ACCESSIBILITY NOTES

### Color Contrast
- All text meets WCAG AA (4.5:1 ratio minimum)
- Critical warnings use both color AND icon (⚠️)
- Status badges use text labels, not color alone

### Touch Targets
- Minimum 48dp per Material Design
- Comfortable 56dp for primary actions
- 8dp spacing between tappable elements

### Offline-First
- No loading spinners during gameplay
- Phase transitions pre-cache data
- Equipment drawer instant response

---

## SUMMARY OF DELIVERABLES

**Wireframes**: 12 layouts (mobile/tablet/desktop variations)
**Interaction Flows**: 4 state diagrams
**Touch Targets**: All callouts 48-56dp
**Responsive Specs**: 3 breakpoints defined
**Component Hierarchy**: 5 GDScript structure examples
**Color/Typography**: Design system fully applied

**Estimated Implementation Time**: 18-26 hours across 3 weeks

**Success Metrics**:
- Equipment visible in <3 seconds from dashboard
- Ship debt payable in <5 taps
- Crew loadout assignable in <10 taps per character
- Phase transitions complete in <2 seconds
- All interactions one-handed on mobile

---

**Document Status**: Ready for implementation
**Next Steps**: Create tickets in PROJECT_INSTRUCTIONS.md, begin Phase 1 components
