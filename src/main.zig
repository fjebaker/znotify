const std = @import("std");
const znotify = @import("znotify");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var notifier = try znotify.INotify.init(allocator);
    defer notifier.deinit();

    try notifier.watchPath(
        "src",
        .{
            .create = true,
            .modify = true,
            .moved_to = true,
            .moved_from = true,
            .delete = true,
        },
    );

    while (try notifier.poll()) |e| {
        const path = try notifier.getPath(allocator, e);
        defer allocator.free(path);
        std.debug.print(
            "NotifyEvent: {s} ({s}) dir: {any}\n",
            .{ path, @tagName(e.event), e.dir },
        );
    }
}
