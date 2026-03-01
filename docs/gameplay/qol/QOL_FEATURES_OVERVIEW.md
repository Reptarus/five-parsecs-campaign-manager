# Quality of Life Features - Master Overview

**Status**: Pre-Beta Preparation  
**Version**: 1.0  
**Last Updated**: 2025-11-17

## 📋 Purpose

This directory contains documentation and implementation guides for Quality of Life (QOL) features designed to enhance the Five Parsecs Campaign Manager user experience. These features are based on recommendations from UI_Framework.md and inspired by successful companion apps like Infinity Army.

## 🎯 Design Philosophy

All QOL features follow these principles:

1. **Eliminate Tedium**: Automate repetitive tasks (calculations, table lookups)
2. **Enhance Storytelling**: Support narrative immersion (journals, history, NPCs)
3. **Quick Reference**: Provide instant access to rules and information
4. **Respect Physical Play**: Support tabletop gaming, don't replace it
5. **Mobile-First**: Optimize for on-the-go and at-table use
6. **Offline-First**: All features work without internet

## 📊 Implementation Priority

### Phase 1: Core UX (Critical for Beta)
**Target**: Week 4-5 implementation

| Feature | Priority | Effort | Impact | Status |
|---------|----------|--------|--------|--------|
| **Keyword System** | P0 - Critical | 2-3 days | Very High | 🟡 Ready to implement |
| **Campaign Journal** | P0 - Critical | 3-4 days | High | 🟡 Ready to implement |
| **NPC Persistence** | P0 - Critical | 4-5 days | Very High | 🟡 Ready to implement |
| **Turn Phase Checklist** | P1 - High | 2-3 days | High | 🟡 Ready to implement |

### Phase 2: Quality of Life (Post-Beta)
**Target**: Version 1.1-1.2

| Feature | Priority | Effort | Impact | Status |
|---------|----------|--------|--------|--------|
| **Equipment Comparison** | P2 - Medium | 2-3 days | Medium | 🟡 Ready to implement |
| **Battle Setup Wizard** | P2 - Medium | 3-4 days | Medium | 🟡 Ready to implement |
| **Undo System** | P2 - Medium | 2 days | Medium | 🟡 Ready to implement |
| **Mission Calculator** | P3 - Low | 1-2 days | Low | 🟡 Ready to implement |

### Phase 3: Polish & Extras (Version 1.3+)
**Target**: Post-launch updates

| Feature | Priority | Effort | Impact | Status |
|---------|----------|--------|--------|--------|
| **Legacy System** | P3 - Low | 2-3 days | Low | 🟡 Ready to implement |
| **Dice Statistics** | P3 - Low | 1 day | Low | 🟡 Ready to implement |
| **Voice Notes** | P4 - Optional | 2-3 days | Low | 🟡 Ready to implement |
| **Share Reports** | P4 - Optional | 2 days | Low | 🟡 Ready to implement |

## 📁 Feature Documentation

### Critical Features (Phase 1)

#### 1. **Keyword System** 📖
**File**: `Keyword_System.md`  
**Implementation**: `src/qol/KeywordSystem.gd`, `src/ui/components/qol/KeywordTooltip.gd`

Tap-to-reveal definitions for all game terms, traits, and abilities. Inspired by Infinity Army's contextual help system.

**Key Features**:
- Inline keyword recognition
- Tap/click to reveal definition
- Cross-reference related keywords
- Search glossary integration
- Bookmark frequently used terms

#### 2. **Campaign Journal** 📔
**File**: `Campaign_Journal.md`  
**Implementation**: `src/qol/CampaignJournal.gd`, `src/ui/components/qol/JournalPanel.gd`

Rich campaign narrative tracking with timeline, events, and character history.

**Key Features**:
- Date-stamped journal entries
- Auto-generated event summaries
- Character-specific histories
- Photo attachments for battles
- Export to PDF/text

#### 3. **NPC Persistence System** 👥
**File**: `NPC_Persistence.md`  
**Implementation**: `src/qol/NPCPersistence.gd`, `src/ui/components/qol/NPCTrackerPanel.gd`

Track relationships with Patrons, Rivals, and visited locations across the campaign.

**Key Features**:
- Patron job history
- Rival encounter tracking
- Location memory (NPCs, facilities)
- Relationship progression
- Galaxy map integration

#### 4. **Turn Phase Checklist** ✅
**File**: `Turn_Phase_Checklist.md`  
**Implementation**: `src/qol/TurnPhaseChecklist.gd`, `src/ui/components/qol/PhaseChecklistPanel.gd`

Phase-by-phase validation to prevent forgotten steps.

**Key Features**:
- Required/optional action tracking
- Can't advance until complete
- Context-sensitive suggestions
- New player guidance mode
- Veteran toggle (disable help)

### Quality Features (Phase 2)

#### 5. **Equipment Comparison Tool** ⚖️
**File**: `Equipment_Comparison.md`  
**Implementation**: `src/qol/EquipmentComparisonTool.gd`, `src/ui/components/qol/ComparisonPanel.gd`

Side-by-side weapon and armor comparison.

**Key Features**:
- Stat highlighting (better/worse)
- Cost/benefit analysis
- Character-specific recommendations
- Purchase decision support

#### 6. **Battle Setup Wizard** 🎲
**File**: `Battle_Setup_Wizard.md`  
**Implementation**: `src/qol/BattleSetupWizard.gd`

One-click battle generation from tables.

**Key Features**:
- Auto-generate enemies
- Set deployment conditions
- Calculate mission parameters
- Quick "Start Battle" button

### Polish Features (Phase 3)

#### 7. **Legacy & Retirement System** 🏆
**File**: `Legacy_System.md`  
**Implementation**: `src/qol/LegacySystem.gd`, `src/ui/components/qol/LegacyHallOfFame.gd`

Archive completed campaigns and retired crews.

**Key Features**:
- Campaign archive
- Hall of Fame
- Import veterans as NPCs
- Crew statistics preservation

#### 8. **Additional QOL Features** 🛠️
**File**: `Additional_QOL_Features.md`  
**Implementation**: `src/qol/QOLUtilities.gd`

Smaller utility features:
- Undo/redo system
- Dice statistics tracking
- Voice notes (mobile)
- Difficulty adjustment
- Share battle reports
- Bulk actions
- Colorblind modes

## 🔧 Technical Integration

### Existing Systems Used

All QOL features build on your current architecture:

| Existing System | QOL Features Using It |
|----------------|----------------------|
| `Tooltip.gd` | Keyword System |
| `GameState.gd` | All persistence features |
| `DiceSystem.gd` | Dice statistics |
| `ResponsiveContainer.gd` | All UI components |
| `CampaignDashboard.gd` | Journal, NPC tracker integration |
| `RulesReference.gd` | Keyword database source |

### New Autoload Singletons

For global access, consider adding:

```gdscript
# project.godot additions
[autoload]
KeywordDB="*res://src/qol/KeywordSystem.gd"
CampaignJournal="*res://src/qol/CampaignJournal.gd"
NPCTracker="*res://src/qol/NPCPersistence.gd"
```


## 📂 File Organization

```
docs/gameplay/qol/
├── QOL_FEATURES_OVERVIEW.md          # This file - master index
├── Keyword_System.md                  # Keyword tap-to-reveal system
├── Campaign_Journal.md                # Campaign narrative tracking
├── NPC_Persistence.md                 # Patron/Rival/Location memory
├── Turn_Phase_Checklist.md            # Phase validation system
├── Equipment_Comparison.md            # Equipment analysis tool
├── Battle_Setup_Wizard.md             # Auto-battle generation
├── Legacy_System.md                   # Crew retirement archive
└── Additional_QOL_Features.md         # Misc utilities

src/qol/
├── KeywordSystem.gd                   # Keyword database + lookups
├── CampaignJournal.gd                 # Event logging + timeline
├── NPCPersistence.gd                  # NPC/location tracking
├── TurnPhaseChecklist.gd              # Phase validation logic
├── EquipmentComparisonTool.gd         # Equipment analysis
├── BattleSetupWizard.gd               # Battle generator
├── LegacySystem.gd                    # Crew archival
└── QOLUtilities.gd                    # Undo, stats, helpers

src/ui/components/qol/
├── KeywordTooltip.tscn/.gd            # Keyword popup UI
├── JournalPanel.tscn/.gd              # Journal interface
├── ComparisonPanel.tscn/.gd           # Equipment comparison UI
├── NPCTrackerPanel.tscn/.gd           # NPC relationship UI
├── PhaseChecklistPanel.tscn/.gd       # Turn checklist UI
└── LegacyHallOfFame.tscn/.gd          # Retired crews UI
```

## 🚀 Implementation Roadmap

### Week 4-5: Phase 1 Critical Features
**Goal**: Core UX enhancements for beta release

1. **Keyword System** (2-3 days)
   - Build keyword database from rules
   - Implement tooltip integration
   - Add search functionality

2. **Campaign Journal** (3-4 days)
   - Event logging system
   - Timeline visualization
   - Auto-generated entries

3. **NPC Persistence** (4-5 days)
   - Patron job tracking
   - Rival encounter history
   - Location memory system

4. **Turn Phase Checklist** (2-3 days)
   - Phase validation logic
   - Required action tracking
   - UI integration

### Post-Beta: Phase 2 Quality Features
**Goal**: Enhanced player experience

5. **Equipment Comparison** (2-3 days)
6. **Battle Setup Wizard** (3-4 days)
7. **Undo System** (2 days)

### Version 1.3+: Phase 3 Polish
**Goal**: Community-requested features

8. **Legacy System** (2-3 days)
9. **Additional utilities** (ongoing)


## 💾 Save/Load Integration

All QOL features support campaign persistence:

```gdscript
# Example save format in GameState
{
  "campaign_data": { ... },
  "qol_data": {
    "keywords": {
      "bookmarked": ["Reactions", "Toughness", "Savvy"],
      "recent_searches": ["combat", "injury"]
    },
    "journal": {
      "entries": [...],
      "timeline": [...],
      "photos": [...]
    },
    "npcs": {
      "patrons": [...],
      "rivals": [...],
      "locations": [...]
    },
    "checklist_settings": {
      "veteran_mode": false,
      "auto_advance": true
    }
  }
}
```

## 📱 Mobile Optimization

All UI components use `ResponsiveContainer` patterns:

- **Desktop**: Rich information density, multi-column layouts
- **Mobile**: Streamlined cards, single-column, touch-friendly
- **Tablet**: Balanced hybrid approach

## 🎨 Accessibility

Features support existing accessibility systems:

- High contrast mode
- Colorblind palettes
- Large text options
- Keyboard navigation
- Screen reader hints

## 🧪 Testing Strategy

Each feature includes:

1. **Unit tests**: Core logic validation
2. **Integration tests**: System interaction
3. **UI tests**: Responsive behavior
4. **Save/load tests**: Persistence verification

## 📝 Documentation Standards

Each feature doc includes:

- **Overview**: Purpose and user value
- **User Stories**: Concrete use cases
- **Technical Spec**: Implementation details
- **UI/UX Mockups**: Visual design
- **API Reference**: Public methods/signals
- **Integration Guide**: How to use in existing code
- **Testing Plan**: Validation approach

## 🔗 Quick Links

- [Keyword System](./Keyword_System.md) - Tap-to-reveal definitions
- [Campaign Journal](./Campaign_Journal.md) - Narrative tracking
- [NPC Persistence](./NPC_Persistence.md) - Relationship management
- [Turn Phase Checklist](./Turn_Phase_Checklist.md) - Phase validation
- [Equipment Comparison](./Equipment_Comparison.md) - Stat analysis
- [Battle Setup Wizard](./Battle_Setup_Wizard.md) - Auto-generation
- [Legacy System](./Legacy_System.md) - Crew retirement
- [Additional Features](./Additional_QOL_Features.md) - Utilities

---

**Status**: All features ready for implementation  
**Next Step**: Begin Phase 1 development (Keyword System)  
**Estimated Total Effort**: 20-25 development days  
**Target Completion**: Pre-beta (Phase 1), Post-beta (Phase 2), v1.3+ (Phase 3)
