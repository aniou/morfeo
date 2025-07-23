# MORFE/O
**Meyer's Own Re-combinable FrankenEmulator / Odin version**

Universal emulator framework, capable of emulating various sets
of CPUs, GPUs and memory models. Support for RTC, PS2, PATA included!

## Supported CPUs
- m68k (Musashi Core)
- WDC 65c816
- WDC W65C02S 

# Available platforms
- [a2560x](https://wiki.c256foenix.com/index.php?title=A2560)
- [c256fmx, c256u, c256u+](https://wiki.c256foenix.com/index.php?title=C256)
- test_65c816, test_w65c02s - simple platform for running [SingleStepTests](https://github.com/SingleStepTests)

# Building
At this moment emulator was built and tested on Ubuntu 22.04 LTS and
openSUSE Leap 15.6.

## Prequisites
1. You need a working copy of [Odin](https://odin-lang.org/docs/install/)
   language - follow link and install Odin in preffered way.

   A ``Makefile`` assumes that ``odin`` binary is in Your ``PATH``!

2. A sdl2 development files: ``apt install libsdl2-dev`` or ``zypper
install SDL2-devel``.

3. Clone repo, update submodules and run binary:

```shell
git clone https://github.com/aniou/morfeo
cd morfeo
git submodule init lib/getargs
git submodule init lib/odin-ini-parser
git submodule init external/Musashi
git submodule update
```

4. If You want to run test programs for 65xx-based core then You need two
additional modules. **WARNING:** they need about 20G of additional space!

```shell
git submodule init external/tests-65816
git submodule init external/tests-6502
```

## Available targets
Type ``make`` for for detailed list of targets, select preferred and issue command,
for example ``make c256u+`` will build emulator for C256 U+ platform. Binary will
be located in current directory

```
make a2560x       - build an a2560x emulator
make c256fmx      - build an C256 FMX
make c256u        - build an C256 U
make c256u+       - build an C256 U+

make test_w65c02s - build a test suite for W65C02S
make test_65c816  - build a test suite for 65C816

make clean        - clean-up binaries
make clean-all    - clean-up binaries and object files
```


# Running
# a2560x 

```shell
./a2560x --gpu=1 --disk0 data/test-fat32.img data/foenixmcp-a2560x.hex
```

At this moment only two keys are supported. See for standard output logs
for unsupported functions and not-implemented-yet memory regions!

|Key     |Effect
---------|---------------------------
F8       |Change active head in multi-head setups
F12      |Exit emulator

# c256fmx, c256u, c256u+

Just use command (``c256fmx``, ``c256u``, ``c256u+``). Configuration will
be loaded automagically from default file ``conf/[binaryname].ini``

Particular settings may be overrided by CLI switches. 

Following command will run emulator in low-res mode, even if ``.ini`` file 
has ``DIP6`` set to value ``on``.

```shell
./c256fmx --dip6 off
```

Additional ``hex`` files may be loaded by providing filename after command,
there is no need to change ``ini`` file for every case:

```shell
./c256fmx data/tetris.hex
```

Configuration file may be selected by ``--cfg path_to/file.ini`` switch 
or  bypassed at all by ``--nc`` flag.

There are two additional switches available: ``-d`` and ``-b``. First one
enables disassembler from the start - second one enables debug for writes
and reads on internal bus. 

```shell
./c256fmx -b
...
[DEBUG] --- bus0 read8  0000005f from 0x 0039:0F7B
[DEBUG] --- bus0 read8  0000000f from 0x 0039:0F7C
[DEBUG] --- bus0 read8  00000039 from 0x 0039:0F7D
[DEBUG] --- bus0 write8 00000039   to 0x 0000:FEEF
[DEBUG] --- bus0 write8 0000000f   to 0x 0000:FEEE
[DEBUG] --- bus0 write8 0000007d   to 0x 0000:FEED
[DEBUG] --- bus0 read8  000000ea from 0x 0039:0F5F
[DEBUG] --- bus0 read8  000000ea from 0x 0039:0F60
```

From now a c256-family platforms has configurable ``F1-F12`` keys, see 
files in ``conf/`` directory for examples. Unconfigured keys are passed
to emulator as-is, but configured one are shadowed by GUI, so beware!

There is possibility to load multiple files at one ``load`` command:
just place space-separated names. There is also possible to issue 
multiple commands via single keystroke, by separating them by ``;``.

Default configuration looks like:

|Key     |Effect
---------|---------------------------
F7       |Load and run Daniel's Tremblay Tetris
F8       |Switch between main and EVID-200 GPU
F9       |Enable/disable bus operation dump
F10      |Enable/disable rudimentary disassembler (to be improved)
F11      |Reset 
F12      |Exit emulator
KP 0-9   |Numeric keyboard as joy0 directions, 5 -> Button0, 0 -> Button1

# OF816 Open Firmware inspired FORTH
This project contains copy of version of [OF816](https://github.com/aniou/of816/tree/C256/platforms/C256) 
by [mgcaret](https://github.com/mgcaret). It can be run by simply passing corresponding hex file to c256u+
or c256fmx emulators, it will start automatically:

```
./c256u+ data/of816.hex
```

Running from `c256u` platform requires manual execution by `call 65536` command from BASIC816 level.

# FQA

### Why not morfe (an Go-based)?

Because interfacing C-libraries from Go is cumbersome and excellent m68k
core (Musashi) is written in C.

### But why Odin?!

Because I need some fun too.

### In which areas morfeo is better than morfe?

* clean architecture
* faster
* irq support
* timer support
* current memory map of a2560x platform
* better 65C816 implementation (**new**)
* an W65C02S implementation (**new**)

### In which areas morfeo is worse than morfe?

* lack of debugging tools for code
* ~lack of 65c816 support~
* Golang is more portable 
* more memory leaks

### What about feature XXX?

In future. I have limited resources and morfe/morfeo were created as
development platform for system software, thus lack of support in 
graphics and sound.

At this moment on my short TODO list are:

- [x] RTC
- [x] joy0 via numpad
- [ ] better debug facilities for c256
- [x] tiles for c256 (WIP)
- [ ] modernisation of a2560x to standard (config file etc.) of c256
- [x] EVID 200 (second monitor) extension card

# Hacking

An preliminary documentation about internals is available in 
[doc\internals](https://github.com/aniou/morfeo/blob/master/doc/internals/README.md)
directory. 

A crucial for understanding internal code and way in which modules
are implemented is an [union concept](https://github.com/odin-lang/Odin/blob/master/examples/demo/demo.odin#L577).

See also ``emulator/gpu/gpu.odin``, and routines ``vicky3_make`` 
and ``vicky3_read`` in ``emulator/gpu/gpu_vicky3.odin`` for samples.

# Included software
* [getargs](https://github.com/jasonKercher/getargs) module
* [odin-ini-parser](https://github.com/laytan/odin-ini-parser) module
* [Musashi](https://github.com/kstenerud/Musashi) core
* a ``hex.odin`` file imported (and tweaked) from Odin core library 
* [C256 Tetris](https://github.com/dtremblay/c256-tetris) binary by Daniel Tremblay
* copy of [official MFX/U/U+ kernel](https://github.com/Trinity-11/Kernel_FMX)
* copy of [OpenFirmware compatible FORTH by mgcaret](https://github.com/aniou/of816/tree/C256/platforms/C256)

# Some screenshots

## a2560x with MCP kernel

![splash screen](doc/morfeo-1.png)
![running system](doc/morfeo-2.png)

## c256 FMX with stock kernel

![splash screen](doc/c256-fmx-1.png)
![running system](doc/c256-fmx-2.png)

