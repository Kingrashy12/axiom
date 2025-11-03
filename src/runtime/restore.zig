const std = @import("std");
const Allocator = std.mem.Allocator;
const ziglet = @import("ziglet");
const fs = @import("../core/fs.zig");
const ActionArg = ziglet.ActionArg;
const repo_mod = @import("../repo.zig");
const manifest_mod = @import("../core/manifest.zig");
const CLIUtils = ziglet.CLIUtils;
const takeBool = CLIUtils.takeBool;
const printColored = ziglet.utils.terminal.printColored;

pub fn restoreSnapshot(
    allocator: Allocator,
    hash_to_use: []const u8,
    obj_dir: *std.fs.Dir,
    clean_opt: ?ziglet.BuilderTypes.Value,
    dry_run: ?ziglet.BuilderTypes.Value,
) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var manifest_map = std.StringHashMap([]const u8).init(allocator);
    defer manifest_map.deinit();

    // Load manifest data (owner: allocator)
    const manifest_data = try manifest_mod.loadSnapshotManifest(arena.allocator(), allocator, hash_to_use);
    defer allocator.destroy(manifest_data);
    defer manifest_data.deinit(allocator);

    // Build hash->path map for quick lookup
    for (manifest_data.files) |value| {
        try manifest_map.put(value.hash, value.path);
    }

    // If clean option is set, remove files not present in the manifest (by path).
    if (clean_opt != null and takeBool(clean_opt.?) == true) {
        // Build a path set from the manifest to check against
        var manifest_path_set = std.StringHashMap(void).init(allocator);
        defer manifest_path_set.deinit();
        for (manifest_data.files) |v| {
            try manifest_path_set.put(v.path, {});
        }

        const current_files = try fs.collectFiles(allocator);
        defer allocator.free(current_files);

        for (current_files) |file| {
            // If file not in manifest, delete
            if (!manifest_path_set.contains(file)) {
                if (dry_run != null and takeBool(dry_run.?) == true) {
                    printColored(.cyan, "[Dry Run] Would delete: {s}\n", .{file});
                } else {
                    std.fs.cwd().deleteFile(file) catch |err| {
                        printColored(.yellow, "Skipping delete {s}: {s}\n", .{ file, @errorName(err) });
                    };
                }
            }
            allocator.free(file);
        }
    }

    // Prepare temporary restore directory
    const tmp_root = ".axiom/tmp_restore";
    // ensure .axiom/tmp_restore exists
    std.fs.cwd().makeDir(tmp_root) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    const tmp_snap_dir = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ tmp_root, hash_to_use });
    defer allocator.free(tmp_snap_dir);

    // If not dry-run, recreate the snapshot-specific tmp directory (clean existing)
    if (dry_run == null) {
        // remove existing tmp dir for this snapshot if present, then create fresh
        _ = std.fs.cwd().deleteDir(tmp_snap_dir) catch {};
        std.fs.cwd().makeDir(tmp_snap_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
    }

    // Walk objects dir (blobs) and write matching manifest files into tmp dir
    var obj_iterator = try obj_dir.walk(allocator);
    defer obj_iterator.deinit();

    var restored_count: usize = 0;

    while (try obj_iterator.next()) |entry| {
        // entry.path here is the hash folder or file path relative to obj_dir; manifest_map keys are file hashes
        if (manifest_map.get(entry.path)) |file_path| {
            // open object file (the blob)
            var obj_file = try obj_dir.openFile(entry.path, .{});
            defer obj_file.close();

            const obj_size = try obj_file.getEndPos();
            const buffer = try allocator.alloc(u8, obj_size);
            defer allocator.free(buffer);
            _ = try obj_file.read(buffer);

            // Prepare destination path in tmp dir (preserve directories)
            const tmp_dst_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ tmp_snap_dir, file_path });
            defer allocator.free(tmp_dst_path);

            if (dry_run != null and takeBool(dry_run.?) == true) {
                printColored(.cyan, "[Dry Run] Would restore {s} -> {s}\n", .{ file_path, tmp_dst_path });
                restored_count += 1;
                continue;
            }

            // Ensure parent directories exist under tmp_snap_dir
            const parent = std.fs.path.dirname(tmp_dst_path);

            if (parent) |dir| {
                std.fs.cwd().makePath(dir) catch |err| {
                    switch (err) {
                        error.PathAlreadyExists => continue,
                        else => {
                            printColored(.yellow, "Warning: failed to make parent {s}: {s}\n", .{ dir, @errorName(err) });
                        },
                    }
                };
            }

            // Write object content to tmp path (truncate/create)
            var tmp_file = std.fs.cwd().createFile(tmp_dst_path, .{}) catch |err| {
                printColored(.red, "Failed to write file: {s}\n", .{@errorName(err)});
                continue;
            };
            defer tmp_file.close();

            _ = tmp_file.write(buffer) catch |err| {
                printColored(.red, "Failed to write {s}: {s}\n", .{ tmp_dst_path, @errorName(err) });
                continue;
            };

            restored_count += 1;
            printColored(.green, "Prepared: {s}\n", .{file_path});
        }
    }

    // If dry-run, we are done (report)
    if (dry_run != null and takeBool(dry_run.?)) {
        printColored(.white, "\n[Dry Run] Restore simulation complete. {d} files would be restored from snapshot {s}\n", .{ restored_count, hash_to_use });
        return;
    }

    // Move files from tmp_snap_dir into working dir atomically (rename per file)
    // Walk tmp_snap_dir and move each file to its destination
    var tmp_dir = try std.fs.cwd().openDir(tmp_snap_dir, .{ .iterate = true });
    defer tmp_dir.close();

    var walker = try tmp_dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        const rel_path = entry.path; // relative to tmp_snap_dir
        const tmp_full = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ tmp_snap_dir, rel_path });
        defer allocator.free(tmp_full);

        const dst_full = try std.fmt.allocPrint(allocator, "{s}", .{rel_path}); // relative to cwd
        defer allocator.free(dst_full);

        // Ensure parent dir exists in cwd
        const parent = std.fs.path.dirname(dst_full);

        if (parent) |dir| {
            std.fs.cwd().makePath(dir) catch |err| {
                switch (err) {
                    error.PathAlreadyExists => continue,
                    else => {
                        printColored(.yellow, "Warning: failed to make parent {s}: {s}\n", .{ dir, @errorName(err) });
                    },
                }
            };
        }

        var src_file = try std.fs.cwd().openFile(tmp_full, .{});
        defer src_file.close();
        const sz = try src_file.getEndPos();
        const tmp_buf = try allocator.alloc(u8, sz);
        defer allocator.free(tmp_buf);
        _ = try src_file.readAll(tmp_buf);

        var dst_file = try std.fs.cwd().createFile(dst_full, .{ .truncate = true });
        defer dst_file.close();
        _ = try dst_file.writeAll(tmp_buf);

        // remove tmp file
        _ = std.fs.cwd().deleteFile(tmp_full) catch |err| {
            printColored(.yellow, "Warning: failed to remove tmp file {s}: {s}\n", .{ tmp_full, @errorName(err) });
        };
        // printColored(.green, "Restored: {s}\n", .{rel_path});
    }

    // Cleanup: remove tmp snapshot dir
    _ = std.fs.cwd().deleteTree(tmp_snap_dir) catch |err| {
        printColored(.yellow, "Warning: failed to remove tmp directory {s}: {s}\n", .{ tmp_snap_dir, @errorName(err) });
    };

    // Write a log entry for this restore under .axiom/log/
    const ts_ns = std.time.nanoTimestamp();
    const log = try std.fmt.allocPrint(allocator, "restore-{s}-{d}.log", .{ hash_to_use, ts_ns });
    defer allocator.free(log);

    const log_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ ".axiom/log", log });
    defer allocator.free(log_path);

    var log_file = try std.fs.cwd().createFile(log_path, .{ .truncate = true });
    defer log_file.close();

    const log_json = try std.fmt.allocPrint(allocator, "{{\"type\":\"restore\",\"hash\":\"{s}\",\"timestamp\":{d},\"files_count\":{d}}}", .{ hash_to_use, ts_ns, restored_count });
    defer allocator.free(log_json);

    _ = try log_file.writeAll(log_json);

    printColored(.white, "\nSummary:\n", .{});
    printColored(.green, "  Restored {d} files\n", .{restored_count});
    printColored(.blue, "  From snapshot: {s}\n", .{hash_to_use});
}
