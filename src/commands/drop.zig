const std = @import("std");
const ziglet = @import("ziglet");
const utils = @import("utils");
const ActionArg = ziglet.ActionArg;

const repo = @import("../repo.zig");

pub fn drop(params: ActionArg) !void {
    try repo.deleteRepo(params.allocator);
}
