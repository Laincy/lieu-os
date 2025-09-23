const std = @import("std");
const Writer = std.io.Writer;
const comptimePrint = std.fmt.comptimePrint;

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    errdefer @panic("Couldn't log kernel message");

    const prefix = comptimePrint("\x1b[{d}m[{s}] \x1b[0;90m({s})\x1b[0m ", .{
        switch (level) {
            .info => 34,
            .warn => 33,
            .err => 31,
            .debug => 35,
        },
        @tagName(level),
        @tagName(scope),
    });

    try log_writer.print(prefix ++ format ++ "\n", args);
}

pub var log_writer: Writer = .{
    .vtable = &.{
        .drain = drain,
        .flush = flush,
    },
    .end = 0,
    .buffer = "",
};

fn drain(io_w: *Writer, data: []const []const u8, splat: usize) error{}!usize {
    std.debug.assert(data.len > 0);

    const buffered = io_w.buffered();

    if (buffered.len != 0) {
        write(buffered);
    }

    _ = io_w.consumeAll();

    var bytes: usize = 0;

    for (data[0 .. data.len - 1]) |buf| {
        if (buf.len == 0) continue;
        write(buf);
        bytes += buf.len;
    }

    const pattern = data[data.len - 1];
    std.mem.doNotOptimizeAway(switch (splat) {
        0 => {},
        1 => {
            write(pattern);
            bytes += pattern.len;
        },
        else => {
            for (0..splat) |_| {
                write(pattern);
                bytes += pattern.len;
            }
        },
    });
    return bytes;
}

fn write(bytes: []const u8) void {
    // // This should be better, but the compiler doesn't like it in release=safe :(
    // asm volatile (
    //     \\cld
    //     \\rep outsb
    //     :
    //     : [string_data] "{esi}" (bytes.ptr),
    //       [string_len] "{ecx}" (bytes.len),
    //       [port] "{dx}" (0xe9),
    //     : .{ .eflags = true });

    for (bytes) |b| asm volatile ("outb %[byte], $0xe9"
        :
        : [byte] "{al}" (b),
    );
}

fn flush(w: *std.io.Writer) error{WriteFailed}!void {
    const drainFn = w.vtable.drain;
    while (w.end != 0) _ = try drainFn(w, &.{""}, 1);

    std.debug.assert(w.end == 0);
}
