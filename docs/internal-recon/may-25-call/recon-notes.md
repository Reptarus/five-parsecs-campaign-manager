# Internal Recon Notes — fiveparsecs.online

**Date**: 2026-05-22
**Purpose**: Direct observation of the web-based companion-app competitor Chris flagged in Entry #11a. Notes are INTERNAL ONLY — reference material for the Mon May 25 12pm Eastern / 5pm UK call with Chris and Gavin. Never to be sent as a deliverable. Never linked from `docs/DOCUMENTATION_INDEX.md`.
**Method**: Playwright MCP. Elijah's existing webapp account auto-detected (browser session was logged in). Recon proceeded with authenticated access from the Reference page onward.

> **Posture note**: The point of this doc is to know our differentiators cold for live conversation. NOT to argue against the competitor in writing. If any sentence in here drifts toward "we're better because X," rewrite it to "we're DIFFERENT because Y." Chris's competitive anxiety is informed by their existence; the right response is "we're a different product category," not "we're a better version of the same product."

---

## 1. Top-line observations (the call-ready bullets)

These are the four differentiation axes Chris asked about in Entry #11a, with observed evidence from the webapp recon. Each one is a sentence Elijah can say aloud during the call.

| Axis | Their tool | Our project | Sentence for Chris |
|---|---|---|---|
| **Product category** | Campaign-logging web app: records what happens at the physical table | Companion app: runs the rules, IS the table experience | "Their tool logs the campaign; our app runs the gameplay" |
| **Procedural generation** | Lookup-binding only (species/background/class → stat modifiers, ship type → hull, captain → +Luck — all live-applied). No D100 rolls, no random table consumption, no battle resolution. | Lookup-binding + procedural generation: D100 rolls on starting gear table, world generation, mission generation, battle resolution, post-battle phase loop | "They modify what's there; we generate what's there" |
| **Turn structure** | Flat 5-field record form (Upkeep toggle, 8-checkbox activities, free-form Encounters + Recorded Changes + Note) | 9-phase guided sequence (STORY → TRAVEL → UPKEEP → MISSION → POST_MISSION → ADVANCEMENT → TRADING → CHARACTER → RETIREMENT) with procedural logic per phase | "They give you a log to fill in; we drive the procedure" |
| **Information architecture** | Noun-based (Crew, Ship, Galaxy, Reference) — manages objects you have | Verb-based (Story / Travel / Mission / Post-battle) — drives turn-cycle actions | "Their UI models what you HAVE; ours models what you DO" |
| **Visual register** | Functional minimalism: white-page utility, no theme or animation | Full art direction: Deep Space theme, TweenFX animations, portraits, atmospheric framing | "Theirs is a form; ours is an experience" |
| **Catalog vs. consumption** | Structured catalogs surfaced as dropdown pickers (49 weapons, 60+ enemies, 25 backgrounds, etc.) — player selects what they rolled at the physical table | Same source data consumed computationally (`data/RulesReference/*.json` drives mechanic invocation) without surfacing raw tables to the user | "They show you the catalog; we use the catalog" |

## 2. Architectural observations (organized by axis)

### 2.1 Product category — "turn recording" vs. running the rules

- **Dashboard help text (verbatim)**: *"Create a crew to start turn recording. Feed and reference remain available without one."*
- The phrase **"turn recording"** is doing the work. Their value proposition is **persistent input** of a campaign players are running with physical books + dice. The webapp doesn't roll D100s, doesn't generate worlds, doesn't resolve battles — it stores what the player did.
- Our project does all of those operations as core gameplay (StoryPointSystem, CharacterGeneration, WorldEconomyManager, BattleResolver, etc.). The webapp is the **stat sheet**, ours is the **game**.
- **Implication for the call**: when Chris asks "what's different," the cleanest answer is "they record, we run." That single sentence draws the category line.

### 2.2 Information architecture — noun-based vs. verb-based

- Their top nav surface: `Dashboard | Crew | Ship | Galaxy | Reference | Feed | Campaign Settings` (7 sections)
- Each section is a **noun** — an object you manage. The user opens Crew to manage the crew, Ship to manage the ship, etc.
- Our top-level surface is the **9-phase turn loop**: Story → Travel → Upkeep → Mission → Post-Mission → Advancement → Trading → Character → Retirement
- The verb model implies a **guided experience**: you don't manage objects in isolation, you advance through a structured turn. That's the companion-app affordance.
- **Implication for the call**: this is what "UI perspective" differentiation actually means in their own words. Their UI is an inventory screen; ours is a journey.

### 2.3 Visual register — minimalism vs. designed atmosphere

- Their auth + dashboard pages are sparse: white background, simple sans-serif type, no thematic elements, no portrait imagery, no animation, no atmospheric framing.
- Their design language is **utility-grade**: it looks like an internal tool or a free indie webapp, which IS what it is.
- Our Deep Space theme: COLOR_BASE `#1A1A2E`, COLOR_ACCENT `#2D5A7B`, Montserrat fonts, TweenFX animations on transitions, portrait avatars with colored-initial fallbacks, art-rich character cards.
- **Implication for the call**: when Chris says "be clear how this product is different ... from a UI perspective," the answer isn't "we have better UI." The answer is "we ARE the visual experience; they're an information form." Different product, not better version.

### 2.4 Data treatment — static reference catalog vs. computational consumption

- Their Reference section is a **paginated lookup catalog**: 669 entries across 28 pages, 33 content types — Backgrounds (25), Basic Training (9), Classes (23), Crew Tasks (8), Crew Types (4), Deployment Conditions (11), Enemies (76), Enemy Traits (74), Enemy Weapons (41), Implants (11), Items (90), Member Types (2), Mission Objectives (11), Motivations (17), Notable Sights (9), Origins (13), Patron Types (6), Resources (4), Ship Parts (14), Ship Traits (6), Ship Types (13), Service History (8), Skills (7), Species (16), Story Stars (5), Special Assignments (12), Support Options (11), Tracked Statuses (2), Unique Foes (22), War Progress Statuses (4), World Traits (42), Weapon Traits (24), Weapons (49). Each entry tagged with source ("Core Rules" badge) and effect text (e.g., "Alien Culture — Effect: +1 High-tech Weapon").
- Their data treatment is **transcriptive**: rulebook → display. The user looks up effects in their Reference catalog the same way they'd look them up in the physical book, just searchable.
- Our data treatment is **computational**: rulebook → JSON (in `data/RulesReference/`) → mechanic invocation (D100 rolls, world generation, battle resolution, advancement) → outcomes presented as gameplay. The user never sees raw tables; they see results of tables firing in context.
- These are **different products in overlapping space**, not competing products. A reference catalog and a game runner serve different moments: one for "I'm at the table with the physical book and want a searchable lookup," one for "I want a tool that runs the game and presents results in context."
- **Implication for the call**: this is the cleanest answer to "how is this product different on content." They DISPLAY rules; we USE rules. Same data, different verbs, different products. The 669-entry catalog is observable evidence Chris can verify himself if he wants.

### 2.5 Multi-IP coverage approach — sibling apps vs. platform

- Their footer has an "ALL PROJECTS" section: *"Browse the other companion apps in this project"* — links to separate Five Parsecs and Five Leagues apps.
- They cover multi-IP, but as **separate websites**, not as a unified platform. Five Leagues users start over on the Five Leagues site.
- Our T3 thesis: this is the **foundation** for Modiphius's wider digital strategy. One platform, multiple IPs, shared infrastructure (StoreManager, LegalConsentManager, save format, design system, telemetry, etc.).
- **Implication for the call**: T3 (multi-project R&D investment) is the strategic frame. Sibling-apps approach and platform approach are different architectural answers to the same multi-IP opportunity.

### 2.6 Commercial-intent observation (factual context, not a talking point)

- Footer link: **"Buy me a coffee"** in the SUPPORT column. Operator runs this on donations, not commercial revenue.
- Captured for situational awareness only. NOT a talking point for the call. The commercial-model contrast is best left unaddressed unless Chris raises it — and even then, neutral facts only, no "they can't be a financial threat" framing. That's defensive snitch-adjacent posture and is explicitly off the table (see [[feedback-competitor-framing-difference-not-violation]]).

## 3. Authenticated areas — not yet observed in this session

Elijah's browser session was already logged into the webapp when recon began (account auto-detected as "Elijah Rhyne" in their nav). The recon has authenticated access to Crew / Ship / Galaxy / Create-a-crew / Campaign Settings / Feed, but those areas have not yet been navigated in this session pending Elijah's call on scope.

If we extend recon into authenticated areas, observations to add:

- Character creation input mechanics — D100 automation, form fields, or hybrid
- Equipment selection — table-driven generation or manual entry
- Mission / world surfacing — automated generation or manual logging of player-rolled results
- Galaxy section — visualization, map view, or pure tracker
- Campaign Settings — difficulty modifiers, campaign-type selection, or just metadata
- Feed — shared community activity stream or personal campaign log

These observations would deepen the "data treatment" finding from Section 2.4 (logging vs. computational consumption) but the call story works without them. The catalog-vs-mechanic difference is already provable.

## 4. QA-relevant edge cases observed (piggyback notes for alpha-1)

Any patterns observed here that map to QA risks in our own product. Filled in as the recon proceeds.

- *(none captured yet — will populate as I navigate Reference / Feed pages)*

## 5. Talking-point candidates for the May 25 call

Ranked by force. Elijah picks 2-3 to lead with. All framed as product-category difference, not as competitive critique. **Refined 2026-05-22 after runtime testing surfaced that the webapp does have lookup-binding automation; the differentiator is procedural generation, not "automation vs. no automation."** See Section 8.10 for the data behind these. **Further refined 2026-05-22 (later) after Elijah articulated the player-experience thesis underneath T1: the differentiator isn't automation, it's player throughput. See [[feedback-strategic-theses-t1-t4]] T1 sharpening.**

0. **"The point of the automation is more turns per session, not fewer player decisions. We get out of the way so users can focus on actually PLAYING the game and on the story being told."** (NEW LEAD — strongest articulation. Centers the player experience, not the app feature set. Measurable metric (turns / battles / time-at-the-table) defensible in alpha data. Frames automation as means, not end. Matches Elijah's verbatim 2026-05-22 articulation. Pair with "Their tool records what happened; ours clears the way for more to happen.")

1. **"Their tool logs the campaign; our app runs the gameplay."** (Strong follow-up sentence. Their own help text uses "turn recording," their Create Crew subtitle reads literally "Record the crew exactly as your table decided it," and Elijah's framing was "campaign-logging web app vs. fully featured app." Same idea, three phrasings, all converging.)
2. **"They modify what's there; we generate what's there."** (NEW from runtime testing. Their lookup-binding automation modifies stats when fields are selected (species → baseline, background → +CS, class → +CS, captain → +Luck). Our app rolls D100 on the underlying tables to GENERATE what gets selected in the first place. They start from player-chosen inputs; we start from procedural outputs.)
3. **"They show you the catalog; we use the catalog."** (Concrete content-side example: their Add Item dialog opens a 49-weapon dropdown picker. Our equipment system rolls on the starting-gear table and instantiates the item automatically. Same source data (`data/RulesReference/EquipmentItems.json` is the equivalent on our side); different relationship to the player.)
4. **"They list the enemies; we run the battle."** (NEW, very concrete. Their Add Encounter dialog has 60+ enemy types in a dropdown plus structured weapon and leadership fields. The player fills in what THEY rolled at the physical table. Our project has BattleResolver + AI behavior + deployment + post-battle phases that run the encounter procedurally.)
5. **"Theirs is a form; ours is an experience."** (Visual register difference — Chris will see this himself if he visits the URL. Their Turn 1 page is a 5-field flat form; ours is a 9-phase guided sequence.)
6. **"Their UI models what you HAVE; ours models what you DO."** (Information architecture difference — noun-based object inventory (Crew / Ship / Galaxy / Reference) vs. verb-based turn-cycle (Story / Travel / Mission / Post-battle). Most precise answer to "UI perspective.")
7. **"Sibling-apps approach vs. platform approach."** (T3 thesis lever — different architectural answers to the same multi-IP opportunity. Sets up Phase 2 wider-digital-strategy conversation without making it the day's topic.)

Off-the-table talking points (intentionally cut):

- ❌ "Donation-based vs. partnership product" — defensive, snitch-adjacent. Don't bring up commercial intent unless Chris does, and even then state neutrally.
- ❌ "They're reproducing rulebook tables openly" — that's Chris's assessment to make about a third party, not ours to push him toward. Observation captured in notes for context; never spoken aloud.
- ❌ "They don't automate anything" — DEMONSTRABLY FALSE per runtime testing. They have lookup-binding automation. The accurate framing is procedural-generation vs. lookup-binding, not no-automation vs. automation. Don't lead with the false framing.
- ❌ Any UX friction notes (silent required-field validation, business-rule communication timing, etc.) — those are critique disguised as observation. Not relevant to the partner conversation.
- ❌ Anything that positions us against them rather than alongside them in a category we share.

## 6. What this doc is NOT

- Not a feature-by-feature comparison
- Not a "we're better" argument
- Not a doc that ever leaves Elijah's hands
- Not material to send Chris after the call (if anything goes to him post-call, it's a fresh artifact written for partner-consumption with comparative framing stripped out)

## 7. Source captures

- Dashboard view: `screenshots/fiveparsecs-online-auth-wall.png` (filename misnomer — the `/auth` redirect bounced back to `/dashboard` with the shell visible; this is actually the dashboard's empty-state view, with the navigation surface, "No active crew" empty-state card, and footer all visible)
- Reference page: snapshot captured 2026-05-22 showing 669-entry paginated catalog with content-type sidebar, Core Rules badge on each entry, and effect text per row (e.g., "Alien Culture — Effect: +1 High-tech Weapon"). Accessibility snapshot only; not screenshotted in this session
- Create Crew empty-state form: `screenshots/fiveparsecs-create-crew-empty.png` (the full Create Crew single-page form with no fields filled — captures the noun-based architecture and zero-state stats)
- Turn 1 record-form: `screenshots/fiveparsecs-turn1-record-form.png` (the load-bearing screen — Upkeep toggle, 8 Campaign Activities checkboxes, Encounters / Recorded Changes / Note sections, Save Draft / Review & Submit buttons)
- Screenshots currently land in the Playwright output dir; move them to `docs/internal-recon/may-25-call/screenshots/` before the May 25 call

## 8. Runtime observations — what happened when I drove their tool (Turn 0 + Turn 1)

All observations below are past-tense first-person from active use via Playwright MCP on 2026-05-22. Each mechanic-claim cites a Core Rules page or RulesReference JSON file per the protocol. Classifications use the three-bucket protocol: faithful catalog / deviation noted / ignored mechanic.

### 8.1 Pre-flight — campaign auto-provisioning

- I navigated to `/dashboard`. The empty-state CTA "Create a crew" had URL `/crew/create?campaign=019e5011-4ebd-77b8-b818-df05e80cabbd` — a pre-existing campaign UUID was already attached.
- **Inference**: their data model auto-provisions an empty campaign object on signup or first dashboard load. Crew creation populates that pre-existing campaign.
- **Difference framing**: their architectural answer is **eager-provision-then-populate**. Our `CampaignCreationCoordinator` is **lazy-instantiate-at-commit**: the campaign object materializes when the 7-step wizard validates at Step 7 (FINAL_REVIEW). Both work; they're different shapes.

### 8.2 Crew creation — single-page form, not a wizard

- The Create Crew page rendered as ONE PAGE with multiple sections visible simultaneously: Crew Identity, Crew Members, Starting Ship, Stash.
- Page subtitle (visible verbatim): **"test · Record the crew exactly as your table decided it."** This is their explicit thesis statement of the product. The word "Record" + "as your table decided it" frames the entire UX.
- **Difference framing**: their UX = single-form input. Our UX = 7-step guided wizard. Different design centers: they trust the user to know what to enter; we sequence the user through generation steps.

### 8.3 Character creation — lookup-binding automation, confirmed via 4 tests

I filled Crew name = "Recon Test Alpha" and crew member #1 Name = "Captain Vex," then ran four tests:

**Test 1 — Species → baseline stats** (Core Rules p.15, verified via PyPDF2 page extraction):

- Webapp pre-test state: all stat spinbuttons at 0
- I selected Species = "Baseline Human"
- Webapp result: REA 1, SPD 4, CS 0, TGH 3, SAV 0
- Rulebook authority: Core Rules p.15 specifies Baseline Human profile as "REACTIONS 1 / SPEED 4″ / COMBAT SKILL +0 / TOUGHNESS 3 / SAVVY +0"
- **Classification: Faithful catalog.** Webapp matches rulebook exactly on species → stat lookup. Also verified Feral (p.18) = "REACTIONS 1 / SPEED 4″ / CS +0 / TGH 3 / SAV +0" and Swift (p.18) = "REACTIONS 1 / SPEED 5″ / CS +0 / TGH 3 / SAV +0."

**Test 2 — Background → stat modifier** (Core Rules p.24):

- I selected Background = "Drifter" first (rulebook: "+1 Gear")
- Webapp result: stats unchanged, Equipment still "No starting items yet"
- I then selected Background = "Frontier Gang" (rulebook: "+1 Combat Skill")
- Webapp result: CS spinbutton changed from 0 to 1
- **Classification: Partial implementation.** STAT-effect backgrounds are applied; EQUIPMENT-effect backgrounds (like Drifter's +1 Gear) are not. The webapp records the Drifter selection but does not instantiate the gear item.

**Test 3 — Class → stat modifier stacking** (Core Rules pp.26-27, classes table):

- I selected Class = "Soldier" while Background = "Frontier Gang" was already set
- Webapp result: CS spinbutton changed from 1 to 2 (Background +1 + Class +1 = 2 stacked cumulatively)
- **Classification: Faithful catalog.** Multi-source modifier composition with live recalculation. Their stat engine handles the +modifier-from-source pattern correctly.

**Test 4 — Captain designation → Luck bonus** (Core Rules p.15 captain mechanic):

- I clicked "Set Captain" button on crew member #1
- Webapp result: "Captain" badge appeared on the row, LCK spinbutton changed from 0 to 1
- Rulebook authority: per Core Rules p.15 and crew-composition rules in pp.10-11, Captain has +1 Luck baseline
- **Classification: Faithful catalog.** Captain → +1 Luck applied automatically.

**What's NOT automated in character creation**: random rolls. Core Rules pp.18-19, 24-27 specify that Background, Motivation, and Class can be rolled D100 on tables. The webapp does NOT roll for the player. The player rolls at the physical table, then selects the matching dropdown option. Their UI is a structured PICKER, not a random GENERATOR.

### 8.4 Equipment — manual catalog picker, no procedural generation

- I clicked "Add Item" under crew member #1's Equipment section
- Dialog opened with Type combobox (Item / Weapon) and Amount spinbutton
- I selected Type = "Weapon"
- A second combobox appeared (progressive disclosure) with ~49 weapon options drawn from their structured weapon catalog: Auto rifle, Beam pistol, Blade, Blast pistol, Blast rifle, Boarding saber, Brutal melee weapon, Cling fire pistol, Colony rifle, Dazzle grenade, Duelling pistol, Flak gun, Frakk grenade, Fury rifle, Glare sword, Hand cannon (appeared twice — likely Core + Compendium duplicate or data quality issue), Hand flamer, Hand gun, Hand laser, Hold out pistol, Hunting rifle, Hyper blaster, Infantry laser, Machine pistol, Marksman's rifle, Military rifle, Needle rifle, Plasma rifle, Power claw (appeared twice), Rattle gun, Ripper sword, Scrap pistol, Shatter axe, Shell gun, Shotgun, Suppression maul, Boarding sword, Carbine, Combat rifle, Flash grenade, Frag grenade, Incinerator, Light machine gun, Mounted launcher, Service pistol, Shot gun, Sniper rifle
- **There was no random-roll button. No "roll on weapons table" affordance. Just a structured picker.**
- Rulebook authority: Core Rules character creation includes a D100 starting weapons table; the webapp does not run this procedure
- **Classification: Ignored mechanic.** Rulebook specifies a procedure (D100 → weapon table → item ID). Webapp provides a structured catalog picker only. The player rolls at the table, then picks the matching item from the dropdown.

### 8.5 Ship configuration — type-driven hull lookup

- I selected Ship type = "Worn freighter" from a 13-option dropdown
- Webapp result: Hull spinbutton auto-populated to 30 (within the Core Rules 20-40 range per CLAUDE.md gotcha note that flagged this exact mechanic)
- Debt spinbutton stayed at 0 (manual entry — webapp doesn't auto-derive starting debt)
- Rulebook authority: Core Rules ship section (around p.55+) specifies hull values per ship type
- **Classification: Faithful catalog** for ship type → hull lookup. **Ignored mechanic** for starting debt (which per Core Rules p.55 area involves a creditor decision the webapp doesn't surface).

### 8.6 Form submission — server-side validation surfaces

- I clicked "Create Crew" with no Captain designated and no Ship name filled
- First submit result: silent client-side failure. Browser focus jumped to the Ship name field (HTML5 `required` validation), no visible error message surfaced. **Friction observation**: required-state isn't visually marked on the form preemptively; user only learns Ship name is required by submitting and being scrolled back to it.
- I filled Ship name = "Wandering Star" and resubmitted
- Second submit result: server-side validation failed. URL changed to include `&definition=parsecs%3Acrew-recorder&error=Parsecs%20crews%20must%20record%20exactly%201%20Captain%20or%20Administrator.&draftKey=019e5037-ac84-7204-8c20-65d5308c9760`. Banner appeared: **"Couldn't save yet — Parsecs crews must record exactly 1 Captain or Administrator."**

Three load-bearing observations from this submit cycle:

1. **Server-side business-rule validation.** They enforce Core Rules pp.10-11 crew composition (must have a Captain) at the server, not just the client. Their backend gates on rulebook-derived rules. **Classification: Faithful catalog** of a critical business rule.
2. **Server-side draft persistence.** The `&draftKey=019e5037-ac84-7204-8c20-65d5308c9760` URL parameter is a UUID — their in-progress form survives validation failure as a server-side draft. Polished UX pattern beyond simple CRUD.
3. **Typed-record system.** The `&definition=parsecs%3Acrew-recorder` parameter — they have a typed-record architecture where "parsecs:crew-recorder" is one of multiple record-type definitions. Architectural sophistication beyond a flat form.

- I clicked "Set Captain" on crew member #1 — "Captain" badge appeared, LCK changed 0 → 1 (per Test 4 above)
- I clicked "Create Crew" again. Server accepted. Redirect to `/dashboard`.

### 8.7 Dashboard state after crew creation

The post-creation dashboard surfaced richly populated state:

- **Resource tracking** card: Squad Reputation 0 / Credits 0 / Quest Rumors 0 / Story Points 0 (matches Core Rules p.66-67 campaign resources)
- **5 Stars of the Story buttons**: "Did you ever meet my mate?" / "It's time to go!" / "Looked worse than it was!" / "Lucky shot!" / "Rainy day fund!" (matches Core Rules p.67 canonical 5-ability list per memory `reference_stars_of_the_story_canonical.md`)
- **Ship card "Wandering Star"**: Type / Hull 30 / 30 / Debt 0 — hull tracked as current/max ratio
- **World card "sdfsdd"** (placeholder world from prior test data) with Galactic War tracking: Invasion None / War progress Not recorded / Invading force Not recorded / Freelancer License Not required
- **Quests + Jobs** sections (both empty)
- **Recent Activity feed** with timeline entry "Today / Roster / Recon Test Alpha created · Elijah Rhyne recorded Recon Test Alpha as an active roster" — they have a campaign-activity-log system
- **Campaign Crews** roster list

The dashboard is **informational/managerial**. It's a status display showing the current state of the campaign as a series of cards, not a turn driver. Compare to our `CampaignDashboard.gd` which surfaces phase progression + active turn actions, not just resource state.

### 8.8 Turn 1 — the load-bearing observation

I clicked "Start Turn" (link to `/turn?start=1`). The Turn 1 page rendered as a single form with these sections (verbatim labels):

1. **Upkeep** — binary "Paid" toggle, defaulted to ON. No calculation displayed. No crew-count-times-cost math. No Sick Bay exclusion logic. Just a toggle.
2. **Campaign Activities (0 / 1 max)** — 8 checkboxes: Decoy / Explore / Find a Patron / Recruit / Repair Your Kit / Track / Trade / Train. Helper text: "Select up to 1 activities for this draft."
3. **Encounters** — "No encounter records are attached to the battle step yet." with Add Encounter button
4. **Recorded Changes** — "No changes recorded yet." with Add Change button
5. **Note** — textbox, helper "Visible to all campaign participants.", placeholder **"Summarize what happened this turn for the shared campaign feed."**

Plus **Save Draft** and **Review & Submit** buttons.

**Rulebook crosscheck — Core Rules pp.65-133 campaign turn structure** (verified against Compendium Campaign-rules JSON at `data/RulesReference/Campaign.json` for our authoritative extraction):

| Core Rules turn step | Webapp coverage | Classification |
|---|---|---|
| Travel Step (Core Rules p.65) — flee/destination, world transition | Not surfaced in turn form | Ignored mechanic |
| Upkeep Step (Core Rules p.76) — pay-per-crew (1 credit each), Sick Bay exclusions, lockout consequences for failure | Single binary toggle, no calculation, no procedural enforcement | Ignored mechanic |
| World Step — Resolve Rumors (Core Rules p.93) | Not surfaced | Ignored mechanic |
| World Step — Job Offers (Core Rules pp.95-96) | Not surfaced (no "draw a patron job" affordance) | Ignored mechanic |
| World Step — Crew Tasks (Core Rules pp.96-103, 8 tasks) | 8 checkboxes matching rulebook catalog exactly | Faithful catalog of NAMES; ignored mechanic on procedural resolution (no D100 per task) |
| World Step — Galactic War events (Core Rules pp.106-107) | Not surfaced in turn form (World card on dashboard tracks war status separately) | Ignored mechanic (in turn flow) |
| Battle Step — mission generation (Core Rules pp.107-110) | Free-form "Add Encounter" | Ignored mechanic |
| Battle Step — deployment, AI behavior, resolution (Core Rules pp.110-120) | Free-form "Add Encounter" + structured enemy form (see 8.9) | Ignored mechanic |
| Post-Battle Step — Rival Update, Patron Update, Quest Progress (Core Rules pp.120-122) | Free-form "Add Change" | Ignored mechanic |
| Post-Battle Step — Get Paid, Battlefield Finds, Loot, Injuries, XP, Training (Core Rules pp.122-128) | Free-form "Add Change" | Ignored mechanic |
| Post-Battle Step — Campaign Event, Character Event tables (Core Rules pp.128-130) | Not surfaced | Ignored mechanic |
| Post-Battle Step — Galactic War Update (Core Rules pp.131-132) | Not surfaced in turn form | Ignored mechanic |
| Post-Battle Step — Stats update (Core Rules p.133) | Manual via stat spinbuttons | Ignored mechanic |

**Classification: Ignored mechanic at the macro level.** The rulebook specifies a 10-15-step procedural sequence; the webapp provides a 5-field flat log. The Note placeholder ("Summarize what happened this turn for the shared campaign feed") and the page subtitle on Create Crew ("Record the crew exactly as your table decided it") both confirm: this product captures player-side decisions after the fact. Our `CampaignPhaseManager.gd` has a 9-phase orchestrated sequence (STORY → TRAVEL → UPKEEP → MISSION → POST_MISSION → ADVANCEMENT → TRADING → CHARACTER → RETIREMENT) where each phase is a panel with procedural logic.

### 8.9 Add Encounter dialog — structured but still a record

I clicked "Add Encounter" to probe their battle-recording UX. Dialog rendered with these fields:

- **Encounter Basics**: Encounter type dropdown (Select / Opportunity / Patron / Rival / Invasion / Quest) — matches Core Rules pp.93-94 encounter categories
- **Opposition**: 
  - Enemy Category: Bug Hunt / Normal / Unique
  - Enemy type dropdown with ~60 entries spanning Core Rules Bestiary categories (verified against `data/RulesReference/Bestiary.json`):
    - 15 Roving Threats (Anarchists, Brat Gang, Cultists, Gangers, Gene Renegades, Gun Slingers, Hulker Gang, K'Erin Outlaws, Pirates, Psychos, Punks, Raiders, Skulker Brigands, Starport Scum, Tech Gangers)
    - 16 Hired Muscle (Assassins, Black Dragon Mercs, Black Ops Team, Blood Storm Mercs, Corporate Security, Enforcers, Feral Mercenaries, Guild Troops, Rage Lizard Mercs, Roid-gangers, Secret Agents, Security Bots, Skulker Mercenaries, Unity Grunts, Unknown Mercs, War Bots)
    - 16 Interested Parties (Abandoned, Bounty Hunters, Colonial Militia, Isolationists, K'Erin Colonists, Mutants, Planetary Nomads, Precursor Exiles, Primitives, Renegade Soldiers, Salvage Team, Soulless Task Force, Swift War Squad, Tech Zealots, Vigilantes, Zealots)
    - 13 Strange Creatures (Abductor Raiders, Carnivore Chasers, Converted Acquisition, Converted Infiltrators, Distorts, Haywire Robots, Krorg, Large Bugs, Razor Lizards, Sand Runners, Swarm Brood, Vent Crawlers, Void Rippers)
  - Enemy count spinbutton (with -/+ controls)
  - Specialist toggle (No / Yes)
  - Leadership selector (No Leadership / Lieutenant)
  - Weapon 1 + Weapon 2 dropdowns with ~40 weapon options each (including creature attacks: Chomp, Claws, Claws (Damage +1), Claws (Damage +2), Corroding touch, Fangs, Mandibles, Rip and tear, Smash, Teeth)
- **Participants**: Crew member toggle buttons (showed "Captain Vex ✓" as pressed)
- **Notes**: textbox with placeholder "What happened, loot/finds, unusual events, reminders for Recorded Changes..."
- **Live validation panel** ("Complete the encounter before saving" + bulleted list of remaining requirements: "Choose an encounter type." / "Enemy 1 is missing a type selection." / "Enemy 1 needs a count greater than 0.")
- Save Encounter button (disabled until validation clears)

**Classification: Sophisticated record form with live validation, but still a record.** The catalog depth is real (60+ enemies, ~40 weapons). The validation is live and clear. But the player has already rolled D100 on the Enemy Table at the physical table (Core Rules pp.110-115), fought the battle with the physical book's rules, computed outcomes. The dialog asks them to RECORD what happened — it doesn't generate the encounter.

### 8.10 Pattern lock — the refined differentiation thesis

After the full Turn 0 + Turn 1 walkthrough, the pattern is solidified:

**What the webapp automates:**

- **Lookup binding**: species → stats, background → stat modifiers, class → stat modifiers, captain → +1 Luck, ship type → hull
- **Multi-source modifier composition**: live recalculation when any modifier source changes
- **Server-side business rules**: must-have-Captain, definition-typed records, draft persistence
- **Catalog depth**: 16 species, 25 backgrounds, 23 classes, ~49 weapons, ~60 enemies, etc. all dropdown-pickable

**What the webapp does NOT automate:**

- **Procedural generation**: no D100 rolls on any table (background / class / motivation / starting equipment / mission / encounter / character events / campaign events)
- **Turn-phase orchestration**: no procedural phase sequence; flat record form
- **Mechanic resolution**: no battle resolution, no AI behavior, no upkeep math, no Sick Bay enforcement, no Galactic War simulation
- **World / Galaxy generation**: world objects pre-exist (placeholder "sdfsdd" attached on signup); no generation procedure observed

**Refined difference framings** (replacing the earlier "they record / we run" candidates):

| What they do | What we do | Single sentence for Chris |
|---|---|---|
| Apply lookup-bound stat modifiers in real time | Apply lookup-bound modifiers + run D100 procedures to generate inputs | "They modify what's there; we generate what's there." |
| Catalog 49 weapons in a dropdown picker | Roll D100 on the gear table, instantiate the item, equip to character | "They show you the list; we roll for you." |
| Provide a flat 5-field turn-record form | Walk you through a 9-phase procedural turn loop with mechanics firing automatically | "They give you a log to fill in; we drive the procedure." |
| Enforce server-side business rules | Same enforcement + derive procedural consequences | "They gate on constraints; we apply consequences." |
| Catalog 60+ enemies for the player to record | Roll D100 on the Enemy Table, generate the encounter, drive AI behavior, resolve combat | "They list the enemies; we run the battle." |

The "fully featured app vs. campaign-logging web app" framing the user articulated is now backed by specific, observable, rulebook-anchored evidence on every dimension.

### 8.11 What this session deliberately did NOT cover (for May 25 readiness)

Per the plan's circuit-breaker rule, runtime testing stopped after Turn 1 entry + Add Encounter dialog probe. Areas left unobserved:

- Turn 2 / Turn 3 (state-persistence across turns) — pattern was solidified; additional turns would be diminishing returns
- Save Draft vs Review & Submit behavior — variations of the same submit flow
- Galactic War mechanics (Invasion / War Progress tracking)
- Feed (their shared-campaign social layer)
- Campaign Settings (likely metadata-only based on URL inspection)
- World creation (the campaign already had a placeholder world from prior test data)
- The full Encounter save → Battle resolution → Post-battle flow

None of these gaps affect the load-bearing differentiation answer for the May 25 call. If specific questions surface during the call that need answers from these areas, they can be tested ad hoc.

### 8.12 Friction observations (UX notes captured for context)

Captured for honesty, not for use as call talking points (per `feedback_competitor_framing_difference_not_violation` — facts get noted, judgments stay out):

- Required-field validation on Ship name fires silently (focus scrolls to field, no visible error message)
- "Must have a Captain" business rule is communicated only AFTER submit attempt — could be a preemptive indicator near the Set Captain button
- Apparent duplicate weapon entries in some dropdowns (Hand cannon ×2, Power claw ×2) — likely Core + Compendium overlap or data quality issue
- The "sdfsdd" placeholder world demonstrates that the auto-provisioning leaves visible default data in the user's account — minor UX wart, not a differentiation point

These exist; they're not weaponized in the call.

## 9. Multi-turn audit and retractions (2026-05-22 follow-up)

Section 8 stopped after a partial Turn 1 walkthrough. The conclusions in that section were directionally right but several claims about specific webapp surfaces turned out to be **incomplete or wrong** when I returned and drove Turns 1, 2, and 3 end-to-end. This section is the corrective: what actually happens across multiple turns, with retractions called out by reference so the call material is honest.

**Method**: same Playwright MCP session, same authenticated browser, same campaign (`Recon Test Alpha`). Submitted Turn 1 and Turn 2 end-to-end. Drove Turn 3 up to the Member > Progression form schema inspection. All screenshots in [screenshots/](screenshots/).

### 9.1 Retractions and corrections to Section 8

| Earlier claim | What runtime testing actually showed | Severity |
|---|---|---|
| **Section 8.8 / table**: "Battle Step — mission generation: Free-form 'Add Encounter'" | Add Encounter is a **structured form** with Encounter type (6 options), Battle Setup section (Deployment condition: 11 options matching Core Rules p.91 deployment-conditions table; Notable sight: 9 options matching Core Rules p.95; Objective: 5 options matching Core Rules pp.86-90 mission-objectives), Enemy Category / Type / Count / Specialist / Leadership / Weapons, Participants, Notes. NOT free-form. | Material |
| **Section 8.8 / table**: "Post-Battle Step — Get Paid, Battlefield Finds, Loot, Injuries, XP, Training: Free-form 'Add Change'" | Recorded Changes > Add Change is a **typed CRUD picker** with 6 categories: Member update / Inventory-Resource / Campaign update / Stars of the Story / World update / Ship update. Member > Progression form has stepper controls for XP, Advancements, Reactions, Speed, Combat Skill, Toughness, Savvy, Saving Throw, Luck, Missions, Reputation, plus an Advanced Training dropdown matching Core Rules p.123 (Bot technician, Broker training, Mechanic training, Medical school, Merchant school, Pilot Training, Security training). Schema-driven, not free-form. | Material |
| **Section 8.11**: "Turn 2 / Turn 3 (state-persistence across turns) — pattern was solidified; additional turns would be diminishing returns" | The pattern was **not** solidified. Multi-turn testing surfaced the Save Encounter auto-populate behavior, the Play Encounter route, the Recorded Changes schema, and the end-to-end state mutation pipeline. Stopping at Turn 1 missed the most evidence-dense surfaces. | Material (was an honesty failure) |
| **Section 7**: "the `/auth` redirect bounced back to `/dashboard` with the shell visible; this is actually the dashboard's empty-state view" filename note | Verified accurate. No retraction. | None |

The thesis of Section 1 (procedural-generation vs. lookup-binding; running vs. recording) survives intact. What needed correcting is the granular evidence about HOW well-structured their recording surfaces are.

### 9.2 Save Encounter auto-populates the full Core Rules enemy profile

After clicking Save Encounter on a configured Add Encounter dialog (Opportunity / Small encounter / Fight Off / Anarchists / count 4 / Hand gun), the saved card on the Turn 1 page showed:

- **Anarchists** with the full Core Rules p.83 enemy profile inline: `Number 4 · Speed 5" · Combat +0 · Toughness 3 · AI Aggressive · Weapons: Hand gun · Traits: Stubborn`
- This is **schema-driven lookup**: select "Anarchists" + count, the system attaches the full enemy stat block from a backing data table (matches Core Rules pp.82-85 enemy roster)
- Weapon button "Hand gun" is clickable; popover shows `Range 12". Shots 1. Damage 0. Pistol: +1 to Brawling rolls` (matches Core Rules p.41)
- Trait button "Stubborn" is clickable; popover shows `They ignore the first casualty of the battle when making a Morale check.` (matches Core Rules p.81)
- Screenshot: [fiveparsecs-encounter-saved-with-autopop.png](screenshots/fiveparsecs-encounter-saved-with-autopop.png)

**Classification: Faithful catalog with strong inline-rules linking.** They have a rulebook-grade enemy catalog wired into the encounter card, with click-through rules text for every weapon and every trait. This is more sophisticated than I suggested in Section 8.

**Difference framing for the call**: still procedural-generation vs. lookup-binding. The webapp doesn't ROLL the encounter category, enemy type, count, or weapons (Core Rules pp.78, 82-85 specify D100 procedures); the player picks each from a dropdown after rolling at the physical table. But once picked, the catalog content shows up live. Our project does the same lookup AND runs the dice procedure that generates the selection in the first place.

### 9.3 The Play Encounter route is a digital battle-reference card, not a battle simulator

Each saved encounter has a `Play encounter` link to `/turn/encounters/encounter-1/play?roster=<UUID>`. Clicking it renders a side-by-side stat-block view:

- **Warband panel**: Captain Vex with full stat block (Reactions 1 / Speed 4" / Combat +2 / Toughness 3 / Savvy +0 / Luck 1 / XP 0 / Upgrades 0), tagged "Captain" and "Baseline Human · Frontier Gang · Soldier"
- **Enemy Forces panel**: Anarchists with description, Panic 1-2 / Speed 5" / Combat +0 / Toughness 3, Number 4, AI Aggressive, clickable Weapons and Traits sections
- **Battle note textbox**: placeholder "Capture the battle note you want to carry back into the draft."
- Footer links: `Print Sheet` (route `/turn/encounters/encounter-1/sheet?roster=<UUID>`) and `Back to Draft`
- Screenshot: [fiveparsecs-play-encounter-reference-card.png](screenshots/fiveparsecs-play-encounter-reference-card.png)

This is a **printable battle handout for the physical table**. It does NOT roll initiative, does NOT resolve actions, does NOT compute to-hit, does NOT track wounds. The player consults this card while rolling dice on the tabletop, and writes a "battle note" back to the draft when finished.

**Sharpened call framing**: the cleanest sentence is now "they print the battle card; we run the battle." Both are valid product positions for the companion-app category. Our `TacticalBattleUI.gd` with three modes (LOG_ONLY / ASSISTED / FULL_ORACLE) explicitly scales from log-only tracker (closer to their model) through full oracle (procedural resolution). They sit at one end of that spectrum; we cover the spectrum.

**Classification**: their battle-step model is **faithful catalog + printable reference card**. Procedural resolution is the **ignored mechanic** (deliberate product positioning, not an oversight).

### 9.4 Recorded Changes is a 6-category typed CRUD editor

Clicking "Add Change" inside Turn 2 opened a breadcrumb-driven dialog with six top-level categories, each described in their own copy:

1. **Member update**: "Roster status, recovery, experience, and personal progression changes." → sub-picker: Progression / Status / Implant
2. **Inventory / Resource**: "Adjust supplies, backpack equipment, and stack condition or quantity." → sub-picker: Resource change / Existing item update / Add new item
3. **Campaign update**: "Record travel, opposition, contacts, and world or region state."
4. **Stars of the Story**: "Record a one-use Stars of the Story option." → Stars of the Story state IS tracked here, contradicting my earlier inference from the dashboard-only popovers (which only display rules text)
5. **World update**: "Record world status, traits, and linked progression."
6. **Ship update**: "Record ship progression, components, upgrades, replacement, or retirement."

The **Resource change** form has stepper controls for the four campaign counters (Squad Reputation, Credits, Quest Rumors, Story Points) with dual-column display showing current value vs. updated value, plus an optional Note field. Screenshot: [fiveparsecs-resource-change-form.png](screenshots/fiveparsecs-resource-change-form.png).

The **Member > Progression** form covers XP, Advancements, Reactions, Speed, Combat Skill, Toughness, Savvy, Saving Throw, Luck, Missions, Reputation, plus a "New advanced training" dropdown matching Core Rules p.123 advanced training list. Screenshot: [fiveparsecs-progression-form-captain.png](screenshots/fiveparsecs-progression-form-captain.png).

**Classification**: their **post-battle data model** is faithful to Core Rules pp.122-128 and p.123. The schema captures every stat the rulebook tracks. What they **do not** do is derive these values from rules procedures (no Trade Table roll, no XP per battle award, no injury table lookup, no campaign-event D100). The user does the dice math, then types the delta into a typed form. The app then validates and persists.

**Difference framing**: this is the cleanest verb-level distinction. Theirs: "record what you did." Ours: "do it for you with optional override." The data model is roughly the same; the procedural ownership is opposite.

### 9.5 Multi-turn state persistence (verified end-to-end)

Driving Turn 2 with a Resource Change of `Credits 0 → 3` and submitting produced the following verified state delta:

- **Pre-submit dashboard** (after Turn 1): Squad Reputation 0 / Credits 0 / Quest Rumors 0 / Story Points 0
- **Post-submit dashboard** (after Turn 2): Squad Reputation 0 / Credits **3** / Quest Rumors 0 / Story Points 0
- Activity feed updated: `Turn 2 submitted · 0 encounters, 1 persistent change · Recon Test Alpha`
- Banner updated: `Ready for Turn 3`
- Screenshot: [fiveparsecs-dashboard-after-turn2-credits3.png](screenshots/fiveparsecs-dashboard-after-turn2-credits3.png)

This confirms:

- The Resource Change form actually mutates persistent state on submit (it's not just a journal entry)
- Turn submission increments the turn counter on the dashboard
- The Activity feed counts "persistent changes" separately from encounters (the Turn 1 submission showed `0 persistent changes` since no Recorded Changes were attached; Turn 2 showed `1 persistent change`)
- The post-submit URL pattern (`/turns/<UUID>`) gives every submitted turn a stable permalink, useful for a multi-participant shared campaign

**Classification**: faithful state-mutation pipeline. The CRUD-editor pattern is well-built and end-to-end correct. Not a half-done feature.

### 9.6 Per-character state remains unchanged unless explicitly mutated

After Turn 1 submit, I navigated to `/crew?roster=<UUID>` and inspected Captain Vex. All stats were unchanged from creation: XP 0 / Luck 1 / Combat +2 / Toughness 3 / Speed 4" / Reactions 1 / Savvy +0 / Upgrades 0.

The Core Rules p.123 XP-award procedure (1 XP per battle survived, +1 per kill, +1 for objective achieved) is **not auto-applied**. The Turn 1 encounter against 4 Anarchists with Captain Vex as a participant should have awarded at least 1 XP per Core Rules p.123 if executed; no XP appeared. The user is expected to record the XP through a Member > Progression change in a subsequent turn.

There is also an **Admin Correction** link visible at `/crew?roster=<UUID>` going to `/campaign-settings?campaign=<UUID>&recordChangeRoster=<UUID>`. This appears to be a back-door for retroactive corrections outside the turn flow. I did not exercise it; noting its existence in case the call surfaces "how do they handle out-of-band fixes."

### 9.7 Sharpened call framing for May 25

Two of the talking points in Section 5 are now sharper after the multi-turn audit:

- **#2 "They modify what's there; we generate what's there"**: still the right sentence. The webapp's lookup-binding goes further than Section 8 suggested (Save Encounter auto-loads a full enemy stat block; weapons and traits surface rules text on click). The catalog integration is good. The generative procedure is what's absent.
- **#4 "They list the enemies; we run the battle"**: now better stated as "They print the battle card; we run the battle." Their Play Encounter route is a printable reference handout. Ours is a tactical companion with three modes ranging from log-only to full oracle resolution.

One new talking-point candidate, ranked below #6 but worth having ready:

8. **"Their recording schema is rulebook-grade; their execution model is on the table."** This is the most generous framing of what their app actually is. Useful if Chris asks "but they have all the data tables; what's missing?" Answer: not the data, the execution. They have the schema for XP, advancement, ship hull, world traits, all 22 enemy traits, all 49 weapons. They surface that data well. What they don't do is run the procedure that fills those fields from dice. That's the genuine product-category line, and it doesn't require deprecating their work to draw it.

### 9.8 Honest UX/UI comparison (response to "be honest, be thorough")

Elijah asked: "how do they facilitate the battle phase, what does their campaign dashboard look like compared to ours? how is their UX/UI compared to hours, be honest, be thorough."

Honest answers, no sycophancy:

**Battle facilitation**:

- Theirs: Add Encounter dialog (structured form with enemy catalog + Battle Setup section), Save Encounter (auto-populates enemy stat block on the turn card), Play Encounter route (printable battle-reference card with clickable weapon and trait popovers), Battle note textbox at the bottom of the Play view. The player does dice on the physical table; the app provides a structured handout and a place to write outcomes.
- Ours: TacticalBattleUI with three modes (LOG_ONLY / ASSISTED / FULL_ORACLE), BattleResolver, AI behavior, deployment, post-battle 14-step orchestrator. Procedural execution with optional player override.
- Verdict: different products in the same category. Theirs facilitates physical play with reference cards. Ours computes the battle with mode flexibility for players who want to drive it themselves.

**Campaign dashboard comparison**:

- Theirs: clean single-page summary with Status & Blockers, Recon Test Alpha (resource counters + Stars of the Story buttons), ship card, world card with galactic-war fields, Quests/Jobs cards, Recent Activity feed, Campaign Crews roster. Information-dense, no animation, no thematic styling. Functional and well-organized. Screenshot: [fiveparsecs-dashboard-after-turn2-credits3.png](screenshots/fiveparsecs-dashboard-after-turn2-credits3.png)
- Ours: CampaignDashboard with HubFeatureCards, role pills, stat strip, persistent resource bar (CanvasLayer 80), notification manager (layer 90), TweenFX animations on transitions, Deep Space theme (#1A1A2E / #2D5A7B), portrait avatars, journal timeline, story track pills, character event status pills.
- Verdict: theirs is a status report. Ours is a campaign cockpit. Both are correct for their respective product positions. If the criterion is "information density per pixel" they're competitive; if the criterion is "atmospheric immersion" we're a different category.

**Overall UX/UI honest assessment**:

- Their UX is **well-built for its product class**. Breadcrumb-driven Add Change dialog, server-side draft persistence (`draftKey=<UUID>`), typed-record system (`definition=parsecs:crew-recorder`), dual-column current/updated stepper displays, server-side business-rule validation. These are not amateur. The implementation behind the minimal visual surface is mature.
- Their UI is **functional minimalism done well**. White backgrounds, simple sans-serif, no thematic art, no animation. This isn't a critique; it's a product-category choice. It looks the way a free indie webapp is supposed to look. It loads fast, works on any browser, doesn't need a GPU.
- **Where they're better than us**: server-side draft persistence with UUID resumption, the breadcrumb-driven typed CRUD editor, the inline weapon/trait popovers on encounter cards. These are patterns we could borrow.
- **Where we're a different product, not a better one**: animated transitions, themed visual register, portrait imagery, atmospheric framing, procedural execution of game rules. These map to the "ours is an experience" thesis.
- **Where we're outright more ambitious**: the full 9-phase guided campaign loop, the three-tier battle assistant (LOG_ONLY / ASSISTED / FULL_ORACLE), the Compendium expansion content (Bug Hunt / Planetfall / Tactics gamemodes), the Stars of the Story system with auto-mutation, the 8-step terrain generator, the 14-step post-battle orchestrator.

The honest summary: **their app is a competent campaign-logging companion built on a strong typed data model; ours is an experience-driven companion that procedurally executes the rulebook**. Both are legitimate companion-app architectures. The category-difference framing in Sections 1-2 holds without overclaiming our position or underclaiming theirs.

### 9.9 What's still un-observed (gap acknowledgment)

Same honest list as Section 8.11, minus the items I covered in 9.1-9.8:

- Galactic War mechanics (Invasion / War Progress tracking) are visible on dashboard, not yet exercised through the turn flow
- Feed (their shared-campaign social layer)
- Campaign Settings panel content
- World creation flow (the existing world was placeholder data named "sdfsdd")
- Add Encounter sub-cases beyond Opportunity (the other 5 encounter types: Patron / Rival / Invasion / Quest, plus what happens with non-Normal enemy categories Bug Hunt / Unique)
- The "Print Sheet" route output (`/turn/encounters/<id>/sheet`)
- The Admin Correction back-door route from /crew
- Multi-crew-member behavior (only one crew member in test campaign)

None of these gaps invalidate the load-bearing call framing. They're noted in case Chris's questions on May 25 require ad hoc follow-up testing.

### 9.10 Screenshots inventory (call-ready)

All in [screenshots/](screenshots/):

| File | Surface captured | Section reference |
|---|---|---|
| [fiveparsecs-online-auth-wall.png](screenshots/fiveparsecs-online-auth-wall.png) | Dashboard empty-state view (filename misnomer per Section 7) | 8.7 baseline |
| [fiveparsecs-create-crew-empty.png](screenshots/fiveparsecs-create-crew-empty.png) | Create Crew single-page form, zero-state | 8.2 |
| [fiveparsecs-turn1-record-form.png](screenshots/fiveparsecs-turn1-record-form.png) | Turn 1 record form (load-bearing) | 8.8 |
| [fiveparsecs-encounter-dialog-populated.png](screenshots/fiveparsecs-encounter-dialog-populated.png) | Add Encounter dialog with Battle Setup section, Anarchists/4/Hand gun configured | 9.1 retraction evidence |
| [fiveparsecs-encounter-saved-with-autopop.png](screenshots/fiveparsecs-encounter-saved-with-autopop.png) | Saved encounter card on Turn 1, full Anarchists Core Rules p.83 profile inlined | 9.2 |
| [fiveparsecs-play-encounter-reference-card.png](screenshots/fiveparsecs-play-encounter-reference-card.png) | Play Encounter route, Warband + Enemy Forces side-by-side reference card | 9.3 |
| [fiveparsecs-turn1-submitted.png](screenshots/fiveparsecs-turn1-submitted.png) | Turn 1 post-submit permalink view (`/turns/<UUID>`) | 9.5 |
| [fiveparsecs-dashboard-after-turn1.png](screenshots/fiveparsecs-dashboard-after-turn1.png) | Dashboard after Turn 1 submit, Credits still 0, Ready for Turn 2 | 9.5 baseline for state delta |
| [fiveparsecs-resource-change-form.png](screenshots/fiveparsecs-resource-change-form.png) | Resource change form with Credits 0 → 3 stepper configured | 9.4 |
| [fiveparsecs-dashboard-after-turn2-credits3.png](screenshots/fiveparsecs-dashboard-after-turn2-credits3.png) | Dashboard after Turn 2 submit, Credits = 3, Ready for Turn 3 | 9.5 verified state mutation |
| [fiveparsecs-progression-form-captain.png](screenshots/fiveparsecs-progression-form-captain.png) | Member > Progression form for Captain Vex, full stat schema visible | 9.4 |

Call usage: open the screenshots dir during the May 25 call screen-share so any specific finding is one click from the visual proof.

