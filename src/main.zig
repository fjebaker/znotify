const std = @import("std");
const znotify = @import("znotify");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var not = try znotify.INotify.init(allocator);
    defer not.deinit();

    try not.watchPath(
        "src",
        .{
            .create = true,
            .modify = true,
            .moved_to = true,
            .moved_from = true,
            .delete = true,
        },
    );

    std.debug.print("Watching...\n", .{});
    while (try not.poll()) |e| {
        std.debug.print(
            "NotifyEvent: {s} ({s}) dir: {any}\n",
            .{ e.path, @tagName(e.event), e.dir },
        );
    }
}
