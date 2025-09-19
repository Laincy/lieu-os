/// Contains information from the BIOS that's passed to the kernel as a pointer in EBX.
///
/// https://www.gnu.org/software/grub/manual/multiboot/multiboot.html#Boot-information-format
pub const MultibootInfo = packed struct {
    flags: u32,

    mem_lower: u32,
    mem_upper: u32,

    boot_device: u32,

    cmdline: u32,

    mods_count: u32,
    mods_addr: u32,

    syms: u96,

    mmap_length: u32,
    mmap_addr: u32,

    drivers_length: u32,
    drivers_addr: u32,

    config_table: u32,

    boot_loader_name: u32,

    apm_table: u32,

    vbe_control_info: u32,
    vbe_mode_info: u32,
    vbe_mode: u16,
    vbe_interface_seg: u16,
    vbe_interface_len: u16,

    framebuffer_addr: u48,
    framebuffer_pitch: u32,
    framebuffer_width: u32,
    framebuffer_height: u32,

    framebuffer_bpp: u8,
    framebuffer_type: u8,
    color_info: u48,
};

