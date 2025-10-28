const std = @import("std");
const ziglet = @import("ziglet");
const utils = @import("utils");
const ActionArg = ziglet.ActionArg;

pub fn log(param: ActionArg) !void {
    _ = param;
}
