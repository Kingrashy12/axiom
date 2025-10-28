const std = @import("std");
const Allocator = std.mem.Allocator;

// ---------- Config ----------
pub const REPO_DIR = ".axiom";
pub const OBJECTS_DIR = ".axiom/objects";
pub const REFS_HEADS_DIR = ".axiom/refs/heads";
pub const HEAD_FILE = ".axiom/HEAD";
pub const INDEX_FILE = ".axiom/index.json";

pub fn ensureDir(path: []const u8) !void {
    var fs = std.fs.cwd();

    // if (fs.existsPath(path) catch false) return;

    var dir = fs.openDir(path, .{}) catch |err| {
        switch (err) {
            error.FileNotFound => {
                try fs.makePath(path);
                return;
            },
            else => return err,
        }
    };
    defer dir.close();
    // try fs.createDirectoryPath(path, 0o755);
}

pub fn hexEncode(bytes: []const u8, allocator: Allocator) []u8 {
    var b = allocator.alloc(u8, bytes.len * 2) catch unreachable;
    var idx: usize = 0;
    for (bytes) |x| {
        const hi = ((x >> 4) & 0xF);
        const lo = (x & 0xF);
        b[idx] = toHex(hi);
        idx += 1;
        b[idx] = toHex(lo);
        idx += 1;
    }
    return b;
}

pub fn toHex(n: u8) u8 {
    if (n < 10) return '0' + n;
    return 'a' + (n - 10);
}

pub fn hexToString(allocator: Allocator, bytes: []const u8) ![]u8 {
    // convenience if you want an allocated hex string
    return hexEncode(bytes, allocator);
}

// ---------- SHA256 helper ----------
pub fn sha256_of_stream(reader: anytype) ![32]u8 {
    var hasher = std.crypto.hash.composition.Sha256oSha256.init(.{});
    var buf: [4096]u8 = undefined;
    while (true) {
        const read = try reader.read(buf[0..]);
        if (read == 0) break;
        hasher.update(buf[0..read]);
    }
    var out: [32]u8 = undefined;
    hasher.final(&out);
    return out;
}

// For header + data hashing we will use functions that accept slices
pub fn sha256_of_bytes(data: []const u8) [32]u8 {
    var hasher = std.crypto.hash.composition.Sha256oSha256.init(.{});
    hasher.update(data);
    var out: [32]u8 = undefined;
    hasher.final(&out);
    return out;
}

// ---------- hex decode helper ----------
pub fn hexDecodeToBytes(hex: []const u8, out: *[32]u8) !void {
    if (hex.len != 64) return error.InvalidHex;
    var i: usize = 0;
    var j: usize = 0;
    while (i < hex.len) : (i += 2) {
        const hi = fromHex(hex[i]) orelse return error.InvalidHex;
        const lo = fromHex(hex[i + 1]) orelse return error.InvalidHex;
        out[j] = @as(u8, (hi << 4) | lo);
        j += 1;
    }
}

pub fn fromHex(c: u8) ?u8 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'a' and c <= 'f') return c - 'a' + 10;
    if (c >= 'A' and c <= 'F') return c - 'A' + 10;
    return null;
}

pub fn pathExists(dir: *std.fs.Dir, path: []const u8) bool {
    dir.access(path, .{}) catch return false;
    return true;
}
