pub const SnapshotFile = struct {
    path: []const u8,
    hash: []const u8,
};

pub const Snapshot = struct {
    timestamp: i64,
    files: []SnapshotFile,
};

pub const FileEntry = struct {
    path: []const u8,
    hash: []const u8,
};
