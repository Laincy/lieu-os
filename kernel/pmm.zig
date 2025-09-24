const std = @import("std");
const log = std.log.scoped(.pmm);

extern const KERNEL_PHYSADDR_START: *u32;
extern const KERNEL_VADDR_START: *u32;
extern const KERNEL_VADDR_END: *u32;

pub const PmmError = error{InvalidFlags};

// FIXME: Genuine clusterfuck in here, split this up a bit and maybe write
// a unit test instead of praying I got it right.

pub fn init(mbi_addr: u32) PmmError!PageAllocator {
    log.info("Initializing PMM", .{});
    defer log.info("Finished initializing PMM", .{});

    if (@as(*u32, @ptrFromInt(mbi_addr)).* & (1 | (1 << 6)) == 0) return error.InvalidFlags;

    // Our total memory in bytes
    const mem_bytes = 1024 * (@as(*u32, @ptrFromInt(mbi_addr + 4)).* + @as(*u32, @ptrFromInt(mbi_addr + 8)).* + 1024);
    log.debug("Memory found: 0x{X:0>8} bytes", .{mem_bytes});

    // The end of memory mapped up into the upper half
    // const kernel_mapped_end = std.mem.alignForward(u32, @intFromPtr(&KERNEL_VADDR_END), 0x400000);
    const kernel_page_end = std.mem.alignForward(u32, @intFromPtr(&KERNEL_VADDR_END), 0x4000);

    var alloc = PageAllocator.init(@ptrFromInt(kernel_page_end), mem_bytes);

    // NOTE: This assumes that all MMAP entries have a size of 24 bytes
    // (20 byte minimum + 4 byte size). This may not always be the case

    const mmap_len = @as(*u32, @ptrFromInt(mbi_addr + 44)).* / @sizeOf(MmapEntry);
    const mmap_addr = @as(*u32, @ptrFromInt(mbi_addr + 48)).*;
    const mmap_entries = @as([*]MmapEntry, @ptrFromInt(mmap_addr))[0..mmap_len];

    for (mmap_entries, 0..) |entry, i| {
        const start: u32 = @truncate(entry.base_addr);
        const entry_t = entry.type;

        log.debug("Entry {d}: 0x{X:0>8} - 0x{X:0>8} Bytes ({f})", .{ i, start, entry.length, entry_t });

        if (entry_t != .Free and entry.length < 0xFFFFFFFF) {
            alloc.setRange(start, @truncate(entry.length));
        }
    }

    const kernel_len: u32 = kernel_page_end - @intFromPtr(&KERNEL_VADDR_START);

    log.debug("Allocating {d} pages of kernel memory, starting at 0x{X:0>8}", .{ kernel_len >> 12, @intFromPtr(&KERNEL_PHYSADDR_START) });

    alloc.setRange(@intFromPtr(&KERNEL_VADDR_START), kernel_len);

    return alloc;
}

const MmapEntry = extern struct {
    size: u32,
    base_addr: u64,
    length: u64,
    type: MmapType,
};

const MmapType = enum(u32) {
    /// Memory that can be used as the kernel wants. This does not mean
    /// that nothing is here, the kernel itself is loaded into this memory.
    Free = 1,
    /// Usable memory that contains ACPI information. The kernel shouldn't
    /// write over this until it's used it.
    Acpi = 3,
    /// Memory that must be preserved on hibernation
    Hiber = 4,
    /// Defective RAM sticks.
    Defective = 5,
    _,

    pub fn format(this: MmapType, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        _ = switch (this) {
            .Free => try writer.write("Free"),
            .Acpi => try writer.write("Acpi"),
            .Hiber => try writer.write("Hibernate"),
            .Defective => try writer.write("Defective"),
            _ => try writer.write("Reserved"),
        };
    }
};

/// A page allocator that uses a buddy allocator.
pub const PageAllocator = struct {
    /// The backing bitmaps, lower blocks are more fine grained.
    bitmaps: [levels][]u8,

    /// The size of each block in bytes
    const block_size: usize = 0x1000;

    /// The number of bitmap levels
    const levels: usize = 7;

    fn init(region_ptr: [*]u8, mem_bytes: u32) PageAllocator {
        var region = region_ptr;

        log.debug("Initializing buddy allocator starting at 0x{X:0>8}...", .{@intFromPtr(region)});
        var bitmaps: [levels][]u8 = undefined;

        var bitmap_len = (mem_bytes / 0x1000) / 8;

        for (0..levels) |i| {
            bitmaps[i] = region[0..bitmap_len];

            @memset(bitmaps[i], 0);

            region += bitmap_len;

            bitmap_len /= 2;
        }

        log.debug("Finshed initializing buddy allocator, ended at 0x{X:0>8}", .{@intFromPtr(region)});
        return .{ .bitmaps = bitmaps };
    }

    /// Sets values in a range as occupied
    fn setRange(self: *PageAllocator, start: u32, length: u32) void {
        const max_page: u32 = self.bitmaps[0].len <<| 3;

        var start_page: u32 = std.mem.alignBackward(u32, start, 0x1000) >> 12;
        var end_page: u32 = @min(std.mem.alignBackward(u32, start +| length, 0x1000) >> 12, max_page);

        if (start_page > max_page) {
            log.warn("Tried to map page outside of range", .{});
            return;
        }

        std.debug.assert(start_page < end_page);

        for (self.bitmaps) |bitmap| {
            const start_bit: u3 = @truncate(start_page);
            const end_bit: u3 = @truncate(end_page);

            start_page = start_page >> 3;
            end_page = end_page >> 3;

            bitmap[start_page] |= @as(u8, 0xFF) << start_bit;

            bitmap[end_page] |= @as(u8, 0xFF) >> (7 - end_bit);

            if (start_page < end_page) {
                @memset(bitmap[start_page + 1 .. end_page], 0xFF);
            }
        }
    }
};
