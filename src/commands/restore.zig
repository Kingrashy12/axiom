const std = @import("std");
const ziglet = @import("ziglet");
const fs = @import("../core/fs.zig");
const ActionArg = ziglet.ActionArg;
const repo_mod = @import("../repo.zig");
const restore_rt = @import("../runtime/restore.zig");
const printColored = ziglet.utils.terminal.printColored;

pub fn restore(param: ActionArg) !void {
    fs.ensureRepo();

    const allocator = param.allocator;
    const args = param.args;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const info = try repo_mod.readInfo(allocator, true);

    defer {
        for (info.SNAPSHOTS) |value| {
            defer allocator.free(value);
        }
        allocator.free(info.SNAPSHOTS);
        allocator.free(info.CURRENT_SNAPSHOT_HASH);
        allocator.free(info.CURRENT_TIMELINE);
        allocator.free(info.PREVIOUS_SNAPSHOT_HASH);
        allocator.destroy(info);
    }
    const hash_to_use = if (args.len > 0) args[0] else info.PREVIOUS_SNAPSHOT_HASH;

    if (std.mem.eql(u8, hash_to_use, "EMPTY")) {
        printColored(.yellow, "No snapshot found. Please provide a valid snapshot hash to restore from.\n", .{});
        return;
    }

    const object_path = try std.fmt.allocPrint(allocator, ".axiom/objects/{s}", .{hash_to_use});
    defer allocator.free(object_path);

    const manifest_path = try std.fmt.allocPrint(allocator, ".axiom/snapshots/{s}/manifest.json", .{hash_to_use});
    defer allocator.free(manifest_path);

    var obj_dir = std.fs.cwd().openDir(object_path, .{ .iterate = true }) catch |err| {
        switch (err) {
            error.FileNotFound => {
                printColored(.red, "Object not found\n", .{});
                return;
            },
            else => {
                printColored(.red, "Unexpected error: {s}\n", .{@errorName(err)});
                return;
            },
        }
    };
    defer obj_dir.close();

    const clean_opt = param.options.get("clean");

    try restore_rt.restoreSnapshot(allocator, hash_to_use, &obj_dir, clean_opt);

    // std.debug.print("Restoring codebase to snapshot: {s}\n", .{hash_to_use});
}
