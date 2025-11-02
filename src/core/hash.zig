const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn fromHex(c: u8) ?u8 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'a' and c <= 'f') return c - 'a' + 10;
    if (c >= 'A' and c <= 'F') return c - 'A' + 10;
    return null;
}

pub fn hex_encode_alloc(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const hex_len = bytes.len * 2;
    const out = try allocator.alloc(u8, hex_len);
    var idx: usize = 0;
    for (bytes) |b| {
        const hi: u8 = (b >> 4) & 0xF;
        const lo: u8 = b & 0xF;
        out[idx] = if (hi < 10) '0' + hi else 'a' + (hi - 10);
        idx += 1;
        out[idx] = if (lo < 10) '0' + lo else 'a' + (lo - 10);
        idx += 1;
    }
    return out;
}

pub fn hash_file_hex(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var cwd = std.fs.cwd();

    // open the file; path is a slice representing relative path like "src/main.zig"
    var f = try cwd.openFile(path, .{});
    defer f.close();

    var hasher = std.crypto.hash.composition.Sha256oSha256.init(.{});
    var buf: [8192]u8 = undefined;

    while (true) {
        const n = try f.read(buf[0..]);
        if (n == 0) break;
        hasher.update(buf[0..n]);
    }

    var digest: [32]u8 = undefined;
    hasher.final(&digest);

    const hex = try hex_encode_alloc(allocator, digest[0..]);
    return hex;
}

pub fn hash_hex_short(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var hasher = std.crypto.hash.Blake3.init(.{});
    hasher.update(data);

    var digest: [5]u8 = undefined;
    hasher.final(&digest);

    return try hex_encode_alloc(allocator, digest[0..]);
}
