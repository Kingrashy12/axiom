const std = @import("std");
const ziglet = @import("ziglet");
const utils = @import("utils");
const ActionArg = ziglet.ActionArg;

const repo = @import("../repo.zig");

pub fn init(params: ActionArg) !void {
    _ = params;
    try repo.initRepo();
}
