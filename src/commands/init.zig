const std = @import("std");
const ziglet = @import("ziglet");
const fs = @import("../core/fs.zig");
const ActionArg = ziglet.ActionArg;
const printColored = ziglet.utils.terminal.printColored;

const repo = @import("../repo.zig");

pub fn init(params: ActionArg) !void {
    _ = params;

    var dir = std.fs.cwd();

    if (fs.pathExists(&dir, ".axiom")) {
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
        \\PREVIOUS_SNAPSHOT_HASH = EMPTY
        \\SNAPSHOTS = EMPTY
        \\CURRENT_TIMELINE = @main
    ;

    try info_file.writeAll(info_data);

    printColored(.green, "Initialized empty Axiom repository in ./.axiom\n", .{});
}
