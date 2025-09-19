comptime {
    asm (@embedFile("boot/boot.s"));
}

const std = @import("std");
const builtin = @import("builtin");
const gdt = @import("gdt.zig");

const MAGIC = 0xE85250D6;
const ARCHITECTURE = 0;
const HEADER_SIZE = @sizeOf(MultibootHeader);

const EndTag = packed struct {
    type: u16 = 0,
    flags: u16 = 0,
    size: u32 = 8,
};

const MultibootHeader = extern struct {
    magic: u32,
    architecture: u32,
    header_len: u32,
    checksum: i32,
    endtag: EndTag,
};

export const multiboot2 align(4) linksection(".multiboot.data") = MultibootHeader{
    .magic = MAGIC,
    .architecture = ARCHITECTURE,
    .header_len = HEADER_SIZE,
    .checksum = 0x100000000 - (MAGIC + ARCHITECTURE + HEADER_SIZE),
    .endtag = EndTag{},
};

export fn kmain(mbi: usize) callconv(.c) noreturn {
    std.log.info("System Initialized...", .{});
    std.log.debug("Multiboot Info Addr: 0x{X:0>8}", .{mbi});

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
