
```
// przy zapisie do pamięci vicky mogę zaznaczyć 'recalculate' i oszczędzić na mocy!
// bo bitmapę będę rysowac od nowa tylko jeśli coś przestanie działać!


00_00_0000  00_3F_FFFF    4 MB ram
00_40_0000  00_7F_FFFF         BUS ERROR
00_80_0000  00_9F_FFFF    2 MB vram a (banked from total 8, not implemented)
00_A0_0000  00_BF_FFFF    2 MB vram b (banked from total 8, not implemented)
00_C0_0000  01_FF_FFFF         BUS ERROR
02_00_0000  03_FF_FFFF   32 MB sdram
---
FE_C0_0000  FE_C1_FFFF         gabe
FE_C2_0000  FE_C3_FFFF         beatrix
FE_C4_0000  FE_C4_7FFF         vicky a registers and tables (details later)
FE_C4_8000  FE_C4_8FFF         font bank 0
FE_C4_9000  FE_C5_FFFF         ???
FE_C6_0000  FE_C6_3FFF         vicky a ram text
FE_C6_8000  FE_C6_BFFF         vicky a ram text color
FE_C6_C000  FE_C6_C3FF         ???
FE_C6_C400  FE_C6_C43F         vicky a Foreground LUT
FE_C6_C440  FE_C6_C47F         vicky a Background LUT
???
FE_C8_0000  FE_C8_7FFF         vicky b registers and tables (details later)
FE_C8_8000  FE_C8_8FFF         font bank 0
FE_C8_9000  FE_C9_FFFF         ???
FE_CA_0000  FE_CA_3FFF         vicky b ram text
FE_CA_8000  FE_CA_BFFF         vicky b ram text color
FE_CA_C000  FE_CA_C3FF         ???
FE_CA_C400  FE_CA_C43F         vicky b Foreground LUT
FE_CA_C440  FE_CA_C47F         vicky b Background LUT
???
FF_C0_0000  FF_FF_FFFF      4 MB flash
```
