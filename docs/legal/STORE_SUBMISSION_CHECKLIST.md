# Store Submission Legal Checklist

**Last Updated:** 2026-04-07

This checklist covers all legal/compliance steps required before submitting to each platform. Complete all items before first submission.

---

## Pre-Submission (All Platforms)

- [ ] Replace `[DATE OF RELEASE]` in `data/legal/eula.md` and `data/legal/privacy_policy.md`
- [ ] Replace `[CONTACT EMAIL]` in both documents with actual support email
- [ ] Resolve all `[PENDING MODIPHIUS REVIEW]` markers in EULA (requires Modiphius legal input)
- [ ] Update `docs/legal/gh-pages/privacy.html` and `eula.html` to match final Markdown versions
- [ ] Enable GitHub Pages: repo Settings > Pages > Source: Deploy from branch > `/docs/legal/gh-pages`
- [ ] Verify live URLs work:
  - Privacy: `https://reptarus.github.io/five-parsecs-campaign-manager/legal/gh-pages/privacy.html`
  - EULA: `https://reptarus.github.io/five-parsecs-campaign-manager/legal/gh-pages/eula.html`
- [ ] Test EULA screen blocks first launch (delete `user://legal_consent.cfg` to verify)
- [ ] Test data export and data deletion flows in Settings

---

## Google Play Store

### Privacy Policy
- [ ] Enter privacy policy URL in Play Console > App content > Privacy policy
- [ ] Verify URL loads correctly (Google reviews it)

### Data Safety Form
- [ ] Complete Data Safety form in Play Console > App content > Data safety

**Pre-filled answers for V1 (local-only, no cloud):**

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | Yes |
| Is all of the user data collected by your app encrypted in transit? | N/A (no data transmitted) |
| Do you provide a way for users to request that their data is deleted? | Yes (Settings > Delete All Data) |

**Data types:**
| Type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Personal info (name, email, etc.) | No | No | - |
| Financial info | No | No | - |
| Location | No | No | - |
| App activity | No | No | - |
| App info and performance | No | No | - |
| Device or other IDs | No | No | - |

**Note:** If analytics upload is enabled in a future version, update these answers to reflect data transmission.

### IARC Age Rating
- [ ] Complete IARC questionnaire in Play Console > App content > Content rating

**Expected answers:**
- Violence: Mild (text descriptions of sci-fi combat, no graphic imagery)
- Sexual content: None
- Language: None
- Controlled substance: None
- User interaction: None (single-player, no multiplayer)
- Shares location: No
- Digital purchases: Yes (DLC/expansion packs)

**Expected rating:** PEGI 7 or PEGI 12

### EULA
- [ ] Optional: Enter EULA text in Play Console (Google has default terms if omitted)

---

## Apple App Store

### Privacy Policy
- [ ] Enter privacy policy URL in App Store Connect > App Information > Privacy Policy URL
- [ ] Verify URL loads correctly

### App Privacy Details (Nutrition Label)
- [ ] Complete in App Store Connect > App Privacy

**Pre-filled answers for V1:**

| Category | Data collected? | Linked to identity? | Used for tracking? |
|---|---|---|---|
| Contact Info | No | - | - |
| Health & Fitness | No | - | - |
| Financial Info | No | - | - |
| Location | No | - | - |
| Sensitive Info | No | - | - |
| Contacts | No | - | - |
| User Content | No | - | - |
| Browsing History | No | - | - |
| Search History | No | - | - |
| Identifiers | No | - | - |
| Purchases | No* | - | - |
| Usage Data | No | - | - |
| Diagnostics | No | - | - |

*Purchases are handled entirely by Apple StoreKit. Apple does not require you to declare data that Apple itself collects through its own services.

### Age Rating
- [ ] Set in App Store Connect > App Information > Age Rating

**Expected:** 9+ (Infrequent/Mild Cartoon or Fantasy Violence)

### EULA
- [ ] Use Apple's default EULA or provide custom EULA text in App Store Connect

### Apple Sign-In Requirement
- [ ] If any third-party sign-in is offered (Google, Facebook), Apple Sign-In MUST also be offered
- [ ] For V1 (no sign-in): Not applicable

---

## Steam

### Privacy Policy
- [ ] Add privacy policy link to store page (Steamworks > Store Page > Legal)
- [ ] Or include in game's EULA section on Steam

### EULA
- [ ] Optional: Add custom EULA in Steamworks > Store Page > Legal Info
- [ ] If omitted, Steam Subscriber Agreement applies as default

### Age Rating / Content Descriptors
- [ ] Complete content survey in Steamworks > Store Page > Content Descriptors
- [ ] Ensure `steam_appid.txt` exists at project root with correct App ID

**Expected rating:** Everyone 10+

### Additional Steam Requirements
- [ ] Controller support declared (if applicable)
- [ ] System requirements listed accurately
- [ ] Screenshots and trailers uploaded
- [ ] Steam overlay tested with GodotSteam

---

## Post-Submission Monitoring

- [ ] Monitor for privacy policy review feedback from Google/Apple
- [ ] If analytics upload ships: update Data Safety form, Nutrition Label, and privacy policy
- [ ] If cloud save ships: update Data Safety form, Nutrition Label, privacy policy, and add consent flow
- [ ] Respond to any GDPR/CCPA data requests within 30 days
- [ ] Update EULA version constant in `LegalConsentManager.gd` when terms change (re-triggers acceptance)
