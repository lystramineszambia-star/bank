ENTRY(_start)
SECTIONS
{
  . = 0x00100000;              /* load/phys addr */
  .text : { (.text) }
  .rodata : { (.rodata) }
  .data : { (.data) }
  .bss : {
    (.bss)
    *(COMMON)
  }
}