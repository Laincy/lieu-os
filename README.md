*Lieu* is a hobby operating system primarily targeting IA-32 systems. The goal is to be able to run this on a PC I bought off Facebook Marketplace with 1GB of ram and an Intel Pentium 4 Northwood running at 2.66 GHZ. I might expand this to support other architectures, but at the moment I just want to reach user space for this target.

## Why Zig?

I chose Zig as the primary implementation language for a myriad of reasons, namely its allocator API, build system, low level control, and additional safety. Generally, I would have chosen rust for a project that would benefit from safety such as this one, but when working with memory in the way that an OS needs to, I find Zig the better tool. Zig still has lots of safety checks and errors as values, which provide enough safety for me to fee comfortable using it.

The Zig standard library does not link against the C standard library, which allows much more of it to work without an OS. The same cannot be said for the Rust standard library aside from `core` and `alloc`.

## Development

The easiest way to get started is to just run the Nix dev shell. Otherwise, you'll need the following packages:

- Zig 0.15.1
- Grub2
- Xorrsio
- Qemu (Optional, run with `zig build run`)
- Bochs (Optional, run with `zig build bochs`)
