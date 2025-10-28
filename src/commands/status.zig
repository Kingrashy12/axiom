const std = @import("std");
const ziglet = @import("ziglet");
const utils = @import("utils");
const ActionArg = ziglet.ActionArg;
const manifest = @import("../manifest.zig");
const fs_utils = @import("../fs_utils.zig");
const diff_mod = @import("../diff.zig");

pub fn status(param: ActionArg) !void {
    const allocator = param.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const manifest_data = try manifest.loadSnapshotManifest(arena.allocator(), allocator);
    defer allocator.destroy(manifest_data);
    defer manifest_data.deinit(allocator);

    var files: std.ArrayList([]const u8) = .empty;
    defer files.deinit(allocator);

    const current_files = try fs_utils.collectFiles(allocator);
    defer allocator.free(current_files);

    var diff_result = try diff_mod.diff(
        allocator,
        manifest_data,
        current_files,
    );
    defer diff_result.deinit();

    if (diff_result.added.items.len == 0 and diff_result.modified.items.len == 0 and diff_result.removed.items.len == 0) {
        ziglet.utils.terminal.printColored(.blue, "No changes detected since last snapshot.", .{});
        return;
    }

    if (diff_result.added.items.len > 0) {
        ziglet.utils.terminal.printColored(.white, "Added:\n", .{});
        for (diff_result.added.items) |path| {
            ziglet.utils.terminal.printColored(.green, "  + {s}\n", .{path});
        }
        std.debug.print("\n", .{});
    }

    if (diff_result.modified.items.len > 0) {
        ziglet.utils.terminal.printColored(.white, "Modified:\n", .{});
        for (diff_result.modified.items) |path| {
            ziglet.utils.terminal.printColored(.yellow, "  ~ {s}\n", .{path});
        }
        std.debug.print("\n", .{});
    }

    if (diff_result.removed.items.len > 0) {
        ziglet.utils.terminal.printColored(.white, "Removed:\n", .{});
        for (diff_result.removed.items) |path| {
            ziglet.utils.terminal.printColored(.red, "  - {s}\n", .{path});
        }
        std.debug.print("\n", .{});
    }

    for (current_files) |value| {
        defer allocator.free(value);
    }
}
