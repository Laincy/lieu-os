const mb = @import("multiboot.zig");

const KERNEL_PAGE_NUMBER = 0xC0000000 >> 22;
const KERNEL_NUM_PAGES = 1;

export const boot_page_dir: [1024]u32 align(4096) linksection(".rodata.boot") = init: {
    @setEvalBranchQuota(1024);
    var dir: [1024]u32 = undefined;

    dir[0] = 0x00000083;

    var i = 0;
    var idx = 1;

    while (i < KERNEL_PAGE_NUMBER - 1) : ({
        i += 1;
        idx += 1;
    }) {
        dir[idx] = 0;
    }

    i = 0;
    while (i < KERNEL_NUM_PAGES) : ({
        i += 1;
        idx += 1;
    }) {
        dir[idx] = 0x00000083 | (i << 22);
    }

    i = 0;
    while (i < 1024 - KERNEL_PAGE_NUMBER - KERNEL_NUM_PAGES) : ({
        i += 1;
        idx += 1;
    }) {
        dir[idx] = 0;
    }

    break :init dir;
};

export var kernel_stack: [16 * 1024]u8 align(16) linksection(".bss.stack") = undefined;
extern var KERNEL_ADDR_OFFSET: *u32;

export fn _start() align(16) linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\xchg %%bx, %%bx
        \\mov %[bpd], %%cr3
        \\mov %%cr4, %%ecx
        \\or $0x00000010, %%ecx
        \\mov %%ecx, %%cr4
        \\mov %%cr0, %%ecx
        \\or $0x80000000, %%ecx
        \\mov %%ecx, %%cr0
        \\jmp start_higher_half
        :
        : [bpd] "{ecx}" (&boot_page_dir),
    );

    while (true) {}
}

export fn start_higher_half() callconv(.naked) noreturn {
    asm volatile (
    // Unmap the identity map
        \\movl $0, boot_page_dir
        \\invlpg (0)
        \\mov $KERNEL_STACK_END, %%esp
        \\sub $32, %%esp
        \\mov %%esp, %%ebp
    );

    const mb_info_addr = asm ("mov %%ebx, %[res]"
        : [res] "=r" (-> usize),
    ) + @intFromPtr(&KERNEL_ADDR_OFFSET);

    asm volatile (
        \\.extern kmain
        \\pushl %[mb_addr]
        \\call kmain
        :
        : [mb_addr] "{ebx}" (mb_info_addr),
    );

    while (true) {}
}
