//! Types and functions for interfacing with IA-32 virtual memory, including PSE.

/// An entry in a page table.
pub const PageTableEntry = packed struct(u32) {
    /// Is this page present in physical memory
    present: bool,

    /// Is this page writable, or only readable? Whether this applies
    /// to kernel space, or only user space, is determined by `cr0`.
    writable: bool,

    /// Controls access to this page. If `true`, then anyone can access it,
    /// otherwise only the "supervisor" can access it.
    is_user_page: bool,

    /// Controls write through caching. If `true`, the page uses write-through
    /// caching, else uses write-back caching.
    wt_enabled: bool,

    /// Whether caching is disabled on this page.
    cache_disabled: bool,

    /// Whether this page entry has been read during virtual address translation/
    accessed: bool,

    /// Whether the page itself has been written to
    dirty: bool,

    /// The page attribute table, not using this atm but maybe later.
    _pat: u1 = 0,

    /// Whether or not to invalidate this page's `TLB` entry or not.
    /// Note that global pages must be enabled in `cr4` for this to
    /// take effect.
    global: bool,

    _avl: u3 = 0,

    /// The upper 20 bits of the physical address this entry maps to
    addr: u20,
};

/// An entry in a page directory that maps to a [PageTableEntry].
pub const PageDirTable = packed struct(u32) {
    /// Is this page present in physical memory
    present: bool,

    /// Is this page writable, or only readable? Whether this applies
    /// to kernel space, or only user space, is determined by `cr0`.
    writable: bool,

    /// Controls access to this page. If `true`, then anyone can access it,
    /// otherwise only the "supervisor" can access it.
    is_user_page: bool,

    /// Controls write through caching. If `true`, the page uses write-through
    /// caching, else uses write-back caching.
    wt_enabled: bool,

    /// Whether caching is disabled on this page.
    cache_disabled: bool,

    /// Whether this page entry has been read during virtual address translation/
    accessed: bool,

    _avl_0: u1 = 0,

    _size: u1 = 0,

    _avl_1: u4 = 0,

    /// The upper 20 bits of a 4 KB aligned address pointing to a page table
    addr: u20,
};

/// An entry in a page directory that defines a 4 MB page in memory. For
/// this to work, PSE must be enabled in `cr4`.
pub const PageDirPage = packed struct(u32) {
    /// Is this page present in physical memory
    present: bool,

    /// Is this page writable, or only readable? Whether this applies
    /// to kernel space, or only user space, is determined by `cr0`.
    writable: bool,

    /// Controls access to this page. If `true`, then anyone can access it,
    /// otherwise only the "supervisor" can access it.
    is_user_page: bool,

    /// Controls write through caching. If `true`, the page uses write-through
    /// caching, else uses write-back caching.
    wt_enabled: bool,

    /// Whether caching is disabled on this page.
    cache_disabled: bool,

    /// Whether this page entry has been read during virtual address translation/
    accessed: bool,

    /// Whether the page itself has been written to
    dirty: bool,

    _size: u1 = 1,

    /// Whether or not to invalidate this page's `TLB` entry or not.
    /// Note that global pages must be enabled in `cr4` for this to
    /// take effect.
    global: bool,

    _avl: u3 = 0,

    /// The upper 20 bits of the physical address this entry maps to
    addr: u20,
};

/// An entry in a page directory.
pub const PageDirEntry = extern union {
    /// A 4 MB page of memory
    page: PageDirPage,
    /// A 4 KB page table
    table: PageDirTable,

    /// As a u32.
    int: u32,
};
