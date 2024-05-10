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
            .close_nowrite = true,
            .close_write = true,
        },
    );

    while (try notifier.poll()) |e| {
        std.debug.print(
            "NotifyEvent: {s} ({s}) dir: {any}\n",
            .{ e.path, @tagName(e.event), e.dir },
        );
    }
}
