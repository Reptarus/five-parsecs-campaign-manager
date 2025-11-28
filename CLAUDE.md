# Five Parsecs Campaign Manager - Living Development Guide

**Last Updated**: 2025-11-27
**Document Version**: 2.2 (Parallel Agent Orchestration Integration)
**Update Trigger**: Refresh when workflow productivity measurably improves from knowledge update

## 📊 EVOLUTION HISTORY - HOW OUR UNDERSTANDING CHANGED

### v1.0 → v2.0 (November 2025)
**What We Believed**:
- Project "85% complete" (vague progress metric)
- Target "20 files" (Framework Bible v1)
- Signal integration gaps at line 1200+ needed fixing
- Memory MCP would be primary tool

**What We Learned**:
- ✅ Project is BETA_READY (94/100) with measurable scorecard
- ✅ 20-file target unrealistic for Godot scene architecture
- ✅ **Evolution**: 518 → 415 → **target range ~150-250 files** (adjustable)
- ✅ Signal integration completed via test-driven QA (Week 3)
- ✅ Desktop Commander is primary tool (Memory MCP unused)

**Productivity Impact**: +300% (8 critical bugs caught by tests vs 0 from code review)

### v2.1 → v2.2 (November 2025)
**What We Believed**:
- Sequential task execution was sufficient
- Single-agent approach for complex tasks
- Manual orchestration of multi-step features

**What We Learned**:
- ✅ Parallel agent execution dramatically increases productivity
- ✅ 5 parallel agents discovered critical architectural insights (gap analysis)
- ✅ Task tool enables true concurrent execution (single message, multiple agents)
- ✅ Specialized agents (godot-specialist, ui-designer, data-architect, qa-specialist, senior-advisor) handle specific domains
- ✅ Complex features benefit from multi-agent approach (UI + Backend + Tests simultaneously)

**Productivity Impact**: Gap analysis with 5 agents discovered "missing systems" actually existed; real issue was JSON integration (would have taken 5 sequential sessions)

### Update Triggers (When to Refresh This Document)
🔄 **Required**: When file count target changes by >25%
🔄 **Required**: When productivity improves >50% from methodology change
🔄 **Required**: When architectural pattern proves superior to current approach
🔄 **Suggested**: Monthly during active development
🔄 **Suggested**: After each major milestone (BETA → PRODUCTION)

---

## 🎯 CURRENT PROJECT STATUS (Auto-Update from WEEK_N_RETROSPECTIVE.md)

**Phase**: BETA_READY (95/100) - Week 4 In Progress
**Source**: WEEK_4_RETROSPECTIVE.md (2025-11-23)
**Next Milestone**: PRODUCTION_CANDIDATE (98/100)

**Production Scorecard**:
- Core Systems: 100% ✅
- Victory Conditions: 100% ✅ (multi-select + custom targets)
- Test Coverage: 96.2% (76/79 tests) ⚠️
- Save/Load: 100% ✅
- Performance: 2-3.3x targets ✅
- File Count: 441 files ⚠️ (target range: 150-250)
- E2E Coverage: 90.9% ⏳ (2 tests failing)
- Data Presentation: ✅ VALIDATED (first successful backend → UI data flow)

**Flexible Targets** (subject to architectural discoveries):
- File consolidation: **150-250 files** (current: 441)
  - Aggressive: 150 files (64% reduction)
  - Realistic: 200 files (52% reduction)
  - Conservative: 250 files (40% reduction)
  - **Principle**: Optimize for maintainability, not arbitrary numbers

---

## 🎯 WEEK 4 OBJECTIVES (Auto-Source from Active TODO List)

**Primary Source**: PROJECT_INSTRUCTIONS.md (96 verified TODOs)
**Secondary**: Git commit messages, test files

### Completed This Week
✅ **Data Persistence & UI Presentation** (Session 2 - 2025-11-18)
   - Crew Management Screen displays crew with Background/Motivation/Class
   - Character Details Screen shows full character info (Origin/Background/Motivation/XP/Stats/Equipment)
   - Equipment system displays items (Infantry Laser, Auto Rifle confirmed)
   - Navigation validated (Crew Management ↔ Character Details ↔ Dashboard)
   - All Resource syntax errors fixed (.has() → "property" in object)
   - **Foundation Proven**: Bespoke character creation now feasible (data flow validated)
   - Known Issues: UI spacing needs refinement, CampaignDashboard missing scene nodes (cosmetic)
   - See: [WEEK_4_SESSION_2_PROGRESS.md](WEEK_4_SESSION_2_PROGRESS.md)

✅ **Core Rules Comparison & Doc Cleanup** (Session 3 - 2025-11-20)
   - Compared codebase against docs/gameplay/rules/core_rules.md
   - **Key Finding**: BattlePhase handler MISSING from CampaignPhaseManager
   - Implementation Status: Character Creation 95%, World Phase 90%, Battle Phase 50%, Post-Battle 75%
   - Estimated 12-17 hours to functional beta (~60% integration, ~40% new implementation)
   - Archived 6 outdated docs, deleted 1 malformed report
   - Created WEEK_4_RETROSPECTIVE.md with comprehensive status

✅ **Victory Condition System Complete** (Session 4 - 2025-11-23)
   - Created CustomVictoryDialog for custom victory targets
   - Enhanced VictoryDescriptions with 17 victory types (full narratives, strategy tips)
   - VictoryProgressPanel now tracks multiple conditions with "closest to completion"
   - Complete data flow wiring: UI → Finalization → GameStateManager
   - Files created: CustomVictoryDialog.gd/.tscn
   - Files modified: VictoryDescriptions, CampaignConfig, ExpandedConfigPanel, VictoryProgressPanel, GameStateManager, CampaignFinalizationService
   - Reduced beta estimate by 2-3 hours

### High Priority (Next Sessions)
1. **Create BattlePhase Handler** (~3-4 hours) 🔴 CRITICAL
   - Create: src/core/campaign/phases/BattlePhase.gd
   - Wire into CampaignPhaseManager alongside Travel/World/PostBattle handlers
   - Connect battle flow: setup → combat → resolution
   - **Blocker for functional beta**

2. **Wire Phase Transitions** (~2-3 hours)
   - Connect CampaignTurnController signals to phase handlers
   - Implement phase-to-phase handoffs
   - Test complete turn loop (Travel → World → Battle → Post-Battle)

3. **Fix E2E Test Failures** (~35 min)
   - Source: tests/legacy/test_campaign_e2e_workflow.gd
   - Blocker: 2 tests failing (equipment field mismatch)
   - Success Metric: 100% test coverage (79/79)

4. **File Consolidation Sprint** (~6-8 hours)
   - Current: 441 files (measured via `find src -name "*.gd" | wc -l`)
   - Target Range: 150-250 files
   - Method: Merge UI components, consolidate systems

### Update This Section When:
- TODO list in PROJECT_INSTRUCTIONS.md changes
- New test files created
- File count reaches target range
- New objectives emerge from testing

---

## 🏗️ CODEBASE REALITY - MEASURED METRICS

**Measurement Date**: 2025-11-16
**Measurement Command**: `find src -name "*.gd" | wc -l` → **441 files**

### Directory Structure (Actual Counts)
```
src/
├── core/ (218 files)          # Largest - consolidation opportunity
├── ui/ (140 files)            # Second largest - scene-based architecture
├── game/ (33 files)
├── data/ (11 files)
├── utils/ (5 files)
├── autoload/ (4 files)
└── (totals verified by actual file count)

tests/ (75+ files)             # Testing infrastructure
```

### Architectural Patterns (Framework Bible Audit)
**Last Audit**: 2025-11-16
**Audit Method**: Search for "Manager", "Coordinator", "Enhanced", "Handler" classes

✅ **Compliant**:
- Autoload singletons: GameState, DiceSystem, SignalBus
- Resource classes with behavior: Character, Enemy, Mission
- Static utilities: DiceSystem.roll(), TableLookup.query()
- Scene-based UI: Self-contained screens

❌ **Violations**: 0 confirmed passive Manager/Coordinator patterns

**Flexibility Note**: Some classes named "*Manager" (e.g., BattleManager) contain actual orchestration logic, not passive delegation. This is acceptable.

### File Count Evolution & Targets
| Date | File Count | Change | Target Range | Status |
|------|-----------|--------|--------------|--------|
| Unknown | 518 | Baseline | - | Bloated |
| Week 3 | 415 | -20% | 150-250 | In Progress |
| Week 4 | 441 | +6% | 150-250 | Active consolidation |

**Update Trigger**: Re-measure after each consolidation sprint

---

## 🎨 UI DESIGN SYSTEM - UNIFIED STYLING

**Source**: `src/ui/screens/campaign/panels/BaseCampaignPanel.gd`
**Implementation Date**: 2025-11-23

All campaign wizard panels inherit design system constants from BaseCampaignPanel. Use these for consistency.

### Spacing System (8px Grid)
```gdscript
SPACING_XS := 4   # Icon padding, label-to-input gap
SPACING_SM := 8   # Element gaps within cards
SPACING_MD := 16  # Inner card padding
SPACING_LG := 24  # Section gaps between cards
SPACING_XL := 32  # Panel edge padding
```

### Touch Target Minimums
```gdscript
TOUCH_TARGET_MIN := 48      # Minimum interactive element height
TOUCH_TARGET_COMFORT := 56  # Comfortable input height
```

### Typography Scale
```gdscript
FONT_SIZE_XS := 11  # Captions, limits
FONT_SIZE_SM := 14  # Descriptions, helpers
FONT_SIZE_MD := 16  # Body text, inputs
FONT_SIZE_LG := 18  # Section headers
FONT_SIZE_XL := 24  # Panel titles
```

### Color Palette - Deep Space Theme
```gdscript
# Backgrounds
COLOR_BASE := Color("#1A1A2E")         # Panel background
COLOR_ELEVATED := Color("#252542")     # Card backgrounds
COLOR_INPUT := Color("#1E1E36")        # Form field backgrounds
COLOR_BORDER := Color("#3A3A5C")       # Card borders

# Accent
COLOR_ACCENT := Color("#2D5A7B")       # Primary accent (Deep Space Blue)
COLOR_ACCENT_HOVER := Color("#3A7199") # Hover state
COLOR_FOCUS := Color("#4FC3F7")        # Focus ring (cyan)

# Text
COLOR_TEXT_PRIMARY := Color("#E0E0E0")   # Main content
COLOR_TEXT_SECONDARY := Color("#808080") # Descriptions
COLOR_TEXT_DISABLED := Color("#404040")  # Inactive

# Status
COLOR_SUCCESS := Color("#10B981")  # Green
COLOR_WARNING := Color("#D97706")  # Orange
COLOR_DANGER := Color("#DC2626")   # Red
```

### Helper Methods Available
All panels extending FiveParsecsCampaignPanel can use:
- `_create_section_card(title, content, description)` - Styled card container
- `_create_labeled_input(label_text, input)` - Label + input pair
- `_create_stat_display(stat_name, value)` - Stat badge
- `_create_stats_grid(stats, columns)` - Grid of stat displays
- `_create_button_group_selector(options, selected_index)` - Toggle buttons
- `_create_character_card(name, subtitle, stats)` - Character display
- `_create_add_button(text)` - Styled add button
- `_style_line_edit(line_edit)` - Apply styling to LineEdit
- `_style_option_button(option_btn)` - Apply styling to OptionButton

### Usage Example
```gdscript
# Creating styled UI elements
func _create_my_input() -> LineEdit:
    var input = LineEdit.new()
    input.placeholder_text = "Enter value..."
    _style_line_edit(input)  # Applies design system styling
    return input

# Using constants
var label = Label.new()
label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

var button = Button.new()
button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
```

### BBCode Colors for RichTextLabel
When using RichTextLabel with BBCode, use hex values:
```gdscript
"[color=#10B981]✅ Success[/color]"  # COLOR_SUCCESS
"[color=#D97706]⚠️ Warning[/color]"  # COLOR_WARNING
"[color=#DC2626]❌ Error[/color]"    # COLOR_DANGER
```

---

## 🧪 TESTING METHODOLOGY - PROVEN EFFECTIVE

**Primary Source**: tests/TESTING_GUIDE.md
**Framework**: gdUnit4 v6.0.1
**Success Metric**: 100% test coverage with 0 regressions

### Current Test Coverage (Auto-Update from TESTING_GUIDE.md)
- Total Tests: 138 passing (100% of created tests)
- Character Advancement: 36 tests ✅
- Injury System: 26 tests ✅
- Loot System: 44 tests ✅
- State Persistence: 32 tests ✅
- E2E Workflow: 20/22 tests ⚠️ (2 failing - IN PROGRESS)

### Week 3 Proven Results
**Methodology**: Test-driven bug discovery
**Results**: 8/8 critical bugs caught by tests (0 by code review)
**Productivity**: +300% bug discovery rate
**Regression Rate**: 0% (all fixes validated)

### Testing Constraints (Empirically Discovered)
⚠️ **NEVER**: Use `--headless` flag (signal 11 crash after 8-18 tests)
✅ **ALWAYS**: Use UI mode via PowerShell
✅ **LIMIT**: Max 13 tests per file (runner stability)
✅ **PATTERN**: Plain helper classes (no Node inheritance)

**Evolution Note**: Originally tried headless mode (failed). UI mode discovered through experimentation. If Godot fixes headless bug, reevaluate.

### Running Tests (Current Working Method)
```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_character_advancement_costs.gd `
  --quit-after 60

# Note: Path has .exe as directory name - this is correct (verified)
```

**Update Trigger**: When test runner changes, Godot version updates, or new testing pattern discovered

---

## 🔧 MCP TOOLS - EMPIRICALLY VALIDATED WORKFLOW

**Measurement**: Based on actual command history & productivity metrics

### Tools Actually Used Daily
#### Desktop Commander (Primary - 90% of operations)
- `read_file`: File inspection before edits
- `edit_block`: Surgical edits (exact string replacement)
- `search_code`: Pattern finding across codebase

#### Git (Version Control - 100% of commits)
- All changes tracked
- Descriptive commit messages
- No force pushes to main

#### Task Tool - Parallel Agent Orchestration (See detailed section below)
- Launch multiple specialized agents concurrently for complex tasks
- Maximize parallelism for analysis, implementation, and testing
- Use single message with multiple agent invocations whenever possible

### Tools NOT Used (Despite CLAUDE.md v1.0 Recommendations)
❌ **Memory MCP**: Never used in practice (workflow doesn't need it)
❌ **Gemini Orchestrator**: Not integrated (manual analysis sufficient)
❌ **Context7**: Not used (official Godot docs preferred)
❌ **Godot MCP test runner**: Replaced by PowerShell (headless bug workaround)

**Evolution Note**: v1.0 assumed Memory MCP would be primary. Practice proved Desktop Commander + Git + Parallel Agents more effective. Keep flexibility to add tools if productivity improves.

### Actual Workflow (Empirically Optimized with Parallel Agents)
```
1. Read project status: WEEK_N_RETROSPECTIVE.md
2. Check tests: TESTING_GUIDE.md
3. Read source: Desktop Commander read_file
4. **NEW: Launch parallel agents for complex tasks** (see section below)
5. Edit surgically: Desktop Commander edit_block
6. Test via PowerShell: (not Godot MCP)
7. Validate: git diff
8. Document: Update .md files
9. Commit: git commit -m "descriptive message"
```

**Update Trigger**: When new tool proves >25% productivity improvement over current workflow

---

## 🤖 PARALLEL AGENT ORCHESTRATION - MAXIMIZE PRODUCTIVITY

**Core Principle**: Launch multiple specialized agents concurrently whenever possible to maximize performance.
**Proven Impact**: 5 parallel agents analyzed gap report in previous session, discovering critical architectural insights.

### Available Specialized Agents

#### **godot-technical-specialist**
**Use For**: Implementing Godot 4.5 technical solutions
- Signal architecture (call-down-signal-up patterns)
- UI container systems (VBoxContainer, HBoxContainer, ResponsiveContainer)
- Mobile optimization (touch targets, responsive breakpoints)
- Scene tree organization
- GDScript performance optimization

**Examples**: Character card with signals, crew roster performance, panel signal connections, responsive layouts

#### **five-parsecs-ui-designer**
**Use For**: UI/UX design for Five Parsecs Campaign Manager
- Wireframes and component layouts
- Responsive breakpoints (mobile-first)
- Tabletop companion app best practices
- Infinity Army hyperlinked rules standard
- Touch target compliance audits

**Examples**: Character details screen design, battle HUD mobile layout, crew management touch compliance

#### **campaign-data-architect**
**Use For**: Save/load systems, data persistence, Resource schemas
- Designing data structures for game features
- Save file versioning and migration
- Preventing circular references in Resources
- Import/export functionality
- Debugging save corruption

**Examples**: Ship upgrades persistence, save migration paths, undo/redo systems

#### **qa-integration-specialist**
**Use For**: Testing, integration validation, quality assurance
- Writing GDUnit4 test suites
- Validating signal flows (UI/State/Backend)
- Testing edge cases in procedural systems
- Performance profiling for mobile
- Save/load corruption testing
- Regression test creation

**Examples**: Test suites for new systems, signal flow validation, mobile performance benchmarks

#### **senior-dev-advisor**
**Use For**: Production-ready code, architecture decisions, debugging
- Full-stack features with error handling
- Technology stack recommendations
- Complex issue debugging
- Scalable system design
- Security and compliance

**Examples**: Authentication systems, database selection, performance debugging

---

### When to Use Parallel Agents

#### **ALWAYS Launch in Parallel When**:
✅ Complex multi-step feature spanning UI + Backend + Tests
✅ Gap analysis requiring multiple perspectives (architecture, data, UI, testing)
✅ Independent analysis tasks (e.g., UI review + data model audit)
✅ Simultaneous implementation + testing (e.g., feature code + test suite)

#### **Real Project Examples**:

**Victory Condition System (Ideal for 4 Parallel Agents)**:
- Agent 1 (five-parsecs-ui-designer): Design victory condition selection UI
- Agent 2 (godot-technical-specialist): Implement UI components with signals
- Agent 3 (campaign-data-architect): Design save/load for victory progress
- Agent 4 (qa-integration-specialist): Create test suite for victory system

**Gap Analysis (Proven Successful - 5 Parallel Agents)**:
- Agent 1 (godot-technical-specialist): Audit signal integration gaps
- Agent 2 (five-parsecs-ui-designer): Review UI component hierarchy
- Agent 3 (campaign-data-architect): Analyze data persistence gaps
- Agent 4 (qa-integration-specialist): Identify missing test coverage
- Agent 5 (senior-dev-advisor): Review architecture patterns
Result: Discovered "missing systems" actually existed; real gap was JSON integration

**Performance Fix + Prevention (2 Parallel Agents)**:
- Agent 1 (godot-technical-specialist): Fix crew roster frame drops
- Agent 2 (qa-integration-specialist): Create regression test for performance

---

### How to Launch Parallel Agents

**CRITICAL**: Use **single message** with multiple Task tool invocations for true parallelism.

#### Decision Matrix: When to Use Which Agents

| Task Type | Agent Combination | Expected Output |
|-----------|------------------|-----------------|
| New UI Feature | ui-designer + godot-specialist + qa-specialist | Mockup + Implementation + Tests |
| Data Model Change | data-architect + godot-specialist + qa-specialist | Schema + Integration + Tests |
| Performance Issue | godot-specialist + qa-specialist | Fix + Regression Test |
| Complex Feature | All 5 agents | Design + Code + Data + Tests + Review |
| Bug Investigation | senior-dev-advisor + qa-specialist | Root Cause + Prevention Test |
| Architecture Review | senior-dev-advisor + data-architect + godot-specialist | Analysis + Recommendations |

---

### Parallel Agent Best Practices

#### ✅ DO:
- Launch agents in **single message** (enables true parallelism)
- Give each agent **specific, independent tasks**
- Provide **detailed context** in each agent's prompt
- Specify **exactly what to return** (files, analysis, recommendations)
- Use agents for **complex multi-step work** (not simple edits)

#### ❌ DON'T:
- Launch agents **sequentially** in separate messages (loses parallelism)
- Give agents **dependent tasks** (Agent 2 needs Agent 1's output)
- Use agents for **simple file edits** (use Desktop Commander instead)
- Launch agents **without clear deliverables**
- Mix agent tasks with **manual edits** in same workflow step

---

### Evolution Note: Agent Usage

**Week 3**: Discovered parallel agents via gap analysis (5 agents, major productivity boost)
**Week 4**: Standardizing parallel agent usage in CLAUDE.md
**Future**: Track agent productivity metrics, add new specialized agents as needed

**Update Trigger**: When new agent types added, productivity patterns change, or better orchestration discovered

---

## 📖 FRAMEWORK PRINCIPLES - EVOLUTION-FRIENDLY

**Source**: REALISTIC_FRAMEWORK_BIBLE.md
**Philosophy**: Principles over prescriptions, flexibility over rigidity

### File Count Philosophy (Evolution Acknowledged)
**v1.0 Belief**: "Maximum 20 files across entire project"
**v1.5 Learning**: "Realistic target: 75 core files"
**v2.0 Reality**: "Target range: 150-250 files based on architectural needs"

**Current Principle**:
> Optimize for maintainability and architectural clarity, not arbitrary numbers.
> If 300 files is more maintainable than 200, use 300.
> If 150 files achieves same functionality, use 150.
> **Measure**: Can a new developer understand the system in <1 day?

### Pattern Prohibitions (Empirically Validated)
✅ **Confirmed Violations**: 0 passive Manager/Coordinator classes
✅ **Principle**: Avoid delegation-only classes with no domain logic
✅ **Acceptable**: Classes named "*Manager" that contain orchestration logic

**Flexibility Note**: If a passive coordinator proves more maintainable than alternatives, document the reasoning and use it. Principles guide, not mandate.

### Architecture Principles (Proven Effective)
1. **Autoload for global state** - Works well for GameState, DiceSystem
2. **Resource classes with behavior** - Effective for Character, Enemy
3. **Scene-based UI** - Godot's native pattern, proven scalable
4. **Test-driven development** - 300% productivity improvement validated

**Update Trigger**: When principle proves counterproductive or superior pattern discovered

---

## 📝 CONFIGURATION (Auto-Verify These Paths)

```bash
# Verify with: Test-Path "C:\path\to\file"
PROJECT_ROOT: C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\
GODOT_CONSOLE: C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe
GODOT_VERSION: 4.5.1-stable (non-mono)

# Note: .exe in path is a directory name - verified correct
```

### Key Documentation (Auto-Reference Latest)
- **WEEK_N_RETROSPECTIVE.md** - Project status source of truth
- **TESTING_GUIDE.md** - Testing methodology & results
- **REALISTIC_FRAMEWORK_BIBLE.md** - Flexible constraints
- **PROJECT_INSTRUCTIONS.md** - Verified TODO roadmap

**Update Trigger**: When new WEEK_N_RETROSPECTIVE.md created or doc structure changes

---

## ⚡ QUICK REFERENCE - CURRENT BEST PRACTICES

### Session Start Checklist
☑ Read WEEK_N_RETROSPECTIVE.md (current project status)
☑ Check TESTING_GUIDE.md (test status & failures)
☑ Review `git log --oneline -10` (recent changes)
☑ Scan PROJECT_INSTRUCTIONS.md (active TODOs)

### Before Starting Complex Work
☑ **Assess task complexity**: Simple edit vs multi-step feature?
☑ **Identify agent needs**: Which specialized agents would help?
☑ **Plan parallel execution**: Can agents work simultaneously?
☑ **Prepare agent prompts**: Detailed, specific, independent tasks

### For Complex Multi-Step Features (Use Parallel Agents)
☑ Identify task components: UI + Backend + Data + Tests
☑ Match components to agents:
  - UI design → five-parsecs-ui-designer
  - Technical implementation → godot-technical-specialist
  - Data/persistence → campaign-data-architect
  - Testing/validation → qa-integration-specialist
  - Architecture review → senior-dev-advisor
☑ Launch agents **in single message** (multiple Task calls)
☑ Provide detailed context in each agent prompt
☑ Specify exact deliverables expected from each agent

### For Simple Edits (Use Desktop Commander)
☑ Desktop Commander: `read_file` (understand context)
☑ Identify exact `old_string` for surgical edit
☑ Plan `new_string` replacement
☑ Never guess - always read first
☑ Use `edit_block` for surgical changes

### After Any Change
☑ Run affected tests (PowerShell, not Godot MCP)
☑ Validate: `git diff` (review changes)
☑ Check regressions: Run test suite
☑ Update docs if methodology changed
☑ Commit with descriptive message

### Agent Selection Quick Guide
- **New Feature (UI + Code + Tests)**: 3-4 agents (ui-designer, godot-specialist, qa-specialist, optionally data-architect)
- **Architecture Review**: 2-3 agents (senior-advisor, data-architect, godot-specialist)
- **Performance Fix**: 2 agents (godot-specialist, qa-specialist)
- **Data Model Change**: 3 agents (data-architect, godot-specialist, qa-specialist)
- **Bug Investigation**: 2 agents (senior-advisor, qa-specialist)
- **Simple Edit/Fix**: 0 agents (use Desktop Commander directly)

### Update This Guide When
🔄 File count target changes by >25%
🔄 Productivity improves >50% from new workflow
🔄 New architectural pattern proves superior
🔄 Testing framework changes (Godot update, etc.)
🔄 Monthly review during active development

**Philosophy**: This guide evolves with understanding. Rigidity causes obsolescence. Flexibility enables continuous improvement.
