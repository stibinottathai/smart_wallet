# Smart Wallet — Play Store Listing Pack

Everything you need to paste into the Google Play Console. Character limits noted.

---

## App title (max 30 chars)

```
Smart Wallet: Expense Tracker
```
(29 chars)

Alternative: `Smart Wallet — Money Manager` (28 chars)

## Short description (max 80 chars)

```
Track income & expenses offline. AI insights, budgets, reminders & reports.
```
(75 chars)

## Full description (max 4000 chars)

```
Smart Wallet is a private, offline-first money manager that helps you track every
rupee — income, expenses, budgets, savings goals and bills — without accounts,
ads, or tracking. Your data stays on your device.

WHY SMART WALLET

• Offline-first & private — all your financial data is stored locally on your
  phone. No sign-up, no cloud account, no ads.
• AI-powered insights (optional) — bring your own API key (OpenRouter, Anthropic
  or OpenAI) to get personalised spending analysis and savings tips.
• Built for India — defaults to ₹ INR, with 11 other currencies supported.

TRACK EVERYTHING
• Log income and expenses in seconds with smart categories.
• Scan receipts with your camera — text is recognised on-device to pre-fill entries.
• Add entries by voice using on-device speech recognition.
• Set monthly budget limits per category and savings goals.
• Keep on top of recurring bills and subscriptions.

STAY ON TRACK
• Daily reminders to log your spending (12:00 PM & 8:00 PM).
• Budget alerts when a category nears its monthly limit.
• A daily insight summarising your finances with a personalised savings tip.

UNDERSTAND YOUR MONEY
• Beautiful charts and a financial health score.
• Monthly PDF reports you can save or share.
• Full CSV backup & restore — move your ledger to a new phone anytime.

PRIVATE BY DESIGN
• No account, no sign-up, no ads, no tracking.
• Your financial data never leaves your device.
• AI features are off until you choose to enable them with your own key.

Smart Wallet keeps your finances simple, private, and entirely in your control.
```

---

## Category & contact

- **App category:** Finance
- **Email:** stib.inau.gus.tin.e.07@gmail.com
- **Privacy policy URL:** host `store/privacy_policy.md` publicly (GitHub Pages /
  Google Sites / any static host) and paste the URL here.

---

## Data safety form (answers)

> Path in Console: App content → Data safety.

**Does your app collect or share any of the required user data types?** → **Yes**
(because of the optional AI feature). Declare only what actually applies:

- **Data type: Financial info → "Other financial info"**
  - Collected? **No** (we don't collect it on our servers).
  - Shared? **Yes** — shared with a third-party AI provider, **only when the user
    enables AI** and provides their own key.
  - Purpose: **App functionality** (generating insights).
  - Is sharing optional (user can choose)? **Yes**.

- **Security practices:**
  - Is data encrypted in transit? **Yes** (HTTPS to the AI provider).
  - Can users request data deletion? **Yes** — data is on-device; clearing app
    data or uninstalling removes it.

- **Everything else** (transactions, receipts, audio): processed **on-device
  only**, not collected or shared → do **not** declare as collected. Camera and
  microphone inputs are used locally and are not sent off the device.

> If you ship the first release **without** enabling/announcing AI and want the
> simplest form, you could answer "No data collected or shared" — but since the AI
> option exists in-app, declaring the optional financial-info sharing above is the
> accurate and safe choice.

---

## Content rating questionnaire

- Category: **Utility / Productivity / Finance** (no game content).
- No violence, sexual content, profanity, gambling, or user-generated content.
- Expected rating: **Everyone / PEGI 3**.

---

## Required graphic assets (you produce these)

| Asset | Spec | Notes |
|---|---|---|
| App icon | 512 × 512 PNG (32-bit) | Reuse `assets/app_icon.png` upscaled/clean. |
| Feature graphic | 1024 × 500 PNG/JPG | Banner shown at top of listing. |
| Phone screenshots | 2–8, min 1080px, 16:9 or 9:16 | Capture: dashboard, add expense, insights/charts, budgets, settings. |
| (Optional) 7" / 10" tablet shots | — | Only if targeting tablets. |

Screenshot capture tip: run the release build on a device/emulator, add a few
sample transactions so the charts and insights look populated, then screenshot the
Dashboard, Insights, Budgets, Receipt scan, and Settings screens.

---

## Release checklist

1. [ ] Create `android/key.properties` (your keystore password).
2. [ ] `flutter build appbundle --release` → upload `app-release.aab`.
3. [ ] Host privacy policy; paste URL into Console.
4. [ ] Fill store listing (title/descriptions above) + upload graphics.
5. [ ] Complete Data safety + Content rating.
6. [ ] Upload to **Internal testing**, add your email as a tester, install & verify.
7. [ ] Promote to Production.
