# Horizone StockFlow — REST API Specification (v1)

Base URL: `http://localhost:5050/api/v1`

---

## Health Check
- **`GET /health`**
  - Response: `{ status: "healthy", service: "Horizone StockFlow API", version: "1.0.0", mode: "development-in-memory", uptimeSeconds: 120 }`

---

## Customers
- **`GET /customers?search=`**
  - Returns array of customer records matching search (consumer number, phone, or name).
- **`GET /customers/:id`**
  - Returns customer profile along with their linked solar sale transactions.
- **`POST /customers`**
  - Body:
    ```json
    {
      "consumerNumber": "1155443322110", // Required KSEB number
      "phone": "+91 98470 12345",       // Required phone number
      "name": "Venu Gopal Nair",          // Optional
      "address": "Sasthamangalam, TVM"    // Optional
    }
    ```
- **`PUT /customers/:id`**
  - Updates customer profile.
- **`DELETE /customers/:id`**
  - Blocks deletion with HTTP 400 if customer has linked sales.

---

## Purchases (Inward Shipments)
- **`GET /purchases?batch=&wattage=&search=`**
  - Returns list of purchase transactions.
- **`GET /purchases/:id`**
  - Returns purchase batch with full list of serial numbers.
- **`POST /purchases`**
  - Body:
    ```json
    {
      "purchaseDate": "2026-03-12T09:30:00.000Z",
      "supplierName": "Tata Power Solar Systems",
      "batchNumber": "BATCH-540-A1",
      "wattage": 540,
      "quantity": 2,
      "serialNumbers": ["HZ-540-001", "HZ-540-002"],
      "unitPurchasePrice": 11500,
      "notes": "Invoice #9822"
    }
    ```
  - Validates `serialNumbers.length === quantity`. Rejects duplicates and already registered serials.
- **`PUT /purchases/:id`**
  - Updates batch details.
- **`DELETE /purchases/:id`**
  - Rejects deletion if any panel from this purchase has already been sold.

---

## Sales (Outward Dispatches)
- **`GET /sales?customerId=&wattage=&search=`**
  - Returns list of sales transactions.
- **`GET /sales/:id`**
  - Returns sale record with customer details and allocated serials.
- **`POST /sales`**
  - Body:
    ```json
    {
      "saleDate": "2026-03-18T14:20:00.000Z",
      "customerId": "cust-101",
      "panelWattage": 540,
      "serialNumbers": ["HZ-540-001", "HZ-540-002"],
      "unitSellingPrice": 14200,
      "notes": "3kW On-Grid Rooftop Phase 1"
    }
    ```
  - Automatically derives `quantity` from `serialNumbers.length`.
  - Verifies panels exist, are available, and match requested wattage.
  - Atomically marks panels as `'sold'`.
- **`DELETE /sales/:id`**
  - Reconciles inventory: returns all allocated panels back to `'available'` status.

---

## Inventory & Reporting
- **`GET /inventory?wattage=&batch=&status=&search=`**
  - Granular table of physical panel items.
- **`GET /inventory/available/:wattage`**
  - Returns all uncommitted panels available for immediate sale of specified wattage.
- **`GET /inventory/by-wattage`**
  - Returns available, sold, and total panels grouped by wattage with low-stock alerts.
- **`GET /inventory/by-batch`**
  - Returns aggregations grouped by batch number.
- **`GET /dashboard`**
  - Executive summary with total available, total purchased, total sold, total stock valuation in ₹, low stock warnings, and recent transactions.
