const PageDirEntry = @import("vmem.zig").PageDirEntry;

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

const KERNEL_ADDR_OFFSET = 0xC0000000;

/// The first page in our PD that our kernel will be mapped to
/// (not including identiry map)
const KERNEL_PAGE_NUMBER = KERNEL_ADDR_OFFSET >> 22;

// TODO: Make this automatic
/// The number of pages to be mapped
const KERRNEL_NUM_PAGES = 1;

/// The page directory used during early stages of the kernel.
// NOTE: When using this in lower half, make sure you subtract the kernel offset.
export var boot_page_dir: [1024]PageDirEntry align(4096) = init: {
    var dir = [_]PageDirEntry{.{ .int = 0 }} ** 1024;

    // Identity mapping for the first 4 MB of mem
    dir[0] = PageDirEntry{ .page = .{
        .present = true,
        .writable = true,
        .is_user_page = false,
        .wt_enabled = false,
        .cache_disabled = false,
        .accessed = false,
        .dirty = false,
        .global = false,
        .addr = 0,
    } };

    var i = 0;
    var idx = KERNEL_PAGE_NUMBER;

    // Map kernel pages
    while (i < KERRNEL_NUM_PAGES) : ({
        i += 1;
        idx += 1;
    }) {
        dir[idx] = PageDirEntry{
            .page = .{
                .present = true,
                .writable = true,
                .is_user_page = false,
                .wt_enabled = false,
                .cache_disabled = false,
                .accessed = false,
                .dirty = false,
                .global = false,
                // Map 4 MB (i << 22) bytes then prune the lower 12 bytes (i >> 12)
                .addr = i << 12,
            },
        };
    }

    break :init dir;
};

/// Primary entry point for x86 systems. Sets up our page table and then jumps into higher half
export fn _start() align(16) linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\mov %[page_dir], %%cr3
        // Enable PSE
        \\mov %%cr4, %%ecx
        \\or $0x10, %%ecx
        \\mov %%ecx, %%cr4

        // Enable paging
        \\mov %%cr0, %%ecx
        \\or $0x80000000, %%ecx
        \\mov %%ecx, %%cr0
        // Jump to higher half
        \\jmp jump_higher_half
        // We subtract here to map it back to physical memory since this is
        // linked in the upper half of our kernel
        :
        : [page_dir] "{ecx}" (@intFromPtr(&boot_page_dir) - KERNEL_ADDR_OFFSET),
    );
}

/// Sets up the kernel stack and calls kmain
export fn jump_higher_half() callconv(.naked) noreturn {
    asm volatile (
        \\.extern kmain
        // Set up stack
        \\mov $KERNEL_STACK_END, %%esp
        \\sub $32, %%esp
        \\mov %%esp, %%ebp
        // Call kmain
        \\push %%ebx
        \\call kmain
    );
}
