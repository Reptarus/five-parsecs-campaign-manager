# Ship UI Components

Modern, mobile-first UI components for ship management in Five Parsecs Campaign Manager.

## Components

### 1. ShipDamageStatusPanel

**Purpose**: Display ship hull integrity, damage state, and repair costs.

**Visual Design**:
- Progress bar showing hull percentage (green → yellow → red)
- Damage state text (OPERATIONAL, MINOR DAMAGE, DAMAGED, CRITICAL, DESTROYED)
- Hull stats (current/max)
- Repair cost estimate
- Critical damage warning banner (shown when hull ≤25%)

**Signals**:
```gdscript
signal repair_requested()
```

**API**:
```gdscript
# Update ship status
update_display(hull: int, max_hull: int) -> void

# Set repair cost per hull point (default: 5 credits)
set_repair_cost_per_point(cost: int) -> void
```

**Usage Example**:
```gdscript
@onready var damage_panel: ShipDamageStatusPanel = $ShipDamageStatusPanel

func _ready():
    damage_panel.repair_requested.connect(_on_repair_requested)
    damage_panel.update_display(75, 100)  # 75/100 hull
    damage_panel.set_repair_cost_per_point(5)

func _on_repair_requested():
    # Calculate cost: (max_hull - current_hull) * cost_per_point
    var cost = (100 - 75) * 5  # 125 credits
    # Show repair confirmation dialog...
```

**Color States**:
- **Green (>75%)**: OPERATIONAL
- **Yellow (50-75%)**: MINOR DAMAGE / DAMAGED
- **Red (≤50%)**: DAMAGED / CRITICAL
- **Critical Warning (≤25%)**: Visible warning banner

---

### 2. ShipPurchaseDialog

**Purpose**: Modal dialog for purchasing new ships with loan options.

**Visual Design**:
- Player credits display
- Selectable ship cards with stats
- Loan checkbox for insufficient funds
- Cancel/Purchase buttons (touch-friendly 48dp height)

**Ship Types** (from Five Parsecs rulebook):
- **Worn Freighter**: 200 CR, 80 hull
- **Standard Transport**: 400 CR, 100 hull
- **Armed Trader**: 600 CR, 100 hull + weapons
- **Fast Courier**: 500 CR, 80 hull + speed

**Signals**:
```gdscript
signal ship_purchased(ship_data: Dictionary)
signal dialog_cancelled()
```

**API**:
```gdscript
# Show dialog with player's current credits
show_dialog(credits: int) -> void
```

**Usage Example**:
```gdscript
@onready var purchase_dialog: ShipPurchaseDialog = $ShipPurchaseDialog

func _on_buy_ship_button_pressed():
    var player_credits = 350
    purchase_dialog.show_dialog(player_credits)

func _ready():
    purchase_dialog.ship_purchased.connect(_on_ship_purchased)
    purchase_dialog.dialog_cancelled.connect(_on_purchase_cancelled)

func _on_ship_purchased(ship_data: Dictionary):
    print("Purchased: %s" % ship_data.name)
    print("Cost: %d credits" % ship_data.cost)
    print("Hull: %d" % ship_data.hull)
    print("Used loan: %s" % ship_data.used_loan)

    # Deduct credits or add debt
    if ship_data.used_loan:
        campaign_debt += ship_data.cost
    else:
        player_credits -= ship_data.cost
```

**Ship Data Dictionary**:
```gdscript
{
    "name": "Standard Transport",
    "cost": 400,
    "hull": 100,
    "description": "Reliable balanced ship for small crews",
    "used_loan": false  # true if loan checkbox was checked
}
```

---

### 3. CommercialPassagePanel

**Purpose**: Book commercial passage when player has no ship.

**Visual Design**:
- Cost per crew member (10 credits)
- Total cost calculation
- Destination selector
- Warning about cargo/injured crew limitations

**Signals**:
```gdscript
signal passage_booked(destination: String)
```

**API**:
```gdscript
# Set crew size (recalculates cost)
set_crew_size(size: int) -> void

# Update available destinations
set_available_destinations(destinations: Array[String]) -> void

# Update cost display
update_cost_display() -> void

# Get total passage cost
get_total_cost() -> int
```

**Usage Example**:
```gdscript
@onready var passage_panel: CommercialPassagePanel = $CommercialPassagePanel

func _ready():
    passage_panel.passage_booked.connect(_on_passage_booked)
    passage_panel.set_crew_size(6)  # 6 crew members

    var destinations = ["Fringe World", "Industrial Hub", "Trading Station"]
    passage_panel.set_available_destinations(destinations)

func _on_passage_booked(destination: String):
    var cost = passage_panel.get_total_cost()  # 6 * 10 = 60 credits

    # Deduct credits
    player_credits -= cost

    # Move to destination
    travel_to_world(destination)

    print("Booked passage to %s for %d credits" % [destination, cost])
```

**Game Rules**:
- **Cost**: 10 credits per crew member (Five Parsecs p.67)
- **Limitations**:
  - Cannot carry cargo
  - Cannot transport injured crew
  - No ship upgrades possible

---

## Design System Integration

All components follow the **BaseCampaignPanel design system**:

### Spacing (8px Grid)
- `SPACING_XS`: 4px (icon padding)
- `SPACING_SM`: 8px (element gaps)
- `SPACING_MD`: 16px (card padding)
- `SPACING_LG`: 24px (section gaps)
- `SPACING_XL`: 32px (panel edges)

### Typography
- `FONT_SIZE_XS`: 11px (captions)
- `FONT_SIZE_SM`: 14px (descriptions)
- `FONT_SIZE_MD`: 16px (body text)
- `FONT_SIZE_LG`: 18px (headers)
- `FONT_SIZE_XL`: 24px (titles)

### Colors (Deep Space Theme)
```gdscript
# Backgrounds
COLOR_PRIMARY := Color("#0a0d14")      # Darkest
COLOR_SECONDARY := Color("#111827")    # Cards
COLOR_TERTIARY := Color("#1f2937")     # Elevated
COLOR_BORDER := Color("#374151")       # Borders

# Status
COLOR_SUCCESS := Color("#10b981")      # Green (healthy)
COLOR_WARNING := Color("#f59e0b")      # Amber (damaged)
COLOR_DANGER := Color("#ef4444")       # Red (critical)
COLOR_ACCENT := Color("#3b82f6")       # Blue (primary)

# Text
COLOR_TEXT_PRIMARY := Color("#f3f4f6")   # Bright
COLOR_TEXT_SECONDARY := Color("#9ca3af") # Gray
```

### Touch Targets
- `TOUCH_TARGET_MIN`: 48dp (standard)
- `TOUCH_TARGET_COMFORT`: 56dp (important actions)

---

## Testing

Run the demo scene to see all components in action:

**Scene**: `ShipComponentsDemo.tscn`

**Test Features**:
- Damage ship (reduce hull by 25)
- Repair ship (restore to max)
- Open purchase dialog (test selection, loan checkbox)
- Change crew size (test passage cost calculation)

**Run Demo**:
1. Open `ShipComponentsDemo.tscn` in Godot
2. Press F5 to run
3. Use test buttons to interact with components

---

## File Structure

```
src/ui/components/ship/
├── ShipDamageStatusPanel.gd        # Hull integrity display
├── ShipDamageStatusPanel.tscn
├── ShipPurchaseDialog.gd           # Ship purchase modal
├── ShipPurchaseDialog.tscn
├── CommercialPassagePanel.gd       # No-ship travel option
├── CommercialPassagePanel.tscn
├── ShipComponentsDemo.gd           # Test scene script
├── ShipComponentsDemo.tscn         # Test scene
└── README.md                       # This file
```

---

## Integration Checklist

When integrating these components into the campaign manager:

- [ ] Add ShipDamageStatusPanel to ship management screen
- [ ] Connect repair_requested signal to repair system
- [ ] Add ShipPurchaseDialog to trading/shop screens
- [ ] Handle ship purchase (deduct credits or add debt)
- [ ] Show CommercialPassagePanel when ship is destroyed/sold
- [ ] Validate crew size before showing passage panel
- [ ] Disable passage for injured crew members
- [ ] Block cargo operations when using commercial passage
- [ ] Update ship hull from battle damage
- [ ] Save/load ship state with campaign data

---

## Responsive Design

All components support **mobile-first responsive layout**:

- **Mobile (<600px)**: Single column, comfortable touch targets (56dp)
- **Tablet (600-900px)**: Two-column layout where applicable
- **Desktop (>1024px)**: Full visibility, mouse-optimized spacing

Components automatically adapt to viewport size via BaseCampaignPanel responsive system.

---

## Accessibility

- High contrast text (WCAG AAA compliant)
- Touch target minimums (48dp minimum)
- Color-blind friendly status indicators (text + color)
- Keyboard navigation support (tab order preserved)
- Screen reader compatible labels

---

## References

- **Five Parsecs From Home Rules**: p.67 (Commercial Passage), p.91-93 (Ship Damage)
- **Design System**: `BaseCampaignPanel.gd` (lines 567-1554)
- **UI Modernization Checklist**: `/docs/UI_MODERNIZATION_CHECKLIST.md`
