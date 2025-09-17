# Set up the stack
.section .bootstrap_stack, "aw", @nobits
stack_bottom:
.skip 0x4000
stack_top:

# Pre-allocate page dir/table. May need more pages if kernel is larger than 4MB
.section .bss, "aw", @nobits
  .align 0x1000
boot_page_dir:
  .skip 4096
boot_page_table1:
  .skip 4096

.section .multiboot.text, "a"
.global _start
.type _start, @function
_start:
  # Set up our registers
  movl $(boot_page_table1 - 0xC0000000), %edi
  movl $0, %esi
  # Number of pages we want to map, 1024 will be our VGA buffer
  movl $1023, %ecx

1:
  # We loop until our source index reaches our kernel. This does *not* map 
  # anything pages in the page table yet.
  cmpl $_kernel_start, %esi
  jl 2f

  # Check if we've already mapped our entire kernel, if not we proceed
  # Otherwise, jump to setting up VGA and actually mapping our memory
  cmpl $(_kernel_end - 0xC0000000), %esi
  jge 3f

  # Map the pages as "present/writable." This is a security issue since we're also
  # maping .text and .rodata this way but we can handle that later.
  movl %esi, %edx
  orl $0x003, %edx
  movl %edx, (%edi)

2:
  # Move to next page, incrementing both our source and destination
  addl $0x1000, %esi
  addl $4, %edi
  loop 1b

3: 
  # Now that we've mapped our entire kernel, we can handle our VGA memory
  movl $(0x000B8000 | 0x003), boot_page_table1 - 0xC0000000 + 1023 * 4

  # Identity map
  movl $(boot_page_table1 - 0xC0000000 + 0x003), boot_page_dir - 0xC0000000
  # Map to new address
  movl $(boot_page_table1 - 0xC0000000 + 0x003), boot_page_dir - 0xC0000000 + 768 * 4
  
  # Set cr3 to address of our page directory
  movl $(boot_page_dir - 0xC0000000), %ecx
  movl %ecx, %cr3

  # Enable paging and the write-protect bit
  movl %cr0, %ecx
  orl $0x80010000, %ecx
	movl %ecx, %cr0

  # Jump to higher half
  lea 4f, %ecx
  jmp *%ecx

.section .text

4:
  # Now we are in upper half with paging set up
  # Unmap the identity mapping
  movl $0, boot_page_dir

  movl %cr3, %ecx
  movl %ecx, %cr3

  movl $stack_top, %esp
  movl %esp, %ebp

  # Pass the physical address of the multiboot info struct to our
  # kernel so we can handle it in something other than ASM
  pushl %ebx
  call kmain

  cli
  hlt
