const std = @import("std");

pub fn build(b: *std.Build) !void {
    var disabled_features = std.Target.Cpu.Feature.Set.empty;
    var enabled_features = std.Target.Cpu.Feature.Set.empty;

    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.mmx));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse2));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.avx));
    disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.avx2));
    enabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.soft_float));

    const target_query = std.Target.Query{
        .cpu_arch = std.Target.Cpu.Arch.x86,
        .os_tag = std.Target.Os.Tag.freestanding,
        .abi = std.Target.Abi.none,
        .cpu_features_sub = disabled_features,
        .cpu_features_add = enabled_features,
    };

    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.addModule("kernel", .{
            .root_source_file = b.path("kernel/main.zig"),
            .target = b.resolveTargetQuery(target_query),
            .optimize = optimize,
            .code_model = .kernel,
        }),
    });
    kernel.setLinkerScript(b.path("kernel/linker.ld"));
    b.installArtifact(kernel);

    const check_step = b.step("check", "Check that the project compiles");
    check_step.dependOn(&kernel.step);

    const kernel_step = b.step("kernel", "Build the kernel");
    kernel_step.dependOn(&kernel.step);

    const iso_dir = b.fmt("{?s}/iso_root", .{b.cache_root.path});
    const kernel_path = try std.fs.path.join(b.allocator, &[_][]const u8{ b.install_path, "bin", kernel.out_filename });
    const iso_path = b.fmt("{s}/disk.iso", .{b.exe_dir});

    const iso_cmd_str = &[_][]const u8{
        "/usr/bin/env", "bash", "-c", std.mem.concat(b.allocator, u8, &[_][]const u8{
            "mkdir -p ",
            iso_dir,
            "/boot/grub",
            " && ",
            "cp ",
            kernel_path,
            " ",
            iso_dir,
            "/boot",
            " && ",
            "cp grub.cfg ",
            iso_dir,
            "/boot/grub",
            " && ",
            "grub-mkrescue -o ",
            iso_path,
            " ",
            iso_dir,
        }) catch unreachable,
    };

    const iso_cmd = b.addSystemCommand(iso_cmd_str);
    iso_cmd.step.dependOn(kernel_step);

    const iso_step = b.step("iso", "Build an ISO image");
    iso_step.dependOn(&iso_cmd.step);
    b.default_step.dependOn(iso_step);

    const run_cmd_str = &[_][]const u8{
        "qemu-system-i386",
        "-cdrom",
        iso_path,
        "-debugcon",
        "stdio",
        "-vga",
        "virtio",
        "-m",
        "128M",
        "-machine",
        "q35,accel=kvm:tcg",
        "-no-reboot",
        "-no-shutdown",
    };

    const run_cmd = b.addSystemCommand(run_cmd_str);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the kernel in QEMU");
    run_step.dependOn(&run_cmd.step);

    const bochs_cmd_str = &[_][]const u8{
        "bochs",
        "-f",
        ".bochsrc",
        "-q",
        "-debugger",
    };

    const bochs_cmd = b.addSystemCommand(bochs_cmd_str);
    bochs_cmd.step.dependOn(b.getInstallStep());

    const bochs_step = b.step("bochs", "Run the kernel in Bochs");
    bochs_step.dependOn(&bochs_cmd.step);
}
