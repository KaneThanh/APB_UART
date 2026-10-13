ENTRY(_start)
MEMORY { ram (rwx) : ORIGIN = 0x00010000, LENGTH = 65536 }
SECTIONS {
  .entry 0x00010000 : { KEEP(*(.entry)) } > ram
  .exceptions 0x00010020 : { KEEP(*(.exceptions)) } > ram
  .text : { *(.text.start) *(.text*) *(.rodata*) } > ram
  .data : { *(.data*) *(.sdata*) } > ram
  . = ALIGN(4);
  _gp = . + 0x7ff0;
  .bss (NOLOAD) : {
    __bss_start = .;
    *(.bss*) *(.sbss*) *(COMMON)
    . = ALIGN(4); __bss_end = .;
  } > ram
  _stack_top = ORIGIN(ram) + LENGTH(ram) - 16;
  ASSERT(__bss_end < _stack_top - 4096, "Firmware overlaps stack")
}
