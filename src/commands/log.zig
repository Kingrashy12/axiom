const std = @import("std");
const ziglet = @import("ziglet");
const ActionArg = ziglet.ActionArg;
const fs = @import("../core/fs.zig");
const repo_mod = @import("../repo.zig");
const manifest_mod = @import("../core/manifest.zig");
const printColored = ziglet.utils.terminal.printColored;
const print = ziglet.utils.terminal.print;
const LogEntry = @import("../types.zig").LogEntry;
const Date = @import("../core/date.zig");

pub fn log(param: ActionArg) !void {
    fs.ensureRepo();

    const allocator = param.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var log_dir = try std.fs.cwd().openDir(".axiom/log", .{ .iterate = true });
    defer log_dir.close();

    var it = log_dir.iterate();

    var entries: std.ArrayList(LogEntry) = .empty;
    defer {
        for (entries.items) |e| {
            allocator.free(e.hash);
            allocator.free(e.message);
        }
        entries.deinit(allocator);
    }

    // Collect entries
    while (try it.next()) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".log") or std.mem.startsWith(u8, entry.name, "restore")) continue;

        var file = try log_dir.openFile(entry.name, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);
        _ = try file.read(buffer);

        const parsed = try std.json.parseFromSliceLeaky(LogEntry, arena.allocator(), buffer, .{});

        const hash = try allocator.dupe(u8, parsed.hash);
        const message = try allocator.dupe(u8, parsed.message);
        const time_val = parsed.timestamp;
        const files_count: usize = @intCast(parsed.files_count);

        try entries.append(allocator, .{ .hash = hash, .message = message, .timestamp = time_val, .files_count = files_count });
    }

    // Sort chronologically (newest first)
    std.mem.sort(LogEntry, entries.items, {}, struct {
        fn lessThan(_: void, a: LogEntry, b: LogEntry) bool {
            return a.timestamp > b.timestamp;
        }
    }.lessThan);

    // Pretty-print results
    if (entries.items.len == 0) {
        print("No log entries found.\n", .{});
        return;
    }

    print("═════════════ Axiom Snapshots Log ═════════════\n\n", .{});

    for (entries.items) |e| {
        const time_str = try Date.formatTimestamp(e.timestamp, allocator);
        defer allocator.free(time_str);

        printColored(.green, "◉ ", .{});
        print("{s}  |  {s}  |  {s} ({d} files)\n", .{ e.hash, time_str, e.message, e.files_count });
    }
}
