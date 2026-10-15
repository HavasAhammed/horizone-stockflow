# Horizone StockFlow — Solar Inventory Management System

**Horizone StockFlow** is a complete, modular, and maintainable solar inventory management system built specifically for **Horizone Energy**. It manages physical solar panel stocks at the granular serial-number level, tracks inward purchase batches, records sales dispatches to Kerala State Electricity Board (KSEB) consumer accounts, and prevents stock inconsistencies or accidental transaction deletion.

---

## Architecture & Directory Structure

The project is structured into three decoupled, independent applications:

```text
horizone-stockflow/
├── assets/
│   └── branding/
│       ├── horizone_energy_logo.pdf  # Original source vector logo
│       ├── logo.png                  # Extracted logo for app UI (1200x800)
│       └── logo_hd.png               # High-definition crisp logo render
├── backend/                          # Node.js & Express REST API (TypeScript)
│   ├── src/
│   │   ├── controllers/              # Customer, purchase, sale, inventory handlers
│   │   ├── routes/                   # Versioned routes (/api/v1)
│   │   ├── services/                 # Centralized inventory business logic
│   │   ├── types/                    # Domain models and API schemas
│   │   └── tests/                    # Vitest & Supertest automated API tests
│   ├── .env.example
│   └── tsconfig.json
├── docs/
│   ├── API_SPECIFICATION.md          # Complete REST API endpoint reference
│   └── DATABASE_ROADMAP.md           # PostgreSQL transition & offline sync architecture
├── mobile/                           # Flutter mobile application (Android & iOS)
│   ├── lib/
│   │   ├── core/                     # Solar theme tokens, colors, validators
│   │   ├── models/                   # Customer, Purchase, Sale, PanelItem, Settings
│   │   ├── repositories/             # Repository interfaces + Hive implementations
│   │   ├── services/                 # Centralized InventoryService
│   │   ├── providers/                # Reactive state management with Provider
│   │   ├── screens/                  # Home, Sales, Purchase, Customer, Settings
│   │   ├── widgets/                  # Reusable stat cards, badges, dialogs
│   │   └── utils/                    # Currency (₹ INR), date, serial parsers
│   └── test/                         # Flutter unit and widget business rule tests
├── website/                          # React web application (Vite + TypeScript)
│   ├── public/branding/              # Extracted Horizone Energy logo assets
│   ├── src/
│   │   ├── components/               # Layout, StatCard, Badge, Modal dialogs
│   │   ├── pages/                    # Dashboard, Sales, Purchases, Customers, Inventory, Settings
│   │   ├── services/                 # API client with health checks & local fallback
│   │   └── tests/                    # Client-side validation & parser tests
│   ├── vercel.json                   # Vercel SPA routing configuration
│   └── .env.example
├── .gitignore
└── README.md
```

---

## Core Invariants & Business Rules

1. **Individual Panel Serial Tracking:** Stock is **never** calculated solely by tallying transaction rows. Every physical panel is an individual inventory item (`status: 'available' | 'sold'`).
2. **KSEB Customer Mandatory Fields:** KSEB consumer number and phone number are mandatory, trimmed, and strictly unique. Duplicate registrations are rejected.
3. **Safe Deletion Protections:** 
   - Customers with linked sales transactions cannot be deleted.
   - Purchase batches containing panels that have already been sold cannot be deleted.
4. **Sales Verification & Derivation:**
   - Only panels matching the requested wattage and currently possessing `'available'` status can be selected.
   - Quantity is derived directly from selected serial numbers.
   - Panels are atomically marked as `'sold'` with their `sale_id`.
5. **Inventory Reconciliation on Deletion:** When a sale is deleted or cancelled, all its assigned panel serial numbers are atomically returned to `'available'` stock.
6. **Separation of Wattage and Currency:** Quantities, panel wattage (W), and financial totals (₹ INR) are strictly separated.

---

## Prerequisites

- **Node.js:** v18+ (tested on Node v26)
- **npm:** v9+
- **Flutter SDK:** v3.22+ (tested on Flutter 3.41 / Dart 3.11)
- **Web Browser:** Modern Chrome, Safari, Edge, or Firefox

---

## 1. Backend REST API Setup & Execution

The backend runs an Express server in TypeScript with versioned routes under `/api/v1/`.

```bash
cd backend

# 1. Install dependencies
npm install

# 2. Configure environment (PORT 5050 is configured to avoid macOS AirPlay conflict on 5000)
cp .env.example .env

# 3. Run automated tests (17 tests covering all business invariants)
npm test

# 4. Compile TypeScript bundle
npm run build

# 5. Start development server with live reload
npm run dev

# Or run the compiled production server
npm start
```

- **Health check endpoint:** `http://localhost:5050/api/v1/health`
- **Dashboard summary:** `http://localhost:5050/api/v1/dashboard`

---

## 2. React Website Setup & Execution

The web portal is a responsive management dashboard built with React, Vite, and TypeScript.

```bash
cd website

# 1. Install dependencies
npm install

# 2. Configure environment variables
cp .env.example .env

# 3. Run client-side validation tests
npm test

# 4. Build production bundle (tested with TypeScript compilation)
npm run build

# 5. Start development server
npm run dev -- --port 3000
```

Open your browser to: **`http://localhost:3000`**

---

## 3. Flutter Mobile Application Setup & Execution

The mobile application runs on Android and iOS devices, using **Hive** for fast offline-first storage and **Provider** for reactive state updates.

```bash
cd mobile

# 1. Fetch dependencies
flutter pub get

# 2. Run static analysis (0 warnings)
flutter analyze

# 3. Run Flutter unit and widget tests (11 passing tests)
flutter test

# 4. Run the app on a connected device or simulator
flutter run
```

---

## Local Storage vs Shared Synchronization

- **Initial Phase (Active):**
  - Mobile uses local **Hive** boxes (`customers_box`, `purchases_box`, `sales_box`, `panels_box`, `settings_box`). Data persists reliably across app restarts on the device.
  - The website connects to the local development API (`http://localhost:5050/api/v1`).
  - **Important:** Data entered in the local mobile app and the web browser is not automatically shared across separate devices until a central database is connected.
- **Next Phase (Shared Cloud Database):**
  - See [docs/DATABASE_ROADMAP.md](docs/DATABASE_ROADMAP.md) for the PostgreSQL schema, row-level pessimistic locking (`SELECT ... FOR UPDATE`), and the mobile synchronization protocol.

---

## Branding Asset Replacement Instructions

The extracted Horizone Energy brand mark is distributed to:
- Source PDF: `assets/branding/horizone_energy_logo.pdf`
- Extracted Web & Mobile PNG: `assets/branding/logo.png`
- HD Render: `assets/branding/logo_hd.png`
- Web client asset: `website/public/branding/logo.png`
- Mobile client asset: `mobile/assets/branding/logo.png`

To update the branding with an updated corporate asset:
1. Place the new file as `assets/branding/logo.png`.
2. Copy it to `website/public/branding/logo.png` and `mobile/assets/branding/logo.png`.
3. In `mobile/`, run `flutter pub get` and restart the app.

---

## Deployment Instructions

### Website -> Vercel
1. Install the Vercel CLI (`npm i -g vercel`) or push the repository to GitHub.
2. In the Vercel dashboard:
   - Root directory: `website`
   - Framework preset: `Vite`
   - Build command: `npm run build`
   - Output directory: `dist`
3. Environment variables:
   - `VITE_API_BASE_URL`: URL of your deployed backend (e.g., `https://api.horizone.energy/api/v1`).
4. Note: `website/vercel.json` contains single-page application (SPA) rewrite rules so direct URL routes (`/sales`, `/purchases`, `/customers`) resolve correctly on page reload.

### Backend -> Render / Railway / Fly.io
1. Set the root directory to `backend`.
2. Build command: `npm install && npm run build`
3. Start command: `node dist/index.js`
4. Set environment variables:
   - `PORT`: (allocated by provider, e.g., 8080)
   - `NODE_ENV`: `production`
   - `CORS_ORIGIN`: `https://stockflow.horizone.energy` (or your Vercel web domain)
   - `API_PREFIX`: `/api/v1`

---

## Quality & Test Results

### 1. Backend (`backend/`)
- Test runner: Vitest v5.0.4 + Supertest
- Result: **17 passed (17 tests)**
  - Health check endpoint verification
  - Mandatory KSEB consumer number and phone validation
  - Duplicate KSEB consumer number rejection
  - Customer deletion safety check with linked transactions
  - Purchase serial count validation and duplicate detection
  - Serial collision rejection across overall inventory
  - Purchase deletion block when panels are already sold
  - Atomic sale inventory deduction and serial status updates
  - Rejection of already-sold panels and wattage mismatches
  - Immediate panel inventory restoration on sale deletion
  - Aggregations by wattage and batch without conflating wattage and currency
- TypeScript compilation (`npm run build`): **Clean compilation to `dist/` with 0 errors**.

### 2. Website (`website/`)
- Test runner: Vitest v5.0.4
- Result: **4 passed (4 tests)**
  - Bulk serial parsing across space, comma, newline delimiters
  - Duplicate serial number detection in user inputs
  - Currency formatting strictly in INR (₹) without mixing with wattage
  - Mandatory field validation
- Production build (`npm run build`): **Clean Vite production bundle in `dist/` with 0 TypeScript errors**.

### 3. Mobile (`mobile/`)
- Test runner: `flutter test`
- Result: **11 passed (11 tests)**
  - Customer validation & duplicate consumer number rejection
  - Purchase serial count and duplicate detection
  - Serial uniqueness in global inventory
  - Atomic sale deduction & panel restoration on cancellation
  - Purchase deletion block when panels are sold
  - Currency formatter & serial parser utilities
  - StatCard & Badge widget tests
- Static analysis (`flutter analyze`): **No issues found! (0 warnings, 0 errors)**.
