// Report calculations. Stats are built from events, never from other services.

# Average delivery time for a driver, rounded to 2 decimal places.
# + completed - Number of finished deliveries.
# + totalMinutes - Sum of delivery durations in minutes.
# + return - The average, or 0 when there are no deliveries.
public function averageMinutes(int completed, int totalMinutes) returns decimal {
    if completed <= 0 {
        return 0d;
    }
    return (<decimal>totalMinutes / <decimal>completed).round(2);
}

# Builds the order totals report from per-status counts and restaurant revenue.
# + stats - Per-status counts (negative counts from missed events are clamped to 0).
# + restaurants - Restaurant stats used to total the revenue.
# + return - The assembled report.
public function buildOrdersReport(OrderStat[] stats, RestaurantStat[] restaurants) returns OrdersReport {
    OrderStat[] byStatus = [];
    int total = 0;
    foreach OrderStat stat in stats {
        int count = stat.count < 0 ? 0 : stat.count;
        byStatus.push({status: stat.status, count: count});
        total += count;
    }
    decimal revenue = 0d;
    foreach RestaurantStat restaurant in restaurants {
        revenue += restaurant.revenue;
    }
    return {byStatus: byStatus, totalOrders: total, totalRevenue: revenue};
}

# Adds the average delivery time to each driver's stats.
# + drivers - Raw driver stats.
# + return - One report row per driver.
public function buildDeliveryReport(DriverStat[] drivers) returns DriverReportRow[] {
    DriverReportRow[] rows = [];
    foreach DriverStat driver in drivers {
        rows.push({
            driverId: driver.driverId,
            completed: driver.completed,
            totalMinutes: driver.totalMinutes,
            averageMinutes: averageMinutes(driver.completed, driver.totalMinutes)
        });
    }
    return rows;
}

# Splits payment stats into success and failure buckets.
# + stats - Stored payment stats (SUCCESS / FAILED rows).
# + return - The assembled report; a missing bucket is zero.
public function buildPaymentsReport(PaymentStat[] stats) returns PaymentsReport {
    PaymentsReport report = {success: {count: 0, amount: 0d}, failed: {count: 0, amount: 0d}};
    foreach PaymentStat stat in stats {
        if stat.status == "SUCCESS" {
            report.success = {count: stat.count, amount: stat.amount};
        } else if stat.status == "FAILED" {
            report.failed = {count: stat.count, amount: stat.amount};
        }
    }
    return report;
}
