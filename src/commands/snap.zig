const std = @import("std");
const ziglet = @import("ziglet");
const utils = @import("utils");
const ActionArg = ziglet.ActionArg;
const fs_utils = @import("../fs_utils.zig");
const repo_mod = @import("../repo.zig");
const snapshot_mod = @import("../snapshot.zig");
const FileEntry = snapshot_mod.FileEntry;
const collectEntry = snapshot_mod.collectEntry;
const printColored = ziglet.utils.terminal.printColored;

pub fn snapshot(param: ActionArg) !void {
    const allocator = param.allocator;

    var message: []const u8 = "(unset)";

    if (param.options.get("message")) |m| {
        message = ziglet.CLIUtils.takeString(m);
    }

    repo_mod.ensureRepo();

    var dir = try std.fs.cwd().openDir("", .{ .iterate = true });
    defer dir.close();

    const current_files = try fs_utils.collectFiles(allocator);
    defer allocator.free(current_files);

    const entries = try collectEntry(allocator, current_files);
    defer allocator.free(entries);

    const hash_key = try std.fmt.allocPrint(allocator, "{s}::{d}", .{ message, std.time.timestamp() });
    defer allocator.free(hash_key);

    const snap_hash = try utils.hash_hex_short(allocator, hash_key);
    defer allocator.free(snap_hash);

    const obj_path = try std.fmt.allocPrint(allocator, ".axiom/objects/{s}", .{snap_hash});
    defer allocator.free(obj_path);

    const snap_path = try std.fmt.allocPrint(allocator, ".axiom/snapshots/{s}", .{snap_hash});
    defer allocator.free(snap_path);

    dir.makePath(obj_path) catch |err| {
        printColored(.red, "Error: Filed to create snapshot object: {s}\n", .{@errorName(err)});
        freeEntries(allocator, entries);
        return;
    };

    dir.makePath(snap_path) catch |err| {
        printColored(.red, "Error: Filed to create snapshot metadata: {s}\n", .{@errorName(err)});
        freeEntries(allocator, entries);
        return;
    };

    // ============= Write snapshot objects to disk ================

    for (entries) |entry| {
        // construct object path
        const entry_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ obj_path, entry.hash });
        defer allocator.free(entry_path);

        // Read data from file
        const file_data = try dir.readFileAlloc(allocator, entry.path, 10_000_000);
        defer allocator.free(file_data);

        // If object does not exits create it
        if (!utils.pathExists(&dir, entry_path)) {
            var obj_file = try dir.createFile(entry_path, .{});
            defer obj_file.close();

            try obj_file.writeAll(file_data);
        }
    }

    const manifest_path = try std.fmt.allocPrint(allocator, "{s}/manifest.json", .{snap_path});
    defer allocator.free(manifest_path);

    // =============== Write snapshot metadata to disk ==============

    var manifest_file = try std.fs.cwd().createFile(manifest_path, .{});
    defer manifest_file.close();

    const timestamp_str = try std.fmt.allocPrint(allocator, "{}", .{std.time.timestamp()});
    defer allocator.free(timestamp_str);

    try manifest_file.writeAll("{ \"timestamp\": ");
    try manifest_file.writeAll(timestamp_str);
    try manifest_file.writeAll(", \"message\": \"");
    try manifest_file.writeAll(message);
    try manifest_file.writeAll("\", \"hash\": \"");
    try manifest_file.writeAll(snap_hash);
    try manifest_file.writeAll("\", \"files\": [");

    for (entries, 0..) |entry, i| {
        if (i != 0) try manifest_file.writeAll(", ");
        const file = try std.fmt.allocPrint(
            allocator,
            "{{ \"path\": \"{s}\", \"hash\": \"{s}\" }}",
            .{ entry.path, entry.hash },
        );
        defer allocator.free(file);

        manifest_file.writeAll(file) catch {
            freeEntries(allocator, entries);
        };

        defer allocator.free(entry.hash);
        defer allocator.free(entry.path);
    }

    try manifest_file.writeAll("] }");

    const info = try repo_mod.readInfo(allocator, false);
    defer {
        // allocator.free(info.CURRENT_SNAPSHOT_HASH);
        allocator.free(info.CURRENT_TIMELINE);
        allocator.destroy(info);
    }

    info.TOTAL_SNAPSHOTS += 1;
    info.CURRENT_SNAPSHOT_HASH = snap_hash;

    try repo_mod.updateInfo(allocator, info.*);

    // std.debug.print("Hash: {s}\nTotal: {d}\n", .{ info.CURRENT_SNAPSHOT_HASH, info.TOTAL_SNAPSHOTS });

    printColored(.green, "Created new snapshot: {s}", .{snap_hash});
}

fn freeEntries(allocator: std.mem.Allocator, entries: []snapshot_mod.FileEntry) void {
    for (entries) |entry| {
        defer allocator.free(entry.hash);
        defer allocator.free(entry.path);
    }
}
