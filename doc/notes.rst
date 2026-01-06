
C256 Foenix (Original) = VICKY + GAVIN + BEATRIX
C256 FMX - VICKY II & GABE (GABE = GAVIN + BEATRIX)
U/U+ - FAT VICKY II (FAT = GAVIN + VICKY II + BEATRIX are together)
A2560K - FAT VICKY III (FAT = GAVIN + VICKY III + BEATRIX are together)
Gen X - FAT VICKY III

There are differences in memory map and registers between models.  Many changes
have occurred within Vicky.  Tile registers moved between Vicky-I and Vicky-II;
Scrolling of Tiles was added in Vicky-II; Bitmaps changed in Vicky-II; Sprites
changed in Vicky-II.  Since Vicky-I seems to be obsolete, I wouldn't worry too
much about the significant changes that occurred in Vicky-II.  I seem to recall
seeing additional change being planned for Vicky-III.  The Define files are
your best bet to understand changes that have occurred within the FPGAs.  For
kernel changes, the best place to identify the changes seems to be within the
kernel source.  Look for TARGET_SYSTEM references.  Example...

.if ( TARGET_SYS == SYS_C256_FMX ) || ( TARGET_SYS == SYS_C256_U_PLUS )
; Key memory areas for the Foenix FMX
  START_OF_FLASH := $380000                   ; The Foenix FMX Flash starts at $380000
  START_OF_KERNEL := $390400                  ; The kernel itself starts at $390400
  START_OF_BASIC := $3A0000                   ; The BASIC flash code starts at $3A0000
  START_OF_CREDITS := $3B0000                 ; The credits screen starts at $3B0000
  START_OF_SPLASH := $3E0000                  ; SplashScreen Code and Data $3E0000
  START_OF_FONT := $3F0000                    ; The font starts at $3F0000
.else
; Key memory areas for the Foenix User
  START_OF_FLASH := $180000                   ; The Foenix U Flash starts at $180000
  START_OF_KERNEL := $190400                  ; The kernel itself starts at $190400
  START_OF_BASIC := $1A0000                   ; The BASIC flash code starts at $1A0000
  START_OF_CREDITS := $1B0000                 ; The credits screen starts at $1B0000
  START_OF_SPLASH := $1E0000                  ; SplashScreen Code and Data $3E0000
  START_OF_FONT := $1F0000                    ; The font starts at $3F0000
.endif




                    RAM = new MemoryRAM(MemoryMap.RAM_START, memSize),                        // RAM: 2MB Rev B & U, 4MB Rev C & U+
                    VICKY = new MemoryRAM(MemoryMap.VICKY_START, MemoryMap.VICKY_SIZE),       // 60K
                    VIDEO = new MemoryRAM(MemoryMap.VIDEO_START, MemoryMap.VIDEO_SIZE),       // 4MB Video
                    FLASH = new MemoryRAM(MemoryMap.FLASH_START, MemoryMap.FLASH_SIZE),       // 8MB RAM
                    GABE = new GabeRAM(MemoryMap.GABE_START, MemoryMap.GABE_SIZE),            // 4K 

                    // Special devices
                    MATH = new MathCoproRegister(MemoryMap.MATH_START, MemoryMap.MATH_END - MemoryMap.MATH_START + 1), // 48 bytes
                    PS2KEYBOARD = new PS2KeyboardRegisterSet1(keyboardAddress, 5),
                    SDCARD = sdcard,
                    INTERRUPT = new InterruptController(MemoryMap.INT_PENDING_REG0, 4),
                    UART1 = new UART(MemoryMap.UART1_REGISTERS, 8),
                    UART2 = new UART(MemoryMap.UART2_REGISTERS, 8),
                    OPL2 = new OPL2(MemoryMap.OPL2_S_BASE, 256),
                    FLOAT = new MathFloatRegister(MemoryMap.FLOAT_START, MemoryMap.FLOAT_END - MemoryMap.FLOAT_START + 1),
                    MPU401 = new MPU401(MemoryMap.MPU401_REGISTERS, 2),
                    DMA = vdma,
                    TIMER0 = new TimerRegister(MemoryMap.TIMER0_CTRL_REG, 8),
                    TIMER1 = new TimerRegister(MemoryMap.TIMER1_CTRL_REG, 8),
                    TIMER2 = new TimerRegister(MemoryMap.TIMER2_CTRL_REG, 8),
                    RTC = new RTC(MemoryMap.RTC_SEC, 16),
                    CODEC = codec,
                    MMU = null

