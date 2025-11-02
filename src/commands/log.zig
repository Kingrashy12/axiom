const std = @import("std");
const ziglet = @import("ziglet");
const utils = @import("utils");
const ActionArg = ziglet.ActionArg;
const repo_mod = @import("../repo.zig");

pub fn log(param: ActionArg) !void {
    _ = param;

    repo_mod.ensureRepo();
}
