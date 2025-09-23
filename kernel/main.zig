const std = @import("std");
const builtin = @import("builtin");

const gdt = @import("gdt.zig");

comptime {
    _ = @import("boot.zig");
}

/// When this is jumped to, we are in the upper half with a minimal page dir
export fn kmain(mbi_phys_addr: u32) noreturn {
    const log = std.log.scoped(.kmain);

    _ = mbi_phys_addr;

    log.info("Jumped to higher half, beginning initialization", .{});

    gdt.init();

    log.info("Kernel initialization finished, entering event loop...", .{});
    while (true) {}
}

// Configure a couple of kernel wide Zig options

pub const std_options: std.Options = .{
    .logFn = @import("debugcon.zig").logFn,
};

pub const panic = std.debug.FullPanic(lieuPanic);
fn lieuPanic(msg: []const u8, addr: ?usize) noreturn {
    const log = std.log.scoped(.panic);

    if (addr != null) {
        log.err("Kernel panicked @ 0x{X:0>8}\nReason: {s}", .{ addr.?, msg });
    } else {
        log.err("Kernel Panicked @ ??\nReason: {s}", .{msg});
    }

    while (true) {}
}
