comptime {
    _ = @import("boot/boot.zig");
}

const mb = @import("boot/multiboot.zig");
const std = @import("std");
const builtin = @import("builtin");
const gdt = @import("gdt.zig");

const MultiBootHeader = packed struct {
    magic: i32,
    flags: i32,
    checksum: i32,
    _padding: u32 = 0,
};

const ALIGN = 1 << 0;
const MEMINFO = 1 << 1;
const MAGIC = 0x1BADB002;
const FLAGS = ALIGN | MEMINFO;

export const multiboot_header align(4) linksection(".rodata.boot") = MultiBootHeader{
    .magic = MAGIC,
    .flags = FLAGS,
    .checksum = -(MAGIC + FLAGS),
};

export fn kmain(mbi: *mb.MultibootInfo) noreturn {
    std.log.info("System Initialized...", .{});
    std.log.debug("Multiboot Info Addr: 0x{X:0>8}", .{@intFromPtr(mbi)});

    gdt.init();

    std.log.info("Kernel shutting down...", .{});
    while (true) {}
}

pub const std_options: std.Options = .{
    .logFn = @import("log.zig").logFn,
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
};

pub const panic = std.debug.FullPanic(lieuPanic);

fn lieuPanic(msg: []const u8, addr: ?usize) noreturn {
    if (addr != null) {
        std.log.err("Kernel Panicked @ 0x{X:0>8}\nReason: {s}", .{ addr.?, msg });
    } else {
        std.log.err("Kernel Panicked @ ??\nReason: {s}", .{msg});
    }

    _ = @import("log.zig").log_writer.flush() catch {};

    while (true) {}
}
