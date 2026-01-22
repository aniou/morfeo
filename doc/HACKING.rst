
General schema
===============================================================================

Emulator itself is divided into two parts - a frontend (GUI) 
and backend (machine itself). Usually a GUI part relies on the
internals of machine - for example on bitmap buffers that
are created inside a GPU device - but machine part can be used
without any GUI interface.

Every machine consist of following parts: the main is a *platform*
that represents a particular machine type: C256, F256 and so on::
 
            (shorcut)
        ┌────────────────┐
        │                ↓
    platform ──➔ cpu ─> bus ─┬─> ram
                             ├─> gpu ──┐
                             ├─> rtc ──┤
                             ├─> kbd ──┤
                             ├─> ps2 ──┤
                             │   ...   │
                             └─> pic <─┘


The shortcut ``platform->bus`` is a matter of convenience. It is
a lot easier to type ``p.bus->read()`` than ``p.cpu0.bus->read()``,
especially when we are coming to multiple CPUs on single bus:
"via which one should I write when I need to upload a simple file
into memory from GUI level?"

In theory nothing prevents us before creating a platform with two,
separate buses - there is only a one thing, that is hard-coded in
a mechanisms of most programming languages: cycles are absolutely
forbidden! Because of that a communication is one-way: a cpu can
communicate with devices via bus but a devices can not communicate
to CPU because it leads to a cyclic dependency in code.

We can go around that in way that is used for a PIC (programmable
interrupt controler) module: a devices, that needs to signal IRQs
have a pointer to ``pic`` passed during creation and they calling
it directly (via ``pic->trigger(irq)`` routine).

Processor itself is pooling a ``pic`` in fixed intervals to check,
if there is a pending interrupts and - sometimes - to sets a flags
in ``pic`` itself.


A (not so) common nomenclature
===============================================================================

In theory, across the emulator, every variable should be created
in the same names:

``ra``
    Requested Address, address issued by CPU or user to BUS
    ``ra`` is usually passed to device as additional param,
    to improve debug messages (because all addresses used at
    device level are relative and starts from 0, regardless
    of device position in computer memory)

``ea``
    Effective Address, address after all calculations at BUS level. 

``addr``
    An internal address of device, usually subtraction between
    ``ea`` and "base" memory address. It allows to count every
    cell in device drivers from 0, regardless of it place in
    memory. Calculated at BUS level

``out`` 
    Returned value, usually from write() routines

``val``
    Argument value, usually for  read() routines

