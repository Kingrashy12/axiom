const std = @import("std");
const ziglet = @import("ziglet");
const utils = @import("utils");
const object = @import("object");
const ActionArg = ziglet.ActionArg;

pub fn add(params: ActionArg) !void {
    if (params.args.len == 0) {
        ziglet.utils.terminal.printColored(.red, "usage: axiom add [path]\n", .{});
        return;
    }
    const path = params.args[0];
    const allocator = params.allocator;
    // read file into buffer and write blob
    const fs = std.fs.cwd();
    const file = try fs.openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const size: usize = @intCast(stat.size);
    const buf = try allocator.alloc(u8, size);
    defer allocator.free(buf);
    _ = try file.readAll(buf);

    const oid = try object.write_object("blob", buf, allocator);
    const hex = utils.hexEncode(oid[0..], allocator);
    std.debug.print("Wrote blob {s}\n", .{hex});
    // update index.json -- simple append approach for demo
    // (production: lock and rewrite index atomically)
    const idxFile = try fs.openFile(utils.INDEX_FILE, .{});
    defer idxFile.close();
    var idxBuf: [4096]u8 = undefined;
    _ = try idxFile.readAll(&idxBuf);
    // For brevity, not performing JSON parse here. Real impl must parse and safely update.
    std.debug.print("Note: update index.json with path={s} oid={s}\n", .{ path, hex });
}
