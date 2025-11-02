const std = @import("std");
const Allocator = std.mem.Allocator;
const ziglet = @import("ziglet");
const printColored = ziglet.utils.terminal.printColored;

pub const CONFIG_VERSION = [_]u8{ 0x01, 0x00 };
pub const NAME_MAX = 10;
pub const EMAIL_MAX = 50;
pub const CONFIG_SIZE = CONFIG_VERSION.len + NAME_MAX + EMAIL_MAX;

pub const Config = struct {
    version: [2]u8 = CONFIG_VERSION,
    name: [NAME_MAX]u8 = .{0} ** NAME_MAX,
    email: [EMAIL_MAX]u8 = .{0} ** EMAIL_MAX,
};

pub fn pathExists(dir: *std.fs.Dir, path: []const u8) bool {
    dir.access(path, .{}) catch return false;
    return true;
}

pub fn repoExists(dir: *std.fs.Dir) bool {
    return pathExists(dir, ".axiom");
}

pub fn initRepo() !void {
    var dir = std.fs.cwd();
    if (repoExists(&dir)) {
        printColored(.yellow, "Axiom repository already exists!\n", .{});
        return;
    }

    try dir.makeDir(".axiom");
    var repo_dir = try dir.openDir(".axiom", .{});
    defer repo_dir.close();

    try repo_dir.makeDir("objects");
    try repo_dir.makeDir("snapshots");
    var info_file = try repo_dir.createFile("INFO", .{});

    const info_data =
        \\TOTAL_SNAPSHOTS = 0
        \\CURRENT_SNAPSHOT_HASH = EMPTY
        \\SNAPSHOTS_ORDER = EMPTY
        \\CURRENT_TIMELINE = main
    ;

    try info_file.writeAll(info_data);

    try writeConfig(null, null);

    printColored(.green, "Initialized empty Axiom repository in ./.axiom\n", .{});
}

pub fn writeConfig(m_name: ?[]const u8, m_email: ?[]const u8) !void {
    var dir = std.fs.cwd();

    var config = readConfig(&dir) catch Config{};

    if (m_name) |name| {
        if (name.len > NAME_MAX) return error.NameTooLong;
        @memset(&config.name, 0);
        std.mem.copyForwards(u8, config.name[0..name.len], name);
    }

    if (m_email) |email| {
        if (email.len > EMAIL_MAX) return error.EmailTooLong;
        @memset(&config.email, 0);
        std.mem.copyForwards(u8, config.email[0..email.len], email);
    }

    var file = try dir.createFile(".axiom/config.bin", .{ .truncate = true });
    defer file.close();

    try file.writeAll(std.mem.asBytes(&config));
}

pub fn readConfig(dir: *std.fs.Dir) !Config {
    var file = try dir.openFile(".axiom/config.bin", .{});
    defer file.close();

    var config: Config = .{};
    const read = try file.read(std.mem.asBytes(&config));

    if (read < CONFIG_SIZE) {
        // File malformed: zero-pad remaining
        @memset(std.mem.asBytes(&config)[read..], 0);
    }
    return config;
}

pub fn printConfig(dir: *std.fs.Dir) !void {
    const config = try readConfig(dir);

    printColored(.white, "name: {s}\n", .{trimField(&config.name) orelse "[unset]"});
    printColored(.white, "email: {s}\n", .{trimField(&config.email) orelse "[unset]"});
}

fn trimField(field: []const u8) ?[]const u8 {
    var end = field.len;
    while (end > 0 and field[end - 1] == 0) end -= 1;
    if (end == 0) return null;
    return field[0..end];
}

pub fn deleteRepo(allocator: Allocator) !void {
    var dir = std.fs.cwd();

    if (!repoExists(&dir)) {
        printColored(.yellow, "No Axiom repository found to delete!\n", .{});
        return;
    }

    const message = try std.fmt.allocPrint(allocator, "Are you sure you want to delete the Axiom repository?\n This action cannot be undone", .{});
    defer allocator.free(message);

    const should_delete = ziglet.utils.terminal.confirm(allocator, message) catch |err| {
        printColored(.red, "Error during confirmation: {s}\n", .{@errorName(err)});
        return;
    };

    if (!should_delete) {
        printColored(.yellow, "Aborted repository deletion.\n", .{});
        return;
    }

    dir.deleteTree(".axiom") catch |err| {
        printColored(.red, "Failed to delete Axiom repository: {s}\n", .{@errorName(err)});
        return;
    };
    printColored(.green, "\nAxiom repository deleted successfully.\n", .{});
}

const Info = struct {
    TOTAL_SNAPSHOTS: usize,
    SNAPSHOTS_ORDER: [][]const u8,
    CURRENT_SNAPSHOT_HASH: []const u8,
    CURRENT_TIMELINE: []const u8,
};

pub fn readInfo(allocator: Allocator, dupe_hash: bool) !*Info {
    var dir = std.fs.cwd();
    var info_file = dir.openFile(".axiom/INFO", .{}) catch |err| {
        printColored(.red, "Error reading file: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
    defer info_file.close();

    const size = try info_file.getEndPos();

    const buffer = try allocator.alloc(u8, size);
    defer allocator.free(buffer);

    _ = try info_file.readAll(buffer);

    var iter = std.mem.splitScalar(u8, buffer, '\n');

    const info = try allocator.create(Info);

    while (iter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

        if (std.mem.indexOf(u8, trimmed, "=") == null) {
            printColored(.red, "Error: Invalid INFO file.", .{});
            std.process.exit(1);
        }

        var parts = std.mem.tokenizeAny(u8, trimmed, " = ");

        const name = parts.next().?;
        const value = parts.next().?;

        if (std.mem.eql(u8, name, "TOTAL_SNAPSHOTS")) {
            info.TOTAL_SNAPSHOTS = std.fmt.parseInt(usize, value, 10) catch 0;
        }

        if (std.mem.eql(u8, name, "CURRENT_SNAPSHOT_HASH")) {
            info.CURRENT_SNAPSHOT_HASH = if (dupe_hash) try allocator.dupe(u8, value) else value;
        }

        if (std.mem.eql(u8, name, "SNAPSHOTS_ORDER")) {
            info.SNAPSHOTS_ORDER = &.{}; // parse 0x98ud0, 10927cd0, 0cd345h0 into {0x98ud0, 10927cd0, 0cd345h0}
        }

        if (std.mem.eql(u8, name, "CURRENT_TIMELINE")) {
            info.CURRENT_TIMELINE = try allocator.dupe(u8, value);
        }
    }

    return info;
}

pub fn ensureRepo() void {
    var dir = std.fs.cwd();

    if (!pathExists(&dir, ".axiom")) {
        printColored(.cyan, "No Axiom repository found. Please run 'axiom init' to create a new repository.", .{});
    }
}

pub fn updateInfo(allocator: Allocator, new_info: Info) !void {
    var repo_dir = try std.fs.cwd().openDir(".axiom", .{});
    defer repo_dir.close();

    var info_file = repo_dir.openFile("INFO", .{ .mode = .read_write }) catch |err| {
        printColored(.red, "Error reading file: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
    defer info_file.close();

    const info_data = try std.fmt.allocPrint(allocator,
        \\TOTAL_SNAPSHOTS = {d}
        \\CURRENT_SNAPSHOT_HASH = {s}
        \\SNAPSHOTS_ORDER = EMPTY
        \\CURRENT_TIMELINE = {s}
    , .{ new_info.TOTAL_SNAPSHOTS, new_info.CURRENT_SNAPSHOT_HASH, new_info.CURRENT_TIMELINE });
    defer allocator.free(info_data);

    try info_file.writeAll(info_data);
}
