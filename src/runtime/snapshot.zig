const std = @import("std");
const ziglet = @import("ziglet");
const hash_mod = @import("../core/hash.zig");

pub const FileEntry = struct {
    path: []const u8,
    hash: []const u8,
};

pub const Manifest = struct {
    message: []const u8,
    timestamp: i64,
    hash: []const u8,
    files: []FileEntry,
};

pub fn collectEntry(
    allocator: std.mem.Allocator,
    current_files: [][]const u8,
) ![]FileEntry {
    var entries: std.ArrayList(FileEntry) = .empty;

    for (current_files) |path| {
        const hash = try hash_mod.hash_file_hex(allocator, path);

        try entries.append(allocator, FileEntry{
            .path = path,
            .hash = hash,
        });
    }

    return try entries.toOwnedSlice(allocator);
}
