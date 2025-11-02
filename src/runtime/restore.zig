const std = @import("std");
const Allocator = std.mem.Allocator;
const ziglet = @import("ziglet");
const fs = @import("../core/fs.zig");
const ActionArg = ziglet.ActionArg;
const repo_mod = @import("../repo.zig");
const manifest_mod = @import("../core/manifest.zig");
const printColored = ziglet.utils.terminal.printColored;

pub fn restoreSnapshot(allocator: Allocator, hash_to_use: []const u8, obj_dir: *std.fs.Dir, clean_opt: ?ziglet.BuilderTypes.Value) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var manifest_map = std.StringHashMap([]const u8).init(allocator);
    defer manifest_map.deinit();

    // Load manifest data
    const manifest_data = try manifest_mod.loadSnapshotManifest(arena.allocator(), allocator, hash_to_use);
    defer allocator.destroy(manifest_data);
    defer manifest_data.deinit(allocator);

    for (manifest_data.files) |value| {
        try manifest_map.put(value.hash, value.path);
    }

    var obj_iterator = try obj_dir.walk(allocator);
    defer obj_iterator.deinit();

    if (clean_opt != null and ziglet.CLIUtils.takeBool(clean_opt.?) == true) {
        const current_files = try fs.collectFiles(allocator);
        defer allocator.free(current_files);

        for (current_files) |file| {
            if (!manifest_map.contains(file)) {
                std.fs.cwd().deleteFile(file) catch |err| {
                    printColored(.yellow, "Skipping {s}: {s}\n", .{ file, @errorName(err) });
                };
            }
            defer allocator.free(file);
        }
    }

    while (try obj_iterator.next()) |entry| {
        if (manifest_map.get(entry.path)) |file_path| {
            var file = try obj_dir.openFile(entry.path, .{});
            defer file.close();

            const file_size = try file.getEndPos();
            const buffer = try allocator.alloc(u8, file_size);
            defer allocator.free(buffer);
            _ = try file.read(buffer);

            var new_file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });
            defer new_file.close();
            _ = try new_file.writeAll(buffer);

            printColored(.green, "Restored: {s}\n", .{file_path});
        }
    }
}
