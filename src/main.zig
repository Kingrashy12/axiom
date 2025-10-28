const std = @import("std");
const ziglet = @import("ziglet");
const CLIBuilder = ziglet.CLIBuilder;
const commands = @import("commands/root.zig");

pub fn main() !void {
    ziglet.utils.terminal.setWinConsole();

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var cli = CLIBuilder.init(allocator, "axiom", "0.1.0", "Axiom — A simple version control system");
    defer cli.deinit();

    cli.setGlobalOptions();

    // ============= Init Command =============
    _ = cli.command("init", "Creates a new repo in the working directory with internal storage.").action(commands.initCommand).finalize();

    // ============= Config Command =============
    const config_cmd = cli.command("config", "Manage Axiom configuration.").option(.{
        .name = "name",
        .alias = "n",
        .description = "Set the user name.",
        .type = .string,
    }).option(.{
        .name = "email",
        .alias = "e",
        .description = "Set the user email.",
        .type = .string,
    }).action(commands.config).finalize();

    // ============= Snapshot Command =============
    const snap_cmd = cli.command("snap", "Take a snapshot of the current state of the working directory.").option(.{
        .name = "message",
        .alias = "m",
        .description = "Snapshot message.",
        .type = .string,
    }).action(commands.snap).finalize();

    // ============= Restore Command =============
    _ = cli.command("restore", "Restore files to the state of a previous snapshot.").action(commands.restore).finalize();

    // ============= Log Command =============
    _ = cli.command("log", "See snapshot history newest first.").action(commands.log).finalize();

    // ============= Status Command =============
    _ = cli.command("status", "See if working copy changed since last snapshot.").action(commands.status).finalize();

    // ============= Drop Command =============
    _ = cli.command("drop", "Delete the repository.").action(commands.drop).finalize();

    try cli.parse(args, &.{ config_cmd, snap_cmd });
}
