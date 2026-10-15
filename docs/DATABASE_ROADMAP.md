# Horizone StockFlow — Shared Database & Synchronization Roadmap

This document outlines the transition plan from standalone local offline storage (Hive mobile + in-memory web API) to a unified shared cloud database.

---

## 1. Database Evaluation & Trade-offs

| Criterion | **PostgreSQL (Recommended)** | MongoDB |
| :--- | :--- | :--- |
| **ACID Guarantees** | Full Multi-Row ACID transactions, strict row-level locking (`SELECT ... FOR UPDATE`). | Document-level ACID; multi-document transactions exist but introduce latency and lock contention. |
| **Serial Uniqueness** | Enforced at the database engine level via unique constraints (`UNIQUE(serial_number)`). | Supported via unique indexes, but partial index constraints can be nuanced. |
| **Inventory Integrity** | Prevents concurrent over-allocation of physical serials under high concurrency. | Prone to optimistic concurrency race conditions unless carefully engineered with version locks. |
| **Reporting & Aggregations**| Native, high-performance relational aggregation (`GROUP BY wattage`, `GROUP BY batch`). | Aggregation pipeline required; more verbose syntax. |
| **Cost & Hosting** | Generous free tiers on Neon, Supabase, Render, Railway. | Free 512MB M0 cluster on MongoDB Atlas. |

### Recommendation
**PostgreSQL is strongly recommended** for Horizone Energy. In solar stock management, physical assets (panels) are discrete physical items that must never be sold twice or assigned to two customer sites concurrently. PostgreSQL's row-level locks and strict foreign key constraints (preventing deletion of customers or purchases that hold active sales) match these business invariants perfectly.

---

## 2. Preventing Concurrent Panel Sales (Authoritative Backend)

When multiple stock managers or sales executives attempt to dispatch panels simultaneously:
1. The backend API begins an explicit database transaction (`BEGIN;`).
2. The selected panel serial numbers are queried with pessimistic locking:
   ```sql
   SELECT id, serial_number, status, wattage 
   FROM panels 
   WHERE serial_number = ANY($1) 
   FOR UPDATE;
   ```
3. If any panel has `status != 'available'`, the transaction is immediately rolled back, returning HTTP 409 Conflict with the specific offending serial number.
4. If all are available, the sale record is inserted, the panels are updated to `'sold'` with the associated `sale_id`, and the transaction commits (`COMMIT;`).

---

## 3. Mobile Synchronization Protocol (Offline-First to Cloud)

### Architecture
- **Local Cache:** Mobile devices maintain a local Hive database for instant read/write latency and offline resilience in rural Kerala sites with intermittent 4G/5G signal.
- **Sync Journal:** Every local mutation (Create Customer, Add Purchase, Record Sale) generates an immutable journal entry with a client-generated UUID `sync_id` and timestamp.
- **Idempotency:** When the device regains connectivity, the sync engine transmits pending journal entries with their `idempotency_key`. The server rejects duplicate applications of the same operation.
- **Conflict Handling:**
  - **Customers:** Last-Write-Wins on non-critical metadata (address, phone). Consumer numbers are strictly unique; duplicate registrations reject the incoming mobile entry.
  - **Purchases:** Appended unconditionally (each batch has distinct serials).
  - **Sales:** If an offline mobile recorded a sale of a serial number that was concurrently sold on the website while the mobile was offline, the server returns a `SALE_SERIAL_CONFLICT` error. The mobile app flags the transaction in an "Action Required" queue for the manager to reassign a different available serial of the same wattage.

---

## 4. Security & Role-Based Access Control (RBAC)

Prior to exposing the shared database publicly:
- Implement JSON Web Tokens (JWT) authentication.
- Establish roles:
  - **Admin / Stock Manager:** Full CRUD on purchases, sales, customers, thresholds.
  - **Field Technician / Installer:** Read-only access to customer sites and assigned panel serial numbers.
  - **Accountant:** Read-only access to transaction history, unit prices, and valuation summaries.
