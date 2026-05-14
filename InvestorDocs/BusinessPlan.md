# ScholarsGallery — Business Plan
**Confidential | Prepared for Angel Investor Review**
*Australian Investment Network — Proposal 1619143*

---

## 1. Executive Overview

ScholarsGallery is an Australian-focused iOS platform at the intersection of AI-powered professional training and digital art commerce. The company operates two distinct but complementary revenue streams under a single app:

1. **Aged Care Monitor** — an on-device AI coaching platform for Australia's 366,000+ aged care workers, delivering trauma-aware communication training, dementia-dignity curriculum, and personalised flashcard learning
2. **Creative Studio & Gallery** — an AI image generation studio and curated digital art marketplace for collectors and creative professionals

The app is built natively on Apple's latest frameworks (Foundation Models, StoreKit 2, CloudKit, SwiftData), available on iOS, and distributed through the App Store with a subscription and à la carte commerce model.

We are seeking **seed investment** to accelerate go-to-market in the Australian aged care sector, expand curriculum content, and fund App Store launch marketing.

---

## 2. Problem Statement

### Aged Care Workforce Crisis
Australia's aged care sector faces a chronic workforce quality and retention problem. The 2021 Royal Commission into Aged Care Quality and Safety found:

- Over **60% of residential care workers** have received no formal dementia-specific training
- Trauma-informed and dignity-centred communication is consistently identified as a skills gap
- Existing training solutions are **web-based, session-locked, and expensive** (AUD $400–$1,200 per worker per year), making ongoing micro-learning practically inaccessible on the floor

### Creative Professional Market Gap
AI image generation tools (Midjourney, Stable Diffusion) are powerful but divorced from scholarly context, art history, and curated collections. There is no premium iOS-native platform that bridges AI creativity with genuine intellectual and collectible depth.

---

## 3. Solution

ScholarsGallery delivers training and creativity as a single coherent iOS experience:

| Feature | Value Delivered |
|---|---|
| **Aged Care Monitor** | On-device AI flashcards, lesson plans, and study coach for trauma-aware care — works offline, no corporate LMS required |
| **Study Coach** | Apple Intelligence–powered tutoring that adapts to a worker's last topic and role |
| **Exhibitions & Essays** | Curated scholarship essays tied to artworks — continuing education with academic rigour |
| **Creative Studio + Dola** | AI prompt refinement + image generation for professionals and collectors |
| **Collection & Editions** | Owned digital art with CloudKit-backed provenance tracking |
| **Admin Panel** | Operator-level controls for care facility managers or studio operators |

---

## 4. Market Opportunity

### Aged Care Training (Primary TAM)
| Metric | Value |
|---|---|
| Australian aged care workforce | ~366,000 workers (AIHW 2023) |
| Facilities (residential + home care) | ~2,700+ approved providers |
| Addressable workers (residential) | ~230,000 |
| Target penetration Year 3 | 2% of residential workforce |
| Implied subscribers at 2% | ~4,600 |
| ARPU (Monitor Monthly AUD $14.99) | ~AUD $828,000 ARR |

### Creative Studio / Collector Market (Secondary TAM)
- Australia has ~1.2M active art market participants (Arts Council 2022)
- AI creative tools subscription market: USD $1.4B globally (2024), growing 38% CAGR
- Target 0.1% penetration = 1,200 Studio subscribers

### Combined 3-Year ARR Target: AUD $1.6M+

---

## 5. Product & Technology

### Architecture
- **Platform**: iOS 18+ (iPhone, iPad)
- **AI**: Apple Foundation Models (on-device, no cloud cost for inference)
- **Backend**: Vapor (Swift) server on custom domain `api.scholarsgallery.app`
- **Data sync**: CloudKit (iCloud) — zero additional database cost for users
- **Payments**: StoreKit 2 — Apple-managed subscriptions and in-app purchases
- **Distribution**: App Store (global) with TestFlight beta pipeline

### IP Moats
1. **On-device AI inference** — training content is private, secure, and works offline — critical differentiator for care floor environments where devices may be in airplane mode
2. **Curriculum depth** — trauma-aware, dementia-specific content developed with aged care clinical input
3. **Scholarship integration** — unique positioning linking art history and care philosophy
4. **Operator tooling** — admin access grant system enables B2B2C facility-level deployment

### Development Status
- App in **TestFlight beta** with full CI/CD pipeline (GitHub Actions → TestFlight)
- 47 unit tests + full UI test suite passing
- CloudKit sync, StoreKit subscriptions, and admin panel fully implemented
- Production API server live at `api.scholarsgallery.app`

---

## 6. Business Model

### Revenue Streams

| Stream | Product | Price (AUD) | Billing |
|---|---|---|---|
| Monitor subscription | `gallery.monitor.monthly` | ~$14.99/mo | Monthly recurring |
| Monitor subscription | `gallery.monitor.yearly` | ~$119.99/yr | Annual recurring |
| Studio subscription | `gallery.studio.monthly` | ~$19.99/mo | Monthly recurring |
| Studio subscription | `gallery.studio.yearly` | ~$159.99/yr | Annual recurring |
| Generation credits | `gallery.studio.generation.pack` | ~$4.99 pack | One-time IAP |
| Digital art editions | Marketplace checkout | Variable | One-time sale |

### Unit Economics (Monitor, Monthly Sub)
- ARPU: AUD $14.99/mo
- App Store net (after 30% → 15% for small dev): ~AUD $12.74/mo per sub
- Estimated CAC (App Store organic + aged care referral): AUD $35–60
- Payback period: 3–5 months
- Estimated LTV (12-month retention): AUD $153/user

---

## 7. Go-to-Market Strategy

### Phase 1 — App Store Launch (Months 1–3)
- TestFlight → App Store public launch
- Content seeding: 3 full Monitor curriculum units (dementia, trauma, co-design)
- Referral program through aged care professional networks (LinkedIn, ACSA, LASA)
- PR in sector publications (*Australian Ageing Agenda*, *Aged Care Insite*)

### Phase 2 — Facility Partnerships (Months 4–9)
- Direct outreach to top 50 residential aged care providers by bed count
- Offer facility-level admin panel with usage analytics
- Pilot program: 3-month free access for 1 facility (50–100 workers) → convert to group licensing
- Target: 5 pilot facilities × 80 workers avg = 400 active subscribers

### Phase 3 — B2B Licensing (Month 10+)
- Volume licensing for facilities (e.g., AUD $8/worker/month for 50+ seats)
- Integration with facility rostering/LMS systems via API
- Expand to New Zealand, UK aged care markets (same English-language content)

---

## 8. Competitive Landscape

| Competitor | Type | Weakness vs ScholarsGallery |
|---|---|---|
| Altura Learning | Web LMS, aged care | Session-locked, no AI, no offline, high cost |
| HelpingMinds / CarePath | Care workflow apps | No training content |
| Midjourney / DALL-E | AI image tools | No care content, no iOS-native, no scholarship layer |
| Dementia Australia eLearning | Free, government | No personalisation, no flashcards, no ongoing engagement |
| Generic mLearning platforms | Broad eLearning | Not aged-care specific, no on-device AI |

**Key differentiator**: ScholarsGallery is the only platform combining on-device AI coaching, dementia/trauma-specific curriculum, and digital art scholarship in a single polished iOS app.

---

## 9. Team

| Role | Responsibility |
|---|---|
| Founder / CEO | Product vision, iOS development, clinical curriculum direction |
| (Hiring) Head of Care Content | Curriculum development, clinical validation, ACSA partnerships |
| (Hiring) Growth / Partnerships | Aged care facility sales, App Store ASO, content marketing |

The founding team brings deep iOS platform expertise (Xcode 26, SwiftUI, Foundation Models) and a clear understanding of the aged care workforce challenge.

---

## 10. Financial Summary

*(See accompanying Financials document for full 3-year model)*

| Metric | Year 1 | Year 2 | Year 3 |
|---|---|---|---|
| Total Subscribers | 320 | 1,850 | 5,100 |
| ARR (AUD) | $58,000 | $342,000 | $940,000 |
| Gross Revenue | $68,000 | $398,000 | $1,080,000 |
| Net Revenue (post App Store) | $57,800 | $338,300 | $918,000 |
| Operating Expenses | $185,000 | $310,000 | $490,000 |
| EBITDA | ($127,200) | $28,300 | $428,000 |
| Cumulative Cash Position | ($127,200) | ($98,900) | $329,100 |

**Break-even**: Mid Year 2 (~Month 20)
**Investment sought**: AUD $250,000 seed round
**Use of funds**: 60% product & content (curriculum, AI), 25% marketing & partnerships, 15% operations

---

## 11. Investment Opportunity

**Raise**: AUD $250,000
**Structure**: SAFE note or convertible equity at AUD $2.5M cap
**Use of Funds**:

| Category | Amount | Purpose |
|---|---|---|
| Curriculum & content | $95,000 | 3 additional Monitor modules, clinical review |
| Marketing & ASO | $62,500 | App Store optimisation, sector PR, influencer pilots |
| Facility partnerships | $37,500 | Pilot program delivery, enterprise sales |
| Operations & infrastructure | $37,500 | API scaling, server costs, legal |
| Working capital reserve | $17,500 | Buffer |

**Return scenario (3-year exit)**:
- Strategic acquisition by Altura Learning, Medibank, or BUPA aged care division
- Comparable SaaS exit multiples: 4–6× ARR
- At AUD $940,000 ARR Year 3 → implied valuation AUD $3.8M–$5.6M
- Investor return on $250K seed at $2.5M cap: **1.5×–2.2× at Year 3 exit**

---

## 12. Risk Factors & Mitigations

| Risk | Mitigation |
|---|---|
| App Store review delays | TestFlight pipeline live; CI/CD auto-deployment reduces iteration cycle |
| Low aged care worker smartphone penetration | iPad-compatible; facility-provided devices becoming standard post-Royal Commission |
| Apple Foundation Models availability | Fallback to cloud inference (Dola API) already built into architecture |
| Competition from free government tools | Premium positioning; AI personalisation unavailable in free tools |
| Key person dependency | Documented codebase, CI pipeline, hiring plan for content lead |

---

## 13. Appendices

- A: App screenshots and feature walkthrough *(available on request)*
- B: TestFlight beta link *(available to accredited investors under NDA)*
- C: 3-Year Financial Model *(see Financials document)*
- D: Pitch Deck *(see Pitch Deck document)*

---

*This document contains forward-looking statements and projections. Actual results may vary. This is not a prospectus. For sophisticated investor use only in accordance with the Corporations Act 2001 (Cth).*

*© 2025 ScholarsGallery. All rights reserved. Confidential.*
