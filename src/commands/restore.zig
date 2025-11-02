const std = @import("std");
const ziglet = @import("ziglet");
const fs = @import("../core/fs.zig");
const ActionArg = ziglet.ActionArg;
const repo_mod = @import("../repo.zig");
const printColored = ziglet.utils.terminal.printColored;

pub fn restore(param: ActionArg) !void {
    fs.ensureRepo();

    const allocator = param.allocator;
    const args = param.args;

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

    std.debug.print("Restoring codebase to snapshot: {s}\n", .{hash_to_use});
}
