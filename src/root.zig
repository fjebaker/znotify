const std = @import("std");

/// inofity mask / events
pub const Mask = packed struct(u32) {
    const event_mask = 0b1111_1111_1111;

    /// File was accessed
    access: bool = false,
    /// File was modified
    modify: bool = false,
    /// Metadata changed
    attrib: bool = false,
    /// Writtable file closed
    close_write: bool = false,
    /// Unwrittable file closed
    close_nowrite: bool = false,
    /// File was opened
    open: bool = false,
    /// File was moved from X
    moved_from: bool = false,
    /// File was moved to Y
    moved_to: bool = false,
    /// Subfile was created
    create: bool = false,
    /// Subfile was deleted
    delete: bool = false,
    /// Self was deleted
    delete_self: bool = false,
    /// Self was moved
    move_self: bool = false,

    // padding
    _: u20 = 0,

    /// Cast an integer to the Mask
    pub fn fromInt(i: u32) Mask {
        const m: Mask = @bitCast(i);
        std.debug.assert(m._ == 0);
        return m;
    }

    fn toEvent(m: Mask) Event {
        std.debug.assert(m._ == 0);
        return @enumFromInt(@as(u32, @bitCast(m)));
    }
};

/// All of the events from the `Mask` represented as an Enum
pub const Event = b: {
    const EnumField = std.builtin.Type.EnumField;

    const fields = @typeInfo(Mask).Struct.fields;
    var enum_fields: []const EnumField = &.{};
    var x: u32 = 1;
    for (fields) |f| {
        const new = EnumField{
            .name = f.name,
            .value = x,
        };
        x = x << 1;
        enum_fields = enum_fields ++ [_]EnumField{new};
    }
    const typedef = std.builtin.Type.Enum{
        .fields = enum_fields,
        .decls = &.{},
        .is_exhaustive = false,
        .tag_type = u32,
    };
    break :b @Type(.{ .Enum = typedef });
};

/// An inotify event
pub const NotifyEvent = struct {
    /// The event type
    event: Event,
    /// The path the event occured at
    path: []const u8,
    /// Is the path a directory
    dir: bool,
};

/// inotify manager for creating and polling inotify file descriptors
pub const INotify = struct {
    const inotify_event_t = extern struct {
        wd: c_int,
        mask: c_uint,
        cookie: c_uint,
        len: c_uint,
    };

    const Monitors = std.ArrayList(std.posix.fd_t);

    ifd: std.fs.File,
    monitors: Monitors,
    name_buffer: [std.fs.MAX_NAME_BYTES]u8 = undefined,

    fn getHandle(self: *const INotify) std.posix.fd_t {
        return self.ifd.handle;
    }

    /// Initialise the INotify manager
    pub fn init(allocator: std.mem.Allocator) !INotify {
        const fd = try std.posix.inotify_init1(0);
        return .{
            .ifd = .{ .handle = fd },
            .monitors = Monitors.init(allocator),
        };
    }

    /// Deinitialise the INotify manager. Calls `inotify_rm_watch` on all
    /// watches and closes the inotify fd
    pub fn deinit(self: *INotify) void {
        for (self.monitors.items) |w| {
            std.posix.inotify_rm_watch(self.getHandle(), w);
        }
        self.monitors.deinit();
        self.ifd.close();
    }

    /// Add a watcher for a specific path, triggering at the events given in
    /// `Mask`
    pub fn watchPath(self: *INotify, path: []const u8, mask: Mask) !void {
        const old_size = self.monitors.items.len;

        const ptr = try self.monitors.addOne();
        errdefer self.monitors.shrinkRetainingCapacity(old_size);

        ptr.* = try std.posix.inotify_add_watch(
            self.getHandle(),
            path,
            @bitCast(mask),
        );
    }

    /// Poll for events. Will return `null` if no events have occured since the
    /// last poll.
    pub fn poll(self: *INotify) !?NotifyEvent {
        var buf: [@sizeOf(inotify_event_t) + std.fs.MAX_NAME_BYTES + 1]u8 = undefined;
        const size = try std.posix.read(self.getHandle(), &buf);

        if (size == 0) return null;

        const event = std.mem.bytesToValue(
            inotify_event_t,
            buf[0..@sizeOf(inotify_event_t)],
        );

        const name_end = std.mem.indexOfScalarPos(
            u8,
            &buf,
            @sizeOf(inotify_event_t),
            0,
        ).?;
        const name_len = name_end - @sizeOf(inotify_event_t);

        const is_dir_event = event.mask & (1 << 30);

        std.mem.copyForwards(
            u8,
            &self.name_buffer,
            buf[@sizeOf(inotify_event_t)..name_end],
        );

        return .{
            .path = self.name_buffer[0..name_len],
            .event = Mask.fromInt(event.mask & Mask.event_mask).toEvent(),
            .dir = is_dir_event != 0,
        };
    }
};
