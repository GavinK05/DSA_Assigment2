# Work log — admin-service

| Date | Name | Function / endpoint | File | Status | How I tested it | Known issues / edge cases |
|---|---|---|---|---|---|---|
| 2026-10-05 | Erastus (code written with Claude) | 5 report endpoints | service.bal | ✅ Tested | curl against stats built from published events; unknown restaurant → 404 | Reports are empty until events arrive |
| 2026-10-05 | Erastus (with Claude) | `averageMinutes`, report builders | logic.bal | ✅ Tested | 16 + 25 min over 2 deliveries → 20.5 | Negative status counts (missed events) are shown as 0 |
| 2026-10-05 | Erastus (with Claude) | `incrementRestaurantStat`, `incrementDriverStat`, `incrementOrderStat`, `incrementPaymentStat`, `find…` | db.bal | ✅ Tested | via the reports and mongosh | Revenue is counted when an order becomes DELIVERED |
| 2026-10-05 | Erastus (with Claude) | 6 consumer handlers | consumer.bal | ✅ Tested | published a full order lifecycle, a duplicate and bad JSON; Compose end-to-end | A crash between updating stats and marking the event processed could double-count (at-least-once) |
