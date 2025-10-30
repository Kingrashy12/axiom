const std = @import("std");
const manifest_mod = @import("manifest.zig");
const Allocator = std.mem.Allocator;
const utils = @import("utils");

pub const DiffChange = enum {
    Added,
    Modified,
    Removed,
};

pub const DiffResult = struct {
    added: std.ArrayList([]const u8),
    modified: std.ArrayList([]const u8),
    removed: std.ArrayList([]const u8),
    allocator: Allocator,

    pub fn init(allocator: Allocator) DiffResult {
        return .{
            .added = .empty,
            .modified = .empty,
            .removed = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DiffResult) void {
        self.added.deinit(self.allocator);
        self.modified.deinit(self.allocator);
        self.removed.deinit(self.allocator);
    }
};

pub fn diff(
    allocator: Allocator,
    manifest: *const manifest_mod.Manifest,
    current_files: [][]const u8, // paths only
    // hashLookup: fn ([]const u8) []const u8, // external hashing fn
) !DiffResult {
    var result = DiffResult.init(allocator);

    // check for added / modified
    for (current_files) |path| {
        var is_known = false;

        for (manifest.files) |m| {
            if (std.mem.eql(u8, m.path, path)) {
                is_known = true;

                const new_hash = try utils.hash_file_hex(allocator, path);
                defer allocator.free(new_hash);
                if (!std.mem.eql(u8, new_hash, m.hash)) {
                    try result.modified.append(allocator, path);
                }
                break;
            }
        }

        if (!is_known) {
            try result.added.append(allocator, path);
        }
    }

    // check for removed
    for (manifest.files) |m| {
        var still_exists = false;

        for (current_files) |path| {
            if (std.mem.eql(u8, path, m.path)) {
                still_exists = true;
                break;
            }
        }

        if (!still_exists) {
            try result.removed.append(allocator, m.path);
        }
    }

    return result;
}

pub fn hashLookup(path: []const u8) []const u8 {
    _ = path;
    // dummy implementation
    return "dummy_hash";
}
