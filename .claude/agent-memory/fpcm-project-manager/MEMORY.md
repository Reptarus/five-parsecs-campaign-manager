# FPCM Project Manager — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Save: routing decisions, cross-domain coordination patterns, project-level gotchas -->

## ABSOLUTE RULE: Core Rules & Compendium Are Word of God

The Core Rules and Compendium PDFs at `docs/rules/` are the canonical authority for ALL game mechanics. When routing data tasks, ensure agents verify values against the PDFs, not just code. **All agents extract from the PDFs using PyPDF2 ONLY** — do NOT use PyMuPDF/fitz. Example: `py -c "from PyPDF2 import PdfReader; r = PdfReader('docs/rules/...'); print(r.pages[PAGE].extract_text())"`.

## Session 60.1: Apr 30 Forecast Deep-Dive — Steam-First + Industry Research + Strategic Theses Captured

Apr 30 follow-up to Apr 29 meeting. Forecast doc deep-dive over the course of one session. Three substantive changes baked in:

### 1. Steam-first refocus (forecast §6 → §9)
- Phase 1 (EA + 1.0) targets Steam exclusively. Mobile reframed as Phase 2 "pocket edition" port (post-1.0, separate revenue stream)
- Platform-cut multiplier: 0.72 (blended Steam + mobile Small Business) → **0.70 (flat Steam 30%)**
- All net revenue figures, 50/50 splits, and contractor break-even tables recomputed
- Break-even thresholds (N\*) UNCHANGED — they're rev-share-delta-driven, not platform-cut-driven. Defensible talking point.
- New §6c: mobile pocket edition forward-looking sizing ($4.99-9.99, Apple/Google Small Business 0.85 multiplier, post-Steam-EA scope decision)

### 2. §11 Industry Research added (~2,500 words, 30+ sources)
Seven subsections with external research validating/challenging forecast assumptions:
- §11.1 Steam tabletop products (RIGHT comparison vector restructure — 4 subsections splitting digital REPLACEMENTS from digital COMPANIONS; Gloomhaven retired as product comp, retained only as audience-size ceiling)
- §11.1c lists 12 off-Steam companion-app peers (Mythic GME Digital, Quest Companion, World Anvil, Kanka, New Recruit, Army Forge, BattleScribe, Old World Builder, Campaign Console, Warscribe, Frostgrave Campaign Tracker, Stargrave Crew Builder)
- §11.1d category whitespace finding — empty Steam category = both moat AND discovery risk
- §11.2 wishlist conversion benchmarks (5-10% industry-wide 2026, EA ~20% first month median, target 10K-20K wishlists)
- §11.3 EA risk environment (31-50% failure rate)
- §11.4 pricing psychology (anchoring, charm pricing, AAA $60 ceiling)
- §11.5 cannibalization → §11.5a active digital→physical strategy (5 mechanisms)
- §11.6 TTRPG market tailwinds (13.2% CAGR, solo segment fastest-growing)
- §11.7 synthesis (now ternary: Reinforced / **Reframed** / Challenged)

### 3. FOUR MUTUALLY AGREED STRATEGIC THESES captured (durable framings)
Both Elijah and Modiphius have stated these positions repeatedly across conversations. Apr 30 made them explicit and durable:
- **T1**: Companion app, not digital port — defuses cannibalization concern
- **T2**: Establishing a category, not entering one — solo-RPG/wargame digital companion apps absent on Steam
- **T3**: Multi-project platform R&D investment — foundation for Modiphius's wider digital strategy
- **T4**: Active digital→physical conversion strategy — 5 in-app mechanisms drive Steam users to physical books

### Files updated Apr 30 (deep-dive)
- `docs/MODIPHIUS_DIGITAL_FORECAST.md` — header rev notes, §3 date fix, §4c + §5a conservatism footnotes, §6 Steam-first rewrite, §6c new mobile sizing, §7b/c table updates, §8 two new "what would change" rows, §9b three table updates (50/50 baseline x 0.70 multiplier), §9c Steam-only context note, §9.5 multi-project reframe promoted to baseline, §9e bug fix (60/40 → 50/50), §10 next-actions updated with Phase B/C deliverables, §11 NEW (7 subsections), §11.1 four-subsection restructure, §11.5a NEW (5 mechanisms), §11.7 ternary synthesis
- `docs/MEETING_FOLLOWUPS_2026-04-29.md` — new §1.5 mutually agreed strategic theses table, §5 deliverables updated to reflect SENT/in-flight
- `docs/CLOSED_ALPHA_PLAN.md` — new §6.1 category-perception probe + new §6.5 digital→physical mechanism specs
- `CLAUDE.md` — header partnership block + 4 strategic theses block + 7 new Apr 30 gotchas
- `.claude/skills/fpcm-project-management/references/project-status.json` — current_phase + roadmap rewritten, new strategic_theses + phase_B_alpha_deliverables_apr30 sections
- `docs/launch-dashboard.html` — Phase B/C deliverables added (category-perception probe, digital→physical mechanism specs, Steam-store-positioning brief)

### Files updated Apr 30 (evening delivery prep)
- `docs/MODIPHIUS_FORECAST_SUMMARY.md` (NEW) — 1-page executive summary for email attachment. Section A confirmed numbers · Section B T1-T4 · Section C 3-row revenue table (Conservative/Moderate/Strong, Steam-only 0.70 multiplier, 50/50 split) · Section D 3 contractor frames · Section E 5 mechanisms · Section F industry research highlights · "what's en route" footer
- `docs/MODIPHIUS_FORECAST_SUMMARY.html` (NEW, rendered) — print-ready HTML for browser → Save as PDF
- `docs/MODIPHIUS_DIGITAL_FORECAST.html` (NEW, rendered) — full forecast in print-ready HTML for held-in-reserve PDF render
- `docs/EMAIL_DRAFT_FORECAST_DELIVERY.txt` (NEW) — ~150-word email body, paste-and-send. Headline bullets pulled from 1-pager. Coordination items listed (discount sizing, contractor frame preference)
- `scripts/render_md_to_print_html.py` (NEW) — reusable markdown→HTML print-ready renderer. Pure Python (markdown library only). NO PyMuPDF (per project rule). Browser Print-to-PDF flow eliminates Pandoc/wkhtmltopdf system dependency
- Spot-check completed before send: Section D Frame B/C break-even labels were incorrectly conflating Frames with §9b Structures. **Frame A has $100K-$180K break-even range (Structure 1 or 2 math). Frames B and C are pure additional cost (no rev-share concession, no break-even threshold).** Fix applied, HTML re-rendered.

### Forecast SENT (A1.10 marked done 2026-04-30)
- Sent date: 2026-04-30 (one day ahead of May 1 EOD target)
- Recipients: Chris Birch + CC Gavin (per Apr 29 cadence agreement)
- Attachments: `MODIPHIUS_FORECAST_SUMMARY.pdf` (rendered from .html via Chrome Print-to-PDF) + current Windows build .exe (post-Apr 28 perf sprint)
- Held in reserve: `MODIPHIUS_DIGITAL_FORECAST.pdf` (full forecast, send if Modiphius requests)
- Awaiting reply — log responses in `MEETING_FOLLOWUPS_2026-04-29.md` §9 tracking table as they land
- Routing for replies: any partnership-related response goes to project-manager (me); domain-specific clarifications get triaged to the right agent

### Coordination items needed from Modiphius (Phase A.2)
- T4 discount-code sizing (15-20% placeholder)
- T4 redemption mechanism (one-time codes? promo codes? URL parameter?)
- T4 co-branded landing page
- T4 newsletter API endpoint
- T2 store-positioning input (Modiphius newsletter timing already in §2.5 ask)

### Routing notes (unchanged from Session 60)
- **Strategic / partnership tasks**: route to me (project-manager). NOT delegated to domain agents.
- **T4 mechanism implementation in app**: route to ui-panel-developer (frontend) + campaign-systems-engineer (state persistence for opt-in flows / consent) once mock-ups exist
- **Category-perception data analysis**: capture during alpha, synthesize end-of-alpha → Phase C Steam-store-positioning brief

### See also
- Plan: `C:\Users\admin\.claude\plans\5pfh-4219-dtrpg-jiggly-charm.md`
- Research sidecar: `C:\Users\admin\.claude\plans\5pfh-4219-dtrpg-jiggly-charm-agent-a6522ae24714bef96.md` (30+ sourced URLs)
- User memory: `project_session_apr30_forecast_deepdive.md`, `feedback_strategic_theses_t1_t4.md`, `reference_steam_companion_app_landscape.md`

---

## Session 60: Modiphius Partnership Workback (Apr 29, 2026) — DEAL FRAME LOCKED

Apr 29 meeting with Chris Birch + Gavin (Modiphius). Three things changed strategic posture:
- **Sales numbers confirmed**: 5PFH 4,219 DTRPG / 30K phys, 5L 2,700 DTRPG / 20K phys. Every physical book bundles a PDF (NOT separate revenue events).
- **50/50 net revenue split** confirmed as working deal. Prior 60/40 baseline superseded across all docs. Contractor structures re-run on 50/50 — break-evens shifted: Structure 1 $75K→$100K, Structure 3 $200K→$400K (no longer viable).
- **5x system positioned as foundation** for Modiphius's wider digital strategy across other licensed IPs (Star Trek Adventures, Achtung Cthulhu, Fallout, Dune). Quality bar = "template for Modiphius digital."

### Phase A.1 deliverables COMPLETE (Apr 29 same-day)
- `docs/MODIPHIUS_DIGITAL_FORECAST.md` — updated with 50/50 baseline + new §9.5 (three contractor scope frames A/B/C)
- `docs/MODIPHIUS_ASK_LIST.md` — updated with Apr 29 confirmations + linked to MEETING_FOLLOWUPS
- `docs/MEETING_FOLLOWUPS_2026-04-29.md` — canonical 13-ask list with email draft embedded + tracking table
- `docs/EMAIL_DRAFT_2026-04-29.txt` — plain-text email body, SENT to Chris (CC Gavin)
- `docs/launch-dashboard.html` — interactive HTML PM dashboard (tabs: Kanban/Phases/Timeline/Asks/Critical/Risks). Personal-use only, NOT shared with Modiphius.
- `docs/CLOSED_ALPHA_PLAN.md` — 10-20 testers from Ivan's Discord, 6-week window, weekly builds, 6 graduation gates
- `docs/PRICING_RESEARCH_PLAN.md` — Van Westendorp + Prolific n=200 + Gabor-Granger methodology

### Workback (Apr 29 → Steam EA late Sep 2026)
A.1 (this wk Apr 29-May 4 internal) → A.2 (next wk May 5-11 external + partnership-on-paper) → A.3 (May 12-24 alpha prep) → B (May 25-Jul 6 closed alpha 6wk) → C (Jul 7-20 refinement 2wk) → D (Jul 21-Sep 1 beta/Steam Playtest 6wk) → E (Sep 2-22 marketing lock 3wk) → F (Sep 23-30 Steam EA launch) → G (post-EA 6-12mo to 1.0).

### Routing notes for partnership-era tasks
- **Strategic / partnership tasks**: route to me (project-manager). NOT delegated to domain agents — these are strategy + business + comms work, not code.
- **Domain tasks during alpha**: standard agent routing applies. Bug-hunt/character-data/battle/UI agents continue normal work.
- **MVP / core selling point gate**: pricing, store-page, Modiphius newsletter timing all gated on alpha pricing-perception data. Don't lock these in advance.
- **Partnership-on-paper**: LOI in Phase A.2 → MOU in alpha+refinement (Jun-Jul) → Definitive Agreement before Steam EA. Cannot launch without Definitive Agreement signed.
- **Asset placeholder strategy**: ~1 week+ ETA from Modiphius asset person. Don't block Phases A/B on assets. Use placeholder pattern (TextureRect-swap-ready).
- **Closed alpha cohort**: Ivan's private playtesting Discord (10-20 testers). No external recruitment workstream needed.

### See also
- Plan: `C:\Users\admin\.claude\plans\5pfh-4219-dtrpg-jiggly-charm.md`
- Research sidecar: `C:\Users\admin\.claude\plans\5pfh-4219-dtrpg-jiggly-charm-agent-a6522ae24714bef96.md` (30+ sourced URLs)
- User memory: `project_session_apr29_modiphius_meeting.md`, `project_workback_to_steam_ea.md`, `project_contractor_scope_frames.md`, `reference_html_dashboard_template.md`

---

## Session 49: UX Polish Sprint (Apr 8, 2026)

Shotgun sprint — 8 non-blocked UX items shipped. UX checklist moved from **58/8/15** to **59/7/15** done/partial/pending.

- **ThemeManager bug fixes**: Colorblind modes were silently broken (wrong dict keys), reduced animation toggle didn't apply at runtime. Both fixed.
- **Load Campaign dialog**: Deep Space themed (was bare OS default)
- **Help buttons**: CaptainPanel + CrewPanel get "?" buttons with RulesPopup (Core Rules pp.12-25)
- **TweenFX expansion**: CampaignDashboard (crew card cascade), WorldPhaseController (step fade-in), CharacterDetailsScreen (stat pop-in), SettingsScreen (content fade). All guarded by reduced-animation setting.
- **Phase header**: "World Step" → "World Phase" in CampaignTurnController
- **HP formatting**: PDF exporter uses `%d/%d` instead of `str()` (prevents "3.0/5.0")
- **Compendium font**: Marked as ✅ Done (Montserrat is intentional design, not a gap)
- **Routing**: All work to `ui-panel-developer` domain. 11 files modified, 0 compile errors.
- **Gotcha discovered**: `var x := A and B` with nullable A fails Godot 4.6 type inference. Use `var x: bool = ...`

---

## Session 43: Story Points Full Integration (Apr 7, 2026)

Closed all story point wiring gaps. StoryPointSystem.gd and UI (popover+dialog+badge) were already complete but campaign loop bypassed the system.

- **Battle earning** wired in PostBattlePhase: `_check_bitter_day_story_point()` — +1 SP for held field + character killed (Core Rules p.67)
- **Turn earning** routed through StoryPointSystem (was direct `campaign.story_points += 1`). Insanity mode now checked
- **Dashboard sync**: `_sync_sp_system()` reloads `_sp_system` from campaign state on phase events + before popover open
- **XP spend**: Character picker dialog (ConfirmationDialog + ItemList), cancel-refund flow
- **Extra Action**: NotificationManager toast confirmation
- **Battle-only stars**: Dramatic Escape + It's Time To Go disabled on dashboard popover (need battle context)
- **Routing**: PostBattlePhase (campaign-systems), CampaignPhaseManager (campaign-systems), Dashboard + Popover (ui-panel-developer)
- **4 files modified**, 0 compile errors

---

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
- **Python (PyPDF2 ONLY)**: `py` launcher (NOT `python`). PyPDF2 3.0.1 is the only PDF tool — do NOT use PyMuPDF/fitz.
- **Example**: `py -c "from PyPDF2 import PdfReader; r = PdfReader('path'); print(r.pages[PAGE].extract_text())"`

---

## QA Documentation Suite (Mar 20, 2026)

Route all QA-related questions through the qa-specialist agent, which now has 4 master docs:

- `docs/QA_STATUS_DASHBOARD.md` — Start here for overall QA health, open bugs, next priorities
- `docs/QA_CORE_RULES_TEST_PLAN.md` — 170 mechanics → test status (47 NOT_TESTED, 63 MCP_VALIDATED, 0 RULES_VERIFIED)
- `docs/QA_INTEGRATION_SCENARIOS.md` — 9 E2E workflow scripts with MCP templates
- `docs/QA_UX_UI_TEST_PLAN.md` — Systematic UI testing (theme, responsive, TweenFX, accessibility)

After any sprint that fixes bugs or adds features, remind the assigned agent to update the dashboard and core rules plan.

## Project Status (Apr 7, 2026) — v0.9.7-dev — STORY POINTS FULLY INTEGRATED

- **Zero compile errors** (headless-verified)
- **925/925 data values verified** against Core Rules + Compendium
- **Session 40b**: Legal stack (14 files), Compendium library (10 categories, 340+ items), Icon SOP, Modiphius ask list
- **Session 40**: Difficulty audit — 3 deprecated enums, 4 fabricated keys removed, 10 dead files deleted, Progressive Difficulty UI
- **Session 39-39c**: Crew size scaling — campaign_crew_size (4/5/6), 25 files, 13 tests
- **Session 38-39b**: Intro Campaign + Story Track reconciled, runtime-tested, loading screen wired
- **Session 37**: UX Enhancement — 14 new reusable components (Fallout app patterns)
- **Session 36**: Story Track + CharacterDetailsScreen QOL
- **Session 35**: Red & Black Zone Jobs (Core Rules Appendix III)
- **Session 43**: Story points fully integrated — battle earning, turn earning via system, XP picker, Extra Action toast, dashboard sync, battle-only stars disabled
- **Next priorities**: Fill EULA placeholders, get Modiphius legal review, enable GitHub Pages, submit platform store forms, miniature photography assets
