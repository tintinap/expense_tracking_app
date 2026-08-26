# Product Requirements Document

## Project PET — Personal Expense Tracker (Monorepo)

**Version:** 5.2.1
**Last updated:** 13 August 2026
**Status:** Active

---

## Table of Contents

1. [Overview](#1-overview)
2. [Goals &amp; success metrics](#2-goals--success-metrics)
3. [Target users](#3-target-users)
4. [Platform &amp; tech stack](#4-platform--tech-stack)
5. [App architecture overview](#5-app-architecture-overview)
6. [Screen map &amp; navigation](#6-screen-map--navigation)
7. [Authentication &amp; account model](#7-authentication--account-model)
8. [Expense entry &amp; management](#8-expense-entry--management)
9. [Categories](#9-categories)
10. [Currency handling](#10-currency-handling)
11. [Currency income &amp; exchange events](#11-currency-income--exchange-events)
12. [Time period views](#12-time-period-views)
13. [Budget alerts](#13-budget-alerts)
14. [Visualisation dashboard](#14-visualisation-dashboard)
15. [Offline-first sync architecture](#15-offline-first-sync-architecture)
16. [Google Sheets integration](#16-google-sheets-integration)
17. [Excel export](#17-excel-export)
18. [Theming (light &amp; dark mode)](#18-theming-light--dark-mode)
19. [Error states &amp; edge cases](#19-error-states--edge-cases)
20. [Data models](#20-data-models)
21. [Riverpod providers](#21-riverpod-providers)
22. [User stories &amp; acceptance criteria](#22-user-stories--acceptance-criteria)
23. [Non-functional requirements](#23-non-functional-requirements)
24. [Out of scope (v1)](#24-out-of-scope-v1)
25. [Excel Import](#25-excel-import)
26. [View Currency Display Improvements (v5.1.0)](#26-view-currency-display-improvements-v510)
27. [Implementation Rollout Update (v5.2.0)](#27-implementation-rollout-update-v520)

---

## 1. Overview

Project PET is a personal expense tracking application built as a **monorepo** with three apps:

- **Flutter mobile app** (iOS & Android) — offline-first with local SQLite storage
- **Next.js web app** — online-only, same feature set and visual style as mobile
- **NestJS backend API** — cloud source of truth, handles sync, auth, and Google Sheets integration

Users can log, categorise, and analyse daily spending across multiple currencies. The mobile app is **offline-first**: SQLite (via Drift) is the primary write target on device. When online and signed in, the mobile app syncs to the NestJS backend. The Next.js web app talks directly to the NestJS API (online only).

The **base currency** is user-configurable (default: **AUD**). All stored amounts are converted to the user's base currency. Original currency and amount are also stored for auditability. Changing the base currency re-converts all stored `amount_base` values using the latest exchange rates.

---

## 2. Goals & success metrics

### Goals

- Log an expense in under 10 seconds
- Work fully offline on mobile; sync seamlessly when connectivity returns
- Alert users before they overspend, not after
- Mirror expense data to Google Sheets automatically (via backend)
- Give users clear spending insight across flexible time periods
- Maintain consistent UI/UX between mobile and web

### Success metrics

| Metric                              | Target                                                  |
| ----------------------------------- | ------------------------------------------------------- |
| Time to log one expense             | < 10 seconds                                            |
| Offline entry → sync on reconnect  | 100% of pending records synced                          |
| Budget alert delivery               | Fires once at 75%, once at 90%, once at 100% per period |
| Google Sheet write latency (online) | < 5 seconds after sync to backend                       |
| App cold start (mobile)             | < 2 seconds on mid-range device                         |
| Web page load (initial)             | < 3 seconds                                             |
| Crash rate                          | < 0.5% of sessions                                      |

---

## 3. Target users

**Primary:** Individual users tracking personal daily expenses with occasional multi-currency spending (e.g. travel abroad, online purchases in foreign currencies). The app supports any base currency, making it suitable for users worldwide. Default base currency is AUD.

**Key use cases:**

- Logging coffee, groceries, transport on the go (mobile, offline)
- Reviewing weekly/monthly spend trends on a laptop (web)
- Checking exchange-rate-adjusted totals when travelling
- Sharing or auditing expenses via Google Sheets

---

## 4. Platform & tech stack

### Monorepo structure

| App         | Technology                                       | Location         |
| ----------- | ------------------------------------------------ | ---------------- |
| Mobile      | Flutter (iOS & Android)                          | `apps/mobile/` |
| Web         | Next.js 16 (App Router, Tailwind, i18n: EN + TH) | `apps/web/`    |
| Backend API | NestJS 11 (TypeScript)                           | `apps/api/`    |

### Mobile app stack

| Layer            | Choice                                    | Notes                                                 |
| ---------------- | ----------------------------------------- | ----------------------------------------------------- |
| Framework        | Flutter                                   | iOS & Android from one codebase                       |
| Local database   | **SQLite via `drift`**            | Source of truth on device; offline-first              |
| State management | **Riverpod**                        | `flutter_riverpod` + `riverpod_annotation`        |
| Navigation       | **`go_router`**                   | Declarative routing with`ShellRoute` for bottom nav |
| HTTP             | **`dio`**                         | With interceptors for auth (JWT) + retry              |
| Secure storage   | `flutter_secure_storage`                | JWT tokens only                                       |
| Exchange rates   | Frankfurter API (`api.frankfurter.app`) | Free, ECB-backed, no API key required                 |

### Backend API stack

| Layer              | Choice                           | Notes                                               |
| ------------------ | -------------------------------- | --------------------------------------------------- |
| Framework          | NestJS 11                        | TypeScript, modular                                 |
| ORM                | **Prisma 6**               | PostgreSQL schema management + migrations           |
| Database           | **PostgreSQL 16**          | Cloud source of truth                               |
| Auth               | **Passport.js + JWT**      | `@nestjs/passport` + `@nestjs/jwt`              |
| OAuth providers    | Google OAuth 2.0 + Apple Sign-In | Via Passport strategies                             |
| Google Sheets      | Google Sheets API v4             | Server-side mirror; backend writes to Sheet on sync |
| Push notifications | Firebase Cloud Messaging (FCM)   | Budget alerts (mobile only, v1)                     |

### Web app stack

| Layer     | Choice                           | Notes                            |
| --------- | -------------------------------- | -------------------------------- |
| Framework | Next.js 16                       | App Router, server components    |
| Styling   | Tailwind CSS                     | Same design tokens as mobile     |
| i18n      | `next-intl`                    | EN + TH locales                  |
| HTTP      | Fetch API                        | Calls NestJS API directly        |
| Auth      | JWT (stored in httpOnly cookies) | Received from NestJS after OAuth |

### Infrastructure

| Layer            | Choice         | Notes                                |
| ---------------- | -------------- | ------------------------------------ |
| Containerisation | Docker Compose | PostgreSQL + NestJS + Next.js        |
| Toolchain        | MISE           | `mise run setup`, `mise run dev` |

### Dependency decisions (closed)

- **NestJS backend over Supabase direct**: Full control over business logic, validation, conflict resolution, and Google Sheets writes. Single API for both web and mobile clients
- **Drift (mobile) + Prisma (server)**: Drift provides offline-first SQLite on mobile; Prisma manages the server-side PostgreSQL schema. Both share the same logical data model
- **Riverpod over Provider**: Better async state handling (`AsyncValue`), compile-safe references, `family` modifiers for parameterised providers (exchange rates, budget progress), no `BuildContext` dependency
- **go_router over Navigator**: Declarative routing, `ShellRoute` for bottom nav, type-safe parameters, auth redirect guards
- **Passport.js over Supabase Auth**: Keeps auth in the NestJS stack, no external auth dependency, well-proven NestJS pattern

---

## 5. App architecture overview

### Monorepo layout

```
expense_app/
├── .mise.toml                    # Tool versions + task runner
├── docker-compose.yml
├── scripts/
│   ├── setup.sh                  # First-time setup
│   └── dev.sh                    # Start all services
│
├── apps/
│   ├── mobile/                   # Flutter (iOS & Android)
│   │   └── lib/
│   │       ├── main.dart
│   │       ├── app.dart          # MaterialApp + GoRouter setup
│   │       ├── core/
│   │       │   ├── database/     # Drift DB, DAOs, migrations
│   │       │   ├── sync/         # SyncService, SyncQueue worker
│   │       │   ├── network/      # Dio client, Frankfurter service
│   │       │   ├── notifications/# FCM setup, budget alert service
│   │       │   └── theme/        # AppTheme (light + dark)
│   │       ├── features/
│   │       │   ├── auth/         # Google + Apple Sign-In
│   │       │   ├── expenses/     # Expense CRUD, add/edit sheets
│   │       │   ├── categories/   # Category management
│   │       │   ├── budgets/      # Budget CRUD, alert logic
│   │       │   ├── dashboard/    # Home screen, charts
│   │       │   ├── reports/      # Period views, comparisons
│   │       │   ├── export/       # Excel export
│   │       │   └── settings/     # App settings, account
│   │       └── shared/
│   │           ├── widgets/      # Reusable UI components
│   │           └── utils/        # Formatters, date helpers
│   │
│   ├── web/                      # Next.js (web frontend)
│   │   ├── messages/             # i18n (en.json, th.json)
│   │   └── src/
│   │       ├── app/[locale]/     # Locale routes (/en, /th)
│   │       │   ├── dashboard/
│   │       │   ├── reports/
│   │       │   ├── budgets/
│   │       │   └── settings/
│   │       ├── components/       # Shared UI components
│   │       ├── lib/              # API client, auth utils
│   │       └── i18n/             # next-intl config
│   │
│   └── api/                      # NestJS (backend)
│       ├── prisma/
│       │   └── schema.prisma     # DB schema (source of truth)
│       └── src/
│           ├── auth/             # Passport.js strategies, JWT guard
│           ├── transactions/     # Transaction CRUD + sync endpoints
│           ├── categories/       # Category CRUD
│           ├── budgets/          # Budget CRUD + alert logic
│           ├── exchange-rates/   # Frankfurter proxy + caching
│           ├── sheets/           # Google Sheets mirror service
│           ├── sync/             # Sync controller (push/pull)
│           └── prisma/           # PrismaService
│
└── docs/                         # PRD, architecture docs
```

### Data flow

```
┌──────────────────────────────┐
│       Flutter Mobile         │
│                              │
│  ┌────────────────────┐      │         ┌──────────────────────────┐
│  │  SQLite (Drift)    │      │  sync   │       NestJS API         │
│  │  = offline source  │◄────────────►  │                          │
│  │    of truth        │      │  HTTP   │  PostgreSQL (Prisma)     │
│  └────────────────────┘      │  (Dio)  │  = cloud source of truth │
│                              │         │                          │
└──────────────────────────────┘         │  ┌──────────────────┐   │
                                         │  │ Google Sheets     │   │
┌──────────────────────────────┐         │  │ (server-side      │   │
│       Next.js Web            │         │  │  mirror writes)   │   │
│                              │  HTTP   │  └──────────────────┘   │
│  (online only, no local DB)  │◄───────►│                          │
│                              │         └──────────────────────────┘
└──────────────────────────────┘
```

### Layer rules

- **Mobile**: Feature folders own their screens, providers, and repositories. Providers call repositories; repositories call DAOs (Drift) or remote services (Dio). No feature imports another feature directly — shared state goes in `core/` or `shared/`
- **API**: Follows NestJS module pattern — Controller → Service → Repository (Prisma). Each module is self-contained
- **Web**: Next.js App Router with server components where possible. Shared UI components in `components/`. API calls via a typed client in `lib/`
- **Cross-app consistency**: Mobile and web share the same visual design language, colour tokens, and UX patterns. Both consume the same NestJS API

---

## 6. Screen map & navigation

### Navigation structure (mobile — go_router)

Bottom navigation bar with 4 tabs using `ShellRoute` and a notched center FAB. Persists across the app. Hidden only when add/edit sheets are open.

| Tab index | Label           | Icon                                | Route                             |
| --------- | --------------- | ----------------------------------- | --------------------------------- |
| 0         | Home            | `home_outlined`                   | `/`                             |
| 1         | Wallets         | `account_balance_wallet_outlined` | `/wallets`                      |
| —        | *(FAB notch)* | `add`                             | *(opens Add Transaction sheet)* |
| 2         | Budgets         | `savings_outlined`                | `/budgets`                      |
| 3         | Reports         | `bar_chart`                       | `/reports`                      |

A floating `+` FAB sits in the centre notch of the `BottomAppBar` and opens the Add Transaction bottom sheet.

**Settings access:** A gear icon (`settings_outlined`) in the **top-right corner of the AppBar** on all primary screens provides access to Settings. Settings is **not** a bottom navigation tab.

### Navigation structure (web — Next.js App Router)

Sidebar navigation (desktop) / hamburger menu (mobile viewport). Same four sections as mobile.

| Section          | Route                   |
| ---------------- | ----------------------- |
| Dashboard (Home) | `/[locale]/dashboard` |
| Wallets          | `/[locale]/wallets`   |
| Reports          | `/[locale]/reports`   |
| Budgets          | `/[locale]/budgets`   |
| Settings         | `/[locale]/settings`  |

### Screen inventory

#### Home (`/`)

- Period selector (segmented control: Daily / Weekly / Fortnightly / Monthly / Yearly)
- Period navigation (← label →, tap label to date-pick)
- Summary cards: **base currency** total spent (primary), view currency equivalent below in smaller text (secondary, hidden when base == view)
- Top category card: category name (primary), base currency amount spent (secondary)
- Currency balance bar: horizontal scrollable chips showing each currency balance (tappable → opens Currency Wallets screen)
- Expense list for selected period (grouped by date)
- Each expense row: category colour dot, category name, note (truncated), original amount; **view currency estimate** shown underneath if currencies differ and a cached rate is available
- Swipe-left on row: delete (with confirmation); swipe-right: edit
- Donut chart: shows **base currency only** (no view currency overlay on home screen)

#### Add/Edit Expense (bottom sheet on mobile, modal on web)

- Auto-focuses amount field on open
- Fields: Amount, Currency (picker, defaults to last used), Date (defaults to today), Time (defaults to current time, follows system 12h/24h format), Category (picker), Note (optional, max 200 chars)
- "Save" button — disabled until Amount and Category are filled
- Shows converted base currency equivalent below amount field in real time

#### Transaction Detail (bottom sheet — tap any row in the transaction list)

- Opened by tapping a transaction row in any list (Home, Currency Detail, Reports, etc.)
- Shows all transaction fields in a read-only detail view inside a bottom sheet
- **No Edit or Delete action buttons** — these are accessed via swipe on the list tile
- **Sync status badge** (`pending` / `synced` / `conflict`) — mobile only, shown prominently near the top
- Shows whether exchange rate was estimated (offline) with an "Estimated rate" label
- **View currency estimate** shown next to the amount if view currency differs from base currency, including the conversion rate used (e.g. `≈ + THB 1,234.56 (1 AUD = 24.50 THB)`)
- For exchange transactions: shows both sides of the linked pair

#### Dashboard Detail (tap "Spend by Category" →)

- Full-screen donut + expanded category breakdown
- Summary cards (Total Spent, Net Income, Top Category) show **base currency** as primary value and **view currency** as secondary (≈ prefix) when base ≠ view
- Donut chart now shows **all currencies** (not filtered to base currency), with optional view currency overlay

#### Reports (`/reports`)

- Same period selector as Home
- Donut chart: spend by category — shows **base currency** with view currency overlay beneath center value when base ≠ view
- Bar chart: daily spend within period
- Line chart: rolling spend trend
- Period comparison card: this period vs previous (absolute + %)
- List of categories with spend amount and % of total

#### Budgets (`/budgets`)

- List of active budgets (global first, then per-category)
- Each card: name, period type, progress bar (green/amber/red), amount used / limit
- "+ Add budget" button → Add Budget sheet
- Tap card → Budget Detail

#### Budget Detail (`/budgets/:id`)

- Budget config (editable inline or via edit sheet)
- Full progress breakdown (percentage, spent, remaining, progress bar)
- Configuration section: period mode, recurring toggle, scope, categories, current period dates
- **Period history** (recurring budgets only): inline scrollable list of all past completed periods showing date range, amount spent, limit, and percentage — most recent first

#### Settings (`/settings` — accessed via gear icon in AppBar, not bottom nav)

- Account section: sign-in status (Google or Apple), sign out, delete account
- Google Sheets section: connect/disconnect (only available for Google accounts), linked sheet name
- Export section: "Export as Excel (.xlsx)" button — available to all signed-in users and local-mode users
- Preferences: base currency picker (default: AUD, changeable to any supported currency), view currency toggle, dark mode toggle
- Categories: manage default + custom categories
- About: version, licenses

#### Currency Wallets (`/wallets`)

- Overview card: **total portfolio value** — sum of all currency balances converted to base currency using today's rate; view currency equivalent shown in smaller text below when base ≠ view
- List of currency cards, one per currency with non-zero balance (or all tracked currencies)
- Each currency card shows:
  - Currency flag + ISO code (e.g. 🇹🇭 THB)
  - **Current balance** in that currency (e.g. `4,500 THB`)
  - **Base currency equivalent** using today's rate (e.g. `≈ A$191.25`)
  - Mini sparkline or delta showing balance trend (last 30 days)
  - Breakdown summary: total income, total spent, total exchanged
- Tap a currency card → **Currency Detail** screen
- Currencies with zero balance shown at bottom in a collapsed "Empty" section
- Manual balance adjustment button (for correcting discrepancies — adds a `balance_adjustment` note)

#### Currency Detail (`/wallets/:currency`)

- Full transaction history filtered to that currency only
- Summary stats at top:
  - Total received (income events)
  - Total spent (expenses in this currency)
  - Total exchanged out / in
  - Current balance
- Transaction list grouped by date (same visual style as Home, but filtered to one currency)
- Each row shows: transaction type icon, amount, note, date

#### Category Management (`/settings/categories`)

- List of all categories (default + custom), grouped hierarchically: parent categories with their sub-categories indented below
- Toggle visibility (hide/show)
- Tap to edit (rename, change colour, or assign/change parent category)
- "+ Add category" at bottom (unlimited) — can create a top-level category or a sub-category under an existing parent
- Sub-categories are limited to **1 level deep** — a sub-category cannot have its own children
- Cannot delete a parent category that has sub-categories — must reassign or delete children first
- Cannot delete a category with associated expenses — must reassign first
- Hidden categories do not appear in the add/edit expense picker

---

## 7. Authentication & account model

### Auth architecture

Authentication is handled entirely by the **NestJS backend** using Passport.js strategies. The backend issues JWTs after successful OAuth.

```
┌─────────────────┐     OAuth      ┌──────────────────┐     Verify     ┌──────────┐
│  Flutter/Web    │──────────────► │   NestJS API     │◄──────────────│ Google / │
│  (client)       │  redirect      │   Passport.js    │   token        │ Apple    │
│                 │◄──────────────│   + JWT issuer   │               └──────────┘
│  Stores JWT     │   JWT pair     │                  │
│  (secure stor.) │  (access +     │  Stores user in  │
│                 │   refresh)     │  PostgreSQL      │
└─────────────────┘               └──────────────────┘
```

**JWT flow:**

1. Client initiates OAuth (Google or Apple) → redirected to provider
2. Provider callback hits NestJS endpoint (`/auth/google/callback` or `/auth/apple/callback`)
3. NestJS validates the OAuth token, creates/finds user in PostgreSQL
4. NestJS issues JWT pair (access token: 15min, refresh token: 7 days)
5. Mobile: stores tokens in `flutter_secure_storage`
6. Web: stores tokens in httpOnly cookies
7. All subsequent API calls include the access token in `Authorization: Bearer` header
8. Dio interceptor (mobile) / fetch wrapper (web) handles automatic token refresh

### Modes

**Local mode (no account) — mobile only**

- Full app functionality, zero sign-in friction
- All data in local SQLite only
- No cross-device sync
- Google Sheets integration unavailable
- Excel export available (generated on device)
- Sign-in prompt shown once on first launch as a dismissible banner (not a blocking gate)

**Signed-in mode — Google account**

- Sign in via Google OAuth through NestJS backend
- Mobile: local SQLite remains the primary write target; syncs to backend when online
- Web: reads/writes directly to NestJS API (online only)
- Google Sheets integration available (handled server-side)
- Excel export available
- On first sign-in (mobile): all existing local records are uploaded to NestJS and marked `synced`
- On sign-out: local data retained (mobile); cloud data remains; writes stop

**Signed-in mode — Apple account**

- Sign in via Apple Sign-In through NestJS backend
- Same sync behaviour as Google account
- Google Sheets integration **unavailable** — requires a linked Google account
- Excel export available (on-demand replacement for Sheets)
- On first sign-in (mobile): all existing local records are uploaded to NestJS and marked `synced`
- On sign-out: local data retained (mobile); cloud data remains

### Feature matrix by account type

| Feature                | Local mode (mobile) | Apple Sign-In | Google Sign-In |
| ---------------------- | ------------------- | ------------- | -------------- |
| Expense logging        | ✅                  | ✅            | ✅             |
| Offline-first (mobile) | ✅                  | ✅            | ✅             |
| Cloud sync (NestJS)    | ❌                  | ✅            | ✅             |
| Cross-device sync      | ❌                  | ✅            | ✅             |
| Web app access         | ❌                  | ✅            | ✅             |
| Google Sheets mirror   | ❌                  | ❌            | ✅             |
| Excel export           | ✅                  | ✅            | ✅             |
| Budget alerts (FCM)    | ✅                  | ✅            | ✅             |

### Auth flow

```
App launch (mobile)
  └── Show Home (local mode)
        └── Sign-in banner (dismissible, shown once)
              └── User taps "Sign in"
                    ├── "Continue with Google" → Google OAuth via NestJS
                    │     ├── Success → Receive JWT → Upload local records → Enable sync + Sheets
                    │     └── Cancel → Dismiss, continue local mode
                    └── "Continue with Apple" → Apple Sign-In via NestJS
                          ├── Success → Receive JWT → Upload local records → Enable sync (no Sheets)
                          └── Cancel → Dismiss, continue local mode

Web launch
  └── Show login page
        ├── "Continue with Google" → Google OAuth via NestJS → JWT in cookie → Dashboard
        └── "Continue with Apple" → Apple Sign-In via NestJS → JWT in cookie → Dashboard
```

### NestJS auth modules

```
src/auth/
├── auth.module.ts
├── auth.controller.ts         # /auth/google, /auth/apple, /auth/refresh, /auth/logout
├── auth.service.ts            # JWT issuance, user creation/lookup
├── strategies/
│   ├── google.strategy.ts     # PassportStrategy(Strategy, 'google')
│   ├── apple.strategy.ts      # PassportStrategy(Strategy, 'apple')
│   └── jwt.strategy.ts        # PassportStrategy(Strategy, 'jwt')
├── guards/
│   └── jwt-auth.guard.ts      # Protects authenticated routes (JwtAuthGuard)
└── dto/
    └── auth-response.dto.ts   # { accessToken, refreshToken, user }
```

### Google Sheets upsell for Apple users

When an Apple Sign-In user navigates to Settings → Google Sheets, show an informational banner:

> "Google Sheets sync requires a Google account. Sign in with Google to enable automatic mirroring, or use Excel export below."

No blocking gate — the export buttons are immediately below the banner.

### Acceptance criteria

- [ ] App is fully usable without signing in (mobile — local mode)
- [ ] Web app requires sign-in (redirects to login page)
- [ ] Sign-in prompt (mobile) offers both "Continue with Google" and "Continue with Apple" options
- [ ] Sign-in prompt is a dismissible banner, not a blocking screen
- [ ] On first sign-in (mobile), all local records are uploaded to NestJS and marked `synced`
- [ ] Google Sign-In users have access to Google Sheets integration
- [ ] Apple Sign-In users do not see Google Sheets connect option; see export-only UI instead
- [ ] Sign-out retains local data (mobile); sync stops; Sheet (if connected) remains intact
- [ ] User can delete account — all PostgreSQL data deleted; local data optionally deleted (confirmation dialog)
- [ ] JWT access tokens expire after 15 minutes; refresh tokens after 7 days
- [ ] Mobile: JWT tokens stored in `flutter_secure_storage`; never in plain text
- [ ] Web: JWT stored in httpOnly secure cookies
- [ ] Dio interceptor automatically refreshes expired access tokens

---

## 8. Expense entry & management

### Add expense fields

| Field    | Type                     | Required | Default                      | Notes                                                                         |
| -------- | ------------------------ | -------- | ---------------------------- | ----------------------------------------------------------------------------- |
| Amount   | Decimal input            | Yes      | Empty                        | Auto-focused on sheet open                                                    |
| Currency | Picker                   | Yes      | Last used (or base currency) | Shows ISO code + flag                                                         |
| Date     | Date picker              | Yes      | Today                        | Can be backdated or set to a future date                                      |
| Time     | Time picker (input mode) | Yes      | Current time                 | Follows system 12h (AM/PM) or 24h format; opens in text-input mode by default |
| Category | Picker                   | Yes      | Last used                    | From active categories                                                        |
| Note     | Text field               | No       | Empty                        | Max 200 chars                                                                 |

### Entry behaviour

1. User taps FAB → bottom sheet opens (mobile) / modal opens (web), amount field auto-focused
2. User enters amount → base currency equivalent shown below field in real time (uses cached rate)
3. If currency = base currency, equivalent line is hidden
4. User fills required fields → "Save" button enables
5. On save:
   - Exchange rate fetched (or loaded from cache) for the selected date
   - **Mobile**: Expense written to local SQLite (Drift) with `sync_status = pending`. If online and signed in: sync worker pushes to NestJS backend
   - **Web**: Expense sent directly to NestJS API via POST request
   - Sheet/modal closes; expense appears at top of list

### Exchange rate at save time

- If expense date = today → use today's cached rate (or fetch if not cached)
- If expense date = past → fetch Frankfurter historical rate for that date
- If offline (mobile) → use last known cached rate; set `rate_estimated = true`; show "estimated rate" label on the expense

### Edit behaviour

- All fields editable
- Changing amount or currency re-fetches/recalculates exchange rate
- Changing date re-fetches historical rate for new date
- Save overwrites existing record; `updated_at` refreshed; `sync_status = pending` (mobile)

### Delete behaviour

- Confirmation dialog: "Delete this expense? This cannot be undone."
- **Mobile**: On confirm: soft-delete locally (set `deleted_at`), add delete operation to `sync_queue`; when synced: hard-delete from PostgreSQL
- **Web**: On confirm: DELETE request to NestJS API; removed from PostgreSQL immediately
- Backend removes corresponding row from Google Sheet by UUID (if Sheets connected)

### Recurring expenses (stretch goal, v1)

- User can mark expense as recurring: weekly, fortnightly, or monthly
- App auto-logs a copy at the start of each new cycle
- Recurring expenses can be paused or deleted

### Acceptance criteria

- [ ] Expense can be saved in under 10 seconds
- [ ] Amount in foreign currency is converted to user's base currency and both stored
- [ ] Backdated expense uses Frankfurter historical rate for that date
- [ ] Offline entry (mobile) uses last cached rate and shows "estimated" label
- [ ] Base currency equivalent updates in real time as user types the amount
- [ ] All fields of an existing expense can be edited
- [ ] Delete prompts confirmation and removes from local DB (mobile), PostgreSQL, and Google Sheet
- [ ] Web expense save sends POST directly to NestJS API

---

## 9. Categories

### Default categories

| Category              | Colour hex  |
| --------------------- | ----------- |
| Food & dining         | `#378ADD` |
| Groceries             | `#4CAF50` |
| Transport             | `#FF7043` |
| Health & medical      | `#E91E8C` |
| Shopping & retail     | `#9C27B0` |
| Bills & utilities     | `#009688` |
| Entertainment         | `#FFC107` |
| Travel                | `#FF8F00` |
| Subscriptions         | `#F44336` |
| Education             | `#455A64` |
| Personal care         | `#4FC3F7` |
| Other / uncategorised | `#9E9E9E` |

### Customisation rules

- Users can rename any default or custom category — renames propagate to all historical expenses
- Users can change a category's colour at any time
- Users can create custom categories with any name and colour — **no limit on count**
- Users can create **sub-categories** under any top-level (parent) category — limited to **1 level deep**
- Transactions can be assigned to either a parent category or a sub-category
- Sub-category expenses are **aggregated under the parent** in charts and dashboard summaries
- The transaction entry dropdown shows the hierarchy clearly (e.g. parent in bold, sub-categories indented with "— " prefix)
- Users can hide categories (removed from pickers, still shown in reports/history)
- A parent category **cannot be deleted** if it has active sub-categories — user must reassign or delete children first
- Categories with associated expenses **cannot be deleted** — user must reassign expenses to another category first
- A parent category **cannot be demoted** to a sub-category while it has children
- Hidden categories do not appear in the add/edit expense picker

### Acceptance criteria

- [ ] All 12 default categories present on first launch
- [ ] User can create a custom category with name and colour
- [ ] User can create a sub-category under any top-level parent category
- [ ] Sub-category depth is enforced to 1 level (cannot nest sub-sub-categories)
- [ ] Transaction entry dropdown shows hierarchical labels (parent bold, children indented)
- [ ] Donut chart and dashboard summary aggregate sub-category expenses under their parent
- [ ] Renaming a category updates all historical expenses retroactively
- [ ] Hiding a category removes it from pickers but not from reports
- [ ] Attempting to delete a category with expenses shows a "reassign first" dialog
- [ ] Attempting to delete a parent with sub-categories shows a "remove children first" dialog
- [ ] A parent category cannot be made a sub-category while it has children
- [ ] Categories (including parentId) sync between mobile and web via NestJS API
- [ ] Backend validates parentId references and enforces 1-level depth on sync

---

## 10. Currency handling

### Design principle

All expenses are **stored in the user's base currency** (default: AUD). The base currency is configurable in Settings → Preferences. Original currency and original amount are also stored for auditability. Display currency is a view-layer concern only — stored data is never rewritten when exchange rates change.

**Changing base currency:** When the user changes their base currency (e.g. AUD → THB), all existing `amount_base` values are re-converted from `original_amount` + `original_currency` using the latest Frankfurter rate for each transaction's date. This is a background operation; a progress indicator is shown. The exchange rate cache is also updated for the new base currency. On app startup, a background `recalculateBaseAmounts` pass is also run to ensure consistency.

### Exchange rate source

**Frankfurter API** (`https://api.frankfurter.app`) — free, no API key, ECB-backed

| Use case        | Consumer                          | Endpoint                                                 |
| --------------- | --------------------------------- | -------------------------------------------------------- |
| Today's rate    | Mobile (direct) or NestJS (proxy) | `GET /latest?from={currency}&to={base_currency}`       |
| Historical rate | Mobile (direct) or NestJS (proxy) | `GET /{YYYY-MM-DD}?from={currency}&to={base_currency}` |

**NestJS exchange rate module**: The backend also caches exchange rates in PostgreSQL. When the mobile app syncs a transaction with a rate, the backend stores it. The web app fetches rates from the NestJS API (which proxies/caches Frankfurter).

### Caching strategy

**Mobile (Drift/SQLite):**

1. On first use of a currency pair on a given date → fetch from Frankfurter → cache in local `exchange_rates` table
2. Same pair + same date → use cached rate (no API call)
3. New day → fetch fresh rate and cache
4. API timeout (5s) or offline → use last known cached rate → set `rate_estimated = true`

New in v5.1.0: A **DB-only cache lookup** (`getForDateOrRecent`) is available for UI display purposes. This returns `null` instead of the 1.0 fallback when no rate is cached, allowing the UI to hide view currency estimates rather than showing a misleading 1:1 conversion.

**Backend (Prisma/PostgreSQL):**

1. Exchange rates cached in `exchange_rates` table
2. Web app requests rates from NestJS → NestJS checks cache → fetches from Frankfurter if missing
3. Synced mobile transactions include their rate, which backend stores

### Supported currencies (v1)

AUD (default base), THB, USD, EUR, GBP, JPY, SGD

Any of these currencies can be set as the base currency. The remaining currencies are available as transaction currencies.

### View currency toggle

- User can toggle display currency at any time in Settings
- Persistent setting (not per-session)
- All dashboard totals, lists, and report amounts respect selected view currency
- **Summary cards and totals** display the base currency amount as the primary value, with the view currency equivalent beneath in smaller text (hidden when base == view)
- **Transaction list tiles** display the view currency estimate beneath the original amount, using the **historical cached rate for the transaction's date** (not today's rate); hidden if no rate is cached
- **Donut chart center** on the Home screen shows **base currency only** (no view currency overlay)
- **Donut chart center** on the Reports screen shows base currency with view currency below when base ≠ view
- Stored data is never modified

### Acceptance criteria

- [ ] THB expense stores base currency equivalent using rate at entry date
- [ ] Backdated expense uses Frankfurter historical rate for that date
- [ ] Same currency pair + same date → single API call (cache hit on repeat)
- [ ] Offline entry (mobile) uses last cached rate and shows "estimated" label
- [ ] View currency toggle updates all displayed amounts instantly without touching stored data
- [ ] API timeout falls back to cache within 5 seconds
- [ ] Web app fetches rates through NestJS proxy (not directly to Frankfurter)
- [ ] User can change base currency in Settings → Preferences
- [ ] Changing base currency re-converts all `amount_base` values using latest rates
- [ ] Base currency change shows a progress indicator during re-conversion
- [ ] Transaction list tile view estimate uses historical cached rate at transaction date; hidden if rate unavailable
- [ ] Summary cards show base currency primary, view currency secondary (≈ prefix)
- [ ] When base == view, no secondary row is shown anywhere

---

## 11. Currency income & exchange events

This section covers two new transaction types that sit alongside expenses in the ledger:

1. **Currency income** — user receives foreign cash (e.g. withdraws 20,000 THB from an ATM). Records that the user now holds that foreign currency but has not yet spent or exchanged it.
2. **Currency exchange** — user converts one currency to another at a money changer or bank (e.g. 20,000 THB → AUD). Records the conversion, the actual rate received, and auto-logs a base currency income entry when applicable.

### Why a separate transaction type (not an expense)

These events are not spending — they are balance movements. Treating them as expenses would inflate spending totals and distort budgets. They must be visually distinct but live in the **same chronological list** as expenses so the user has a single unified ledger view.

### Transaction type taxonomy

| Type                    | `transaction_type` value | Effect on ledger                                                                       |
| ----------------------- | -------------------------- | -------------------------------------------------------------------------------------- |
| Expense                 | `expense`                | Reduces base currency balance                                                          |
| Currency income         | `currency_income`        | Records foreign currency received; no base currency spending impact                    |
| Currency exchange (out) | `currency_exchange_out`  | Reduces source currency balance                                                        |
| Currency exchange (in)  | `currency_exchange_in`   | Increases target currency balance; auto-logged as base currency income when applicable |

---

### 11a. Currency income

#### What it represents

User received foreign currency cash. Example: just landed in Bangkok, withdrew 20,000 THB from ATM.

#### Entry fields

| Field    | Type                     | Required | Notes                                                   |
| -------- | ------------------------ | -------- | ------------------------------------------------------- |
| Amount   | Decimal                  | Yes      | Amount received in foreign currency                     |
| Currency | Picker                   | Yes      | The currency received (e.g. THB)                        |
| Date     | Date picker              | Yes      | Defaults to today; future dates allowed                 |
| Time     | Time picker (input mode) | Yes      | Defaults to current time; follows system 12h/24h format |
| Source   | Text                     | No       | e.g. "ATM withdrawal", "Gift from friend"               |
| Note     | Text                     | No       | Max 200 chars                                           |

#### Storage

- **Mobile (Drift)**: Stored in local `transactions` table with `transaction_type = currency_income`
- **Backend (Prisma)**: Stored in PostgreSQL `transactions` table after sync
- `original_currency` = the received currency (e.g. THB)
- `original_amount` = the amount received
- `amount_base` = base currency equivalent at Frankfurter rate for the date (for reporting only — informational estimate, not a real conversion)
- `rate_estimated = true` if offline

#### Display in list

Distinct visual style: **green left border**, `↓ Income` label.
Example row:

```
↓ +20,000 THB            ATM withdrawal
              est. A$850.00             19 Apr 2026
```

#### Effect on running balance

Adds to the user's THB running balance. Informational only — does not block any actions.

#### Dashboard income totals

`currency_income` transactions are included in the Net Income summary. `currency_exchange_in` transactions are **excluded** from income totals to avoid double-counting exchange events.

---

### 11b. Currency exchange

#### What it represents

User physically exchanges currency at a money changer, bank, or airport booth.
Example: exchange 15,000 THB → AUD and receive A$620 at the counter.

#### Entry fields

| Field         | Type                     | Required | Notes                                                      |
| ------------- | ------------------------ | -------- | ---------------------------------------------------------- |
| From amount   | Decimal                  | Yes      | Amount given away (e.g. 15,000)                            |
| From currency | Picker                   | Yes      | Source currency (e.g. THB)                                 |
| To amount     | Decimal                  | Yes      | Amount received (e.g. 620)                                 |
| To currency   | Picker                   | Yes      | Target currency (e.g. AUD)                                 |
| Date          | Date picker              | Yes      | Defaults to today; future dates allowed                    |
| Time          | Time picker (input mode) | Yes      | Defaults to current time; follows system 12h/24h format    |
| Exchange rate | Calculated / editable    | Yes      | Auto-filled as`to_amount ÷ from_amount`; always visible |
| Rate source   | Toggle                   | Yes      | "Custom (what I got)" or "Use Frankfurter rate"            |
| Note          | Text                     | No       | e.g. "Superrich exchange booth"                            |

#### Rate logic

```
if rate_source == "custom":
    exchange_rate = to_amount / from_amount   // derived from the two amount fields
    rate_source_label = "custom"

if rate_source == "frankfurter":
    exchange_rate = Frankfurter rate for (from_currency → to_currency) on date
    to_amount = auto-calculated (editable override allowed)
    rate_estimated = (true if offline)
    rate_source_label = "frankfurter"
```

The rate field is always shown and editable before saving. Switching rate source recalculates the rate or `to_amount` accordingly.

#### What gets created on save

Saving a currency exchange atomically creates **two linked transaction records**:

| Record             | `transaction_type`      | Effect                                                                    |
| ------------------ | ------------------------- | ------------------------------------------------------------------------- |
| Exchange out       | `currency_exchange_out` | Reduces`from_currency` running balance (e.g. THB −15,000)              |
| Exchange in (auto) | `currency_exchange_in`  | Increases`to_currency` running balance (e.g. AUD +620); shown as income |

Both records share the same `exchange_event_id` UUID so they display together and delete together.

#### Import: exchange rate calculation

When importing exchange transactions from Excel, the `amount_base` for both the OUT and IN sides is now correctly computed by looking up the cached exchange rate (`originalCurrency → baseCurrency`) at the transaction date (falling back to most-recently-cached rate). Previously both sides were stored with a hardcoded 1.0 rate.

---

## 12. Time period views

### Available periods

| View        | Date range                              | Step unit |
| ----------- | --------------------------------------- | --------- |
| Daily       | Single day                              | 1 day     |
| Weekly      | Monday to Sunday                        | 1 week    |
| Fortnightly | Monday to Sunday × 2 consecutive weeks | 2 weeks   |
| Monthly     | 1st to last day of calendar month       | 1 month   |
| Yearly      | 1 Jan to 31 Dec                         | 1 year    |

### Navigation controls

- Segmented control at top of Home and Reports screens (both mobile and web)
- Left arrow (`<`) and right arrow (`>`) step backward/forward by one period
- Tapping the period label (e.g. "April 2026") opens a date picker to jump to any period
- "Today" chip snaps back to the current period
- Right arrow is disabled when viewing the current period (no future navigation)

### Acceptance criteria

- [ ] All five period views display the correct start and end dates
- [ ] Stepping forward/back correctly increments by the period unit
- [ ] Expenses are filtered correctly to the selected period (currency income and exchange events shown but not counted in spend totals)
- [ ] Dashboard totals, charts, and budget progress all respond to period changes
- [ ] "Today" chip returns to the current period from any historical period
- [ ] Period views work identically on mobile and web

---



---

## 13. Budget alerts

### Per-currency budgets

Each budget tracks spending in **one user-chosen currency**. Only transactions with `original_currency` matching the budget's currency are counted toward the budget spend total. This allows users to set separate budgets per currency (e.g. a THB budget for daily spending while travelling, an AUD budget for home expenses).

### Period types & recurring toggle

**Recurring budgets (`is_recurring = true`):**

- Weekly (Monday–Sunday)
- Fortnightly (14 days starting from the budget's `start_date`)
- Monthly (1st–last day of calendar month)
- **Auto-rolling:** The system calculates the current active period window from `start_date` + `period_type`. When the current period ends, the next period begins automatically — no manual re-creation needed.
- Notification flags (`notified_75`, `notified_90`, `notified_100`) are **reset automatically** when a new period begins.

**Non-recurring budgets (`is_recurring = false`):**

- Can use any `period_type` (weekly/fortnightly/monthly) for a single occurrence, or `custom` with explicit `start_date` → `end_date`
- Covers one period only. After the period ends, the budget becomes inactive (`is_active = false`)

**Custom date range (always non-recurring):**

- User picks explicit start and end date
- Deactivates automatically on end date

### Auto-rolling period calculator

For recurring budgets, the system computes the current active window:

1. Calculate period duration from `period_type` (7 days / 14 days / calendar month)
2. Count how many full periods have elapsed since `start_date`
3. Current window = `start_date + (periodIndex × duration)` → end of that period
4. For monthly: use calendar month arithmetic (Jan 1 → Jan 31, Feb 1 → Feb 28/29, etc.)

Past completed periods are stored as computed windows (not separate DB rows) and accessible via the **Period History Screen**.

### Budget scope

Budgets support three category scope modes:

| Scope type  | Behavior                                                          | Example                                         |
| ----------- | ----------------------------------------------------------------- | ----------------------------------------------- |
| `all`     | Count all expenses in the budget's currency — no category filter | "Track all my AUD spending"                     |
| `include` | Count only expenses in the listed categories                      | "Track only Food + Groceries"                   |
| `exclude` | Count all expenses EXCEPT the listed categories                   | "Track everything except Subscriptions + Bills" |

- **`all`**: equivalent to the old "global budget" — a single total spend limit across all categories in a given currency. Displayed as a progress bar on the Home screen summary card.
- **`include`**: user selects one or more parent categories. Only expenses assigned to those categories (including their sub-categories) count toward the budget. At least 1 category must be selected.
- **`exclude`**: user selects one or more parent categories to exclude. All other expenses in the budget's currency count toward the budget. At least 1 category must be selected.

Category selection uses a multi-select checklist showing parent categories only. Sub-category expenses automatically roll up to their parent for budget tracking.

If a category referenced in `include`/`exclude` is deleted, its ID is removed from the list. If an `include` list becomes empty, the budget is deactivated.

**Important:** Currency income and exchange events are excluded from budget spend calculations. Only `transaction_type = expense` counts toward budgets.

### Alert thresholds

| State       | Trigger      | Progress bar colour | Notification                                               |
| ----------- | ------------ | ------------------- | ---------------------------------------------------------- |
| On track    | < 75% used   | Green               | None                                                       |
| Caution     | 75–89% used | Amber               | Once: "You've used 75% of your [X] budget"                 |
| Critical    | 90–100% used | Light red           | Once: "You've used 90% of your [X] budget — $Z remaining" |
| Over budget | > 100% used  | Red                 | Once: "You've exceeded your [X] budget by $Y"              |

- Alerts fire **once per threshold per cycle** — `notified_75`, `notified_90`, and `notified_100` flags reset when a new period starts
- Overspending does **not** block adding new expenses
- User can disable alerts per budget in Settings

### Budget-aware transaction entry

When adding an expense in the **Transaction Bottom Sheet**:

- If any active budget (global or category-scoped) for the transaction's currency is **≥ 90% used**, show an inline warning below the amount field:
  - `⚠️ Food budget: $12.50 remaining` (category budget)
  - `⚠️ Global THB budget: ฿500.00 remaining` (global budget)
- Warning is informational only — does not block saving
- Multiple budget warnings may appear if both a global and category budget are near their limits

### Platform-specific alert delivery

| Platform         | Alert delivery method                                                                      |
| ---------------- | ------------------------------------------------------------------------------------------ |
| Mobile (Flutter) | Local push notification (evaluated on-device when transactions change)                     |
| Web (Next.js)    | In-app toast notification (shown at top/bottom of screen when threshold is crossed)        |
| Backend (NestJS) | FCM push notification (sent after sync; supplements mobile local notification when online) |

**Mobile local alerts:** Evaluated reactively when `budgetProgressListProvider` recalculates after a transaction insert/update/delete. This ensures alerts fire even when offline.

**Web toast alerts:** Displayed as transient toast notifications when the web app detects a budget threshold crossing after a transaction save. Toast auto-dismisses after 5 seconds but can be manually dismissed.

### Period history

- Displayed **inline** on the **Budget Detail Screen** below the configuration section
- Shows all past completed periods for the budget as a scrollable list
- Each past period displays: date range, amount spent, limit, percentage
- Ordered most-recent-first
- Only shown for recurring budgets (non-recurring budgets have no past periods)


### Acceptance criteria

- [ ] User can create a global budget with a chosen currency, repeating or one-shot period
- [ ] User can create a per-category budget with its own currency and period type
- [ ] Budget only counts expenses matching the budget's currency (`original_currency`)
- [ ] User can toggle recurring on/off when creating a budget
- [ ] Recurring budgets auto-roll to the next period window without user action
- [ ] Non-recurring budgets set `is_active = false` after their period ends
- [ ] 75% alert fires exactly once per cycle when threshold is crossed
- [ ] 90% alert fires exactly once per cycle when threshold is crossed
- [ ] 100% alert fires exactly once per cycle when threshold is crossed
- [ ] `notified_75`, `notified_90`, and `notified_100` reset at the start of each new cycle
- [ ] Editing a budget amount resets all notification flags
- [ ] Overspend does not prevent adding new expenses
- [ ] Currency income and exchange events do not count toward budget spend totals
- [ ] Transaction entry shows inline budget remaining warning when any matching budget ≥ 90% used
- [ ] Mobile: budget alerts fire as local notifications (works offline)
- [ ] Web: budget alerts display as toast notifications (auto-dismiss after 5s)
- [ ] Backend: FCM push notifications sent after sync as supplementary alert
- [ ] Budget Detail Screen shows inline period history section for recurring budgets
- [ ] Period history displays all past periods with spend/limit/percentage

---



---

## 14. Visualisation dashboard

### Home screen summary cards

The three coloured summary cards at the top of the Home screen display:

| Card         | Primary value                      | Secondary value                                                  |
| ------------ | ---------------------------------- | ---------------------------------------------------------------- |
| Total Spent  | `{baseCurrency} {amount}` (bold) | `≈ {viewCurrency} {amount}` (small, hidden when base == view) |
| Net Income   | `{baseCurrency} {amount}` (bold) | `≈ {viewCurrency} {amount}` (small, hidden when base == view) |
| Top Category | Category name (bold)               | `≈ {viewCurrency} {amount}` (small, hidden when base == view) |

Summary totals are computed from `amountBase` across **all** transaction currencies (multi-currency support), not restricted to base-currency-only transactions.

### Net Income calculation

Net Income = sum of `currency_income` transactions' `amountBase` − sum of `expense` transactions' `amountBase`.

**`currency_exchange_in` transactions are excluded from income totals** to avoid double-counting.

### Donut chart (Home screen)

- Center label: `Total\n{baseCurrency} {amount}` — **base currency only**, no view currency overlay
- Category slices show percentage of total spend

### Donut chart (Dashboard Detail / Reports)

- Center label: `Total\n{baseCurrency} {amount}` — primary
- When base ≠ view: `≈ {viewCurrency} {amount}` beneath (secondary, smaller font)
- Category slices unchanged

### Dashboard Detail summary cards

The Dashboard Detail screen (accessed by tapping "Spend by Category →") includes the same base + view dual-display pattern as the home summary cards.

---

## 15. Offline-first sync architecture

### Principle

On mobile, local SQLite (`drift`) is always the **primary write target**. Every create/edit/delete is written locally first, synchronously. Cloud sync is secondary, asynchronous, and eventual. The sync target is the **NestJS backend API** (not a direct database connection).

On web, there is no offline capability — all operations go directly to the NestJS API.

### Record identity

Every record has a UUID generated on device (mobile) or by the backend (web) at creation. This ensures offline-created records on mobile can be merged with cloud records without duplication or ID conflicts.

### Sync status (mobile only)

Every syncable record in the mobile Drift database carries `sync_status`:

| Value        | Meaning                                           |
| ------------ | ------------------------------------------------- |
| `pending`  | Written locally; not yet pushed to NestJS backend |
| `synced`   | Successfully pushed to and acknowledged by NestJS |
| `conflict` | Same record modified on two devices before sync   |

### Conflict resolution (v1)

**Most recent `updated_at` timestamp wins.** If two versions of the same UUID exist, the one with the later `updated_at` is kept. The losing version is logged to a `conflict_log` table (backend) for debugging. No UI for conflict resolution in v1.

### Sync flows

**Mobile — offline add transaction:**

1. Write to Drift SQLite; `sync_status = pending`
2. Add insert operation to `sync_queue`
3. UI reflects immediately — no disruption

**Mobile — reconnects:**

1. `SyncWorker` detects connectivity (platform connectivity stream)
2. Processes `sync_queue` in order: insert → update → delete
3. For each operation: sends HTTP request to NestJS API
4. Each success: marks record `synced`, removes from queue
5. Each failure: increments `attempts`; retries with exponential backoff (max 5 attempts, then logs error)
6. Backend triggers Google Sheet updates after transaction sync completes

**Remote change arrives (from web or another mobile device):**

1. Mobile periodically polls NestJS API for changes since last sync (`GET /sync/pull?since={timestamp}`)
2. Pulls changed records; merges into local Drift SQLite
3. UUID deduplication prevents duplicates
4. Conflict check: compare `updated_at`; keep winner

**Web — direct API:**

1. Web creates/edits/deletes via NestJS API directly
2. No local queue — operations are synchronous with the server
3. Backend triggers Google Sheet updates immediately

### NestJS sync endpoints

| Endpoint         | Method   | Purpose                                                       |
| ---------------- | -------- | ------------------------------------------------------------- |
| `/sync/push`   | `POST` | Mobile pushes batch of pending changes (insert/update/delete) |
| `/sync/pull`   | `GET`  | Mobile pulls all changes since a timestamp                    |
| `/sync/status` | `GET`  | Returns last sync timestamp and pending conflict count        |

**Push payload:**

```json
{
  "operations": [
    {
      "type": "insert",
      "table": "transactions",
      "record": { ... full record ... }
    },
    {
      "type": "update",
      "table": "categories",
      "record": { ... full record ... }
    },
    {
      "type": "delete",
      "table": "transactions",
      "recordId": "uuid-here"
    }
  ],
  "clientTimestamp": "2026-04-19T08:00:00Z"
}
```

**Pull response:**

```json
{
  "changes": {
    "transactions": [ ... changed records ... ],
    "categories": [ ... changed records ... ],
    "budgets": [ ... changed records ... ]
  },
  "serverTimestamp": "2026-04-19T08:00:05Z",
  "conflicts": []
}
```

### Sync queue table (mobile Drift only)

```
sync_queue
  id           UUID       PK
  record_type  TEXT       "transaction" | "budget" | "category"
  record_id    UUID       FK to relevant table
  operation    TEXT       "insert" | "update" | "delete"
  payload      JSON       Full record snapshot at time of queue
  created_at   TIMESTAMP
  attempts     INTEGER    Default 0
  last_error   TEXT       Nullable
```

### Acceptance criteria

- [ ] Transactions added offline on mobile save immediately with `sync_status = pending`
- [ ] All pending records sync to NestJS within 10 seconds of mobile reconnection
- [ ] UUID deduplication prevents duplicate records after sync
- [ ] Changes from web reflected on mobile within 10 seconds of mobile reconnection (via pull)
- [ ] Sync failures retried with exponential backoff; max 5 attempts
- [ ] After 5 failed attempts, error logged and user sees a sync warning indicator in Settings
- [ ] `updated_at` conflict resolution: later timestamp wins
- [ ] Web operations are synchronous — no local queue needed
- [ ] NestJS `/sync/push` and `/sync/pull` endpoints handle batch operations
- [ ] Backend triggers Google Sheet mirror writes after successful sync

---



---

## 16. Google Sheets integration

### Availability

Optional. Available only when signed in with a Google account. **Handled entirely by the NestJS backend** — neither the mobile app nor the web app writes to Google Sheets directly.

### Setup flow

1. Settings → Google Sheets → "Connect"
2. Client-side OAuth popup/redirect for Google Sheets scopes
3. User authorises
4. OAuth refresh token sent to NestJS backend and stored securely in PostgreSQL (encrypted at rest)
5. NestJS creates spreadsheet titled "Project PET — [Year]" in user's Drive
6. Spreadsheet ID stored in user settings (PostgreSQL)

### Sheet structure

The spreadsheet contains **multiple sheets** covering different time-period aggregations and transaction types. All summary/period sheets are driven by **formulas** referencing the raw data sheets, so they stay in sync automatically.

#### Raw data sheets (written to by backend)

| Sheet name             | Contents                                                               | Write method                         |
| ---------------------- | ---------------------------------------------------------------------- | ------------------------------------ |
| `All Transactions`   | Every transaction (expenses, income, exchanges) in chronological order | Backend appends/updates/deletes rows |
| `Currency Income`    | All currency income records                                            | Backend appends/updates/deletes rows |
| `Currency Exchanges` | All exchange events (one row per exchange pair)                        | Backend appends/updates/deletes rows |

**`All Transactions` columns (Row 1 = frozen header):**

| Column | Header            | Content                                                                                  |
| ------ | ----------------- | ---------------------------------------------------------------------------------------- |
| A      | Date              | `YYYY-MM-DD`                                                                           |
| B      | Type              | `expense` / `currency_income` / `currency_exchange_out` / `currency_exchange_in` |
| C      | Description       | Note field                                                                               |
| D      | Category          | Category name (expenses only)                                                            |
| E      | Original Amount   | Amount as entered                                                                        |
| F      | Original Currency | ISO 4217 code                                                                            |
| G      | Base Amount       | Converted base currency value                                                            |
| H      | Exchange Rate     | Rate used at entry                                                                       |
| I      | Rate Source       | `frankfurter` / `custom` / `estimated`                                             |
| J      | UUID              | Record UUID (used for edit/delete lookup)                                                |

**`Currency Income` columns:** Date, Currency, Amount, Source, Base currency equivalent (est.), UUID

**`Currency Exchanges` columns:** Date, From currency, From amount, To currency, To amount, Rate, Rate source, Note, UUID

#### Time-period summary sheets (formula-driven, auto-sync)

These sheets aggregate data from `All Transactions` using spreadsheet formulas (`SUMIFS`, `QUERY`, `FILTER`). They update automatically when raw data changes.

| Sheet name      | Aggregation         | Content                                                                          |
| --------------- | ------------------- | -------------------------------------------------------------------------------- |
| `Daily`       | Per day             | Date, total spent, breakdown by category, transaction count                      |
| `Weekly`      | Monday–Sunday      | Week start date, total spent, breakdown by category, comparison to previous week |
| `Fortnightly` | Mon–Sun × 2 weeks | Fortnight start date, total spent, breakdown by category                         |
| `Monthly`     | Calendar month      | Month, total spent, breakdown by category, comparison to previous month          |
| `Yearly`      | Calendar year       | Year, total spent, breakdown by category                                         |

Each summary sheet includes:

- Total expenses (base currency)
- Breakdown by category (amounts + percentages)
- Transaction count
- Period-over-period delta (amount + %)

#### Wallet sheet (formula-driven)

| Sheet name  | Content                                                                                                                                                                                    |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Wallets` | Running balance per currency, derived from`All Transactions` via formulas. Shows: Currency, Total income, Total spent, Total exchanged in/out, Current balance, Base currency equivalent |

### Write behaviour (NestJS backend)

| Trigger                                            | Sheet action                                                                       |
| -------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Transaction synced from mobile (via`/sync/push`) | Append/update/delete row in`All Transactions`                                    |
| Transaction created from web (via API)             | Append row to`All Transactions`                                                  |
| Transaction edited from web                        | Find row by UUID in column J; update in place                                      |
| Transaction deleted from web                       | Find row by UUID; delete row                                                       |
| Currency income synced/created                     | Append row to both`All Transactions` and `Currency Income`                     |
| Currency exchange synced/created                   | Append row to`All Transactions` and `Currency Exchanges`                       |
| Exchange event deleted                             | Remove rows by shared`exchange_event_id` from all raw sheets                     |
| Sheet write failure                                | Retry with exponential backoff (max 5 attempts); failure does not affect data sync |

**Summary sheets and Wallets sheet are never written to by the backend** — they are pure formula sheets that auto-update when raw data rows change.

Sheet is **mirror only** — app never reads from the sheet.

### OAuth scopes (obtained from client, stored on server)

- `spreadsheets` — read/write to spreadsheet content
- `drive.file` — access only to files this app created (not full Drive)

### Sign-out behaviour

On sign-out: the spreadsheet **stays in the user's Drive** and writes stop. No data is deleted from the sheet.

### NestJS Sheets module

```
src/sheets/
├── sheets.module.ts
├── sheets.service.ts          # Google Sheets API v4 client
├── sheets.processor.ts        # Queue processor for async Sheet writes
└── dto/
    └── sheet-config.dto.ts    # { spreadsheetId, enabled, lastWriteAt }
```

### Acceptance criteria

- [ ] App creates correctly structured spreadsheet on first setup (via NestJS)
- [ ] Adding an expense appends a row to the correct month tab within 5 seconds (after sync/save)
- [ ] Editing an expense updates the correct row by UUID
- [ ] Deleting an expense removes the correct row by UUID
- [ ] Currency income events append to the `Currency Income` tab
- [ ] Currency exchange events append to the `Currency Exchanges` tab
- [ ] Sheet write failures do not block data sync or API operations
- [ ] Revoking Sheet access stops writes without data loss
- [ ] OAuth uses `drive.file` scope, not full Drive access
- [ ] Sign-out leaves Sheet intact in Drive; writes stop
- [ ] Google Sheets writes are handled entirely by NestJS backend — no client-side Sheet writes

---



---

## 17. Excel export

### Availability

Available to **all users** — local mode (mobile), Apple Sign-In, and Google Sign-In. This is the primary data export path for Apple users who cannot use Google Sheets, and a supplementary export for all other users.

### Trigger

On-demand only. User navigates to **Settings → Export** and taps "Export as Excel (.xlsx)".

No automatic or scheduled export.

### Platform-specific behaviour

| Platform         | Generation                                      | Delivery         |
| ---------------- | ----------------------------------------------- | ---------------- |
| Mobile (Flutter) | Generated on-device from local Drift data       | OS share sheet   |
| Web (Next.js)    | Generated by NestJS backend, downloaded as file | Browser download |

### Export scope

User can choose the date range to export via a date range picker before generating the file. Default range is the current calendar year.

### File structure

The exported `.xlsx` file mirrors the same multi-sheet structure as Google Sheets, with raw data sheets and formula-driven summary sheets:

#### Raw data sheets

**`All Transactions` sheet:**

| Column            | Content                                                                                  |
| ----------------- | ---------------------------------------------------------------------------------------- |
| Date              | `YYYY-MM-DD`                                                                           |
| Type              | `expense` / `currency_income` / `currency_exchange_out` / `currency_exchange_in` |
| Description       | Note field                                                                               |
| Category          | Category name                                                                            |
| Original Amount   | Amount as entered                                                                        |
| Original Currency | ISO 4217 code                                                                            |
| Base Amount       | Converted base currency value                                                            |
| Exchange Rate     | Rate used at entry                                                                       |
| Rate Source       | `frankfurter` / `custom` / `estimated`                                             |
| UUID              | Record UUID                                                                              |

**`Currency Income` sheet** — same columns as Google Sheets `Currency Income` tab

**`Currency Exchanges` sheet** — same columns as Google Sheets `Currency Exchanges` tab

#### Summary sheets (formula-driven)

| Sheet           | Content                                                            |
| --------------- | ------------------------------------------------------------------ |
| `Daily`       | Per-day totals, category breakdown                                 |
| `Weekly`      | Monday–Sunday totals, category breakdown                          |
| `Fortnightly` | 2-week totals (Mon–Sun × 2), category breakdown                  |
| `Monthly`     | Calendar month totals, category breakdown                          |
| `Yearly`      | Calendar year totals, category breakdown                           |
| `Wallets`     | Running balance per currency with income/spent/exchanged breakdown |

All summary sheets use Excel formulas (`SUMIFS`, `COUNTIFS`) referencing `All Transactions`, so the exported file is a working spreadsheet — not just flat data.

#### Export Format Behavior (Empty Dates & Periods)

To ensure high data fidelity for analysis and re-importing:

1. **Empty Date Rows (`no_transaction`)**: Gaps within the export date range (days with zero transactions) are populated on the `All Transactions` raw sheet as empty rows with Type = `no_transaction`, Date = missing date, Amount = 0, and other fields empty. This facilitates parsing and ensures the date range is continuous.
2. **Zero-Transaction Periods**: All summary sheets (Daily, Weekly, Fortnightly, Monthly, Yearly) generate a row for *every* period in the date range, regardless of whether transactions occurred. Periods with no transactions show `0` for all sum amounts, `0` for counts, and `0` for category breakdowns.

### File naming

| Format | Filename                               |
| ------ | -------------------------------------- |
| Excel  | `project-pet-export-YYYY-MM-DD.xlsx` |

### Flutter packages (cross-platform export)

- Excel: `excel` package (`pub.dev/packages/excel`)
- File saving: `file_saver` package (Allows user to pick the destination folder across Web, Android, and iOS)

### NestJS export endpoint (web export)

| Endpoint          | Method  | Response                |
| ----------------- | ------- | ----------------------- |
| `/export/excel` | `GET` | `.xlsx` file download |

Query params: `?from=YYYY-MM-DD&to=YYYY-MM-DD`

### Acceptance criteria

- [ ] "Export as Excel" button present in Settings for all users
- [ ] User can select a custom date range before exporting
- [ ] User can pick the destination folder when exporting Excel across Web, Android, and iOS
- [ ] Excel export produces a single `.xlsx` file with raw data sheets + formula-driven summary sheets
- [ ] Summary sheets (Daily, Weekly, Fortnightly, Monthly, Yearly) correctly aggregate from `All Transactions`
- [ ] `Wallets` sheet shows running balance per currency
- [ ] Exported data matches what is stored locally (mobile) or in PostgreSQL (web) for the selected date range
- [ ] Mobile: file is generated on-device from Drift data; no network request required
- [ ] Mobile: OS share sheet is triggered on completion
- [ ] Web: file is generated by NestJS and downloaded via browser
- [ ] Apple Sign-In users see export as the primary data-sharing option (Google Sheets section shows upsell banner above export buttons)
- [ ] Export works in local mode on mobile (no account required)

---



---

## 18. Theming (light & dark mode)

Dark mode is supported on first release. Both the mobile app and web app respect the system default and allow manual override in Settings.

### Theme tokens

| Token             | Light       | Dark        |
| ----------------- | ----------- | ----------- |
| `surface`       | `#FFFFFF` | `#121212` |
| `background`    | `#F5F5F5` | `#1E1E1E` |
| `primary`       | `#2196F3` | `#90CAF9` |
| `onPrimary`     | `#FFFFFF` | `#000000` |
| `error`         | `#F44336` | `#EF9A9A` |
| `textPrimary`   | `#212121` | `#EFEFEF` |
| `textSecondary` | `#757575` | `#9E9E9E` |
| `divider`       | `#E0E0E0` | `#2C2C2C` |

**Cross-platform consistency**: These tokens are used by both the Flutter `ThemeData` and the Tailwind CSS config in the web app to ensure visual consistency.

Transaction list row accent colours:

| Transaction type  | Left border colour  |
| ----------------- | ------------------- |
| Expense           | Category colour     |
| Currency income   | `#4CAF50` (green) |
| Currency exchange | `#00897B` (teal)  |

Budget progress colours (both themes):

| State                 | Colour              |
| --------------------- | ------------------- |
| On track (< 75%)      | `#4CAF50` (Green)   |
| Warning (75–89%)     | `#FFC107` (Amber)   |
| Critical (90–100%)   | `#FF5252` (Light red)|
| Over budget (> 100%) | `#F44336` (Red)     |

### Acceptance criteria

- [ ] App respects system dark/light mode on launch (both mobile and web)
- [ ] User can override theme in Settings → Preferences
- [ ] All screens, charts, and modals render correctly in both modes
- [ ] Category colours remain consistent across themes
- [ ] Income and exchange rows have correct accent border colours in both themes
- [ ] WCAG AA contrast ratios met in both themes
- [ ] Mobile and web use matching colour tokens for visual consistency

---



---

## 19. Error states & edge cases

Every async operation must have a defined error state. The AI agent must implement all of these — do not leave error handling as a TODO.

### Frankfurter API unavailable

- Show "Estimated rate" badge on expense/exchange amount field
- Use last cached rate for the currency pair
- If no cached rate exists: disable Save; show inline error "Exchange rate unavailable. Please try again when online or enter the amount in your base currency."

### NestJS sync failure (mobile)

- Record stays `pending` in local Drift DB
- Retry with exponential backoff (1s, 2s, 4s, 8s, 16s — max 5 attempts)
- After 5 failures: mark `last_error`, show sync warning icon in Settings
- User can tap warning to see failed records and trigger manual retry

### NestJS API error (web)

- Show toast notification with error message
- Retry button on failed operations where applicable
- Network error → show "You appear to be offline. Please check your connection."

### Google Sheets write failure

- Handled by NestJS backend — does not affect client
- Backend retries with exponential backoff
- Failure does not affect local data or API operations
- Admin logging for persistent failures

### No internet, no cached rate (mobile)

- Disable currency conversion; show inline message
- User can still save by entering the amount in their base currency directly

### Category has expenses on delete attempt

- Show dialog: "This category has [N] expenses. Reassign them to another category before deleting."

### THB running balance goes negative

- Show inline warning on expense entry sheet: `⚠ This will put your THB balance at −X,XXX THB`
- Save is still allowed — warning only

### Currency exchange — partial entry

- If user has filled `from_amount` but not `to_amount` (or vice versa): Save button disabled
- Both amount fields and both currency fields are required

### Exchange event deletion

- Confirm dialog: "Delete this exchange? Both the THB out and AUD in entries will be removed."
- Deletes both records atomically (mobile: local + sync queue; web: API call)

### Account deletion

- Confirmation dialog: "This will permanently delete all your cloud data. Your local data will remain on this device."
- On confirm: NestJS deletes all user data from PostgreSQL; revokes JWT; mobile returns to local mode
- Google Sheet (if connected) remains in Drive but is no longer updated

---



---

## 20. Data models

### Shared logical model

Both Drift (mobile SQLite) and Prisma (backend PostgreSQL) implement the same logical data model. Field names use snake_case in both.

### `users` (backend Prisma only)

| Field                     | Type         | Notes                                  |
| ------------------------- | ------------ | -------------------------------------- |
| `id`                    | UUID         | PK                                     |
| `email`                 | VARCHAR(255) | From OAuth provider                    |
| `display_name`          | VARCHAR(100) | From OAuth provider                    |
| `avatar_url`            | TEXT         | Nullable                               |
| `base_currency`         | VARCHAR(3)   | Default`AUD`; user-configurable      |
| `auth_provider`         | VARCHAR(10)  | `google` / `apple`                 |
| `provider_id`           | VARCHAR(255) | OAuth provider user ID                 |
| `google_refresh_token`  | TEXT         | Nullable; encrypted; for Google Sheets |
| `sheets_spreadsheet_id` | TEXT         | Nullable                               |
| `sheets_enabled`        | BOOLEAN      | Default false                          |
| `fcm_token`             | TEXT         | Nullable; for push notifications       |
| `created_at`            | TIMESTAMP    |                                        |
| `updated_at`            | TIMESTAMP    |                                        |

### `transactions` (unified table for all transaction types)

| Field                 | Type          | Notes                                                                                    |
| --------------------- | ------------- | ---------------------------------------------------------------------------------------- |
| `id`                | UUID          | PK, generated on device (mobile) or backend (web)                                        |
| `user_id`           | UUID          | FK → users (backend only; mobile uses implicit single-user)                             |
| `transaction_type`  | VARCHAR(25)   | `expense` / `currency_income` / `currency_exchange_out` / `currency_exchange_in` |
| `amount_base`       | DECIMAL(12,4) | Base currency equivalent (stored for expenses; estimated for income)                     |
| `original_amount`   | DECIMAL(12,4) | Amount as entered                                                                        |
| `original_currency` | VARCHAR(3)    | ISO 4217 e.g. "THB"                                                                      |
| `exchange_rate`     | DECIMAL(10,6) | Rate at time of entry                                                                    |
| `rate_date`         | DATE          | Date the rate was fetched                                                                |
| `rate_estimated`    | BOOLEAN       | True if rate from cache while offline                                                    |
| `rate_source`       | VARCHAR(15)   | `frankfurter` / `custom` / `estimated`                                             |
| `exchange_event_id` | UUID          | Nullable; links`out` and `in` records of same exchange                               |
| `category_id`       | UUID          | Nullable; FK → categories (expenses only)                                               |
| `note`              | TEXT          | Nullable, max 200 chars                                                                  |
| `source_label`      | TEXT          | Nullable; for currency income (e.g. "ATM withdrawal")                                    |
| `transaction_date`  | DATE          | Date of the transaction                                                                  |
| `is_recurring`      | BOOLEAN       | Default false (expenses only)                                                            |
| `recurrence_type`   | VARCHAR(12)   | weekly / fortnightly / monthly / null                                                    |
| `is_aggregate`      | BOOLEAN       | Default false; when true, represents a period-level aggregate                            |
| `sync_status`       | VARCHAR(10)   | pending / synced / conflict (mobile Drift only; not in Prisma)                           |
| `deleted_at`        | TIMESTAMP     | Nullable; soft delete                                                                    |
| `created_at`        | TIMESTAMP     |                                                                                          |
| `updated_at`        | TIMESTAMP     | Used for conflict resolution                                                             |

### `currency_balances` (derived, kept in sync on every transaction save)

| Field          | Type          | Notes                      |
| -------------- | ------------- | -------------------------- |
| `id`         | UUID          | PK                         |
| `user_id`    | UUID          | FK → users (backend only) |
| `currency`   | VARCHAR(3)    | ISO 4217 code              |
| `balance`    | DECIMAL(12,4) | Current running balance    |
| `updated_at` | TIMESTAMP     |                            |

### `categories`

| Field               | Type        | Notes                                                         |
| ------------------- | ----------- | ------------------------------------------------------------- |
| `id`              | UUID        | PK                                                            |
| `user_id`         | UUID        | FK → users (backend only)                                    |
| `name`            | VARCHAR(50) |                                                               |
| `colour_hex`      | VARCHAR(7)  | e.g.`#378ADD`                                               |
| `icon_code_point` | INTEGER     | Material Icons codePoint (default`0xe148` = Icons.category) |
| `is_default`      | BOOLEAN     |                                                               |
| `is_hidden`       | BOOLEAN     | Default false                                                 |
| `sort_order`      | INTEGER     |                                                               |
| `parent_id`       | UUID        | Nullable; FK → categories (self-referential, 1-level max)    |
| `sync_status`     | VARCHAR(10) | pending / synced (mobile Drift only)                          |
| `created_at`      | TIMESTAMP   |                                                               |
| `updated_at`      | TIMESTAMP   |                                                               |

#### Sub-category hierarchy rules

- `parent_id` references another category in the same table (self-referential FK)
- **Maximum depth: 1 level** — a category with a non-null `parent_id` cannot itself be a parent (enforced on both backend sync and mobile DAO)
- Sub-categories inherit display context from their parent (colour, grouping in charts)
- Backend sync validation: rejects `parentId` if the referenced category already has a `parent_id` (prevents nesting beyond 1 level)
- Backend sync validation: rejects `parentId` if the referenced category does not exist
- Deleting a parent category is blocked if it has children — client must delete/reassign children first
- On backend `onDelete: SetNull` — if a parent is force-deleted via DB, children become top-level

### `budgets`

| Field            | Type          | Notes                                                                 |
| ---------------- | ------------- | --------------------------------------------------------------------- |
| `id`           | UUID          | PK                                                                    |
| `user_id`      | UUID          | FK → users (backend only)                                            |
| `name`         | VARCHAR(150)  | Nullable; user-defined label (auto-generated if blank)                |
| `scope_type`   | VARCHAR(10)   | `all` / `include` / `exclude`                                   |
| `category_ids` | TEXT          | Nullable; JSON array of category UUIDs (null when scope_type = 'all') |
| `currency`     | VARCHAR(3)    | Budget currency (matches transactions'`original_currency`)          |
| `amount_base`  | DECIMAL(12,2) | Budget limit in the budget's currency                                 |
| `period_type`  | VARCHAR(12)   | weekly / fortnightly / monthly / custom                               |
| `is_recurring` | BOOLEAN       | Default true; false = one-shot budget                                 |
| `start_date`   | DATE          | Anchor date for repeating periods; start for custom                   |
| `end_date`     | DATE          | Nullable; only for non-recurring/custom ranges                        |
| `is_active`    | BOOLEAN       | False after non-recurring budget expires                              |
| `notified_75`  | BOOLEAN       | Reset each new cycle                                                  |
| `notified_90`  | BOOLEAN       | Reset each new cycle                                                  |
| `notified_100` | BOOLEAN       | Reset each new cycle                                                  |
| `sync_status`  | VARCHAR(10)   | pending / synced (mobile Drift only)                                  |
| `created_at`   | TIMESTAMP     |                                                                       |
| `updated_at`   | TIMESTAMP     |                                                                       |

#### Budget scope & currency semantics

- **`scope_type = 'all'`**: Counts all expenses in the budget's `currency` (global budget)
- **`scope_type = 'include'`**: Counts only expenses whose `category_id` is in `category_ids` JSON array
- **`scope_type = 'exclude'`**: Counts all expenses EXCEPT those in `category_ids`
- Sub-category expansion: when a parent category is in `category_ids`, its children are automatically included in spend calculations
- Budget spend is calculated from `original_amount` (not `amount_base`) filtered by `original_currency = budget.currency`
- Fortnightly period is exactly 14 days (not "every two weeks" relative to calendar)
- Non-recurring budgets set `is_active = false` after their period ends

### `exchange_rates`

| Field              | Type          | Notes                         |
| ------------------ | ------------- | ----------------------------- |
| `id`             | UUID          | PK                            |
| `base_currency`  | VARCHAR(3)    | e.g. "AUD"                    |
| `quote_currency` | VARCHAR(3)    | e.g. "THB"                    |
| `rate`           | DECIMAL(10,6) |                               |
| `rate_date`      | DATE          | Date the rate applies to      |
| `fetched_at`     | TIMESTAMP     | When fetched from Frankfurter |
| `source`         | VARCHAR(20)   | "frankfurter"                 |

### `sync_queue` (mobile Drift only — not in Prisma)

| Field           | Type        | Notes                           |
| --------------- | ----------- | ------------------------------- |
| `id`          | UUID        | PK                              |
| `record_type` | VARCHAR(20) | transaction / budget / category |
| `record_id`   | UUID        | FK to relevant table            |
| `operation`   | VARCHAR(10) | insert / update / delete        |
| `payload`     | JSON        | Full record snapshot            |
| `created_at`  | TIMESTAMP   |                                 |
| `attempts`    | INTEGER     | Default 0                       |
| `last_error`  | TEXT        | Nullable                        |

### `conflict_log` (backend Prisma only)

| Field               | Type                        | Notes                           |
| ------------------- | --------------------------- | ------------------------------- |
| `id`              | UUID                        | PK                              |
| `user_id`         | UUID                        | FK → users                     |
| `record_type`     | VARCHAR(20)                 | transaction / budget / category |
| `record_id`       | The conflicting record UUID |                                 |
| `winning_version` | JSON                        | The version that was kept       |
| `losing_version`  | JSON                        | The version that was discarded  |
| `resolved_at`     | TIMESTAMP                   |                                 |

### `settings` (mobile Drift only — key-value)

| Key                          | Type        | Default    |
| ---------------------------- | ----------- | ---------- |
| `base_currency`            | VARCHAR(3)  | `AUD`    |
| `view_currency`            | VARCHAR(3)  | `AUD`    |
| `theme_mode`               | VARCHAR(10) | `system` |
| `last_used_currency`       | VARCHAR(3)  | `AUD`    |
| `last_used_category_id`    | UUID        | null       |
| `sign_in_prompt_dismissed` | BOOLEAN     | false      |
| `last_sync_timestamp`      | TIMESTAMP   | null       |

---



---

## 21. Riverpod providers

### New providers (v5.1.0)

#### `txViewAmountProvider` (FutureProvider.family)

```dart
typedef _TxViewKey = ({
  String fromCurrency,
  String toCurrency,
  String dateKey, // "yyyy-MM-dd"
  double originalAmount,
});

final txViewAmountProvider =
    FutureProvider.family<double?, _TxViewKey>((ref, args) async { ... });
```

**Purpose:** Computes the view currency equivalent of a single transaction's `originalAmount` using a **DB-only cached rate** for the transaction's date. Returns `null` when no rate is cached — callers must hide the display row when null.

**Key behaviour:**

- Looks up `fromCurrency → toCurrency` rate for `dateKey` in the local SQLite cache
- Falls back to the most-recent cached rate for that pair (still DB-only, no network)
- Returns `null` if no rate exists in the cache at all
- Never makes a network request (safe to call on every list tile)

#### `ExchangeRateDao.getForDateOrRecent` (new DAO method)

```dart
Future<double?> getForDateOrRecent(String baseCurrency, String quoteCurrency, DateTime date)
```

**Purpose:** DB-only rate lookup returning `null` (not a 1.0 fallback) when nothing is cached. Used exclusively by `txViewAmountProvider`.

---

## 22. User stories & acceptance criteria

### Onboarding

**US-01** As a new mobile user, I want to start using the app immediately without creating an account.

- Given I open the app for the first time
- When I dismiss the sign-in banner
- Then I can add, view, and manage expenses locally

**US-02** As a mobile user who signs in later, I want my existing local records to carry over.

- Given I have existing local transactions in Drift
- When I sign in with Google for the first time
- Then all local records are uploaded to NestJS and marked `synced`

**US-02b** As an iPhone user, I want to sign in with Apple instead of Google.

- Given I tap "Sign in" on the banner
- When I choose "Continue with Apple" and authenticate
- Then my account is created via NestJS, local records sync, and I have full cloud sync

**US-02c** As an Apple Sign-In user, I want to export my data since I can't use Google Sheets.

- Given I am signed in with Apple
- When I navigate to Settings → Export and tap "Export as Excel"
- Then a `.xlsx` file with all my transactions is generated and the share sheet opens

**US-02d** As a web user, I want to access my expense data from my browser.

- Given I am signed in via the Next.js web app
- When I navigate to the dashboard
- Then I see the same data as my mobile app, with the same visual style

### Expense management

**US-03** As a user, I want to log an expense quickly.

- Given I am on the Home screen
- When I tap `+`, fill in amount and category, and tap Save
- Then the expense is saved in under 10 seconds and appears in the list

**US-04** As a traveller, I want to enter an expense in Thai Baht.

- Given I select THB as currency
- When I enter 500 THB and save
- Then the base currency equivalent is stored alongside the original THB amount

**US-05** As a user entering a past expense, I want the correct historical rate used.

- Given I set the expense date to last Tuesday
- When I save
- Then the Frankfurter historical rate for that date is fetched and stored

### Currency income & exchange

**US-11** As a traveller, I want to log that I received 20,000 THB from an ATM.

- Given I tap `+` and select "Income"
- When I enter 20,000 THB and save
- Then a currency income record appears in the list and my THB balance increases by 20,000

**US-12** As a traveller, I want to log that I exchanged 15,000 THB to AUD at a money changer.

- Given I tap `+` and select "Exchange"
- When I enter 15,000 THB → 620 AUD with a custom rate and save
- Then both sides appear as a linked pair in the list, my THB balance decreases by 15,000, and my AUD balance increases by 620

**US-13** As a traveller, I want to see a warning if my THB spending would exceed what I have logged.

- Given my THB running balance is 500 THB
- When I add a 600 THB expense
- Then I see a warning "This will put your THB balance at −100 THB" but can still save

### Budget alerts

**US-06** As a user, I want to set a monthly food budget.

- Given I create a category budget: Food & Dining, monthly, $400 AUD
- When my Food & Dining spend reaches $320 (80%)
- Then I receive a push notification once (via FCM from NestJS) and the category card turns amber

**US-07** As a traveller, I want a trip budget for a specific date range.

- Given I create a custom budget: 10 Apr–20 Apr, $1,500 AUD
- When 20 Apr passes
- Then the budget deactivates automatically and shows as expired

### Sync

**US-08** As a mobile user, I want to log transactions without internet.

- Given my phone has no internet
- When I add any transaction type
- Then it saves instantly to Drift SQLite with `sync_status = pending`

**US-09** As a user, I want my phone and web to stay in sync.

- Given I added transactions on web while my phone was offline
- When my phone reconnects
- Then the new records appear on my phone within 10 seconds (via `/sync/pull`)

### Google Sheets

**US-10** As a user, I want my expenses mirrored to a Google Sheet automatically.

- Given I have connected my Google account and set up a sheet
- When I add an expense (from mobile or web)
- Then a row appears in the correct monthly tab within 5 seconds (written by NestJS backend)

---

## 23. Non-functional requirements

| Requirement                            | Target                                                               |
| -------------------------------------- | -------------------------------------------------------------------- |
| App cold start (mobile)                | < 2 seconds on mid-range device                                      |
| Web page load (initial)                | < 3 seconds                                                          |
| Transaction save (mobile, local Drift) | < 200ms                                                              |
| Transaction save (web, NestJS API)     | < 500ms                                                              |
| Exchange rate API timeout              | 5 seconds; fall back to cache                                        |
| Sync on reconnect (mobile)             | Within 10 seconds of connectivity restored                           |
| Google Sheet write latency             | < 5 seconds after data reaches NestJS                                |
| Local data retention (mobile)          | Never auto-deleted                                                   |
| Cloud data retention                   | Retained for lifetime of account                                     |
| Offline capability (mobile)            | 100% of core features work offline (except Sheet sync)               |
| Offline capability (web)               | Not supported — online only                                         |
| Auth token storage (mobile)            | `flutter_secure_storage` only; no plain text                       |
| Auth token storage (web)               | httpOnly secure cookies                                              |
| GDPR / Privacy                         | User can export and delete all data from Settings                    |
| Accessibility                          | WCAG AA contrast in both themes; supports system text scaling        |
| Dark mode                              | Supported on first release; respects system setting (both platforms) |

---

## 24. Out of scope (v1)

- Receipt photo upload and OCR / photo scanning
- AI-powered spend insights
- Shared expenses / bill splitting
- Bank or credit card import (open banking)
- Multi-currency wallet with live balance tracking (beyond informational running balance)
- Support for more than one Google Sheet per user
- Conflict resolution UI (last-write-wins only in v1)
- Web push notifications (mobile FCM only in v1)
- Tablet-optimised layout
- Additional currencies beyond: AUD, THB, USD, EUR, GBP, JPY, SGD
- Offline support for web app
- Real-time WebSocket sync (polling-based in v1; WebSocket in v2)

---

## 25. Excel Import

### Availability

Available to **all users**. Users can upload or pick a spreadsheet file to import records directly into their transactions database:

- **Mobile (Flutter)**: Local client-side parsing using `excel` package, validations, duplicate matching, and transaction inserts directly to the Drift SQLite DB. Records get `sync_status = pending` and sync asynchronously via the standard `sync_queue`. Works offline.
- **Web (Next.js)**: Client-side parsing using SheetJS/`xlsx` package in browser, previewed in UI modal, and committed to database by submitting parsed JSON list to NestJS backend `POST /import/transactions` endpoint. Works online only.

### Trigger

Available in **Settings → Import from Excel**. Users pick a `.xlsx` file, triggering the parsing and validation preview flow.

### Supported Sheets & Column Mapping

Imports data from three raw sheets if found (sheets not present are skipped):

1. **`All Transactions`**: Date, Type, Description, Category, Original Amount, Original Currency, Base Amount, Exchange Rate, Rate Source, UUID, Period (optional). Rows with Type = `no_transaction` are skipped. Category matches existing categories (case-insensitive, fuzzy fallback).
   - *Duplicate Skip Logic*: To prevent double-importing of exchange and income events, if the specialized sheets `Currency Exchanges` or `Currency Income` are present in the Excel file, the importer will deliberately skip processing the corresponding `currency_exchange_out`, `currency_exchange_in`, and `currency_income` rows from the `All Transactions` sheet, delegating them entirely to the specialized sheets.
2. **`Currency Income`**: Date, Currency, Amount, Source, Base Currency Equivalent, UUID.
3. **`Currency Exchanges`**: Date, From Currency, From Amount, To Currency, To Amount, Rate, Rate Source, Note, UUID. Creates two linked exchange out/in records.

### Aggregate / Missing-Date Support

Supports importing period-level summary items (e.g. "this week my total food spend was 300 AUD") instead of single transactions:

- **Trigger**: Detected if the sheet has a `Period` column (value = `week`, `fortnight`, `month`, `year`) or a prefix in the Description field (e.g. `[WEEK]`, `[MONTH]`).
- **Behavior**: Sets `is_aggregate = true` on the database record, and adjusts the transaction date to the start of the period containing that date (Monday for a week, 1st for a month, Jan 1st for a year, fortnight index start for a fortnight). Aggregate records sum up in dashboard charts and budgets, but are excluded from transaction count metrics.

### Duplicate Detection

Ensures database integrity during import:

- **UUID Match**: If row UUID matches an existing record in the database, it's flagged as an **Update (🔄)** and will overwrite the existing entry. Checked by default in preview.
- **Probable Duplicate**: If row `Date + Amount + Category` (or Currency) matches an existing record, it's flagged as a **Probable Duplicate (⚠️)**. Unchecked by default.
- **Error**: Any row failing basic validation (invalid type, invalid date, missing category for expense, negative amount) is flagged as an **Error (❌)**. All validation errors block the import until corrected.

### Interactive Missing Category Mapping

When the Excel import file contains categories not found in the user's database:

- **Deferred Creation**: The system reads the missing categories into memory during the preview stage without committing them to the database, ensuring database cleanliness if the preview is closed.
- **Mapping UI**: The preview screen displays a "Map New Categories" section listing all newly discovered categories.
- **Hierarchical Overrides**: For each pending category, the user can use a dropdown to select either:
  - Setting it as a new **Top-Level Category** (no parent).
  - Mapping it as a subcategory of any **Existing Category** in the database.
  - Nesting it under another **Newly Pending Category** from the file.
- **Committing**: Upon user confirmation ("Import"), parent/child relations are resolved and the categories are inserted into the database right before transactions are processed.

---

## 26. View Currency Display Improvements (v5.1.0)

This section documents the view currency UI changes introduced in v5.1.0.

### Problem statement

Prior to v5.1.0:

1. **Incorrect view estimate on transaction tiles**: When base == view (e.g. both AUD), a foreign-currency transaction (e.g. 500 THB) would show `≈ AUD 500.00` because the code used `amountBase * viewRate` where `amountBase` was stored with a 1:1 fallback rate and `viewRate = 1.0`. This was misleading.
2. **Missing `≈` prefix**: Some secondary currency rows used `=` instead of the approximation symbol `≈`.
3. **Dashboard totals inconsistency**: Summary card totals showed the view currency as the primary value; base currency was not always clearly differentiated.
4. **Donut chart center**: The home screen donut chart showed view currency below the base currency, crowding the center hole.
5. **Income calculation**: `currency_exchange_in` was incorrectly included in Net Income totals, inflating them.

### Solution

| Component                         | Change                                                                                                        |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `ExchangeRateDao`               | Added`getForDateOrRecent()` — DB-only lookup, returns `null` if uncached                                 |
| `shared_providers.dart`         | Added`txViewAmountProvider` (FutureProvider.family) for per-transaction historical-rate conversion          |
| `transaction_list_tile.dart`    | Uses`txViewAmountProvider`; hides `≈` row when `viewAmount == null`; replaced `=` with `≈`        |
| `dashboard_summary_cards.dart`  | Base currency shown as primary value (bold, large); view currency as secondary (`≈`, smaller)              |
| `wallets_screen.dart`           | Total Net Worth card shows base currency primary, view currency secondary                                     |
| `category_donut_chart.dart`     | Added`showViewCurrency` flag; home screen sets it to `false`                                              |
| `home_screen.dart`              | `CategoryDonutChart(showViewCurrency: false)` — donut center shows base currency only                      |
| `dashboard_detail_screen.dart`  | Summary cards show base primary + view secondary; donut shows all currencies (no currency filter)             |
| `shared_providers.dart`         | `currency_exchange_in` removed from income totals to prevent double-counting                                |
| `import_provider.dart`          | Exchange transaction import now correctly computes`amountBase` using cached rates for both OUT and IN sides |
| `transaction_detail_sheet.dart` | View currency estimate row added with rate label (e.g.`≈ + THB 1,234.56 (1 AUD = 24.50 THB)`)              |
| `period_comparison_card.dart`   | View currency shown as secondary below base currency totals                                                   |

### Behaviour rules

1. **`≈` symbol** is used universally for all view/estimated currency conversions
2. **View currency secondary row** is hidden whenever `fromCurrency == viewCurrency`
3. **Transaction tile view estimate** uses historical cached rate (at transaction date, DB-only); hidden when no rate is cached
4. **Summary totals** use `amountBase` for multi-currency accuracy (base currency equivalent stored at save time)
5. **Donut chart at Home** — base currency only, no view overlay
6. **Donut chart at Reports/Dashboard Detail** — base primary, view secondary when base ≠ view

## 27. Implementation Rollout Update (v5.2.0)

### Backend contracts

- Notifications now support both legacy and PRD-compatible token routes:
  - `POST /notifications/register-token` and `POST /notifications/fcm-token`
  - `DELETE /notifications/unregister-token` and `DELETE /notifications/fcm-token`
- Sheets disconnect supports both `DELETE /sheets/disconnect` and compatibility `POST /sheets/disconnect`.
- Sheets status response includes both `connected` and compatibility field `enabled`.
- Sync responses include compatibility aliases for clients (`accepted` + `synced`, and pull `changes` bundle).

### Mobile sync and notifications

- Mobile sync provider now performs real `POST /sync/push` and `POST /sync/pull` calls.
- Pull records are merged locally using last-write-wins based on `updatedAt`.
- Reconnect-driven sync is enabled via connectivity listener.
- FCM token lifecycle is wired to auth flow:
  - register on sign-in
  - unregister on sign-out / account deletion

### Mobile recurring and wallet operations

- Added recurring template management screen under Settings (`/settings/recurring`) for pause/delete operations.
- Added manual balance adjustment action in wallet detail; inserts transactions with `balance_adjustment` note for auditability and sync.
- Mock data seeding is now restricted to debug builds only.

### Web parity rollout (in progress)

- Replaced mock auth and dashboard scaffolding with real backend integration paths.
- Transactions page now fetches real data and supports create/update/delete via API.
- Wallets, budgets, and reports now consume backend data rather than placeholders.
- Import endpoint aligned to `POST /import/transactions`.
- Added initial web test stack (Vitest + jsdom) and first request-layer unit test.

### Production readiness blockers requiring environment setup

- OAuth production configuration (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI`)
- Firebase production credentials (`FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`)
- Web runtime env values (`NEXT_PUBLIC_API_URL` and OAuth values)

## 28. Exchange Rate Fallback Mechanism (v5.2.1)

This section documents the multi-tier exchange rate fallback strategy introduced in v5.2.1 to handle currencies unsupported by the primary Frankfurter API.

1. **Problem**: The primary exchange rate provider (`api.frankfurter.app`) relies on the European Central Bank, which only tracks ~30 major currencies. When transactions were created in unsupported currencies (e.g. `VND`, `MYR`, `IDR`), the API call would fail, causing the system to silently fall back to an exchange rate of `1.0`. This led to drastically incorrect view currency estimations (e.g. 400,000 VND -> 400,000 AUD).
2. **Solution**: Implemented a 4-tier architecture across Mobile and Backend.
3. **Architecture Tiers**:
    - **Tier 1 (Local DB Cache)**: The mobile app checks `ExchangeRateDao` for the most recently cached rate for the currency pair on the current date.
    - **Tier 2 (Backend Server)**: The mobile app's `ExchangeRateRepository` queries the NestJS backend for the rate, which first checks its own Postgres cache.
    - **Tier 3 (Frankfurter API)**: Both mobile and backend attempt to fetch from `api.frankfurter.app`.
    - **Tier 4 (Open.er-api.com API)**: If Frankfurter fails (e.g., due to unsupported currency), the system now seamlessly falls back to `open.er-api.com/v6/latest`, a free API that natively supports 160+ global currencies, preventing the `1.0` bug.
4. **Resiliency**: The successful fallback rate is instantly cached in both the local SQLite database and the backend Postgres database to prevent repeated fallback lookups.

---

*End of document — Project PET v5.2.1 (adapted for DailySpend monorepo)*