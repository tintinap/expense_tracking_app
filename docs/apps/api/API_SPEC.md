# NestJS API Specification

**Base URL:** `http://localhost:3000` (configurable via `.env`)

**Last Updated:** 21 June 2026 (v5.1.0)

---

## Global Headers

All endpoints except those under `/auth/` (for OAuth initiation) require a valid JWT access token.

| Header | Value | Required |
|--------|-------|----------|
| `Authorization` | `Bearer <access_token>` | Yes |
| `Content-Type` | `application/json` | Yes (for POST/PATCH) |

---

## 1. Authentication

### `POST /auth/google`

Receives Google OAuth token from client, validates, creates/finds user, returns JWT pair.

**Request Body:**
```json
{
  "idToken": "ey...",
  "email": "user@example.com",
  "displayName": "John Doe",
  "avatarUrl": "https://...",
  "providerId": "1234567890",
  "refreshToken": "optional-google-refresh"
}
```

**Response (200 OK):**
```json
{
  "accessToken": "ey...",
  "refreshToken": "ey...",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "displayName": "John Doe",
    "avatarUrl": "https://...",
    "baseCurrency": "AUD",
    "authProvider": "google"
  }
}
```

### `POST /auth/apple`

Receives Apple Sign-In token from client, validates, creates/finds user, returns JWT pair.

**Request Body:**
```json
{
  "identityToken": "ey...",
  "email": "user@example.com",
  "displayName": "John Doe",
  "providerId": "apple.1234567890"
}
```

**Response (200 OK):** Same format as Google auth.

### `POST /auth/refresh`

Exchange a valid refresh token for new access + refresh token pair.

**Request Body:**
```json
{
  "refreshToken": "ey..."
}
```

**Response (200 OK):**
```json
{
  "accessToken": "ey...",
  "refreshToken": "ey..."
}
```

### `POST /auth/logout`

Invalidate the current session.

**Response (204 No Content)**

### `DELETE /auth/account`

Deletes the user account and all associated data.

**Response (204 No Content)**

---

## 2. Sync Controller

Handles offline-first mobile sync operations.

### `POST /sync/push`

Mobile sends a batch of pending local record changes (insert/update/delete) to the server.

**Request Body:**
```json
{
  "records": [
    {
      "recordType": "transaction",
      "recordId": "uuid",
      "operation": "insert",
      "payload": { ... transaction json ... }
    }
  ],
  "clientTimestamp": "2026-06-21T11:00:00Z"
}
```

**Response (200 OK):**
```json
{
  "synced": 1,
  "conflicts": []
}
```

### `POST /sync/pull`

Mobile requests all records updated on the server after a given timestamp.

**Request Body:**
```json
{
  "lastSyncTimestamp": "2026-06-20T10:00:00Z"
}
```

**Response (200 OK):**
```json
{
  "changes": {
    "transactions": [],
    "categories": [],
    "budgets": []
  },
  "serverTimestamp": "2026-06-21T11:00:00Z",
  "conflicts": []
}
```

---

## 3. Transactions

Standard REST CRUD endpoints used by the Web App directly. Mobile syncs via `/sync` instead.

### `GET /transactions`

List transactions with optional filtering and pagination.

**Query Parameters:**
- `page` (default: 1)
- `limit` (default: 50)
- `type` (e.g. `expense`, `currency_income`)
- `from` (`yyyy-MM-dd`)
- `to` (`yyyy-MM-dd`)
- `categoryId` (UUID)

**Response (200 OK):**
```json
{
  "data": [
    {
      "id": "tx-uuid",
      "transactionType": "expense",
      "amountBase": 42.50,
      "originalAmount": 42.50,
      "originalCurrency": "AUD",
      "exchangeRate": 1.0,
      "rateDate": "2026-06-21T00:00:00Z",
      "transactionDate": "2026-06-21T10:30:00Z",
      "categoryId": "cat-uuid"
    }
  ],
  "total": 1,
  "page": 1
}
```

### `GET /transactions/:id`
Fetch a single transaction by ID.

### `POST /transactions`
Create a new transaction. Evaluates budget alerts asynchronously after insert.

**Request Body:** CreateTransactionDto
**Response (201 Created):** Transaction JSON

### `PATCH /transactions/:id`
Update a transaction. Evaluates budget alerts asynchronously after update.

**Request Body:** UpdateTransactionDto
**Response (200 OK):** Transaction JSON

### `DELETE /transactions/:id`
Delete a transaction.

**Response (204 No Content)**

---

## 4. Categories

Standard REST CRUD endpoints. Subcategories are supported (1 level deep) via `parentId`.

### `GET /categories`
List all categories for the user (including defaults).

### `GET /categories/:id`
Fetch a single category.

### `POST /categories`
Create a new custom category.

**Request Body:**
```json
{
  "name": "Coffee",
  "colourHex": "#FF0000",
  "parentId": "optional-uuid"
}
```

### `PATCH /categories/:id`
Update an existing category (including renaming defaults).

### `DELETE /categories/:id`
Delete a category. Fails if the category has associated transactions or subcategories.

---

## 5. Budgets

Standard REST CRUD endpoints.

### `GET /budgets`
List all budgets for the user.

### `GET /budgets/:id`
Fetch a single budget.

### `POST /budgets`
Create a new budget.

**Request Body:**
```json
{
  "scope": "global",
  "amountBase": 1000.0,
  "periodType": "monthly",
  "startDate": "2026-06-01T00:00:00Z",
  "categoryId": null
}
```

### `PATCH /budgets/:id`
Update an existing budget.

### `DELETE /budgets/:id`
Delete a budget.

---

## 6. Exchange Rates

### `GET /exchange-rates/latest?from={cur}&to={base}`
Fetch today's exchange rate for a currency pair. Proxies to Frankfurter if not cached in PostgreSQL, and seamlessly falls back to `open.er-api.com` for unsupported global currencies.

**Response (200 OK):**
```json
{
  "rate": 22.5,
  "date": "2026-06-21",
  "estimated": false
}
```

### `GET /exchange-rates/{date}?from={cur}&to={base}`
Fetch historical exchange rate for a specific date (`yyyy-MM-dd`). Proxies to Frankfurter, and falls back to `open.er-api.com` (which yields the latest rate due to free tier limitations) for unsupported currencies.

### `POST /exchange-rates`
Cache a rate fetched directly by the mobile client. Used when the backend was unreachable at the moment of mobile transaction save.

**Request Body:**
```json
{
  "from": "THB",
  "to": "AUD",
  "date": "2026-06-21",
  "rate": 0.0445
}
```

---

## 7. Import / Export

### `POST /import/transactions`
Import a batch of transactions from an Excel file (parsed by the client). Web App only.

**Request Body:**
```json
{
  "transactions": [
    {
      "transactionType": "expense",
      "amountBase": 42.50,
      "originalAmount": 42.50,
      "originalCurrency": "AUD",
      "transactionDate": "2026-06-21T00:00:00Z"
    }
  ]
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "importedCount": 1
}
```

### `GET /export/excel`
Generate and download an Excel (`.xlsx`) file of the user's transaction data.

**Query Parameters:**
- `startDate` (optional, ISO8601)
- `endDate` (optional, ISO8601)

**Response:** Binary `.xlsx` file stream.

---

## 8. Sheets

### `POST /sheets/setup`
Initializes Google Sheets sync for the user. Only available to users authenticated via Google.

**Response (200 OK):**
```json
{
  "spreadsheetId": "1BxiMVs0XRYFgwnLEUK...",
  "spreadsheetUrl": "https://docs.google.com/spreadsheets/d/1Bxi..."
}
```
