# DailySpend

A production-ready expense tracking application.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile App | Flutter 3.41.7 — iOS & Android |
| Web App | Next.js 16 (App Router, Tailwind, i18n: EN + TH) |
| Backend API | NestJS 11 (TypeScript) |
| Database | PostgreSQL 16 |
| ORM & Migrations | Prisma 6 |
| Containerization | Docker Compose |
| Toolchain | MISE |

## 🚀 Getting Started

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (running)
- [MISE](https://mise.jdx.dev/) (`brew install mise` or `curl https://mise.run | sh`)
- **Flutter 3.41.7+** — required for debug mode on iOS 26+ physical devices (managed automatically via MISE)

### Two commands — that's it

```bash
# First time only — installs Node, pnpm, Flutter, deps, DB, migrations
mise run setup

# Every day — starts PostgreSQL + NestJS + Next.js
mise run dev
```

Once running:

| Service | URL |
|---------|-----|
| **Web App** | http://localhost:3001 |
| **API** | http://localhost:3000/expenses |
| **API Docs (Swagger)** | http://localhost:3000/api/docs |
| **Prisma Studio** | `mise run db-studio` |

Press `Ctrl+C` to stop everything.

### Running Flutter Separately

To run the Flutter mobile app on a simulator or physical device:

```bash
# Ensure a simulator is open, then run:
mise run dev-mobile

# Or manually:
cd apps/mobile && flutter run
```

> **Note for physical device users:** iOS 26+ requires Flutter 3.32+ for debug mode support.
> If prompted to choose a device, select your physical device or the simulator.
> Flutter is managed via MISE (`flutter = "3.44"` in `.mise.toml`) — run `mise install` to upgrade.

---

## All MISE Tasks

```bash
# ── Primary ─────────────────────────
mise run setup          # First-time setup (once)
mise run dev            # Start all services (daily)

# ── Individual services ─────────────
mise run dev-api        # NestJS only (port 3000)
mise run dev-web        # Next.js only (port 3001)
mise run dev-mobile     # Flutter mobile

# ── Database ────────────────────────
mise run db-migrate     # Create + apply migration
mise run db-studio      # Database GUI
mise run db-generate    # Regenerate Prisma Client

# ── Docker ──────────────────────────
mise run docker-up      # Docker: db + api + web
mise run docker-up-all  # Docker: + Flutter web (port 8080)
mise run docker-down    # Stop + wipe everything
mise run docker-logs    # Follow all logs
```

## 🧹 Troubleshooting / Resetting

If you ever need to completely reset your database or if you run into environment issues (like Docker container conflicts):

```bash
# 1. Stop all containers and delete database volumes (THIS ERASES YOUR DATA)
mise run docker-down
# OR manually: docker compose down -v 

# 2. Re-run setup to initialize a fresh database
mise run setup
```

## Project Structure

```
expense_app/
├── .mise.toml              # Tool versions + task runner
├── scripts/
│   ├── setup.sh            # First-time setup
│   └── dev.sh              # Start all services
├── docker-compose.yml
│
├── apps/
│   ├── mobile/             # Flutter (iOS & Android)
│   │   ├── lib/
│   │   │   ├── core/       # Theme, constants
│   │   │   ├── data/       # Models, API client
│   │   │   ├── providers/  # State (Provider)
│   │   │   ├── screens/    # Pages
│   │   │   ├── services/   # Export, import, FX rates
│   │   │   └── widgets/    # Reusable components
│   │   └── pubspec.yaml
│   │
│   ├── web/                # Next.js (web frontend)
│   │   ├── messages/       # i18n (en.json, th.json)
│   │   └── src/
│   │       ├── app/[locale]/   # Locale routes (/en, /th)
│   │       ├── i18n/           # next-intl config
│   │       └── proxy.ts        # Locale detection
│   │
│   └── api/                # NestJS (backend)
│       ├── prisma/
│       │   └── schema.prisma   # DB schema (source of truth)
│       └── src/
│           ├── prisma/         # PrismaService
│           └── expenses/       # Controller → Service → Repository
│
└── .agents/rules/          # AI coding rules
```

## i18n (Web)

- **Locales**: English (`en`), Thai (`th`)
- **URLs**: `/en/dashboard`, `/th/dashboard`
- **Add language**: Create `messages/[locale].json` + update `src/i18n/config.ts`

## Features

- **Dashboard**: Filter by Weekly/Fortnightly/Monthly/Yearly, pie chart, net total
- **Spreadsheet**: Pivot-style view (categories × time periods)
- **Settings**: Theme, Display Currency, Import/Export Excel
- **Multi-currency**: Per-transaction currency, converted via Frankfurter (ECB rates)

---

## 📊 Implementation Progress

> [!IMPORTANT]
> **Current Usability Status:**
> **Mobile** is the primary production path (offline-first + sync). **Backend** APIs for auth/sync/sheets/notifications are in place. **Web** now talks to the NestJS API for core pages, but browser OAuth SDK wiring and full chart/import polish still need production env credentials and UAT.
>
> See [remaining-tasks.md](docs/exec-plans/active/remaining-tasks.md) and PRD v5.2.0 for detailed status.

### 📱 Mobile App (Flutter) — 🟡 ~95%
* **Implemented:**
  - [x] Core Dashboard, Transaction details, & Category breakdowns
  - [x] Transaction bottom sheet editor with recurring toggle
  - [x] Wallets screen with per-currency breakdown and totals
  - [x] Background engine for generating recurring transaction instances
  - [x] Real sync push/pull with Drift last-write-wins merge + reconnect trigger
  - [x] FCM token register/unregister on sign-in/sign-out
  - [x] Recurring templates management UI (pause/delete) in Settings
  - [x] Manual balance adjustment on currency wallet detail
* **Pending:**
  - [ ] Device-level FCM delivery UAT with real Firebase credentials

### 🖥️ Backend API (NestJS) — 🟡 ~95%
* **Implemented:**
  - [x] Prisma ORM and PostgreSQL migrations
  - [x] Core Authentication structure (JWT)
  - [x] Transactions, Categories, and Budgets REST API endpoints
  - [x] Excel Import/Export parsers and Google Sheets background worker queue
  - [x] Automated Frankfurter FX rate scheduler
  - [x] Sheets status/disconnect contract aliases for clients
  - [x] Notifications `fcm-token` register/unregister aliases
  - [x] Sync push enqueues Sheets writes when Sheets is enabled
* **Pending:**
  - [ ] Google OAuth and Firebase production credentials (env-gated graceful fallback today)

### 🌐 Web App (Next.js) — 🟡 ~60%
* **Implemented:**
  - [x] Sidebar navigation layout and multi-page routing structure
  - [x] App router-based i18n support for English (`en`) and Thai (`th`) locales
  - [x] Auth context calling NestJS `/auth/google`, `/auth/apple`, `/auth/refresh`
  - [x] Dashboard / Transactions / Wallets / Budgets / Reports / Settings / Import wired to API
  - [x] Vitest request-helper unit test stack
* **Pending:**
  - [ ] Browser OAuth SDK token acquisition (`@react-oauth/google` / Apple web flow)
  - [ ] Full Recharts visualizations and PRD §25 import badge/mapping polish
  - [ ] Production env values (`NEXT_PUBLIC_API_URL`, OAuth client IDs)

