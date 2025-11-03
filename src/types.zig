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

pub const LogEntry = struct {
    hash: []const u8,
    timestamp: i64,
    message: []const u8,
    files_count: usize,
};
