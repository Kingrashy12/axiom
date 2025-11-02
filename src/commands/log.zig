const std = @import("std");
const ziglet = @import("ziglet");
const ActionArg = ziglet.ActionArg;
const fs = @import("../core/fs.zig");
const repo_mod = @import("../repo.zig");
const manifest_mod = @import("../core/manifest.zig");
const printColored = ziglet.utils.terminal.printColored;
const print = ziglet.utils.terminal.print;

pub fn log(param: ActionArg) !void {
    fs.ensureRepo();

    const allocator = param.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var dir = try std.fs.cwd().openDir(".axiom/snapshots", .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        switch (entry.kind) {
            // TODO: Order log by timestamp
            .directory => {
                const manifest_data = manifest_mod.loadSnapshotManifest(arena.allocator(), allocator, entry.path) catch |err| {
                    printColored(.red, "Unexpected error: {s}\n", .{@errorName(err)});
                    return;
                };

                defer allocator.destroy(manifest_data);
                defer manifest_data.deinit(allocator);

                printColored(.green, "◉", .{});
                print(" ", .{});
                printColored(.gray, "{s}", .{manifest_data.hash});
                print(" — ", .{});
                print("{s}", .{manifest_data.message});

                // const instant = std.time.Instant{ .timestamp = .{ .sec = manifest_data.timestamp } };

                print("\n", .{});
            },
            else => {},
        }
    }
}
