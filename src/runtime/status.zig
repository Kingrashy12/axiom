const std = @import("std");
const Allocator = std.mem.Allocator;
const ziglet = @import("ziglet");
const ActionArg = ziglet.ActionArg;
const manifest = @import("../core/manifest.zig");
const fs = @import("../core/fs.zig");
const diff_mod = @import("../core/diff.zig");
const printColored = ziglet.utils.terminal.printColored;

pub fn checkStatus(arena: Allocator, allocator: Allocator, current_hash: []const u8, log_status: bool) !u8 {
    const manifest_data = manifest.loadSnapshotManifest(arena, allocator, current_hash) catch |err| {
        switch (err) {
            error.ManifestNotFound => {
                return 2; // continue
            },
            else => {
                printColored(.red, "Unexpected error: {s}\n", .{@errorName(err)});
                std.process.exit(1); // for now end the program
            },
        }
    };

    defer allocator.destroy(manifest_data);
    defer manifest_data.deinit(allocator);

    const current_files = try fs.collectFiles(allocator);
    defer allocator.free(current_files);

    var diff_result = try diff_mod.diff(
        allocator,
        manifest_data,
        current_files,
    );
    defer diff_result.deinit();

    if (diff_result.added.items.len == 0 and diff_result.modified.items.len == 0 and diff_result.removed.items.len == 0) {
        for (current_files) |value| {
            defer allocator.free(value);
        }
        return 0;
    }

    if (log_status) {
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
    }

    for (current_files) |value| {
        defer allocator.free(value);
    }

    return 1;
}
