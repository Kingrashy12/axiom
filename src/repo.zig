const std = @import("std");
const Allocator = std.mem.Allocator;
const ziglet = @import("ziglet");
const printColored = ziglet.utils.terminal.printColored;

pub fn pathExists(dir: *std.fs.Dir, path: []const u8) bool {
    dir.access(path, .{}) catch return false;
    return true;
}

const Info = struct {
    TOTAL_SNAPSHOTS: usize,
    SNAPSHOTS: [][]const u8,
    CURRENT_SNAPSHOT_HASH: []const u8,
    PREVIOUS_SNAPSHOT_HASH: []const u8,
    CURRENT_TIMELINE: []const u8,
};

pub fn readInfo(allocator: Allocator, dupe_hash: bool) !*Info {
    var dir = std.fs.cwd();
    var info_file = dir.openFile(".axiom/INFO", .{}) catch |err| {
        printColored(.red, "Error reading file: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
    defer info_file.close();

    const size = try info_file.getEndPos();

    const buffer = try allocator.alloc(u8, size);
    defer allocator.free(buffer);

    _ = try info_file.readAll(buffer);

    var iter = std.mem.splitScalar(u8, buffer, '\n');

    const info = try allocator.create(Info);

    while (iter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

        if (std.mem.indexOf(u8, trimmed, "=") == null) {
            printColored(.red, "Error: Invalid INFO file.", .{});
            std.process.exit(1);
        }

        var parts = std.mem.tokenizeAny(u8, trimmed, " = ");

        const name = parts.next().?;
        const value = parts.next().?;

        if (std.mem.eql(u8, name, "TOTAL_SNAPSHOTS")) {
            info.TOTAL_SNAPSHOTS = std.fmt.parseInt(usize, value, 10) catch 0;
        }

        if (std.mem.eql(u8, name, "CURRENT_SNAPSHOT_HASH")) {
            info.CURRENT_SNAPSHOT_HASH = if (dupe_hash) try allocator.dupe(u8, value) else value;
        }

        if (std.mem.eql(u8, name, "PREVIOUS_SNAPSHOT_HASH")) {
            info.PREVIOUS_SNAPSHOT_HASH = if (dupe_hash) try allocator.dupe(u8, value) else value;
        }

        if (std.mem.eql(u8, name, "SNAPSHOTS")) {
            var snapshots: std.ArrayList([]const u8) = .empty;

            var iterator = std.mem.splitScalar(u8, value, ',');

            while (iterator.next()) |hash| {
                try snapshots.append(allocator, try allocator.dupe(u8, hash));
            }

            info.SNAPSHOTS = try snapshots.toOwnedSlice(allocator);
        }

        if (std.mem.eql(u8, name, "CURRENT_TIMELINE")) {
            info.CURRENT_TIMELINE = try allocator.dupe(u8, value);
        }
    }

    return info;
}

pub fn ensureRepo() void {
    var dir = std.fs.cwd();

    if (!pathExists(&dir, ".axiom")) {
        printColored(.blue, "No Axiom repository found. Please run 'axiom init' to create a new repository.", .{});
    }
}

pub fn updateInfo(allocator: Allocator, new_info: Info) !void {
    var repo_dir = try std.fs.cwd().openDir(".axiom", .{});
    defer repo_dir.close();

    var info_file = repo_dir.openFile("INFO", .{ .mode = .read_write }) catch |err| {
        printColored(.red, "Error reading file: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
    defer info_file.close();

    var snapshots: std.ArrayList(u8) = .empty;

    for (new_info.SNAPSHOTS) |hash| {
        try snapshots.appendSlice(allocator, hash);
        try snapshots.appendSlice(allocator, ",");
        defer allocator.free(hash);
    }

    try snapshots.appendSlice(allocator, new_info.CURRENT_SNAPSHOT_HASH);

    const hashes = try snapshots.toOwnedSlice(allocator);
    defer allocator.free(hashes);

    const info_data = try std.fmt.allocPrint(allocator,
        \\TOTAL_SNAPSHOTS = {d}
        \\CURRENT_SNAPSHOT_HASH = {s}
        \\PREVIOUS_SNAPSHOT_HASH = {s}
        \\SNAPSHOTS = {s}
        \\CURRENT_TIMELINE = {s}
    , .{ new_info.TOTAL_SNAPSHOTS, new_info.CURRENT_SNAPSHOT_HASH, new_info.PREVIOUS_SNAPSHOT_HASH, hashes, new_info.CURRENT_TIMELINE });
    defer allocator.free(info_data);

    try info_file.writeAll(info_data);
}
