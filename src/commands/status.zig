const std = @import("std");
const Allocator = std.mem.Allocator;
const ziglet = @import("ziglet");
const ActionArg = ziglet.ActionArg;
const repo_mod = @import("../repo.zig");
const printColored = ziglet.utils.terminal.printColored;

const status_rt = @import("../runtime/status.zig");

pub fn status(param: ActionArg) !void {
    const allocator = param.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    repo_mod.ensureRepo();

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

    const _status = try status_rt.checkStatus(arena.allocator(), allocator, info.CURRENT_SNAPSHOT_HASH, true);

    if (_status == 0) {
        printColored(.blue, "No changes detected since last snapshot.\n", .{});
        return;
    } else if (_status == 2) {
        printColored(.blue, "No snapshots found. You haven't created any snapshots yet.\n", .{});
        ziglet.utils.terminal.print("Run `axiom snap` to create your first snapshot (for example: axiom snap -m \"initial snapshot\").\n", .{});
    }
}
