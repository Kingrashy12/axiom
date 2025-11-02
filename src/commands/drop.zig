const std = @import("std");
const ziglet = @import("ziglet");
const fs = @import("../core//fs.zig");
const terminal = ziglet.utils.terminal;
const ActionArg = ziglet.ActionArg;
const printColored = terminal.printColored;

const repo = @import("../repo.zig");

pub fn drop(params: ActionArg) !void {
    const allocator = params.allocator;

    var dir = std.fs.cwd();

    if (!fs.pathExists(&dir, ".axiom")) {
        printColored(.yellow, "No Axiom repository found to delete!\n", .{});
        return;
    }

    const message = try std.fmt.allocPrint(allocator, "Are you sure you want to delete the Axiom repository?\n This action cannot be undone", .{});
    defer allocator.free(message);

    const should_delete = terminal.confirm(allocator, message) catch |err| {
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
