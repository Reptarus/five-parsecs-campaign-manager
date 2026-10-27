# Letter of Intent (DRAFT)

**Owner**: Elijah Rhyne
**Created**: 2026-05-26
**Status**: DRAFT for review. Internal scaffolding above the divider; shareable content below it.
**Audience (eventual)**: Chris Birch (CCO) + Gavin (PM), Modiphius Entertainment Ltd.
**Workflow** (per Entry #12): Elijah drafts this as a shared Google Doc → Chris/Gavin co-edit and add Modiphius's standard language → it becomes the basis for the long-form customised agreement. This is the informal "heads of terms / my understanding of the deal" document Chris described, NOT a formal legal instrument.

**Numbers handling** (decided 2026-05-26): the $35K recoup and $1,000/mo fee appear as **non-binding opening proposals** (anchor-first). The non-binding clause protects them from locking. See `PARTNERSHIP_TERM_POSITIONS.md` §2.1.

**Platform language (corrected 2026-09-21)**: every Steam and desktop mention was removed from the body. This is NOT a change of position, it is the draft catching up with what Chris was already told. Entry #24 (2026-07-08, outbound) quotes the sent email verbatim: *"I updated the language that it should be MOBILE ONLY, let me know if I..."*, and `docs/MODIPHIUS_PARTNERSHIP_STATUS.md:134-136` records *"the LOI language is MOBILE ONLY (Entry #24)"* while marking the old Steam-first launch bullet SUPERSEDED by the Jun 18 direction lock (Entry #20). The local file had never been brought into line, so it still carried the old platform language in **six** places and contradicted our own status doc. ⚠ Only five of the six name Steam; the sixth, the pricing paragraph, said just "alpha and Early Access", so a grep for "steam" finds five of six and a reader stops there. ⚠ The one that mattered was the Phase 2 trigger: it gated the Five Leagues conversation on "officially reached Steam Early Access", an event we have no account to reach (`steam_appid.txt` holds `480`, Valve's public Spacewar placeholder, and `export_presets.cfg` has no iOS preset), so the stage 2 door could never open. It is now gated on public launch. ⚠ The "net" definition also lost its App Store example for the same reason: the clause already reads "the storefront's platform fee" generally, so one honest example covers any store the app later sells on. ⚠ Check the shared Google Doc matches before the letterhead version issues; Chris may have edited his copy on Jul 8 and the two can have drifted apart.

**Reconciled against the live document 2026-09-21.** The owner pasted the operative version, dated **7/27/2026**, which is the revision that came out of the Jul 27 call. It was materially AHEAD of this file on commercial substance and BEHIND it on platform, so this pass moves both ways. ⚠ **Nothing here was sent or edited in the Google Doc**; this is the local record catching up.

*Transcribed IN from the operative 7/27/2026 document (pasted by the owner 2026-09-21) (this file did not have them):*

1. **The maintenance-fee taper.** The single biggest gap: this file carried a bare $1,000/month bullet with no taper at all, while the live text defines the whole schedule and, critically, that the fee is payable ONLY out of net receipts with no shortfall owed. Journal `:1774` action item (4) already said to *"confirm $9.99 base + per-book unlocks and the taper (Entry #27) are written in"*, so the taper was known; it had simply never reached this draft.
2. **The pricing model, which is DECIDED, not open.** This file still said *"Pricing model is still open"*. The live text sells the app as a one-time purchase with each expansion as a separate paid unlock, explicitly so sales attribute per product for royalties, and rules a subscription out of the launch model.
3. **The entity-substitution sentence** in IP and ownership. This quietly resolves the signing-entity placeholder that used to sit in the list below: the Developer signs personally and may substitute an entity later by written agreement, so the entity decision no longer blocks signature.
4. **A new section, "Scope: the Five Parsecs family"**, covering the wider product line including the forthcoming squadron title, each as its own paid unlock, with third-party-rights titles such as a Traveller edition excluded.
5. **Stage 2 narrowed** from "other Modiphius properties" to "beyond the Five Parsecs line", which follows from item 4.
6. **Governing law: England and Wales.** `docs/legal/POST_LOI_LEGAL_CHECKLIST.md:29` had predicted exactly this from Modiphius's registered office, and the live document's address matches that entry character for character. This is now answered BY THE PARTIES, so recording it is reading a value they wrote, not inventing one.

*Deliberately NOT transcribed in:*

- **The Developer's home address.** The live header carries it. This repo pushes to `github.com/Reptarus/five-parsecs-campaign-manager` and that address appears in **zero** tracked docs today, so adding it here would put a home address into a GitHub repo as a side effect of a documentation tidy. It stays a placeholder below. Modiphius's registered office is public company information and is kept. ⚠ Owner call: if you want the real header in the repo, say so.
- **The signature block.** Still placeholders, because nobody has signed.

*Carried the other way, this file is AHEAD of the live document:*

- ⚠ **The live 7/27 document still says Steam, in six places**, at exactly the six sites corrected below. See the platform note above for why those are wrong. The pricing paragraph transcribed in at item 2 ended *"using data from the closed alpha and Early Access"* and is written here as "and after launch" to match.
- ⚠ **The tester-reward clause below is our PROPOSED edit, not what the Doc says.** The operative 7/27/2026 text reads: *"Testers who complete the program are credited as playtesters and will have free access to the app upon release along with any additional paid content under the “Five Parsecs From Home” application."* That is Elijah's own earlier wording, added in the Doc after Chris's opening comment. Chris then commented, and **that thread is still open**: *"suggest free access to the base app not paid extra content"*. The owner accepted the narrowing on 2026-09-21, so the clause in the shareable half is what we want the letter to say. ⚠ Duration has never been stated by either party (Chris's opening comment floated *"free purchase, or free X months"* and nobody answered the months question); **do not invent one**.
- ⚠ **Currency symbols.** The live text writes *"Indicative pricing is 9.99 for the base app with expansions between 4.99 and 6.99"* with no currency symbol, in a document that writes "$35,000" and "$1,000" with one. With a US developer, a UK company and England and Wales governing law, a bare "9.99" is a real ambiguity worth about 25% of the price. Written here as $9.99 / $4.99-$6.99, which is what our own record says (journal `:1530`: "$9.99 base + per-book unlocks"). Flag it when the letterhead is reviewed.

**⭐ The finding worth acting on, from the same reconciliation.** Journal Entry #34's first comment thread has Chris saying *"We're fine with this now see note below then we can issue to you and sign"*, and the only other open thread is the tester reward, where his own last word is *"suggest free access to the base app not paid extra content"*. The owner decided on 2026-09-21 in exactly that direction. **INFERRED, not verified** (it rests on reading "the note below" as that second thread, which is the only other one open): answering that comment in the Google Doc may be the whole remaining blocker on the letterhead LOI, and we have been waiting on a meeting instead. Cheap to test and it costs one comment reply.

**Open placeholders to resolve before sharing**:

- ~~Signing entity (individual vs to-be-formed business entity). Tier 1 OPEN item; affects governing law.~~ **RESOLVED by the operative 7/27/2026 document (pasted by the owner 2026-09-21)**: the Developer signs personally and may substitute an entity before the long-form agreement is executed, by written agreement. The entity decision is still worth making, it just no longer blocks signature.
- ~~Governing law (UK vs US). Depends on the entity decision.~~ **ANSWERED: England and Wales**, written into the operative 7/27/2026 document (pasted by the owner 2026-09-21). ⚠ This does NOT auto-apply to the shipped EULA placeholder at `data/legal/eula.md:78`; that is a real decision and stays owner-gated.
- The Developer's address in the header, deliberately left as a placeholder here. See the reconciliation note above.
- Modiphius adds its own endorsement / standard language where marked.

**Before sharing**: confirm no em dashes (per house style), paste the section below the divider into a Google Doc, share edit access with Chris + Gavin.

---

=== SHAREABLE CONTENT BELOW ===

## Letter of Intent: Five Parsecs From Home Digital Companion App

**Between**: Elijah Rhyne ("the Developer") of [address on file, see the live document]
**And**: Modiphius Entertainment Ltd. ("Modiphius") of 3rd Floor, 39 Harwood Road, London. SW6 4QP
**Date**: 7/27/2026

## What this document is

This is an informal record of how I currently understand our partnership and what I am proposing, written so we can put it in one place, you can correct or add to it, and we can use it as the shared starting point for the long-form agreement. It is intentionally plain-language and non-binding (except for the confidentiality and good-faith points near the end). Where I have got something wrong or where Modiphius would say it differently, please edit directly. The goal is a single document we both recognise as "yes, that is the deal," before the formal contract is drawn up from Modiphius's standard agreement.

## The project

I am building a digital companion app for Five Parsecs From Home. It is a companion to the physical game rather than a replacement for it: it runs a player's campaign, assists with battles, tracks characters and crews, and presents the game's events and tables in an illustrated, guided way. The plan is mobile, beginning on Android through Google Play. The app is designed so that a buyer can run a full campaign inside it, which is how we reach players beyond the existing Five Parsecs audience, while still pointing them toward the physical books.

The current build is solo-developed and already substantial: the full campaign loop, multiple game modes, and a battle assistant are working today. I am treating this first project as the proof of the architecture, and as the foundation for the wider digital strategy we have discussed across other Modiphius projects.

## The deal as I understand it

**Recoupment first, then an even split.** I keep 100% of net receipts from the app across all stores it is sold on until an agreed development-cost figure has been recouped. There is no upfront payment from Modiphius. After that figure is recouped, a monthly maintenance and support fee comes to me off the top, and the remainder is then split 50/50 between us.

**The figures I am proposing as a starting point** for the recoupment-cost conversation we agreed to open:

- A development-cost figure of **$35,000** to be recouped, reflecting the real cost of building and running the project to date.
- A monthly maintenance, support and development fee of **$1,000**, which applies after recoupment and before the 50/50 split, and which is intended to keep the app maintained, supported and updated after launch. The maintenance fee is taken in full while net receipts are at or below **$3,000 per month**. Between **$3,000 and $5,000 per month** the fee reduces on a straight line to zero. Above **$5,000 per month** no fee is taken and net receipts are split 50/50. The fee is payable only out of net receipts: if net receipts in a given month are less than the fee, the developer receives the receipts available for that month and Modiphius owes no shortfall.

These are opening proposals, not fixed terms. I expect we will refine them together, anchored to the data we start gathering during alpha testing. The monthly fee is meant as an ongoing operating arrangement regardless of how we end up pricing the app to players (see the open point below), not a charge tied to any one pricing model.

**"Net" means** gross receipts after the storefront's platform fee (for example Google Play's cut) has been taken. The 50/50 split applies to that net figure.

**If Modiphius later funds development, recoupment becomes pro-rata.** The structure above assumes I have carried the development cost to date. If Modiphius later contributes cash toward building the app (for example, funding development hardware, a contractor, or a specific content expansion), the development-cost figure grows by that amount and we recoup pro-rata, each in proportion to the cash we put in. For clarity, the following are Modiphius's contributions in exchange for the revenue split, and are not development-budget contributions for this purpose: the Five Parsecs intellectual property and trademarks, the art and brand assets, and marketing or channel support such as newsletter, social, Discord, and community amplification. Those are already reflected in the 50/50 split and in Modiphius's physical-book sales.

**Pricing model.** The app is sold as a one-time purchase, with each expansion available as a separate one-time paid unlock corresponding to the physical product line. This gives per-product sales attribution for royalty purposes. Indicative pricing is **$9.99** for the base app with expansions between **$4.99 and $6.99**, to be confirmed using data from the closed alpha and after launch. A subscription or all-access tier is not part of the launch model and would be a separate decision if the content programme later justifies it. The monthly maintenance fee applies regardless of pricing model.

## IP and ownership

Modiphius owns the Five Parsecs From Home intellectual property, including the rules text, the art, and the trademarks, and licenses them to me for use in the app and its expansions. I own the code and the underlying architecture I have built. On any termination, the Modiphius IP and assets revert to Modiphius and I retain my code, on terms we will set out in the full agreement. The Developer may substitute a business entity as the contracting party before the long-form agreement is executed with written agreement from both parties.

## Alpha and playtesting

We have agreed an approach for the closed alpha:

- Players sign up through a simple form, which also acts as an experience filter so we can select a strong testing group from the wider interested pool.
- I own and run the tester list and the day-to-day tester communication. Modiphius amplifies the call for testers through its channels (newsletter, social, the official Discord, the community group) when I ask.
- Testers who complete the program are credited as playtesters, and receive free access to the base app on release. This does not extend to paid expansion content.
- We hold a monthly check-in once things are rolling, and track the work on a shared board. Modiphius is otherwise out of the daily loop during the build.

The first big shared milestone we are working toward is the public release on Google Play.

## Phase 2 / wider platform (noted, not yet defined)

### Scope: the Five Parsecs family

This understanding covers the Five Parsecs From Home digital companion app and the wider Five Parsecs product line. Any Five Parsecs own-IP product, including the forthcoming squadron title and future releases in the family, may be added to the app by mutual agreement on the same terms set out above. Each such product ships as its own separately identifiable paid unlock, so sales can be attributed per product for royalty purposes. Titles that carry third-party rights, such as a Traveller edition, are outside this understanding.

We have both referred to a "stage 2": extending this digital platform to Modiphius properties beyond the Five Parsecs line. I would like the door kept open to that, with Five Leagues from the Borderlands as the natural first candidate given the shared design and architecture. To keep this first project focused, I am proposing we open the Five Leagues conversation once the Five Parsecs app has officially launched to the public, and that any wider arrangement across other properties is negotiated at that point. For that reason, this understanding is exclusive to me for the Five Parsecs digital companion app, but does not lock exclusivity across Modiphius's other properties, so that the stage 2 conversation stays genuinely open for both of us.

## Good faith, confidentiality, and the nature of this document

- We both commit to negotiating the long-form agreement in good faith.
- We will each keep confidential the terms of our discussions, the alpha tester list, any unreleased Modiphius material shared with me, and any of my roadmap that is not yet public.
- Each party covers its own costs up to signing the long-form agreement.
- Except for the confidentiality and good-faith points above, this document is non-binding. It records our shared understanding so the formal contract can be drawn from it.
- We are aiming to keep this understanding current for roughly the next six months while the formal agreement is prepared.

Governing law: England and Wales

[Modiphius: please add your standard partnership language and any corrections here.]

---

**Developer**: Elijah Rhyne, [date]

**Modiphius Entertainment Ltd.**: [name, title], [date]
