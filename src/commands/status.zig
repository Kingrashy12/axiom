const std = @import("std");
const ziglet = @import("ziglet");
const utils = @import("utils");
const ActionArg = ziglet.ActionArg;
const manifest = @import("../manifest.zig");
const fs_utils = @import("../fs_utils.zig");
const diff_mod = @import("../diff.zig");
const repo_mod = @import("../repo.zig");
const printColored = ziglet.utils.terminal.printColored;

pub fn status(param: ActionArg) !void {
    const allocator = param.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    repo_mod.ensureRepo();

    const info = try repo_mod.readInfo(allocator, true);
    defer {
        allocator.free(info.CURRENT_SNAPSHOT_HASH);
        allocator.free(info.CURRENT_TIMELINE);
        allocator.destroy(info);
    }

    const manifest_data = try manifest.loadSnapshotManifest(arena.allocator(), allocator, info.CURRENT_SNAPSHOT_HASH);
    defer manifest_data.deinit(allocator);
    defer allocator.destroy(manifest_data);

    const current_files = try fs_utils.collectFiles(allocator);
    defer allocator.free(current_files);

    var diff_result = try diff_mod.diff(
        allocator,
        manifest_data,
        current_files,
    );
    defer diff_result.deinit();

    if (diff_result.added.items.len == 0 and diff_result.modified.items.len == 0 and diff_result.removed.items.len == 0) {
        printColored(.blue, "No changes detected since last snapshot.\n", .{});

        for (current_files) |value| {
            defer allocator.free(value);
        }

        return;
    }

    if (diff_result.added.items.len > 0) {
        printColored(.white, "Added:\n", .{});
        for (diff_result.added.items) |path| {
            printColored(.green, "  + {s}\n", .{path});
        }
        std.debug.print("\n", .{});
    }

    if (diff_result.modified.items.len > 0) {
        printColored(.white, "Modified:\n", .{});
        for (diff_result.modified.items) |path| {
            printColored(.yellow, "  ~ {s}\n", .{path});
        }
        std.debug.print("\n", .{});
    }

    if (diff_result.removed.items.len > 0) {
        printColored(.white, "Removed:\n", .{});
        for (diff_result.removed.items) |path| {
            printColored(.red, "  - {s}\n", .{path});
        }
        std.debug.print("\n", .{});
    }

    for (current_files) |value| {
        defer allocator.free(value);
    }
}
