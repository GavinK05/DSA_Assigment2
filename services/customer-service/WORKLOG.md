# Work log — customer-service

| Date | Name | Function / endpoint | File | Status | How I tested it | Known issues / edge cases |
|---|---|---|---|---|---|---|
| 2026-10-05 | Erastus (code written with Claude) | `POST /customers` | service.bal, logic.bal | ✅ Tested | curl: 201; same email in different case → 409; bad email → 400 | Email check is simple (needs `@` and a dotted domain) |
| 2026-10-05 | Erastus (with Claude) | `GET /customers/{id}`, `PUT /customers/{id}` | service.bal, logic.bal | ✅ Tested | curl: 200, unknown id → 404, empty body → 400 | PUT only changes name/phone, not email |
| 2026-10-05 | Erastus (with Claude) | address endpoints (POST/GET/DELETE) | service.bal, logic.bal | ✅ Tested | curl: 201/200/204; bad lat → 400; deleting twice → 404 | Address count per customer is unlimited |
| 2026-10-05 | Erastus (with Claude) | `GET /customers/{id}/orders` | service.bal | ✅ Tested | Compose end-to-end: order shows CREATED then CONFIRMED with total | Orders list is empty for a customer until events arrive |
| 2026-10-05 | Erastus (with Claude) | db.bal functions (insert/find/update/address/history/processed events) | db.bal | ✅ Tested | via the endpoints above and mongosh | Unique indexes on customerId, email, orderId, eventId |
| 2026-10-05 | Erastus (with Claude) | `handleOrderCreated`, `handleOrderStatusChanged` | consumer.bal | ✅ Tested | published events with kafka-console-producer: duplicate ignored, bad JSON logged and skipped | Total is 0 until the first status-changed event arrives |
