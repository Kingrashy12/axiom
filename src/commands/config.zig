const std = @import("std");
const ziglet = @import("ziglet");
const cli_utils = ziglet.CLIUtils;
const utils = @import("utils");
const ActionArg = ziglet.ActionArg;
const repo = @import("../repo.zig");

pub fn config(param: ActionArg) !void {
    var cwd = std.fs.cwd();

    var set_name: ?[]const u8 = null;
    var set_email: ?[]const u8 = null;

    const options = param.options;

    if (options.get("name")) |name_val| {
        set_name = cli_utils.takeString(name_val);
    }

    if (options.get("email")) |email_val| {
        set_email = cli_utils.takeString(email_val);
    }

    if (set_name == null and set_email == null) {
        return repo.printConfig(&cwd);
    }

    repo.writeConfig(set_name, set_email) catch |err| {
        ziglet.utils.terminal.printColored(.red, "{s}\n", .{@errorName(err)});
    };
    ziglet.utils.terminal.printColored(.green, "Config updated:\n", .{});
    try repo.printConfig(&cwd);
}
