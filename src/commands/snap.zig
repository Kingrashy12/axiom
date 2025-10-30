const std = @import("std");
const ziglet = @import("ziglet");
const utils = @import("utils");
const ActionArg = ziglet.ActionArg;
const fs_utils = @import("../fs_utils.zig");
const snapshot_mod = @import("../snapshot.zig");
const FileEntry = snapshot_mod.FileEntry;
const collectEntry = snapshot_mod.collectEntry;

pub fn snapshot(param: ActionArg) !void {
    const allocator = param.allocator;

    var dir = try std.fs.cwd().openDir("", .{ .iterate = true });
    defer dir.close();

    const current_files = try fs_utils.collectFiles(allocator);
    defer allocator.free(current_files);

    const entries = try collectEntry(allocator, current_files);
    defer allocator.free(entries);

    for (entries) |entry| {
        std.debug.print("Path: {s}, Hash: {s}\n", .{ entry.path, entry.hash });
        defer allocator.free(entry.hash);
    }
}
