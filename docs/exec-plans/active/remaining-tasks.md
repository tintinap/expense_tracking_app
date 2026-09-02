# Remaining Tasks — Project PET

**PRD Reference:** v5.1.0  
**Last updated:** 2026-06-28  
**Scope:** All three apps — Mobile (Flutter), Backend (NestJS), Web (Next.js)

---

## Overview

| App | Status | Summary |
|---|---|---|
| Mobile (Flutter) | 🟡 ~85% | Core features complete. Sync is mocked; FCM registration not wired; recurring UI not in route. |
| Backend (NestJS) | 🟡 ~90% | All modules present. FCM/Firebase requires env credentials; Sheets requires Google OAuth creds; no `/sheets/status` endpoint; sync pull not fully implemented. |
| Web (Next.js) | 🔴 ~20% | All routes are placeholder scaffolds. Auth, data fetching, charts, and all CRUD are mocked or hardcoded. |

---

## Mobile (Flutter)

### 🔴 Critical

#### M1 — Sync Push & Pull are mocked (PRD §15)
**File:** `apps/mobile/lib/features/sync/providers/sync_provider.dart` (lines 98, 121)

The entire `processQueue()` method simulates network calls with `Future.delayed`. No real HTTP request is ever sent to the NestJS backend (`POST /sync/push` or `POST /sync/pull`).

- [ ] Replace mock push with real `POST /sync/push` using `DioClient`
- [ ] Replace mock pull with real `POST /sync/pull` and apply received records to Drift (last-write-wins)
- [ ] Wire connectivity detection (e.g. `connectivity_plus`) so sync fires on reconnect, not just on a 30s timer

---

#### M2 — FCM token never registered with backend (PRD §13)
Firebase Messaging is not in `pubspec.yaml` and `fcmToken` is never sent to backend `POST /notifications/fcm-token`.  
Budget alerts fire locally via `flutter_local_notifications` but cloud FCM from the backend is silent.

- [ ] Add `firebase_messaging` to `pubspec.yaml`
- [ ] On sign-in, get FCM token and `POST` it to `/notifications/fcm-token`
- [ ] Handle FCM foreground/background message delivery

---

### 🟡 Medium

#### M3 — Recurring expenses UI not accessible from Home (PRD §8, "Recurring expenses")
The `RecurringService` logic is complete and wired in `main.dart`. The `TransactionBottomSheet` has the recurring toggle UI. However, there is no way to **view, pause, or delete** recurring templates from any screen.

- [ ] Add "Manage Recurring" section or screen reachable from Home or Settings
- [ ] Allow pausing/deleting a recurring template without deleting all generated instances

---

#### M4 — Manual balance adjustment button missing (PRD §6 — Currency Wallets)
PRD §6 specifies a **manual balance adjustment button** on the Wallets screen ("for correcting discrepancies — adds a `balance_adjustment` note"). This is not implemented.

- [ ] Add adjustment button on `WalletsScreen` or `CurrencyDetailScreen`
- [ ] Creates an `expense` or `currency_income` record with a `balance_adjustment` note

---

#### M5 — `mock_data.dart` still shipped in release builds (tracked, kept by request)
`features/budgets/utils/mock_data.dart` is present. Not a runtime bug, but it ships in production.

- [ ] Add a conditional guard so it is only callable in debug mode (or accept as-is)

---

### 🟢 Low / Polish

#### M6 — View currency not shown in Wallets total (PRD §6, §10)
PRD: *"Overview card: total portfolio value — sum of all currency balances converted to base currency… view currency equivalent shown in smaller text below when base ≠ view."*

- [ ] Verify `WalletsScreen` total card shows `≈ {viewCurrencyAmount}` row when `base ≠ view`

#### M7 — Apple Sign-In upsell for Sheets missing (PRD §7)
When an Apple-authenticated user navigates to the Google Sheets section in Settings, a specific informational banner should appear (not a blocking gate). Verify this is implemented.

- [ ] Confirm `settings_screen.dart` shows the upsell copy per PRD §7 for Apple users

---

## Backend (NestJS)

### 🔴 Critical

#### B1 — Firebase credentials missing → FCM silently disabled (PRD §13)
`notifications.service.ts` gracefully degrades when `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` are not set. The `apps/api/.env` shows these as empty.

- [ ] Provision a Firebase project and service account
- [ ] Add credentials to `.env` (not committed) and to production environment

---

#### B2 — Google OAuth credentials missing → Sheets and Auth non-functional (PRD §7, §16)
`apps/api/.env` has `GOOGLE_CLIENT_ID=` (empty). Without this, `POST /auth/google` will fail token verification and `SheetsService` will fail to create an OAuth2 client.

- [ ] Create a Google Cloud project with OAuth 2.0 credentials
- [ ] Configure `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI` in `.env`

---

#### B3 — No `GET /sheets/status` endpoint (referenced by mobile)
`apps/mobile/lib/features/settings/providers/sheets_provider.dart` line 45 calls `GET /sheets/status` to check if Sheets is connected. This endpoint does not exist in `sheets.controller.ts`.

- [ ] Add `GET /sheets/status` endpoint that returns `{ connected: boolean, sheetUrl?: string }`

---

#### B4 — `POST /sync/pull` response not fully merged on mobile (PRD §15)
The backend `sync.service.ts` has a `pull()` method returning `transactions`, `categories`, `budgets`, `serverTimestamp`. The mobile `sync_provider.dart` mock does not apply these — so even when real sync is wired, the pull path needs to write received records into Drift with last-write-wins logic.

- [ ] (Backend) Confirm pull response shape matches what mobile expects
- [ ] (Mobile — see M1) Apply received records to Drift

---

### 🟡 Medium

#### B5 — Sync push does not emit to Google Sheets (PRD §15 + §16)
`SyncService.syncTransaction()` does not call `SheetsService` after writing to PostgreSQL. The PRD says Sheet writes should happen after sync. Currently the `SheetsProcessor` queue handles it, but verify it is actually wired to the sync path.

- [ ] Confirm `SheetsProcessor` jobs are enqueued after `sync/push` writes transactions
- [ ] If not, add `this.sheetsProcessor.enqueue(...)` call in `SyncService`

---

#### B6 — No `DELETE /notifications/fcm-token` endpoint (PRD §13)
`notifications.controller.ts` has `POST` (register) but no `DELETE` (unregister on logout). PRD §13 implies the token should be cleared on sign-out.

- [ ] Add `DELETE /notifications/fcm-token` endpoint
- [ ] Call it on mobile logout before clearing local JWT

---

### 🟢 Low / Polish

#### B7 — Apple Sign-In strategy uses placeholder verification
`auth.service.ts#verifyAppleToken` — verify this is actually validating the Apple JWT against Apple's public keys (via `apple-auth` or JWKS), not just decoding without verification.

- [ ] Audit `verifyAppleToken` to confirm it validates signature against Apple's JWKS endpoint

#### B8 — Conflict log `losing_version` JSON not always written (PRD §15)
PRD §15: "losing version JSON is written to `conflict_log` table." Verify `sync.service.ts` writes the full payload and not just a partial record.

- [ ] Audit conflict logging in `sync.service.ts` to ensure complete payload is stored

---

## Web (Next.js)

> All pages currently use **hardcoded mock data** or `alert()` stubs. The `AuthContext` issues mock tokens. No page talks to the NestJS backend.

### 🔴 Critical (blocks everything else)

#### W1 — Auth is mocked; no real JWT (PRD §7)
`AuthContext.tsx`: `login()` creates a `mock_token_*` string in `localStorage`. No OAuth or NestJS API call is made.

- [ ] Wire Google Sign-In (e.g. `@react-oauth/google`) → POST id-token to `/auth/google` → store JWT
- [ ] Wire Apple Sign-In → POST identity-token to `/auth/apple` → store JWT
- [ ] Implement token refresh using `/auth/refresh`
- [ ] Replace `localStorage` with `httpOnly` cookies (or at minimum migrate from mock token to real JWT)
- [ ] `ProtectedRoute` already blocks unauthenticated routes — keep this

---

#### W2 — Dashboard: hardcoded mock data, placeholder chart (PRD §6, §14)
`dashboard/page.tsx`: balance is `setBalance(5430.25)`, chart is colored `<div>` elements.

- [ ] Fetch real transactions from `GET /transactions` (filtered by current period)
- [ ] Compute: total spent, net income, top category from real data
- [ ] Add period selector (Daily/Weekly/Fortnightly/Monthly/Yearly)
- [ ] Replace mock chart with `recharts` BarChart fed by real daily aggregates
- [ ] Add spend-by-category donut chart (base currency only — PRD §10 rule)
- [ ] Show base currency primary + view currency secondary (≈) per PRD §10

---

#### W3 — Transactions: hardcoded rows, `ExpenseModal` uses `console.log` (PRD §8)
`transactions/page.tsx`: 4 hardcoded rows. `ExpenseModal.handleSubmit` only `console.log('Saved', formData)`.

- [ ] Fetch real transactions from `GET /transactions` (paginated, with type/category/date filters)
- [ ] Wire `ExpenseModal` save to `POST /transactions` (create) or `PATCH /transactions/:id` (edit)
- [ ] Wire delete action to `DELETE /transactions/:id` with confirmation dialog
- [ ] Fetch real categories from `GET /categories` for the category picker dropdown
- [ ] Add column sorting and type filtering

---

#### W4 — Wallets: static `$0.00` placeholder (PRD §6, §11c)
`wallets/page.tsx`: always shows `$0.00 AUD`, no real balances.

- [ ] Fetch currency balances from backend (via `GET /sync/pull` or a dedicated `/wallets` endpoint)
- [ ] Display portfolio total in base currency; view currency secondary (≈)
- [ ] List one card per non-zero currency with: ISO code, balance, base equiv
- [ ] Link to currency-filtered transaction view

---

#### W5 — Reports: empty placeholder, no charts (PRD §14)
`reports/page.tsx`: only shows *"Reports will appear once you have transactions."*

- [ ] Add period selector
- [ ] Donut chart: spend by category (base currency)
- [ ] Bar chart: daily spend within period using `recharts`
- [ ] Line chart: rolling spend trend using `recharts`
- [ ] Period comparison card: current vs previous (absolute + %)
- [ ] Category list with spend % of total

---

#### W6 — Budgets: empty placeholder, no data (PRD §6, §13)
`budgets/page.tsx`: only shows *"No budgets configured yet."*

- [ ] Fetch from `GET /budgets`
- [ ] Display progress bar per budget (green/amber/red per PRD §13 thresholds)
- [ ] Add Budget modal → `POST /budgets`
- [ ] Show amount used / limit, period type
- [ ] Budget Detail view (progress breakdown + period history for recurring)

---

#### W7 — Settings: all actions are `alert()` stubs (PRD §6, §7, §16, §17)
`settings/page.tsx`: Export triggers `alert('Export downloaded successfully.')`, Sheets toggle triggers `alert('Google Sheets integration connected!')`, base currency `<select>` has no `onChange` handler wired to backend.

- [ ] **Excel Export** → call `GET /export/excel` authenticated, trigger file download via blob
- [ ] **Google Sheets Connect** → call `POST /sheets/setup`; show linked sheet URL on success
- [ ] **Google Sheets Disconnect** → call `POST /sheets/disconnect`
- [ ] **Base currency picker** → persist via backend or user preferences endpoint
- [ ] **Theme toggle** → persist to localStorage (web-only)
- [ ] **Account section** → show real user info (email, provider) from JWT claims
- [ ] **Delete Account** → call `DELETE /auth/account` with confirmation; redirect to login
- [ ] **Apple user upsell** → when Apple-authenticated user opens Sheets section, show informational banner (not a block)

---

### 🟡 Medium

#### W8 — Excel Import: non-compliant with PRD §25
`import/page.tsx` does a basic XLSX parse and POSTs to `/transactions/bulk` (non-existent endpoint — should be `/import/transactions`).  
Missing: multi-sheet support, duplicate detection badges, missing category mapping UI, aggregate row detection.

- [ ] Fix endpoint to `POST /import/transactions`
- [ ] Support all 3 sheet types per PRD §25 (`All Transactions`, `Currency Income`, `Currency Exchanges`)
- [ ] Implement dedup skip logic (when specialized sheets present, skip those types from `All Transactions`)
- [ ] Show per-row status badges: ✅ OK, 🔄 Update (UUID match), ⚠️ Probable Duplicate, ❌ Error
- [ ] Add **Missing Category Mapping** UI (map unknown categories before commit)
- [ ] Detect aggregate rows (`Period` column or `[WEEK]`/`[MONTH]` prefix in Description)

---

#### W9 — View currency not implemented anywhere on web (PRD §10, §26)
The web has no concept of view currency. All amounts are shown in a single currency.

- [ ] Add view currency preference to Settings
- [ ] Apply `≈ {viewAmount}` secondary rows in Dashboard, Transactions, Wallets, Reports
- [ ] Hide secondary row when `base == view`

---

#### W10 — i18n: Thai (TH) locale strings missing for new UI
`messages/th.json` may be missing strings for all new pages (Reports, Budgets, Import, etc.).

- [ ] Audit `messages/en.json` vs `messages/th.json` and add all missing TH strings

---

### 🟢 Low / Polish

#### W11 — `sidebar.tsx` missing Transactions link
Sidebar currently shows Dashboard, Wallets, Reports, Budgets, Import, Settings — no **Transactions** link even though the route exists at `/transactions`.

- [ ] Add Transactions nav item to sidebar

---

## Environment / Config / DevOps

| # | Task | Priority |
|---|---|---|
| E1 | Populate `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI` in `apps/api/.env` for real OAuth | 🔴 P0 |
| E2 | Provision Firebase project; populate `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` in `apps/api/.env` | 🔴 P0 |
| E3 | Add `NEXT_PUBLIC_API_URL` to `apps/web/.env.local` pointing to running NestJS instance | 🟡 P1 |
| E4 | Add Google Sign-In client ID to `apps/web/.env.local` for OAuth SDK | 🟡 P1 |

---

## Summary Count

| Category | Total Tasks | 🔴 Critical | 🟡 Medium | 🟢 Low |
|---|---|---|---|---|
| Mobile | 7 | 2 | 2 | 3 |
| Backend | 8 | 4 | 2 | 2 |
| Web | 11 | 7 | 2 | 2 |
| Env/Config | 4 | 2 | 2 | 0 |
| **Total** | **30** | **15** | **8** | **7** |
