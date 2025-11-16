# Five Parsecs Campaign Manager - Expansion Documentation Index

## Overview

This index provides a complete overview of all expansion and DLC documentation for the Five Parsecs Campaign Manager. The documentation is organized into four major categories: **Integration Guides**, **Content Creation**, **Technical References**, and **Community Resources**.

**Total Documentation**: ~15,000 lines across 11 comprehensive guides

---

## Quick Navigation

### For Players
- [Bug Hunt Integration](./BUG_HUNT_INTEGRATION.md) - Alternative campaign mode documentation

### For Content Creators
- **START HERE**: [Content Creation Guide](./CONTENT_CREATION_GUIDE.md) - Create species, powers, enemies, equipment, missions
- [Data Format Specifications](./DATA_FORMAT_SPECIFICATIONS.md) - JSON schemas and validation
- [Testing & Validation Guide](./TESTING_VALIDATION_GUIDE.md) - Balance testing and quality assurance

### For Developers
- [Trailblazer's Toolkit Integration](./expansions/TRAILBLAZERS_TOOLKIT_INTEGRATION.md) - Psionic & species systems
- [Freelancer's Handbook Integration](./expansions/FREELANCERS_HANDBOOK_INTEGRATION.md) - Elite enemies & difficulty
- [Fixer's Guidebook Integration](./expansions/FIXERS_GUIDEBOOK_INTEGRATION.md) - Mission systems

### For Modders
- [Custom Expansion Creation Guide](./CUSTOM_EXPANSION_CREATION_GUIDE.md) - Build full expansion packs
- [Testing & Validation Guide](./TESTING_VALIDATION_GUIDE.md) - Balance testing and QA methodology
- [Data Format Specifications](./DATA_FORMAT_SPECIFICATIONS.md) - Complete JSON reference

---

## Documentation Categories

### 1. Integration Guides

Complete technical documentation for each official expansion DLC.

#### Trailblazer's Toolkit Integration
**File**: `docs/expansions/TRAILBLAZERS_TOOLKIT_INTEGRATION.md`
**Size**: ~75KB, ~1,900 lines
**Last Updated**: 2024

**Contents**:
- PsionicSystem architecture (10 powers, activation mechanics, duration tracking)
- Species system (Krag & Skulker with full mechanical breakdown)
- Power activation flow (4 steps: validation, roll, effect, tracking)
- Integration with core combat and character creation
- Adding new psionic powers (step-by-step guide with examples)
- Adding new species (design, balance, implementation)
- 5 complete code examples (psyker creation, combat, species, learning, etc.)
- Troubleshooting (5 common problems with solutions)
- Advanced topics (custom effects, psionic items)

**Key Features**:
- 10 psionic powers documented (Barrier, Grab, Lift, Push, Sever, Shielding, Step, Stun, Suggestion, Weaken)
- 2 playable species (Krag: +1 Tough -1" Speed, Skulker: +1" Speed +Bio Resistance)
- Power difficulty levels (Basic 4+, Intermediate 5+, Advanced 6-7+)
- Complete activation mechanics (1D6 + Savvy vs target number)

#### Freelancer's Handbook Integration
**File**: `docs/expansions/FREELANCERS_HANDBOOK_INTEGRATION.md`
**Size**: ~77KB, ~1,950 lines
**Last Updated**: 2024

**Contents**:
- EliteEnemySystem architecture (6 elite enemies, deployment modes)
- DifficultyScalingSystem architecture (8 modifiers, 5 presets, adaptive/progressive)
- Elite enemy mechanics (stat comparison, abilities, deployment points)
- Difficulty modifier system (categories, stacking, mechanical changes)
- Integration with core combat, injuries, rewards
- Adding new elite enemies (design, stats, abilities, costing)
- Adding new difficulty modifiers (design, implementation)
- 5 complete code examples (squad generation, boss battles, presets, etc.)
- Troubleshooting (4 common problems with solutions)
- Best practices (deployment modes, balancing, testing)

**Key Features**:
- 6 elite enemy types (Elite Mercenary, Corporate Enforcer, Veteran Raider, Alien Hunter, Psionic Adept, Pack Alpha)
- 8 difficulty modifiers (Brutal Foes, Larger Battles, Veteran Opposition, Elite Foes, Desperate Combat, Scarcity, High Stakes, Lethal Encounters)
- 4 deployment modes (standard_replacement, elite_only_battles, mixed_squads, boss_battles)
- Progressive difficulty (auto-scales over campaign)
- Adaptive difficulty (responds to win/loss streaks)

#### Fixer's Guidebook Integration
**File**: `docs/expansions/FIXERS_GUIDEBOOK_INTEGRATION.md`
**Size**: ~82KB, ~2,100 lines
**Last Updated**: 2024

**Contents**:
- StealthMissionSystem architecture (alarm system, detection, objectives)
- SalvageJobSystem architecture (tension system, encounters, discoveries)
- Stealth mission mechanics (alarm 0-5, detection rolls, special terrain)
- Salvage mission mechanics (tension 0-10, discovery table, encounter tables)
- Other mission types (street fights, expanded opportunities)
- Integration with core combat and rewards
- Adding new mission types (5-step process with Data Heist example)
- 5 complete code examples (stealth flow, salvage flow, detection, discovery, etc.)
- Troubleshooting (4 common problems with solutions)
- Best practices (balancing tension, counterplay, signals, testing)

**Key Features**:
- 2 stealth mission types (Corporate Infiltration, Warehouse Heist)
- 2 salvage job types (Derelict Ship, Abandoned Colony)
- Alarm system (0-5 levels with progressive effects)
- Tension system (0-10 levels with encounter tables)
- Salvage discovery table (1D10 rolls from nothing to rare finds)
- Detection mechanics (1D6 + Savvy + Cover vs Savvy)

#### Bug Hunt Integration
**File**: `docs/BUG_HUNT_INTEGRATION.md`
**Size**: ~92KB, ~1,800 lines
**Created**: Previous session

**Contents**:
- Complete Bug Hunt campaign mode documentation
- 90% code reuse demonstration
- 5 specialized systems (Panic, MotionTracker, Infestation, MilitaryHierarchy, CharacterTransfer)
- Bug Hunt vs Five Parsecs comparison
- Integration patterns and extensibility

**Key Features**:
- Alternative campaign mode (military vs bugs)
- 5 specialized systems fully integrated with core
- Character transfer (bidirectional Five Parsecs ↔ Bug Hunt)
- 90% code reuse template for future campaign modes

---

### 2. Content Creation

Practical guides for creating custom game content.

#### Content Creation Master Guide
**File**: `docs/CONTENT_CREATION_GUIDE.md`
**Size**: ~103KB, ~1,900 lines
**Last Updated**: 2024

**Contents**:
- **Creating Species** (~400 lines)
  - Design template (culture, strengths, weaknesses)
  - Stat balance guidelines (sum to ~0)
  - Special rule design principles
  - Complete Crystalline species example
  - Full JSON + optional GDScript implementation

- **Creating Psionic Powers** (~350 lines)
  - Power design questions
  - Balance costing (Basic 3-4 XP, Intermediate 4-5 XP, Advanced 5-7 XP)
  - Effect design principles
  - Complete Crystal Armor power example
  - Full JSON + optional implementation

- **Creating Elite Enemies** (~450 lines)
  - Base enemy selection
  - Stat enhancement guidelines
  - Ability design (2-3 abilities)
  - Deployment point costing formula
  - Complete Void Raider example
  - Full JSON with lore

- **Creating Equipment & Weapons** (~400 lines)
  - Item role design
  - Weapon stat balance table
  - Special rules examples
  - Complete equipment set (Plasma Cutter, Reflective Cloak, Grav Boots)
  - Full JSON for all types

- **Creating Mission Types** (~500 lines)
  - Mission concept design
  - Core mechanics design
  - Multi-part objectives
  - Complete Asteroid Mining Raid mission
  - Full JSON + optional OxygenSystem implementation

- **Testing & Publishing** (~250 lines)
  - Balance testing checklist
  - Test script templates
  - Content pack structure
  - README template
  - Sharing platforms

**Target Audience**: Content creators, modders, community contributors

**Prerequisites**: JSON knowledge, basic game design understanding

---

### 3. Technical References

#### Data Format Specifications
**File**: `docs/DATA_FORMAT_SPECIFICATIONS.md`
**Size**: ~113KB, ~1,700 lines
**Last Updated**: 2024-11-16

**Contents**:
- **General JSON Conventions** (~100 lines)
  - Formatting standards
  - Naming conventions
  - Common field types

- **Core Content Types** (~900 lines)
  - Species format (complete schema, examples, validation)
  - Psionic powers format (all fields, balance tiers)
  - Elite enemies format (deployment point formula)
  - Difficulty modifiers format (stacking rules)
  - Equipment & weapons format (DPR calculations)

- **Mission Content Types** (~600 lines)
  - Stealth missions format (alarm system, detection)
  - Salvage jobs format (tension system, discoveries)
  - General missions format (all mission types)

- **Validation Rules** (~100 lines)
  - File-level validation
  - Content-specific validation
  - Cross-reference validation
  - Balance validation

- **Common Patterns** (~100 lines)
  - Dice notation
  - Range notation
  - Stat modifiers
  - Duration formats

**Key Features**:
- Complete JSON schemas for 8 content types
- 90+ field definitions
- 15+ complete examples
- 50+ validation rules
- Alphabetical field reference index

**Target Audience**: Content creators, developers, modders

**Prerequisites**: JSON knowledge

---

### 4. Expansion Creation Guides

#### Custom Expansion Creation Guide
**File**: `docs/CUSTOM_EXPANSION_CREATION_GUIDE.md`
**Size**: ~122KB, ~1,850 lines
**Last Updated**: 2024-11-16

**Contents**:
- **Expansion Planning** (~300 lines)
  - Concept and theme development
  - Content design templates
  - System design (if needed)
  - Scope and timeline estimation

- **Setting Up Your Expansion** (~150 lines)
  - Directory structure
  - Naming conventions
  - File organization

- **Creating the Expansion Manifest** (~150 lines)
  - Manifest schema
  - Versioning (semantic versioning)
  - Dependencies and requirements

- **Building Specialized Systems** (~400 lines)
  - When to create a system
  - System architecture pattern
  - Complete ReputationSystem example
  - System registration

- **Creating Content Data Files** (~300 lines)
  - Species file examples
  - Elite enemies file examples
  - Weapons and gear file examples
  - Missions file examples

- **Integration with Core Systems** (~150 lines)
  - ContentFilter integration
  - ExpansionManager integration
  - Integration points and hooks

- **Testing Your Expansion** (~150 lines)
  - Testing checklist
  - Test script examples
  - Balance testing methodology

- **Publishing and Distribution** (~250 lines)
  - Documentation templates
  - Installation guides
  - Packaging and release process
  - Distribution platforms
  - Licensing

**Complete Example**: "Void Raiders" expansion
- 2 species (Voidborn, Krokar)
- 4 elite enemies
- 8 weapons, 6 gear items
- 6 missions
- 2 custom systems (ReputationSystem, BlackMarketSystem)

**Key Features**:
- Full end-to-end expansion creation workflow
- Working "Void Raiders" expansion example
- ReputationSystem and BlackMarketSystem code
- Complete file structure and organization
- Publishing and licensing guidance

**Target Audience**: Modders, advanced content creators

**Prerequisites**: GDScript knowledge, expansion planning

---

### 5. Testing & Quality Assurance

#### Testing & Validation Guide
**File**: `docs/TESTING_VALIDATION_GUIDE.md`
**Size**: ~109KB, ~1,650 lines
**Last Updated**: 2024-11-16

**Contents**:
- **Testing Philosophy** (~100 lines)
  - Core principles
  - Testing pyramid (40% validation, 30% functional, 20% integration, 10% playtesting)
  - Test-driven development

- **Validation Levels** (~150 lines)
  - Level 1: Syntax validation
  - Level 2: Schema validation
  - Level 3: Content validation
  - Level 4: Functional validation
  - Level 5: Balance validation

- **JSON Validation** (~200 lines)
  - Syntax validation tools
  - Schema validation (JSON Schema)
  - Custom validation scripts (Python examples)

- **Content Balance Validation** (~300 lines)
  - Species balance (net-zero rule, calculations)
  - Elite enemy balance (deployment point formula)
  - Weapon balance (DPR calculations)
  - Mission balance (completion rate targets)

- **Functional Testing** (~250 lines)
  - Loading tests
  - Display tests
  - Functionality tests
  - GDScript test examples

- **Integration Testing** (~200 lines)
  - Compatibility testing
  - Dependency testing
  - Conflict testing
  - Regression testing

- **Playtesting Methodology** (~300 lines)
  - Structured playtesting
  - Metrics to track (quantitative and qualitative)
  - Playtest feedback forms
  - Iteration based on feedback

- **Automated Testing** (~200 lines)
  - GUT (Godot Unit Test) setup
  - Complete test suite example
  - Continuous integration (GitHub Actions)

- **Community Testing** (~100 lines)
  - Beta testing program
  - Feedback collection
  - Managing feedback

**Key Features**:
- Complete testing methodology from JSON to gameplay
- Automated test scripts and examples
- GUT test suite for ReputationSystem (15+ tests)
- Playtesting metrics and feedback forms
- Certification checklist for release readiness

**Target Audience**: Content creators, modders, QA testers

**Prerequisites**: Basic testing concepts, Python/GDScript for automation

---

### 6. Technical References (Detailed)

#### System Deep Dives
**Status**: Detailed in integration guides

**Available References**:
- **PsionicSystem**: See Trailblazer's Toolkit Integration, "PsionicSystem Architecture" section
  - Complete API documentation
  - Signal reference
  - Method signatures
  - Integration hooks

- **EliteEnemySystem**: See Freelancer's Handbook Integration, "EliteEnemySystem Architecture" section
  - Complete API documentation
  - Deployment modes
  - Cost calculation
  - Ability system

- **DifficultyScalingSystem**: See Freelancer's Handbook Integration, "DifficultyScalingSystem Architecture" section
  - Complete API documentation
  - Modifier application
  - Progressive/adaptive difficulty
  - Campaign stats

- **StealthMissionSystem**: See Fixer's Guidebook Integration, "StealthMissionSystem Architecture" section
  - Complete API documentation
  - Alarm mechanics
  - Detection system
  - Objective tracking

- **SalvageJobSystem**: See Fixer's Guidebook Integration, "SalvageJobSystem Architecture" section
  - Complete API documentation
  - Tension mechanics
  - Encounter system
  - Discovery tables

---

## Documentation Statistics

### Total Coverage

| Category | Documents | Lines | Size |
|----------|-----------|-------|------|
| Integration Guides | 4 | ~7,750 | ~326KB |
| Content Creation | 1 | ~1,900 | ~103KB |
| Bug Hunt DLC | 1 | ~1,800 | ~92KB |
| Technical References | 1 | ~1,700 | ~113KB |
| Expansion Creation | 1 | ~1,850 | ~122KB |
| Testing & QA | 1 | ~1,650 | ~109KB |
| **Total** | **9** | **~16,650** | **~865KB** |

### Content Breakdown

**By Document**:
- Trailblazer's Toolkit Integration: ~1,900 lines
- Freelancer's Handbook Integration: ~1,950 lines
- Fixer's Guidebook Integration: ~2,100 lines
- Bug Hunt Integration: ~1,800 lines
- Content Creation Guide: ~1,900 lines
- Data Format Specifications: ~1,700 lines
- Custom Expansion Creation Guide: ~1,850 lines
- Testing & Validation Guide: ~1,650 lines
- Bug Hunt Data Files: ~2,000 lines (JSON)

**By Type**:
- Architecture documentation: ~30%
- Code examples: ~20%
- Data format specifications: ~15%
- Testing & validation: ~15%
- Design guidelines: ~10%
- Troubleshooting & best practices: ~10%

---

## Documentation Quality Standards

All documentation follows these standards:

### Completeness
- ✅ Every system has architecture overview
- ✅ Every feature has working code examples
- ✅ Every data format has complete JSON schema
- ✅ Every guide has troubleshooting section

### Clarity
- ✅ Specific numbers, not vague descriptions
- ✅ Complete working examples, not fragments
- ✅ Clear prerequisites and assumptions
- ✅ Consistent terminology throughout

### Usability
- ✅ Table of contents for navigation
- ✅ Quick reference tables
- ✅ Code examples with explanations
- ✅ Cross-references between guides

### Maintenance
- ✅ Version information
- ✅ Last updated dates
- ✅ Consistent formatting
- ✅ Git commit history

---

## Using This Documentation

### As a Player

**Goal**: Understand expansion features

1. Start with integration guides for expansions you own
2. Read "Overview" and "Contents" sections
3. Focus on mechanics sections relevant to your gameplay

### As a Content Creator

**Goal**: Create custom species, powers, enemies, or missions

1. **START HERE**: Read [Content Creation Guide](./CONTENT_CREATION_GUIDE.md)
2. Follow step-by-step instructions for your content type
3. Reference integration guides for detailed format specifications
4. Test your content using provided test templates

### As a Developer

**Goal**: Understand system architecture for integration or extension

1. Read relevant integration guide (Trailblazer's, Freelancer's, or Fixer's)
2. Study "Architecture" sections for system design
3. Review "Integration with Core Systems" sections
4. Examine code examples for implementation patterns

### As a Modder

**Goal**: Build complete expansion packs

1. Read [Content Creation Guide](./CONTENT_CREATION_GUIDE.md)
2. Study all three expansion integration guides for patterns
3. Review [Bug Hunt Integration](./BUG_HUNT_INTEGRATION.md) for campaign mode creation
4. Follow publishing guidelines in Content Creation Guide

---

## Roadmap & Future Documentation

### Planned Additions

**Phase 1: Specifications** (Next)
- Consolidated data format specification document
- JSON schema files for validation
- Data validation testing tools

**Phase 2: Advanced Guides**
- Custom expansion creation guide (full expansion packs)
- Testing & validation methodology
- Community content guidelines
- UI integration guide

**Phase 3: Examples**
- Community content showcase
- Template expansion pack
- Modding tutorials
- Video documentation

### Contributing to Documentation

Documentation contributions are welcome! Guidelines:

1. **Match existing style**: Follow format and tone of current docs
2. **Be specific**: Include exact numbers, working code examples
3. **Test examples**: All code examples must be tested and working
4. **Cross-reference**: Link to related documentation
5. **Update index**: Add new docs to this index

**Contact**: Submit issues or PRs to the GitHub repository

---

## Frequently Asked Questions

### General

**Q: Where do I start if I'm new to Five Parsecs?**
A: Start with the core game rules, then read the Bug Hunt Integration guide to see how expansions work.

**Q: Can I create content without coding knowledge?**
A: Yes! Most content (species, powers, enemies, equipment, missions) only requires JSON editing. See Content Creation Guide.

**Q: Are the expansions compatible with each other?**
A: Yes, all expansions are designed to work together. They use the same core systems and data structures.

### For Content Creators

**Q: How do I balance my custom species?**
A: Follow the "net-zero" guideline: total stat modifiers should sum to ~0. See Content Creation Guide, "Creating Species" section.

**Q: What deployment cost should my elite enemy have?**
A: Use the formula in Freelancer's Handbook Integration, "Deployment Point System" section. Generally: 2-3 DP for standard elites, 4-5 DP for powerful elites.

**Q: Can I create custom campaign modes like Bug Hunt?**
A: Yes! Study the Bug Hunt Integration guide for the 90% code reuse pattern. Most custom modes reuse core systems with specialized overlays.

### For Developers

**Q: How do systems communicate?**
A: Via Godot signals. See any integration guide's "Architecture" section for signal definitions.

**Q: Can I modify core systems?**
A: You can, but it's recommended to extend instead. Create specialized systems that integrate with core rather than modifying core code.

**Q: Where should I put custom system code?**
A: `src/core/systems/YourCustomSystem.gd` for systems, `data/dlc/your_expansion/` for data.

---

## Version History

### Version 2.1 (Current)
**Date**: 2024-11-16
**Changes**:
- Added Data Format Specifications (complete JSON reference)
- Added Custom Expansion Creation Guide (full modding workflow)
- Added Testing & Validation Guide (QA methodology)
- Updated documentation index
- Added ~5,200 lines of new documentation
- Total documentation now ~16,650 lines across 9 documents

### Version 2.0
**Date**: 2024-11-16
**Changes**:
- Added three expansion integration guides (Trailblazer's, Freelancer's, Fixer's)
- Created comprehensive content creation guide
- Updated Bug Hunt documentation
- Added ~10,000 lines of new documentation
- Consolidated data format specifications

### Version 1.0
**Date**: Previous
**Changes**:
- Initial documentation
- Bug Hunt DLC integration guide
- Core system references

---

## Support & Resources

### Official Resources
- **GitHub Repository**: [Link to repo]
- **Game Rules**: Five Parsecs from Home core rulebook
- **Community Forum**: [Link to forum]

### Community Resources
- **Discord**: [Link to Discord server]
- **Content Sharing**: [Link to content repository]
- **Bug Reports**: GitHub Issues

### Credits

**Documentation Authors**:
- Core documentation: [Authors]
- Expansion guides: Claude (AI Assistant)
- Community contributions: [Contributors]

**Special Thanks**:
- Five Parsecs from Home creators
- Community testers and content creators
- Open source contributors

---

## License

Documentation is licensed under CC-BY-4.0 (Creative Commons Attribution 4.0 International).

You are free to:
- **Share**: Copy and redistribute the material
- **Adapt**: Remix, transform, and build upon the material

Under these terms:
- **Attribution**: Give appropriate credit
- **No additional restrictions**: Don't apply legal terms or technological measures that restrict others

---

**Last Updated**: 2024-11-16
**Documentation Version**: 2.1
**Maintained By**: Five Parsecs Campaign Manager Development Team
