.section .entry,"ax"
.global _start
_start:
    br reset_entry
.section .exceptions,"ax"
exception_stop:
    br exception_stop
.section .text.start,"ax"
reset_entry:
    wrctl status, zero
    movia sp, _stack_top
    movia gp, _gp
    movia r4, __bss_start
    movia r5, __bss_end
1:
    bgeu r4, r5, 2f
    stw zero, 0(r4)
    addi r4, r4, 4
    br 1b
2:
    call main
3:
    br 3b
