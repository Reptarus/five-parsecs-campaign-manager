# Wizard UI/UX Research - Executive Summary

**Date**: 2025-11-23
**Status**: Research Complete - Ready for Implementation
**Documents Created**: 2 detailed guides

---

## KEY FINDINGS

### What Already Exists (The Good News ✅)

The codebase has **world-class foundations** for wizard UI:

1. **Multi-Panel Architecture** (7 sequential panels)
   - ConfigPanel → CaptainPanel → CrewPanel → ShipPanel → EquipmentPanel → WorldInfoPanel → FinalPanel
   - Each panel is self-contained, testable, and reusable
   - Framework Bible compliant (minimal, focused design)

2. **Coordinator Pattern** (Excellent workflow orchestration)
   - Manages step progression and state
   - Emits signals for navigation, validation, and state changes
   - Already tracks completion status
   - Handles both back/forward and jump navigation

3. **Signal-Based Communication** (Loose coupling)
   - Panels emit: `panel_data_changed`, `panel_validation_changed`, `panel_completed`, `validation_failed`
   - Coordinator emits: `step_changed`, `navigation_updated`, `campaign_state_updated`
   - Perfect for adding wizard components without coupling

4. **Theme System** (6 variants ready to use)
   - base_theme.tres (foundation)
   - dark_theme.tres, light_theme.tres, sci_fi_theme.tres, high_contrast_theme.tres
   - Theme support built into all UI components

5. **Tooltip System** (Production-ready)
   - Intelligent positioning (AUTO, TOP, BOTTOM, LEFT, RIGHT, etc.)
   - Delay configurable (default 0.5s show, 0.1s hide)
   - BBCode support for formatted text
   - Static helper methods for easy integration
   - Already used throughout campaign creation UI

6. **Responsive Layout** (Mobile/Tablet/Desktop)
   - Breakpoints defined and working
   - ResponsiveContainer base class available
   - Campaign screens already support multiple resolutions

---

### What's Missing (The Gaps ⚠️)

Three categories of missing UI elements:

#### 1. Progress Indication (Critical)
- ❌ No visual step indicator (which step am I on?)
- ❌ No progress bar
- ❌ No breadcrumb navigation
- ❌ No completion checkmarks

**Impact**: Users don't know how far through the wizard they are or what's coming next

#### 2. Validation & Error Feedback (Partial Gap)
- ✅ Validation logic exists in panels
- ❌ No real-time field validation UI
- ❌ No inline error messages
- ❌ No field highlighting for errors
- ❌ No success state indicators

**Impact**: Users don't know what's wrong with their input until they try to advance

#### 3. Contextual Help (Significant Gap)
- ❌ No help system for each step
- ❌ No rule references integrated
- ❌ No examples shown to users
- ❌ No explanations of mechanics
- ❌ No pro tips or guidance

**Impact**: New players unfamiliar with Five Parsecs ruleset don't understand what to choose

---

## FIVE PARSECS CAMPAIGN CREATION OVERVIEW

### 7-Step Wizard Flow

The game requires these sequential configuration steps:

```
1. CONFIG
   └─ Campaign name, difficulty, story track toggle, victory conditions
   
2. CAPTAIN
   └─ Leader name, background (rolled/selected), motivation
   
3. CREW
   └─ Crew size (1-6), generate members, select species per character
   
4. SHIP
   └─ Ship type, name, hull points, starting debt
   
5. EQUIPMENT
   └─ Generate starting gear package, manage credits
   
6. WORLD
   └─ World generation, danger level, tech level, traits, locations
   
7. FINAL REVIEW
   └─ Summary of all choices, validation, create campaign
```

### Rules Context Players Need

From Five Parsecs rulebook (Appendix V onwards):

- **Difficulty tiers affect**: Enemy strength, resource availability, character advancement speed
- **Permadeath**: Mandatory on HARDCORE/NIGHTMARE, disabled on STORY
- **Story Track**: Optional narrative system connecting campaigns (Appendix V, p.153)
- **Crew advancement**: Characters gain XP, can be injured/killed, create narrative consequences
- **Economic management**: Equipment costs, crew upkeep, loot distribution
- **World danger levels**: Affect encounter generation and loot quality

---

## RECOMMENDED SOLUTION

### Phase 1: Quick Wins (Start Here - 5-7 hours total)

**Components to Create**:

1. **StepIndicator** (2-3 hours)
   - Shows "Step 3 of 7: Equipment Generation (42%)"
   - Visual progress bar or numbered steps
   - Updates via coordinator signal

2. **BreadcrumbNavigation** (2-3 hours)
   - Shows path: CONFIG > CAPTAIN > CREW > SHIP > EQUIPMENT > WORLD > FINAL
   - Allows jumping back to completed steps
   - Prevents jumping forward to uncompleted steps

3. **Enhance Validation Display** (1-2 hours)
   - Show errors in panels with highlighting
   - Use existing ErrorDisplay component
   - Add field-level error feedback

**Result**: Users understand where they are, how much is left, and can navigate back if needed

### Phase 2: Important Additions (Next - 6-10 hours)

4. **HelpPanel** (4-6 hours)
   - Sidebar with contextual help for current step
   - Rule references (links to rulebook sections)
   - Examples of configurations
   - Expandable/collapsible

5. **FieldValidator** (2-3 hours)
   - Real-time validation as user types
   - Error messages below fields
   - Success checkmarks
   - Character count feedback

6. **TemplateSelector** (3-4 hours, optional)
   - Quick-fill presets (Story Focus, Combat Focused, Balanced)
   - Skip manual configuration
   - Good for new players

**Result**: Users understand what each option means and why they're choosing it

### Phase 3: Polish (Optional - 4-8 hours)

7. **Auto-Save Draft** (3-4 hours)
   - Save progress between steps
   - Recover from accidental exit
   - Show "unsaved changes" warning

8. **Advanced Help** (4-6 hours)
   - Video tutorials per step
   - FAQ section
   - Glossary of game terms
   - Direct rulebook links

---

## IMPLEMENTATION STRATEGY

### What NOT to Change

- ✅ Keep existing 7-panel architecture (perfect as-is)
- ✅ Keep coordinator pattern (excellent design)
- ✅ Keep panel validation logic (working well)
- ✅ Keep signal-based communication (enables modularity)

### What to Add

- **New files** in `src/ui/components/wizard/`:
  - StepIndicator.gd + .tscn
  - BreadcrumbNavigation.gd + .tscn
  - HelpPanel.gd + .tscn
  - FieldValidator.gd + .tscn
  - TemplateSelector.gd + .tscn (optional)

- **Minimal changes** to existing files:
  - CampaignCreationUI.gd (instantiate components, connect signals)
  - BaseCampaignPanel.gd (add optional help methods)
  - base_theme.tres (add progress/validation colors)

### Why This Approach Works

1. **Non-Breaking**: New components don't modify existing panels
2. **Composable**: Each component is independent, can be added incrementally
3. **Testable**: Each component can be tested in isolation
4. **Reusable**: Components can be used in other multi-step workflows
5. **Framework Bible Compliant**: Minimal inheritance, composition over complexity

---

## FILES CREATED IN THIS RESEARCH

### 1. WIZARD_UI_RESEARCH.md (932 lines)
**Comprehensive analysis** covering:
- Existing UI component patterns (panels, coordinator, screens)
- Design system elements (themes, colors, responsive design)
- Tooltip & help systems
- Dialog & popup patterns
- Validation & error handling
- Navigation & flow control
- Five Parsecs campaign creation requirements
- Missing pieces & gaps
- Recommended component architecture
- Implementation priority roadmap
- Design patterns & best practices
- Files to create/modify
- Key insights & recommendations
- Appendix: Campaign creation checklist
- Appendix: Theme styling additions

### 2. WIZARD_COMPONENT_REFERENCE.md (671 lines)
**Developer reference** with:
- Component hierarchy diagram (visual tree)
- Existing components to reuse (BaseCampaignPanel, Tooltip, Coordinator, Theme, etc.)
- 5 new components to create with full API specs:
  1. StepIndicator (progress display)
  2. BreadcrumbNavigation (navigation trail)
  3. HelpPanel (contextual help)
  4. FieldValidator (inline validation)
  5. TemplateSelector (quick-fill presets)
- Visual design mockups for each component
- Integration examples with code snippets
- Testing checklist
- Performance notes

### 3. WIZARD_FINDINGS_SUMMARY.md (This Document)
**Executive summary** for quick reference

---

## SUCCESS CRITERIA

A successful wizard UI implementation will:

- ✅ Show user their progress (Step X of 7)
- ✅ Allow navigation within wizard (back/forward/jump)
- ✅ Explain each configuration option clearly
- ✅ Validate input in real-time
- ✅ Prevent invalid state transitions
- ✅ Provide rule references for complex options
- ✅ Support mobile, tablet, and desktop layouts
- ✅ Use consistent Five Parsecs terminology
- ✅ Maintain existing panel architecture
- ✅ Require minimal changes to existing code

---

## RISK ASSESSMENT

### Low Risk ✅
- Adding StepIndicator (isolated component, no coupling)
- Adding BreadcrumbNavigation (isolated component, no coupling)
- Adding tooltips to fields (proven pattern, already used)
- Updating themes (additive, no breaking changes)

### Medium Risk ⚠️
- HelpPanel integration (requires adding methods to each panel, but optional)
- FieldValidator (requires hooking into panel inputs, but non-breaking)
- TemplateSelector (new workflow, but optional and isolated)

### High Risk ❌
- Modifying BaseCampaignPanel extensively (could break existing panels)
- Changing coordinator signals (could break other systems)
- Reordering panel sequence (breaks save/load compatibility)

**Recommendation**: Avoid high-risk changes. Phase 1 and 2 components have very low risk.

---

## TIMELINE ESTIMATE

| Phase | Duration | Components | Priority |
|-------|----------|-----------|----------|
| Phase 1 | 5-7 hrs | StepIndicator, BreadcrumbNav, Validation | Must-Have |
| Phase 2 | 6-10 hrs | HelpPanel, FieldValidator, TemplateSelector | Should-Have |
| Phase 3 | 4-8 hrs | Auto-Save, Advanced Help | Nice-to-Have |
| **Total** | **15-25 hrs** | **All components** | **For Complete UX** |

**Recommended Starting Point**: Phase 1 (5-7 hours) = quick, high-impact improvement

---

## NEXT STEPS FOR TEAM

1. **Review Documents**
   - Read WIZARD_UI_RESEARCH.md for comprehensive context
   - Read WIZARD_COMPONENT_REFERENCE.md for implementation details
   - Discuss findings with team

2. **Choose Phase 1 Components** (If proceeding)
   - Select StepIndicator and BreadcrumbNavigation as MVP
   - Optionally add enhanced validation display

3. **Create Component Files**
   - Use templates from WIZARD_COMPONENT_REFERENCE.md
   - Follow existing code style (GDScript 2.0 syntax, signals, no inheritance chains)
   - Add comprehensive documentation

4. **Integration Testing**
   - Hook components into CampaignCreationUI.gd
   - Test with all 7 panels
   - Verify on mobile/tablet/desktop layouts
   - Check theme compatibility

5. **User Testing**
   - Get feedback from new players unfamiliar with Five Parsecs
   - Refine help text based on common questions
   - Improve validation messages clarity

---

## CONCLUSION

The codebase has **excellent architectural foundations** for a professional wizard UI. The panel-based system, coordinator pattern, and signal communication are exactly what you need. By adding progress indicators, navigation breadcrumbs, and contextual help, you'll have a complete, guided experience that helps both new and experienced players through campaign creation.

**Recommendation**: Start with Phase 1 (StepIndicator + BreadcrumbNavigation) for immediate visual improvement. These are low-risk, high-impact components that can be implemented in 5-7 hours. Phase 2 components (HelpPanel, FieldValidator) add significant educational value but require more time investment.

The research documents provide everything needed to implement successfully:
- Detailed analysis of what exists and what's missing
- Complete API specs for each new component
- Code integration examples
- Visual design guidance
- Testing and performance notes

All documents are stored in project root for easy reference during development.

