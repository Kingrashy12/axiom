const std = @import("std");
const ziglet = @import("ziglet");
const utils = @import("utils");
const ActionArg = ziglet.ActionArg;
const fs_utils = @import("../fs_utils.zig");
const types = @import("../types.zig");

pub fn snapshot(param: ActionArg) !void {
    const allocator = param.allocator;

    var files: std.ArrayList([]const u8) = .empty;
    defer files.deinit(allocator);

    var dir = try std.fs.cwd().openDir("", .{ .iterate = true });
    defer dir.close();

    const ignore_paths = try fs_utils.readIgnoreFile(allocator);
    defer {
        for (ignore_paths) |value| {
            allocator.free(value);
        }
        allocator.free(ignore_paths);
    }

    try fs_utils.walkFiles(allocator, &dir, "", &files, ignore_paths);

    const output_files = try fs_utils.replaceBackslashWithForwardSlash(allocator, files.items);
    defer allocator.free(output_files);

    var snap_files = try allocator.alloc(types.SnapshotFile, files.items.len);
    defer allocator.free(snap_files);

    std.fs.cwd().makePath(".axiom/snapshots/blobs") catch {};

    for (output_files, 0..) |file_path, i| {
        const file_data = try std.fs.cwd().readFileAlloc(allocator, file_path, 10_000_000);
        defer allocator.free(file_data);

        var hasher = std.crypto.hash.composition.Sha256oSha256.init(.{});
        hasher.update(file_data);
        var digest: [32]u8 = undefined;
        hasher.final(&digest);

        const hash_hex = try std.fmt.allocPrint(allocator, "{x}", .{digest});
        defer allocator.free(hash_hex);

        const blob_path = try std.fmt.allocPrint(allocator, ".axiom/snapshots/blobs/{s}", .{hash_hex});
        defer allocator.free(blob_path);

        if (!utils.pathExists(&dir, blob_path)) {
            var blob_file = try std.fs.cwd().createFile(blob_path, .{});
            defer blob_file.close();
            try blob_file.writeAll(file_data);
        }

        snap_files[i] = .{ .path = try allocator.dupe(u8, file_path), .hash = try allocator.dupe(u8, hash_hex) };
    }

    const timestamp = std.time.timestamp();

    const manifest_path = ".axiom/snapshots/manifest.json";
    var manifest_file = try std.fs.cwd().createFile(manifest_path, .{});
    defer manifest_file.close();

    const timestamp_str = try std.fmt.allocPrint(allocator, "{}", .{timestamp});
    defer allocator.free(timestamp_str);

    try manifest_file.writeAll("{ \"timestamp\": ");
    try manifest_file.writeAll(timestamp_str);
    try manifest_file.writeAll(", \"files\": [");

    for (snap_files, 0..) |sf, idx| {
        if (idx != 0) try manifest_file.writeAll(", ");
        const sf_detail = try std.fmt.allocPrint(
            allocator,
            "{{ \"path\": \"{s}\", \"hash\": \"{s}\" }}",
            .{ sf.path, sf.hash },
        );
        defer allocator.free(sf_detail);

        manifest_file.writeAll(sf_detail) catch {
            defer allocator.free(sf.hash);
            defer allocator.free(sf.path);
        };
        defer allocator.free(sf.hash);
        defer allocator.free(sf.path);
    }

    try manifest_file.writeAll("] }");

    for (files.items) |value| {
        defer allocator.free(value);
    }

    ziglet.utils.terminal.printColored(.green, "Snapshot created with {d} files!\n", .{files.items.len});
}
