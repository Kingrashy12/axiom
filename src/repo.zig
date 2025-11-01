const std = @import("std");
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
        \\ TOTAL_SNAP = 0
        \\ CURRENT_SNAP_HASH = 0
        \\ CURRENT_TIMELINE = main
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

pub fn deleteRepo(allocator: std.mem.Allocator) !void {
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
