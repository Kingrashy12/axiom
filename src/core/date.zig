const std = @import("std");
const testing = std.testing;

const Date = @This();

year: u64,
month: u64,
day: u64,
hour: u64,
minutes: u64,
seconds: u64,
milliseconds: u64,

const day_of_week_abbrev_names = [_][]const u8{ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
const month_abbrev_names = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

pub fn formatTimestamp(ts: i64, allocator: std.mem.Allocator) ![]u8 {
    const epoch = fromAnyTimestamp(ts);

    const time_str = try epoch.allocPrintISO8601(allocator);
    defer allocator.free(time_str);

    return try allocator.dupe(u8, time_str);
}

/// Converts any timestamp (s, ms, µs, ns) into a Date.
pub fn fromAnyTimestamp(ts: i64) Date {
    var t = ts;
    if (t > 10_000_000_000_000_000) {
        // nanoseconds → milliseconds
        t = @divTrunc(t, 1_000_000);
    } else if (t > 10_000_000_000_000) {
        // microseconds → milliseconds
        t = @divTrunc(t, 1_000);
    } else if (t < 10_000_000_000) {
        // seconds → milliseconds
        t *= 1000;
    }
    return fromTimestamp(@intCast(t));
}

/// Creates a Date from a Unix timestamp in milliseconds.
pub fn fromTimestamp(timestamp: u64) Date {
    const ms_per_sec: u64 = 1000;
    const ms_per_minute: u64 = 60 * ms_per_sec;
    const ms_per_hour: u64 = 60 * ms_per_minute;
    const ms_per_day: u64 = 24 * ms_per_hour;
    const days_since_epoch = timestamp / ms_per_day;

    var year: u64 = 1970;
    var day_of_year: u64 = days_since_epoch;
    var leap_year: bool = false;

    while (true) {
        leap_year = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
        const days_in_year: u64 = if (leap_year) 366 else 365;
        if (day_of_year < days_in_year) break;
        day_of_year -= days_in_year;
        year += 1;
    }

    const day_of_month_table = [_][12]u64{
        [_]u64{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 },
        [_]u64{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 },
    };

    var month: u64 = 0;
    var day_of_month: u64 = day_of_year;
    while (day_of_month >= day_of_month_table[if (leap_year) 1 else 0][month]) {
        day_of_month -= day_of_month_table[if (leap_year) 1 else 0][month];
        month += 1;
    }

    const ms_in_day = timestamp % ms_per_day;
    const hour = ms_in_day / ms_per_hour;
    const minutes = (ms_in_day % ms_per_hour) / ms_per_minute;
    const seconds = (ms_in_day % ms_per_minute) / ms_per_sec;
    const milliseconds = ms_in_day % ms_per_sec;

    return Date{
        .year = year,
        .month = month + 1,
        .day = day_of_month + 1,
        .hour = hour,
        .minutes = minutes,
        .seconds = seconds,
        .milliseconds = milliseconds,
    };
}

/// AllocPrint ISO-8601, e.g. 2025-11-03T14:11:04.027Z
pub fn allocPrintISO8601(self: Date, allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(
        allocator,
        "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}Z",
        .{ self.year, self.month, self.day, self.hour, self.minutes, self.seconds, self.milliseconds },
    );
}

/// AllocPrint locale style, e.g. 11/3/2025, 2:11:04 PM
pub fn allocPrintLocale(self: Date, allocator: std.mem.Allocator) ![]u8 {
    const am_pm = if (self.hour < 12) "AM" else "PM";
    const hour_12 = if (self.hour % 12 == 0) 12 else self.hour % 12;
    return std.fmt.allocPrint(
        allocator,
        "{d}/{d}/{d}, {d}:{d:0>2}:{d:0>2} {s}",
        .{ self.month, self.day, self.year, hour_12, self.minutes, self.seconds, am_pm },
    );
}

/// AllocPrint Java style, e.g. Mon Nov 3 02:11:04 PM 2025
pub fn allocPrintJava(self: Date, allocator: std.mem.Allocator) ![]u8 {
    const day_of_week: u8 = @intCast((self.toDaysSinceEpoch() + 4) % 7);
    const day_of_week_str = day_of_week_abbrev_names[day_of_week];
    const month_str = month_abbrev_names[self.month - 1];
    const am_pm = if (self.hour < 12) "AM" else "PM";
    const hour_12 = if (self.hour % 12 == 0) 12 else self.hour % 12;

    return std.fmt.allocPrint(
        allocator,
        "{s} {s} {d} {d:0>2}:{d:0>2}:{d:0>2} {s} {d}",
        .{ day_of_week_str, month_str, self.day, hour_12, self.minutes, self.seconds, am_pm, self.year },
    );
}

fn toDaysSinceEpoch(self: Date) u64 {
    var days: u64 = 0;
    var y = self.year;
    while (y > 1970) : (y -= 1) {
        days += if ((y - 1) % 4 == 0 and ((y - 1) % 100 != 0 or (y - 1) % 400 == 0)) 366 else 365;
    }

    const day_of_month_table = [_][12]u64{
        [_]u64{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 },
        [_]u64{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 },
    };

    const leap = (self.year % 4 == 0 and self.year % 100 != 0) or (self.year % 400 == 0);
    for (day_of_month_table[if (leap) 1 else 0][0 .. self.month - 1]) |d| {
        days += d;
    }
    days += self.day - 1;
    return days;
}

test "allocPrintISO8601 basic" {
    const d = Date.fromAnyTimestamp(1762179064027);
    const s = try d.allocPrintISO8601(testing.allocator);
    defer testing.allocator.free(s);
    try testing.expect(std.mem.startsWith(u8, s, "2025-11-03"));
}

test "allocPrintLocale basic" {
    const d = Date.fromAnyTimestamp(1762179064027);
    const s = try d.allocPrintLocale(testing.allocator);
    defer testing.allocator.free(s);
    try testing.expect(std.mem.indexOf(u8, s, "11/3/2025") != null);
}

test "allocPrintJava basic" {
    const d = Date.fromAnyTimestamp(1762179064027);
    const s = try d.allocPrintJava(testing.allocator);
    defer testing.allocator.free(s);
    try testing.expect(std.mem.indexOf(u8, s, "Nov") != null);
}
