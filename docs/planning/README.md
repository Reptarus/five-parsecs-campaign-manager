# Five Parsecs DLC Expansion Planning

**Quick Start Guide for DLC Implementation**

---

## 📋 Planning Documents Overview

This directory contains comprehensive planning for implementing Five Parsecs expansion content as modular DLC add-ons.

### Core Documents

| Document | Purpose | Use When |
|----------|---------|----------|
| **EXPANSION_ADDON_ARCHITECTURE.md** | Complete implementation plan | Planning development, technical reference |
| **EXPANSION_CONTENT_MAPPING.md** | Content-to-DLC reference | Organizing content, data migration |
| **DLC_SYSTEM_ARCHITECTURE_DIAGRAM.md** | Visual system architecture | Understanding code flow, system design |

---

## 🎯 Quick Reference

### The Four Expansions

1. **Trailblazer's Toolkit** ($4.99)
   - Psionics system
   - New species (Krag, Skulker)
   - Character expansion

2. **Freelancer's Handbook** ($6.99)
   - Elite enemies
   - Difficulty scaling
   - Combat expansion

3. **Fixer's Guidebook** ($6.99)
   - 4 new mission types (stealth, salvage, street fights, opportunities)
   - Loans system
   - Campaign depth

4. **Bug Hunt** ($9.99)
   - Standalone campaign mode
   - Military theme
   - Character transfer

---

## 🚀 Implementation Timeline

**Total: 18-20 weeks**

| Phase | Duration | Focus |
|-------|----------|-------|
| 1 | Weeks 1-2 | Data separation |
| 2 | Weeks 3-4 | Core systems (ExpansionManager, DLCManager) |
| 3 | Weeks 5-6 | Trailblazer's Toolkit |
| 4 | Weeks 7-8 | Freelancer's Handbook |
| 5 | Weeks 9-10 | Fixer's Guidebook |
| 6 | Weeks 11-14 | Bug Hunt |
| 7 | Weeks 15-16 | UI polish & DLC store |
| 8 | Weeks 17-18 | Testing |
| 9 | Weeks 19-20 | Launch prep |

---

## 📂 Data Reorganization

### Core Rules Overview

The base Five Parsecs from Home game includes:
- **4-Phase Campaign Turn**: Travel → World → Battle → Post-Battle
- **8 Crew Tasks**: Find Patron, Train, Trade, Recruit, Explore, Track, Repair, Decoy
- **14 Post-Battle Steps**: Complete campaign management cycle
- **3 Core Species**: Human, Swift, Soulless
- **100-entry tables**: Trade Table, Exploration Table, Loot Table
- **Patron System**: 6 Patron types with jobs, benefits, hazards
- **Rivals System**: Persistent enemies across planets
- **Quest System**: Multi-stage story missions
- **Starship Management**: Hull, debt, fuel, upgrades

### Current State
```
/data/RulesReference/
├── SpeciesList.json        [MIXED: core + DLC]
├── Bestiary.json           [MIXED: core + DLC]
├── EquipmentItems.json     [MIXED: core + DLC]
├── Psionics.json           [DLC only]
└── SalvageJobs.json        [DLC only]
```

### Target State
```
/data/
├── /core_rules/
│   ├── core_species.json
│   ├── core_enemies.json
│   └── core_equipment.json
├── /dlc_trailblazers_toolkit/
│   ├── expanded_species.json
│   └── psionic_powers.json
├── /dlc_freelancers_handbook/
│   └── elite_enemies.json
├── /dlc_fixers_guidebook/
│   ├── stealth_missions.json
│   └── salvage_jobs.json
└── /dlc_bug_hunt/
    └── bug_enemies.json
```

---

## 🔑 Key Systems to Create

### Core Managers
```gdscript
src/core/managers/
├── ExpansionManager.gd      [NEW] - DLC content routing
└── DLCManager.gd            [ENHANCE] - Platform integration

src/core/data/
└── ContentFilter.gd         [NEW] - Ownership filtering
```

### DLC Systems
```gdscript
src/core/dlc/
├── PsionicSystem.gd         [NEW] - TT
├── EliteEnemySystem.gd      [NEW] - FH
├── DifficultyScalingSystem.gd [NEW] - FH
├── StealthMissionSystem.gd  [NEW] - FG
├── SalvageJobSystem.gd      [NEW] - FG
├── LoanManager.gd           [NEW] - FG
└── BugHuntCampaignManager.gd [NEW] - BH
```

---

## 🎨 UI Integration Points

### Main Menu
- Add "DLC Store" button
- Gate "Bug Hunt" button with DLC check
- Show DLC ownership indicators

### Character Creator
- Filter species by DLC ownership
- Show locked species with 🔒 badge
- Add psionic power selection (if TT owned)

### Mission Selection
- Filter missions by DLC ownership
- Show mission type badges
- Display DLC-specific mission icons

### Shop
- Filter equipment by DLC ownership
- Add 🌟 badge to DLC items
- Show DLC name labels

---

## 📊 Testing Matrix

| Test Case | TT | FH | FG | BH | Expected |
|-----------|----|----|----|----|----------|
| Base Only | ❌ | ❌ | ❌ | ❌ | Core only |
| TT Only | ✅ | ❌ | ❌ | ❌ | Psionics + species |
| All DLC | ✅ | ✅ | ✅ | ✅ | Full access |

---

## 💰 Monetization

### Pricing Strategy
- Individual DLC: $4.99 - $9.99
- Complete Compendium Bundle: $19.99 (30% discount)

### Revenue Target
- DLC revenue = 60% of total revenue
- 40% attach rate (40% of base game owners buy at least one DLC)

---

## 🛠️ Development Workflow

### Step 1: Review Planning Docs
```bash
# Read these in order:
1. EXPANSION_CONTENT_MAPPING.md  # Understand what goes where
2. EXPANSION_ADDON_ARCHITECTURE.md # Understand how to build it
3. DLC_SYSTEM_ARCHITECTURE_DIAGRAM.md # Understand the code flow
```

### Step 2: Set Up Environment
```bash
# Create test DLC flags
# In project settings or .env:
DLC_UNLOCK_ALL_IN_EDITOR=true
```

### Step 3: Start Phase 1
```bash
# Begin data separation
# Follow Phase 1 tasks in EXPANSION_ADDON_ARCHITECTURE.md
```

### Step 4: Test Continuously
```bash
# Run tests after each phase
# Verify DLC gating works
# Check content filtering
```

---

## 📋 Checklist for Each DLC

### Pre-Implementation
- [ ] Data files separated
- [ ] Content metadata tagged with DLC ID
- [ ] System architecture designed

### Implementation
- [ ] DLC system created (e.g., PsionicSystem.gd)
- [ ] Content loading integrated
- [ ] DLC gating implemented
- [ ] UI updated with DLC prompts

### Testing
- [ ] Works with DLC enabled
- [ ] Hidden without DLC
- [ ] Purchase prompt functional
- [ ] Save game compatibility verified

### Documentation
- [ ] Feature documentation written
- [ ] API documentation complete
- [ ] Player-facing docs created

---

## 🚨 Common Pitfalls to Avoid

1. **Don't mix DLC content with core content**
   - Always separate data files
   - Always tag with `dlc_required`

2. **Don't skip ownership checks**
   - Every DLC feature must verify ownership
   - Use ExpansionManager.is_expansion_available()

3. **Don't hardcode DLC IDs**
   - Use constants or ExpansionManager registry
   - Keep DLC metadata centralized

4. **Don't forget save compatibility**
   - Always include DLC manifest in saves
   - Handle missing DLC gracefully

5. **Don't block core game**
   - Core game must be fully playable without DLC
   - DLC should enhance, not gate core features

---

## 🔗 Related Documentation

- `/docs/features/dlc_gating_mechanism.md` - Original DLC gating design
- `/docs/features/bug_hunt/bug_hunt_integration.md` - Bug Hunt implementation
- `/docs/features/psionics/psionics_system.md` - Psionics implementation
- `/docs/archive/COMPENDIUM_EXPANSION_ANALYSIS.md` - Expansion analysis

---

## 🎯 Success Criteria

### Technical
- ✅ All DLC content properly gated
- ✅ No performance degradation
- ✅ Save game compatibility maintained
- ✅ Platform purchases working

### Business
- ✅ 40% DLC attach rate
- ✅ <2% refund rate
- ✅ 4.5+ star reviews
- ✅ 60% revenue from DLC

### Player Experience
- ✅ Clear DLC value proposition
- ✅ Smooth purchase flow
- ✅ No confusion about locked content
- ✅ Fair pricing

---

## 📞 Questions?

If you need clarification on any aspect:

1. Check the specific planning document
2. Review the architecture diagram for code flow
3. See the content mapping for "what goes where"
4. Refer to existing docs in `/docs/features/`

---

## 🎉 Next Steps

1. **Get stakeholder approval** on architecture
2. **Set up development branch** for DLC work
3. **Begin Phase 1** (data separation)
4. **Create project board** with tasks from roadmap
5. **Schedule regular check-ins** to track progress

---

**Planning Status:** ✅ Complete
**Implementation Status:** 🚧 Pending
**Approved By:** [Awaiting approval]
**Start Date:** [TBD]

---

*These planning documents were created based on analysis of the `feature/campaign-creation-final` branch and represent the current state of the codebase as of 2025-11-16.*
