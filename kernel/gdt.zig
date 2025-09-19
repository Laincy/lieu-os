//! Primatives and functions for managing the global descriptor table (GDT)

const std = @import("std");
const log = std.log.scoped(.gdt);

/// The access byte field of a GDT table.
const AccessByte = packed struct(u8) {
    /// Has this segment been accessed? Set by the CPU, don't set menually.
    accessed: bool = false,

    /// For code segments: Readable bit. If clear, read access is not allowed.
    /// If set ,access is allowed. Write access is never allowed.
    ///
    /// For data segments: Writable bit. If clear, write access is not allowed.
    /// If set write access is allowed. Read access is always set.
    read_write: bool,

    /// The direction/conforming bit.
    /// For data selectors: Direction bit. If clear segment grows up, if set
    /// the segment grows down.
    ///
    /// For code selectors: Conforming bit. If clear code in this segment can
    /// only be executed from the ring set in DPL. If set code in this segment
    /// can be executed from an equal or lower privilege level. For example
    /// code in ring 3 can far jump to a conforming ring 2 segment.
    dc: bool,

    /// If clear this is a data segment, if set this is a code segment.
    executable: bool,

    /// If clear this is a system segment like the TSS. If unset this is a code
    /// or data segment.
    system: bool = true,

    /// THe ring level this segment operates in
    privilege: u2,

    /// Is this segment currently loaded in memory.
    present: bool = true,
};

/// The flag field of a GDT table
const Flags = packed struct(u4) {
    _padding: u1 = 0,

    /// Is this a long mode segment
    long_mode: bool = false,

    /// Is this segment in 32 bit mode? If not it's in 16 bit mode
    is_32_bit: bool = true,

    /// The scale of the limit. When set in pages, else in bytes.
    granularity: bool = true,
};

const GdtEntry = packed struct(u64) {
    /// The lower 16 bits of the limit.
    limit_low: u16,

    /// The lower 24 bits of the base address.
    base_low: u24,

    access: AccessByte,

    /// The upper 4 bits of hte limit.
    limit_high: u4,

    /// The flag bits
    flags: Flags,

    /// The upper 8 bits of the base address.
    base_high: u8,

    /// Creates a new `GdtEntry`, parising it into its correct structure.
    pub fn new(base: u32, limit: u20, flags: Flags, access: AccessByte) GdtEntry {
        return .{
            .limit_low = @truncate(limit),
            .limit_high = @truncate(limit >> 16),

            .base_low = @truncate(base),
            .base_high = @truncate(base >> 24),

            .access = access,
            .flags = flags,
        };
    }
};

pub const GdtPtr = packed struct {
    /// Number of entries in the table - 1.
    limit: u16,
    /// The base address of the GDT
    base: u32,
};

fn lgdt(ptr: *const GdtPtr) void {
    // Load the table into the CPU
    asm volatile (
        \\lgdt (%%eax)
        \\movw $0x10, %%bx
        \\movw %%bx, %%ds
        \\movw %%bx, %%es        
        \\movw %%bx, %%fs         
        \\movw %%bx, %%gs    
        \\movw %%bx, %%ss
        \\
        \\pushl $0x8
        \\pushl $1f
        \\lret
        \\1:
        :
        : [_] "{eax}" (ptr),
        : .{ .bx = true });
}

var gdt_entries = init: {
    var res: [5]GdtEntry = undefined;

    res[0] = std.mem.zeroes(GdtEntry);

    // Kernel code segment
    res[1] = GdtEntry.new(
        0x0,
        0xFFFFF,
        .{ .is_32_bit = true },
        .{
            .read_write = true,
            .dc = false,
            .executable = true,
            .privilege = 0,
        },
    );

    // Kernel data segment
    res[2] = GdtEntry.new(
        0x0,
        0xFFFFF,
        .{},
        .{
            .read_write = true,
            .dc = false,
            .executable = false,
            .privilege = 0,
        },
    );

    // User code segment
    res[3] = GdtEntry.new(
        0x0,
        0xFFFFF,
        .{},
        .{
            .read_write = true,
            .dc = false,
            .executable = true,
            .privilege = 3,
        },
    );

    // User data segment
    res[4] = GdtEntry.new(
        0x0,
        0xFFFFF,
        .{},
        .{
            .read_write = true,
            .dc = false,
            .executable = false,
            .privilege = 3,
        },
    );

    break :init res;
};

var gdt_ptr: GdtPtr = .{
    .limit = @intCast((gdt_entries.len * @sizeOf(GdtEntry)) - 1),
    .base = undefined,
};

pub fn init() void {
    log.debug("Initializing GDT", .{});
    defer log.debug("Finished initializing GDT", .{});
    gdt_ptr.base = @intFromPtr(&gdt_entries[0]);

    lgdt(&gdt_ptr);
}
