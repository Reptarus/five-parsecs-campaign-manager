# FPCM Project Manager — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Save: routing decisions, cross-domain coordination patterns, project-level gotchas -->

## ABSOLUTE RULE: Core Rules & Compendium Are Word of God

The Core Rules and Compendium PDFs at `docs/rules/` are the canonical authority for ALL game mechanics. When routing data tasks, ensure agents verify values against the PDFs, not just code. Any agent can extract data using `py -c "import fitz; ..."`.

## Session 41: UX Sprint — Dashboard + Accessibility + Tutorials (Apr 7, 2026)

Sprint clearing remaining UX checklist items from Maloric/Fallout companion app analysis. UX checklist moved from 44/16/21 to **58/8/15** done/partial/pending.

- **Dashboard polish** (CampaignDashboard.gd): HubFeatureCards (Compendium + Battle Simulator in center column), role pills on crew cards (blue species, purple class, amber captain), 4-stat compact header strip (CREW/TURN/CREDITS/STORY PTS)
- **Accessibility settings** (AccessibilitySettingsPanel.gd): Reduced Motion toggle + Font Size dropdown (Small/Normal/Large) wired to ThemeManager
- **Crew swipe** (CharacterDetailsScreen.gd + CrewManagementScreen.gd): Horizontal swipe + arrow keys to browse crew members, page dots, crew list passed via GameStateManager temp_data
- **Tutorial/onboarding**: TutorialOverlay.gd rewritten (Deep Space theme, L95, scroll-aware). `data/tutorials/first_run.json` (4 steps) + `campaign_dashboard.json` (6 steps). Auto-start on first launch (MainMenu) and first dashboard visit. "?" help button in dashboard header
- **Checklist corrections**: 5 items verified actually done (debug screen, card animations, colorblind). 5 items clarified as partial with specific gaps (high contrast detection stubs, screen reader TTS, keyboard section cycling)
- **Routing**: All work went to `ui-panel-developer` domain. No data/campaign/battle changes

---

## Session 40b: Legal Stack + Compendium Library + Modiphius Ask List (Apr 7, 2026)

Complete legal/compliance and partnership preparation sprint:

- **Legal stack**: 14 new files — EULAScreen (first-launch blocking), LegalConsentManager (autoload), LegalTextViewer (reusable), data/legal/ docs (EULA, privacy, licenses, credits), GitHub Pages HTML, store submission checklist
- **Compendium library**: 10 categories, 340+ items, extensible for Planetfall/Tactics
- **Icon SOP**: game-icons.net SVGs (CC BY 3.0), white on transparent, modulate for color, `assets/icons/{context}/`
- **Modiphius ask list**: `docs/MODIPHIUS_ASK_LIST.md` — 7 legal blockers, 6 publishing blockers, 6 monetization decisions, art asset needs, multi-IP vision. Structured as pitch meeting agenda
- **Routing**: Legal UI → `ui-panel-developer`. Legal data/persistence → `campaign-systems-engineer`. Credits/licenses content → `character-data-engineer`. Partnership strategy → project manager
- **3 `[PENDING MODIPHIUS REVIEW]` markers** in EULA need legal sign-off before release
- **Next priorities**: Fill `[CONTACT EMAIL]`/`[DATE OF RELEASE]` placeholders, enable GitHub Pages, get Modiphius EULA review, submit platform store forms

---

## Session 39-39c: Crew Size Scaling Audit + Continuation (Apr 7, 2026)

Full crew-size-dependent rules audit (Core Rules pp.63-64, 70, 92-93, 99, 118; Compendium pp.124, 141). New `campaign_crew_size` property (4/5/6) on FiveParsecsCampaignCore, distinct from roster count. 20+ files modified across Session 39, 5 more in continuation. Key routing:

- **campaign-systems-engineer**: FiveParsecsCampaignCore serialization, CampaignFinalizationService, ExpandedConfigPanel UI
- **battle-systems-engineer**: EnemyGenerator (Numbers modifier, quest reroll, Raided formula), BattlePhase (fielding-fewer), FiveParsecsCombatSystem (reaction dice), PreBattleUI (deployment cap)
- **character-data-engineer**: FiveParsecsCampaignCore @export property (data model change)
- **qa-specialist**: 13 new tests in test_crew_size_enemy_calc.gd
- **Stealth/Salvage fix**: WorldPhase.gd caller changed from get_crew_size() to get_campaign_crew_size()

---

## Session 39b: Runtime Testing Complete (Apr 7, 2026)

Intro Campaign + Story Track fully runtime-tested. 7 bugs fixed, loading screen wired to 4 transitions, save/load round-trip verified. Key lessons:

- **DLC feature gates**: `is_feature_available()` for UI visibility, `is_feature_enabled()` for gameplay. Use enum constants, NEVER hardcoded ordinals.
- **Finalization timing**: Campaign not on GameState during `_create_campaign_resource()` — set properties directly on the Resource, not via GameStateManager.
- **Early state persist**: Both `_init_intro_campaign()` and `_init_story_track()` must call their `save_*_state()` immediately after init so progress_data has state from first frame.
- **World Phase auto-skip pattern**: Both `_show_current_step()` AND `_can_advance_to_next_step()` must handle skip conditions — one defers, the other marks completed.

---

## Critical Gotchas — Must Remember

### 1. Three-Enum Sync Rule

Any enum change MUST be routed exclusively to character-data-engineer. Three files must stay in perfect alignment:
- `src/core/systems/GlobalEnums.gd` (autoload)
- `src/core/enums/GameEnums.gd` (class_name)
- `src/game/campaign/crew/FiveParsecsGameEnums.gd` (CharacterClass)

Never let another agent modify enums independently.

### 2. Agent Dependency Order

When decomposing multi-domain tasks, route in this order:
```
data (character-data-engineer)
  → campaign (campaign-systems-engineer)
    → battle (battle-systems-engineer)
      → bug-hunt (bug-hunt-specialist)
        → UI (ui-panel-developer)
          → QA (qa-specialist)
```

### 3. Cross-Mode Review Required

Changes to shared files MUST get bug-hunt-specialist review:
- `TacticalBattleUI.gd` — shared between Standard and Bug Hunt
- `GameState.gd` — handles both campaign types
- `SceneRouter.gd` — routes to both mode UIs

### 4. FiveParsecsCampaignCore is Resource

`campaign["key"] = val` **silently fails**. Use `progress_data["key"]` for runtime state.
Route bugs about "lost state" or "data not persisting" to campaign-systems-engineer — this is usually the root cause.

### 5. Godot 4.6 Type Inference

`var x := dict["key"]` will NOT compile — Dictionary values are always Variant.
This is the root cause of "Cannot infer the type" errors project-wide. Always use explicit type annotation: `var x: Type = dict["key"]`.

---

## Session 33: DLC Store UI + Save Protection (Apr 6, 2026)

Complete commercial DLC system:
- **12 new files**: Store UI (DLCContentCatalog, DLCPackCard, BundleCard, BugHuntCard), toggle components (DLCFeatureToggleRow, ExpansionFeatureSection), awareness (DLCUpsellBanner, DLCActivationToast), dialogs (DLCRequirementDialog, DLCContentDisclaimer)
- **Android migration**: Third-party AndroidIAPP replaced with official GodotGooglePlayBilling BillingClient
- **Save protection**: `required_dlc_packs` one-way stamp on FiveParsecsCampaignCore, signal-based (DLCManager → GameState), load-time intercept with peek + dialog
- **MainMenu**: "Expansions" button (was Library), social footer (Modiphius links), DLC badges on saves
- **Routing**: `ui-panel-developer` owns all `src/ui/components/dlc/` and `src/ui/screens/store/` files. `campaign-systems-engineer` owns DLCManager signal + GameState wiring + FiveParsecsCampaignCore serialization

---

## Session 18: Rules Audit Complete + Schema Unification (Mar 30, 2026)

QA_RULES_ACCURACY_AUDIT.md: **0 UNVERIFIED entries** (was 308). 925/925 data values verified.

Fixes: Rival following (campaign-systems-engineer domain, TravelPhase.gd), license costs (same), 3 generator schema unifications (cross-domain: mission generators now delegate to Compendium canonical data classes instead of maintaining duplicate const tables). StreetFightPanel UI updated for new schema.

**Routing note**: Stealth/Street/Salvage generators (`src/core/mission/`) now depend on Compendium data classes (`src/data/compendium_*.gd`). Any data table changes go to `compendium_*.gd` files — generators are thin orchestration wrappers.

---

## Session 11-12: Hardcoded Data Cleanup (Mar 26, 2026)

Major cross-system data integrity pass completed:
- **KeywordDB** (character-data domain): Wired to 89-keyword JSON, 14 weapon traits corrected to Core Rules p.51
- **BattlePhase.gd** (battle/campaign domain): Fabricated payment formula removed. PostBattlePaymentProcessor handles real 1D6 payment.
- **BattleEventsSystem.gd** (battle domain): Wired to event_tables.json (24 events data-driven)
- **Audit verified**: PatronJobGenerator already wired, CharacterCreator already wired, BattleCalculations constants correct
- **Cut (cosmetic/dead data)**: CharacterNameGenerator (cosmetic, no gameplay impact), patron_missions.json (dead data, not wired)
- **Project version**: v0.9.4

---

## PDF Rulebooks & Python Extraction Tools

All agents can now extract data directly from source PDFs — route data verification tasks accordingly:
- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Text extractions**: `docs/rules/core_rulebook.txt` and `docs/rules/compendium_source.txt`
- **Python**: `py` launcher (NOT `python`), PyMuPDF 1.27.1 (fitz) installed
- **Example**: `py -c "import fitz; doc = fitz.open('path'); print(doc[PAGE].get_text())"`

---

## QA Documentation Suite (Mar 20, 2026)

Route all QA-related questions through the qa-specialist agent, which now has 4 master docs:

- `docs/QA_STATUS_DASHBOARD.md` — Start here for overall QA health, open bugs, next priorities
- `docs/QA_CORE_RULES_TEST_PLAN.md` — 170 mechanics → test status (47 NOT_TESTED, 63 MCP_VALIDATED, 0 RULES_VERIFIED)
- `docs/QA_INTEGRATION_SCENARIOS.md` — 9 E2E workflow scripts with MCP templates
- `docs/QA_UX_UI_TEST_PLAN.md` — Systematic UI testing (theme, responsive, TweenFX, accessibility)

After any sprint that fixes bugs or adds features, remind the assigned agent to update the dashboard and core rules plan.

## Project Status (Apr 7, 2026) — v0.9.7-dev — LEGAL STACK + COMPENDIUM SHIPPED

- **Zero compile errors** (headless-verified)
- **925/925 data values verified** against Core Rules + Compendium
- **Session 40b**: Legal stack (14 files), Compendium library (10 categories, 340+ items), Icon SOP, Modiphius ask list
- **Session 40**: Difficulty audit — 3 deprecated enums, 4 fabricated keys removed, 10 dead files deleted, Progressive Difficulty UI
- **Session 39-39c**: Crew size scaling — campaign_crew_size (4/5/6), 25 files, 13 tests
- **Session 38-39b**: Intro Campaign + Story Track reconciled, runtime-tested, loading screen wired
- **Session 37**: UX Enhancement — 14 new reusable components (Fallout app patterns)
- **Session 36**: Story Track + CharacterDetailsScreen QOL
- **Session 35**: Red & Black Zone Jobs (Core Rules Appendix III)
- **Next priorities**: Fill EULA placeholders, get Modiphius legal review, enable GitHub Pages, submit platform store forms, miniature photography assets
