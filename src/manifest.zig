const std = @import("std");
const types = @import("types.zig");
const ziglet = @import("ziglet");
const Allocator = std.mem.Allocator;

pub const Manifest = struct {
    timestamp: i64,
    files: []types.SnapshotFile,

    pub fn deinit(self: *Manifest, allocator: std.mem.Allocator) void {
        for (self.files) |file| {
            allocator.free(file.path);
            allocator.free(file.hash);
        }
        allocator.free(self.files);
    }
};

pub fn loadSnapshotManifest(arena: Allocator, allocator_default: Allocator) !*Manifest {
    var cwd = std.fs.cwd();

    var file = cwd.openFile(".axiom/snapshots/manifest.json", .{}) catch |err| {
        ziglet.utils.terminal.printError("Failed to open manifest file: {s}", .{@errorName(err)});
        std.process.exit(1);
    };
    defer file.close();

    const size = try file.getEndPos();

    const buffer = arena.alloc(u8, size) catch {
        ziglet.utils.terminal.printError("Failed to allocate memory for manifest file.", .{});
        std.process.exit(1);
    };

    defer arena.free(buffer);

    _ = try file.readAll(buffer);

    const parsed = std.json.parseFromSliceLeaky(types.Snapshot, arena, buffer, .{ .allocate = .alloc_if_needed }) catch |err| {
        ziglet.utils.terminal.printError("Failed to parse manifest JSON: {s}", .{@errorName(err)});
        return err;
    };

    const allocated_snapshot = allocator_default.create(Manifest) catch |err| {
        ziglet.utils.terminal.printError("Failed to allocate memory for snapshot: {s}", .{@errorName(err)});
        return err;
    };

    allocated_snapshot.*.timestamp = parsed.timestamp;

    var files_array = try allocator_default.alloc(types.SnapshotFile, parsed.files.len);

    for (parsed.files, 0..) |f, idx| {
        files_array[idx] = types.SnapshotFile{
            .path = try allocator_default.dupe(u8, f.path),
            .hash = try allocator_default.dupe(u8, f.hash),
        };
    }

    allocated_snapshot.*.files = files_array;

    return allocated_snapshot;
}
