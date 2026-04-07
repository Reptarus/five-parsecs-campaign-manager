# Modiphius Partnership — Ask List & Open Questions

**Last Updated**: 2026-04-07
**Purpose**: Everything we need from Modiphius before launch, organized by urgency and category. Also includes "nice to haves" that would accelerate future work across the 5X line and potentially other IPs.
**Related docs**: [MODIPHIUS_PROGRESS_DEMO.md](MODIPHIUS_PROGRESS_DEMO.md) | [Steam Research](archive/modiphius-steam-research.md)

---

## BLOCKERS — Cannot Ship Without These

### 1. Legal / IP License

| Item | Details | Status |
|------|---------|--------|
| **IP license grant scope** | What exactly are we licensed to use? Game mechanics, text, terminology, artwork, miniature photography, trade dress? The EULA has `[PENDING MODIPHIUS REVIEW]` at line 22 — we need the exact scope before any store submission | BLOCKED |
| **Sublicensing terms** | Can we sublicense the IP to platform stores (Apple, Google, Steam) as required by their distribution agreements? EULA line 36 | BLOCKED |
| **Revenue share / royalty structure** | What cut does Modiphius take? Per-sale, percentage of revenue, flat license fee, or hybrid? This determines our pricing model and whether subscription vs one-time purchase makes sense | BLOCKED |
| **DLC revenue treatment** | Are the 3 Compendium DLC packs (Trailblazer's Toolkit, Freelancer's Handbook, Fixer's Guidebook) subject to the same revenue share as the base app, or different terms? | BLOCKED |
| **Governing law / jurisdiction** | England and Wales (Modiphius HQ: 39 Harwood Road, London SW6 4QP) or developer's jurisdiction? EULA line 78 | BLOCKED |
| **EULA full legal review** | 3 `[PENDING MODIPHIUS REVIEW]` markers in `data/legal/eula.md` need sign-off. Do they want their own legal team to draft/review, or are they happy with our draft? | BLOCKED |
| **IP attribution requirements** | Exact copyright line, trademark notices, "used under license" phrasing. We have a placeholder based on the Core Rules PDF copyright page but need their approved version | BLOCKED |

### 2. Publishing & Distribution

| Item | Details | Status |
|------|---------|--------|
| **Publisher identity on stores** | Is this published under "Modiphius Entertainment" or under our name "with Modiphius Entertainment"? The Maloric Fallout app uses Maloric Digital as publisher with Modiphius branding — is that the model? | BLOCKED |
| **Developer accounts** | Do we use our own Apple/Google/Steam developer accounts, or does Modiphius want us publishing through theirs? (Note: Modiphius has zero Steam presence per our research — they'd need to create one, or we use ours) | BLOCKED |
| **App naming** | "Five Parsecs Campaign Manager" — is that approved? Do they want "Five Parsecs From Home" in the title? Any trademark constraints on naming? | BLOCKED |
| **Store listing copy** | Do they want approval over the App Store / Google Play / Steam store description, screenshots, and promotional text? | BLOCKED |
| **Age rating alignment** | We expect PEGI 7-12 / Apple 9+ / Steam E10+. Does that align with how they position the 5PFH brand? | Needs confirmation |
| **Support email** | `[CONTACT EMAIL]` placeholder in EULA + Privacy Policy. Whose email goes here — ours, theirs, or a shared inbox? | BLOCKED |

### 3. Monetization Model Decision

| Item | Details | Status |
|------|---------|--------|
| **Pricing model** | One-time purchase? Subscription ($2.99/mo like Maloric)? Free base + paid DLC? They may have preferences from the Maloric deal | BLOCKED |
| **Price points** | Base app price and DLC pack prices. The 33 content flags across 3 packs are built — we just need to set prices | BLOCKED |
| **Bundle pricing** | We have a `compendium_bundle` product that unlocks all 3 DLC packs. Discount percentage? | Needs input |
| **Bug Hunt pricing** | Separate purchase, included in base, or part of a DLC pack? We have it as a standalone `bug_hunt` product ID currently | Needs input |
| **Free tier scope** | If freemium: what's free? Full campaign with limited turns? Creation only? The Maloric app gives one faction free, gates the rest | Needs input |
| **Platform fee awareness** | Apple takes 30% (15% under Small Business Program), Google takes 15-30%, Steam takes 30% (dropping at $10M+). Revenue share needs to account for this | For discussion |

---

## HIGH PRIORITY — Needed Before Store Submission

### 4. Art & Visual Assets

| Item | Details | Why We Need It |
|------|---------|---------------|
| **Miniature photography** | High-res photos of painted Five Parsecs miniatures for faction/background selection tiles (the strongest UX pattern from the Fallout app analysis — full-bleed photo tiles) | The single biggest visual quality gap in the app right now. Placeholder art vs professional mini photos is the difference between "indie app" and "official product" |
| **3D renders of miniatures** | Clean renders on transparent backgrounds for character cards, unit selection, equipment preview | Character cards currently use colored initials as placeholder — renders would transform the UX |
| **Game logo / wordmark** | Official "Five Parsecs From Home" logo in vector format (SVG/AI) for splash screen, about page, loading screen, store listing | We're using text currently |
| **Modiphius logo** | Vector format for "Published by" / "Licensed by" attribution in app and store listings | Legal requirement |
| **Icon set / game iconography** | If Modiphius has existing icons for stats (Combat, Toughness, etc.), weapons, equipment categories — use official ones for consistency with print materials | Currently using generic icons |
| **Store listing screenshots** | Do they want to provide promotional screenshots or approve ours? The Fallout app has polished store screenshots | Needed for store submission |
| **App icon** | Official or co-branded app icon for stores. Needs to work at 1024x1024 (Apple), 512x512 (Google), and various smaller sizes | Needed for store submission |

### 5. Brand & Marketing

| Item | Details | Status |
|------|---------|--------|
| **Community channels** | Can we link to official Modiphius Discord / forums from the app? We have social link buttons in MainMenu already | Needs approval |
| **Press kit / marketing materials** | Access to their press kit for store listings and promotional material | Needed pre-launch |
| **Beta testing / soft launch plan** | Do they want to run a beta through their community? We'd need their help promoting it. The README mentions "community playtesting pending Modiphius approval" | Needs discussion |
| **Launch announcement** | Will they promote the launch through their channels (newsletter, social, store page)? | Needs discussion |
| **Ivan Sorensen involvement** | The game designer — does Modiphius want him consulted/credited beyond what's in the credits? Is there a relationship to manage there? | Needs clarity |

---

## MEDIUM PRIORITY — Important for Quality But Not Blocking

### 6. Content & Rules Accuracy

| Item | Details | Status |
|------|---------|--------|
| **Rules errata list** | Do they maintain an official errata for the Core Rules and Compendium? We've verified 925 data values against the PDFs, but errata would catch anything the books themselves got wrong | Would improve accuracy |
| **"Canonical" rules clarifications** | Several edge cases in the rules are ambiguous (e.g., does Luck apply to injury rolls? Can bots earn XP through non-combat means?). An official Q&A channel would help | Would improve accuracy |
| **Compendium updates** | Are there planned Compendium updates or new supplements? We'd want advance access to prep data extraction | Forward planning |
| **Permission to extract PDF data** | We already do this (Python + PyMuPDF), but explicit permission to programmatically extract from their PDFs for the app would be good to have in writing | Legal clarity |

### 7. Future IP / Multi-Game Platform Questions

| Item | Details | Why It Matters |
|------|---------|---------------|
| **Planetfall expansion approval** | We have full research notes + architectural design ready. Do they want us to build it? | 200-page rulebook already analyzed, ready to implement |
| **Tactics expansion approval** | Same — 212-page rulebook analyzed. This would be a separate companion app with character transfer to/from the Campaign Manager | Would be a second product |
| **Multi-game app or separate apps?** | The Maloric app covers Wasteland Warfare + Factions in one app. Do they want 5PFH + Bug Hunt + Planetfall in one app (current plan) and Tactics as separate? Or everything separate? | Architectural decision needed |
| **Other 5X titles** | Five Leagues From the Borderlands, Five Klicks From the Zone — would they want companion apps for those too? Same engine, same patterns, massive code reuse | Could be a product line |
| **Non-5X Modiphius IPs** | Star Trek Adventures, Fallout RPG, Elder Scrolls, Dune, Corvus Belli's Infinity — could this app framework (Godot + GDScript + JSON data-driven) be adapted? We've proven the architecture works | Long-term partnership value |
| **Content API / data feed** | If they ever formalize their game data (stats, tables, errata) into a structured format, we'd be a primary consumer. Worth raising as a shared investment | Would eliminate PDF extraction |

---

## NICE TO HAVE — Would Make Our Lives Easier

### 8. Development Support

| Item | Details | Impact |
|------|---------|--------|
| **Physical miniatures for photography** | If they can't provide professional photos, sending a box of painted minis for us to photograph would work | Art assets |
| **Access to source InDesign/layout files** | The game data tables in the PDFs are sometimes ambiguous due to OCR. Source layout files would give us clean data extraction | Accuracy |
| **Playtester access** | Connection to their existing playtest community for beta feedback | QA |
| **Technical contact at Maloric Digital** | Jamie Morris's experience with the Fallout companion app could save us months on platform-specific gotchas | Knowledge transfer |
| **Advance copies of new releases** | Early access to supplements/expansions before publication to have day-one app support ready | Competitive advantage |

### 9. Shared Infrastructure (Multi-IP Value)

| Item | Details | Who Benefits |
|------|---------|-------------|
| **Standardized game data format** | If Modiphius adopted a standard JSON schema for game data (stats, tables, costs), companion apps for ANY of their games could consume it directly | All future companion apps |
| **Asset CDN / image hosting** | A central place for official artwork, miniature renders, and icons that companion apps can pull from — avoids bundling massive image assets in every app | All apps, reduces app size |
| **Shared authentication** | If they ever build a "Modiphius Account" system (like the one Maloric's app uses for Fallout), we should integrate rather than building our own | User experience, data portability |
| **Shared cloud save backend** | Same as above — if there's a Modiphius-wide save system, we should use it. If not, Firebase is our plan | Cross-device sync |
| **Localization / translation** | Do they have existing translations of Five Parsecs? If we build i18n support, who provides translated strings? | International markets |
| **Analytics dashboard** | Would Modiphius want visibility into app usage data (with user consent)? If so, we should agree on a shared analytics platform early | Business intelligence |

---

## Summary: The Pitch Meeting Agenda

### Must-Discuss (Cannot Leave Without Answers)
1. IP license scope + EULA review process
2. Publisher identity + developer account ownership
3. Revenue share structure
4. Pricing model (one-time vs subscription vs freemium)
5. Art assets pipeline (miniature photos at minimum)

### Should-Discuss (Important But Can Follow Up)
6. Store listing approval workflow
7. Beta testing / launch promotion plan
8. Planetfall + Tactics expansion greenlight
9. Support email and community channel linking
10. Ivan Sorensen's role/involvement

### Can-Mention (Plant the Seed)
11. Multi-game platform vision (5X product line)
12. Standardized game data format as shared investment
13. Non-5X IP expansion potential
14. Maloric Digital knowledge sharing

---

## Reference: What We Already Have Built

This context helps frame the asks — Modiphius needs to know we're not asking for help building the app, we're asking for the partnership terms to ship it.

- **925/925 data values** verified against Core Rules + Compendium (zero fabricated data)
- **170/170 game mechanics** implemented and rules-accurate
- **7-phase campaign creation** + **9-phase campaign turns** fully wired
- **Bug Hunt gamemode** complete (38 files, 15 JSON data files)
- **DLC gating system** built for 33 content flags across 3 packs
- **Tri-platform store adapters** (Steam/Android/iOS) implemented
- **Legal stack** shipped (EULA screen, privacy policy, data export/delete, consent management)
- **Planetfall** architectural design complete (200-page rulebook analyzed)
- **Tactics** research complete (212-page rulebook analyzed)
- **Zero compile errors** on Godot 4.6-stable

---

*Document created 2026-04-07. Update after each Modiphius interaction.*
