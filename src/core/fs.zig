const std = @import("std");
const ziglet = @import("ziglet");
const Allocator = std.mem.Allocator;

pub fn readIgnoreFile(
    allocator: std.mem.Allocator,
) ![][]const u8 {
    var file = std.fs.cwd().openFile(".axiomignore", .{}) catch {
        const default_list = try allocator.alloc([]const u8, 1);
        default_list[0] = try allocator.dupe(u8, ".axiom");
        // No ignore file; return default list
        return default_list;
    };
    defer file.close();

    const size = try file.getEndPos();
    const buf = try allocator.alloc(u8, size);
    defer allocator.free(buf);

    _ = try file.readAll(buf);

    var list: std.ArrayList([]const u8) = .empty;

    try list.append(allocator, try allocator.dupe(u8, ".axiom"));

    var iter = std.mem.splitScalar(u8, buf, '\n');
    while (iter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 0) {
            const duped = try allocator.dupe(u8, trimmed);
            try list.append(allocator, duped);
        }
    }

    return list.toOwnedSlice(allocator);
}

pub fn replaceBackslashWithForwardSlash(allocator: Allocator, input: [][]const u8) ![][]const u8 {
    var output: std.ArrayList([]const u8) = .empty;

    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        const segment = input[i];

        std.mem.replaceScalar(u8, @constCast(segment), '\\', '/');

        try output.append(allocator, segment);
    }

    return try output.toOwnedSlice(allocator);
}

pub fn shouldIgnore(path: []const u8, patterns: [][]const u8) bool {
    for (patterns) |p| {
        // Exact file match
        if (std.mem.eql(u8, path, p)) return true;

        // Prefix directory ignore
        if (std.mem.startsWith(u8, path, p)) return true;

        // Simple wildcard suffix matching
        if (std.mem.startsWith(u8, p, "*")) {
            const suffix = p[1..];
            if (std.mem.endsWith(u8, path, suffix)) return true;
        }
    }
    return false;
}

pub fn walkFiles(
    allocator: Allocator,
    dir: *std.fs.Dir,
    base_path: []const u8,
    files: *std.ArrayList([]const u8),
    ignore_paths: [][]const u8,
) !void {
    var it = dir.iterate();

    while (try it.next()) |entry| {
        const name = entry.name;

        const full_path = try std.fs.path.join(allocator, &.{ base_path, name });

        // Check ignore
        if (shouldIgnore(full_path, ignore_paths)) {
            allocator.free(full_path); // Free ignored memory
            continue;
        }

        switch (entry.kind) {
            .file => {
                try files.append(allocator, full_path);
                // Caller frees later
            },
            .directory => {
                var sub_dir = dir.openDir(name, .{ .iterate = true }) catch {
                    allocator.free(full_path);
                    continue;
                };
                defer sub_dir.close();

                // Recurse
                walkFiles(allocator, &sub_dir, full_path, files, ignore_paths) catch {
                    allocator.free(full_path);
                    return;
                };

                allocator.free(full_path); // Always free after recursion
            },
            else => {
                allocator.free(full_path); // Avoid forgetting weird entries
            },
        }
    }
}

pub fn collectFiles(allocator: Allocator) ![][]const u8 {
    var files: std.ArrayList([]const u8) = .empty;
    defer files.deinit(allocator);

    var dir = try std.fs.cwd().openDir("", .{ .iterate = true });
    defer dir.close();

    const ignore_paths = try readIgnoreFile(allocator);
    defer {
        for (ignore_paths) |value| {
            allocator.free(value);
        }
        allocator.free(ignore_paths);
    }

    try walkFiles(allocator, &dir, "", &files, ignore_paths);

    const output_files = try replaceBackslashWithForwardSlash(allocator, files.items);
    return output_files;
}

pub fn pathExists(dir: *std.fs.Dir, path: []const u8) bool {
    dir.access(path, .{}) catch return false;
    return true;
}

pub fn ensureRepo() void {
    var dir = std.fs.cwd();

    if (!pathExists(&dir, ".axiom")) {
        ziglet.utils.terminal.printColored(.blue, "No Axiom repository found. Please run 'axiom init' to create a new repository.", .{});
    }
}
