# Ship Components - Visual Structure Reference

## 1. ShipDamageStatusPanel

```
┌─ PanelContainer (ShipDamageStatusPanel) ─────────────────┐
│ [Glass morphism styling, 16px border radius]            │
│                                                          │
│  ┌─ VBoxContainer (main layout) ─────────────────────┐  │
│  │                                                    │  │
│  │  ┌─ HBoxContainer (Header) ────────────────────┐  │  │
│  │  │                                              │  │  │
│  │  │  SHIP STATUS              [OPERATIONAL] ←─ Dynamic │
│  │  │  [Secondary text]          [Green/Yellow/Red]  │  │
│  │  │                                              │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  │                                                    │  │
│  │  ┌─ ProgressBar (Hull Bar) ──────────────────┐    │  │
│  │  │ ████████████████████░░░░ 75% ←─ Color-coded │  │
│  │  │ [Green >75%, Yellow 50-75%, Red <50%]     │    │  │
│  │  └───────────────────────────────────────────┘    │  │
│  │                                                    │  │
│  │  ┌─ HBoxContainer (Stats) ────────────────────┐   │  │
│  │  │                                             │   │  │
│  │  │  Hull: 75/100      Repair Cost: 125 credits│   │  │
│  │  │  [Primary]         [Secondary, calculated] │   │  │
│  │  │                                             │   │  │
│  │  └─────────────────────────────────────────────┘   │  │
│  │                                                    │  │
│  │  ┌─ PanelContainer (CriticalWarning) ────────┐    │  │
│  │  │ [Visible only when hull ≤25%]             │    │  │
│  │  │  ⚠️ CRITICAL DAMAGE - Ship may be lost!   │    │  │
│  │  │  [Red text, elevated background]          │    │  │
│  │  └───────────────────────────────────────────┘    │  │
│  │                                                    │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

**Minimum Size**: 300×150px
**Spacing**: 24px padding, 8px element gaps

---

## 2. ShipPurchaseDialog

```
┌─ PopupPanel (Modal Dialog - 600×500px) ──────────────────┐
│                                                          │
│  ┌─ PanelContainer (Panel) ──────────────────────────┐  │
│  │ [Secondary bg, 16px radius, 2px border]           │  │
│  │                                                    │  │
│  │  ┌─ VBoxContainer (main layout) ───────────────┐  │  │
│  │  │                                              │  │  │
│  │  │  Purchase Ship [Title, 24px]                │  │  │
│  │  │  Credits: 500 [Warning color, 18px]         │  │  │
│  │  │                                              │  │  │
│  │  │  ─────────────────────────── [HSeparator]   │  │  │
│  │  │                                              │  │  │
│  │  │  ┌─ ScrollContainer ───────────────────┐    │  │  │
│  │  │  │                                      │    │  │  │
│  │  │  │  ┌─ Ship Card: Worn Freighter ───┐  │    │  │  │
│  │  │  │  │ Worn Freighter       200 CR   │  │    │  │  │
│  │  │  │  │ [HULL 80]                     │  │    │  │  │
│  │  │  │  │ Basic transport vessel        │  │    │  │  │
│  │  │  │  └───────────────────────────────┘  │    │  │  │
│  │  │  │                                      │    │  │  │
│  │  │  │  ┌─ Ship Card: Standard Transport ─┐  │  │  │
│  │  │  │  │ Standard Transport   400 CR   │  │    │  │  │
│  │  │  │  │ [HULL 100]                    │  │    │  │  │
│  │  │  │  │ Reliable balanced ship        │  │    │  │  │
│  │  │  │  └───────────────────────────────┘  │    │  │  │
│  │  │  │                                      │    │  │  │
│  │  │  │  [Armed Trader - 600 CR]            │    │  │  │
│  │  │  │  [Fast Courier - 500 CR]            │    │  │  │
│  │  │  │                                      │    │  │  │
│  │  │  └──────────────────────────────────────┘    │  │  │
│  │  │                                              │  │  │
│  │  │  ☐ Take loan (adds debt to campaign)        │  │  │
│  │  │                                              │  │  │
│  │  │  ┌─ HBoxContainer (Buttons) ────────────┐   │  │  │
│  │  │  │                                       │   │  │  │
│  │  │  │  [Cancel]    [Purchase] ←─ 48dp      │   │  │  │
│  │  │  │  [Secondary]  [Primary, disabled]    │   │  │  │
│  │  │  │                                       │   │  │  │
│  │  │  └───────────────────────────────────────┘   │  │  │
│  │  │                                              │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  │                                                    │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

**Size**: 600×500px (centered)
**Card Interaction**: Hover (border highlight), Click (selection state)
**Purchase Logic**: Enabled when selected AND (affordable OR loan checked)

---

## 3. CommercialPassagePanel

```
┌─ PanelContainer (CommercialPassagePanel) ────────────────┐
│ [Glass morphism styling, 16px border radius]            │
│                                                          │
│  ┌─ VBoxContainer (main layout, 16px gaps) ───────────┐ │
│  │                                                     │ │
│  │  Commercial Passage [Title, 24px, centered]        │ │
│  │                                                     │ │
│  │  ─────────────────────────── [HSeparator]          │ │
│  │                                                     │ │
│  │  No ship available - must book passage             │ │
│  │  [Secondary text, autowrap]                        │ │
│  │                                                     │ │
│  │  ┌─ VBoxContainer (CrewCost, 4px gaps) ─────────┐  │ │
│  │  │                                               │  │ │
│  │  │  Cost per person: 10 credits [Primary, 16px] │  │ │
│  │  │  Crew: 6 = 60 credits total [Warning, 18px]  │  │ │
│  │  │                                               │  │ │
│  │  └───────────────────────────────────────────────┘  │ │
│  │                                                     │ │
│  │  ─────────────────────────── [HSeparator]          │ │
│  │                                                     │ │
│  │  Select Destination: [Label, 14px]                 │ │
│  │                                                     │ │
│  │  ┌─ OptionButton (DestinationSelect) ───────────┐  │ │
│  │  │ Fringe World ▼ [48dp height, styled]        │  │ │
│  │  └──────────────────────────────────────────────┘  │ │
│  │                                                     │ │
│  │  ─────────────────────────── [HSeparator]          │ │
│  │                                                     │ │
│  │  ┌─ PanelContainer (WarningPanel) ─────────────┐   │ │
│  │  │                                              │   │ │
│  │  │  ⚠️ Cannot carry cargo or injured crew      │   │ │
│  │  │  [Warning color, centered, autowrap]        │   │ │
│  │  │                                              │   │ │
│  │  └──────────────────────────────────────────────┘   │ │
│  │                                                     │ │
│  │  ┌───────────────────────────────────────────┐     │ │
│  │  │       [Book Passage] ←─ 48dp height       │     │ │
│  │  │       [Primary button, full width]        │     │ │
│  │  └───────────────────────────────────────────┘     │ │
│  │                                                     │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

**Minimum Size**: 400×250px
**Auto-Calculation**: Total cost updates when crew size changes
**Destinations**: Configurable via `set_available_destinations()`

---

## Component Node Hierarchy

### ShipDamageStatusPanel
```
ShipDamageStatusPanel (PanelContainer)
└── VBox (VBoxContainer)
    ├── Header (HBoxContainer)
    │   ├── Title (Label) "SHIP STATUS"
    │   └── StateLabel (Label) "OPERATIONAL" [dynamic color]
    ├── HullBar (ProgressBar) [color-coded fill]
    ├── Stats (HBoxContainer)
    │   ├── HullLabel (Label) "Hull: X/Y"
    │   └── RepairLabel (Label) "Repair Cost: X credits"
    └── CriticalWarning (PanelContainer) [visible ≤25%]
        └── WarningLabel (Label) "⚠️ CRITICAL DAMAGE..."
```

### ShipPurchaseDialog
```
ShipPurchaseDialog (PopupPanel)
└── Panel (PanelContainer)
    └── VBox (VBoxContainer)
        ├── TitleLabel (Label) "Purchase Ship"
        ├── CreditsLabel (Label) "Credits: X"
        ├── HSeparator
        ├── ShipScroll (ScrollContainer)
        │   └── ShipList (VBoxContainer)
        │       └── [ShipOptionCard instances] (created dynamically)
        ├── LoanCheck (CheckBox) "Take loan..."
        └── Buttons (HBoxContainer)
            ├── CancelButton (Button)
            └── PurchaseButton (Button)
```

### CommercialPassagePanel
```
CommercialPassagePanel (PanelContainer)
└── VBox (VBoxContainer)
    ├── Title (Label) "Commercial Passage"
    ├── HSeparator
    ├── InfoLabel (Label) "No ship available..."
    ├── CrewCost (VBoxContainer)
    │   ├── CrewLabel (Label) "Cost per person: 10 credits"
    │   └── TotalLabel (Label) "Crew: X = Y credits total"
    ├── HSeparator2
    ├── DestinationLabel (Label) "Select Destination:"
    ├── DestinationSelect (OptionButton)
    ├── HSeparator3
    ├── WarningPanel (PanelContainer)
    │   └── WarningLabel (Label) "⚠️ Cannot carry cargo..."
    └── BookButton (Button) "Book Passage"
```

---

## Color States Reference

### ShipDamageStatusPanel Hull Bar
```
100%  ████████████████████ [GREEN #10b981]    OPERATIONAL
 90%  ████████████████████ [GREEN #10b981]    OPERATIONAL
 80%  ████████████████░░░░ [GREEN #10b981]    OPERATIONAL
 75%  ███████████████░░░░░ [GREEN #10b981]    MINOR DAMAGE
 65%  █████████████░░░░░░░ [YELLOW #f59e0b]   DAMAGED
 50%  ██████████░░░░░░░░░░ [YELLOW #f59e0b]   DAMAGED
 40%  ████████░░░░░░░░░░░░ [RED #ef4444]      DAMAGED
 25%  █████░░░░░░░░░░░░░░░ [RED #ef4444]      CRITICAL + Banner
 10%  ██░░░░░░░░░░░░░░░░░░ [RED #ef4444]      CRITICAL + Banner
  0%  ░░░░░░░░░░░░░░░░░░░░ [RED #ef4444]      DESTROYED + Banner
```

### ShipPurchaseDialog Card States
```
Default:    [Border: #374151, 1px]
Hover:      [Border: #3b82f6, 2px] (blue accent)
Selected:   [Border: #10b981, 2px] (green success)
```

### Button States (All Components)
```
Normal:     [Background: #3b82f6] (accent blue)
Hover:      [Background: #60a5fa] (lighter blue)
Pressed:    [Background: #2563eb] (darker blue)
Disabled:   [Background: #374151] (gray border)
```

---

## Responsive Breakpoints

All components inherit responsive behavior from BaseCampaignPanel:

```
Mobile (<600px):
- Single column layout
- 56dp touch targets (TOUCH_TARGET_COMFORT)
- Reduced font sizes (-2px)
- Tighter spacing (-4px)

Tablet (600-900px):
- Two-column layout (where applicable)
- 48dp touch targets (TOUCH_TARGET_MIN)
- Base font sizes
- Base spacing

Desktop (>1024px):
- Multi-column layout (where applicable)
- 48dp touch targets
- Base font sizes
- Generous spacing (+4px)
```

---

## Integration Points

### Data Flow: ShipDamageStatusPanel
```
Ship Resource → update_display(hull, max_hull)
                      ↓
             [Hull Bar Updates]
             [State Label Updates]
             [Cost Calculation]
                      ↓
        User clicks "Repair" (if added)
                      ↓
        repair_requested signal → Repair System
                      ↓
        Deduct credits, restore hull
                      ↓
        update_display(new_hull, max_hull)
```

### Data Flow: ShipPurchaseDialog
```
Trading Screen → show_dialog(player_credits)
                      ↓
              [Display ship options]
              [User selects ship]
              [User may check loan]
                      ↓
          ship_purchased signal → Campaign Manager
                      ↓
          Create Ship Resource
          Deduct credits OR add debt
          Update UI with new ship
```

### Data Flow: CommercialPassagePanel
```
Travel System (no ship) → set_crew_size(crew_count)
                               ↓
                   [Calculate total cost]
                   [Display destinations]
                               ↓
           passage_booked signal → Travel System
                               ↓
                   Deduct credits
                   Move to destination
                   Clear cargo (if any)
```

---

## File References

| Component | GDScript | Scene | Demo |
|-----------|----------|-------|------|
| ShipDamageStatusPanel | `ShipDamageStatusPanel.gd` (138 lines) | `ShipDamageStatusPanel.tscn` | Line 27 in Demo |
| ShipPurchaseDialog | `ShipPurchaseDialog.gd` (290 lines) | `ShipPurchaseDialog.tscn` | Line 34 in Demo |
| CommercialPassagePanel | `CommercialPassagePanel.gd` (148 lines) | `CommercialPassagePanel.tscn` | Line 41 in Demo |
| Demo Scene | `ShipComponentsDemo.gd` (113 lines) | `ShipComponentsDemo.tscn` | F5 to run |

---

## Visual Design Language

### Glass Morphism Styling
All components use semi-transparent backgrounds with subtle borders:
```gdscript
var style := StyleBoxFlat.new()
style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 0.8)
style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
style.set_border_width_all(1)
style.set_corner_radius_all(16)
style.set_content_margin_all(SPACING_LG)
```

### Typography Hierarchy
```
Titles (24px):    Panel headers, dialog titles
Headers (18px):   Section titles, ship names
Body (16px):      Stats, descriptions, input fields
Small (14px):     Helper text, warnings
Captions (11px):  Stat labels, limits
```

### Spacing Rhythm (8px Grid)
```
4px:  Icon-to-text gaps
8px:  Element-to-element gaps
16px: Card padding, section content
24px: Section-to-section gaps
32px: Panel edge padding
```

---

## Conclusion

All three components follow a consistent visual structure, color system, and spacing rhythm. They integrate seamlessly with the BaseCampaignPanel design system and provide clear, touch-friendly interfaces for ship management in Five Parsecs Campaign Manager.
