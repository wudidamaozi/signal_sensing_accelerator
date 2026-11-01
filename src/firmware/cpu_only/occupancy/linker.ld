ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 128K
}

SECTIONS
{
    . = ORIGIN(RAM);

    .text :
    {
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
    } > RAM

    .data :
    {
        *(.data*)
        *(.sdata*)
    } > RAM

    .bss (NOLOAD) :
    {
        *(.bss*)
        *(.sbss*)
        *(COMMON)
    } > RAM

    _image_end = .;
    ASSERT(_image_end <= ORIGIN(RAM) + LENGTH(RAM), "firmware exceeds 16 KiB local memory")
}
