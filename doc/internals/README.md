
# MORFE/O structure

```
   program +-→ GUI
           |    ↓
           +-→ platform --→ CPU
                      |      ↓ 
                      +---→ BUS ------→ PIC
                             |           ↑
                             +--+→ ATA --+
                                +→ PS2 --+
                                +→ RTC --+
                                +→ GPU --+
                                   ...
```

## notable modules

#### program

Main binary (``c256fmx``, ``a2560x``) responsible for parsing
parameters, setting flags and so on - I'm trying to keep it
so much separated from GUI routines as possible - it may be
an important factor when different GUI backends comes to play
It is also responsible for calling CPU (or stopping/starting
when it is implemented as separate thread) and GPU rendering

#### GUI

SDL2-based routines, responsible for displaying screen and 
handling keys and mouse. It retains pointer to ``platform``
routine for direct access to ``ps2`` module (for sending 
keycodes and events) and ``GPU`` module (for rendering)

#### platform

a place when all components are created at start and 
destroyed at quit plus some extra routines for reading 
files into memory and preparing initial state of machine
(for example - copying part of "flash" into ram)
Platform has CPU directly attached because attaching CPU
to BUS will lead to cyclic dependencies (CPU itself rely
on the BUS to access to memory and selected devices)

#### CPU

processor routines itself - they connect to different parts
via BUS and - directly - to PIC. Again: that structure gave
cyclic-free dependency because devices cannot be both accesible
via BUS and access PIC via BUS itself due to circular deps,
that make various programming languages hairy.

#### BUS

a place when access calls are routed to different parts of
emulator, responsible for so-called "memory maps" of machines
Previous versions were dynamic and devices were attached to
memory regions at will, but static dispatch wins as much
performant and simplest solution for machines with large amount
of RAM.
Current implementation of BUS in c256-related platforms is also
responsible for maintaning DMA routines

#### PIC

A very simple interrupt controller that is being triggered by
various other devices and polled by CPU to check if any IRQ line
was up in meantime
At this moment (2025-06-20) PIC is very a2560x-centric and that
few interrupts in c256 is handled via simple translation a2560x
IRQ names to C256-ones. It is something that I wan fix in future.

