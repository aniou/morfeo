
===============================================================================
Implementation of ADC and SBC operands on 65xx family
===============================================================================

:Author:  Piotr Meyer
:Contact: [firstname.lastname]@gmail.com
:Address: 

Introduction
-------------------------------------------------------------------------------
ADC and SBC commands are considered as most cumbersome and complicated 
ones to emulate, thanks to BCD mode and subtle differences in handling
in different flavours of CPU (6502, W65C02, 65C816 in both modes).

Fortunately, there are numerous valuable documents, available in Internet,
see "Bibliography" part - but available algorithms are still complicated
and there is a room to improve their clarity.

In this document I want to show a my attempt to achieve balance between
mathematical abstract of BCD algorithm, like in [Clar2016]_ and strict
simulation of individual logic gates. I want code, that should be self
-documenting and reflects logical steps and blocks of CPU but is also
readable and because of that we are doing a simple math ('+') in place
of series XOR's on particular bits.

Some basics
-------------------------------------------------------------------------------
Although there are two commands: SBC that means 'SuBtract with Carry' and
ADC, 'ADd with Carry', CPU itself uses only one kind of logical blocks for
that operation: set of binary adders alongside with two decimal correction
gratings. In 6502 we have a two 4-bit adders, probably 65C816 has four,
because of support of 16-bit numbers, but there is no available schemas of
65C02/65C816 because of intellectual property protection.

.. note:: Those, interested in details should take a look at article about MOS 
          Binary/BCD adder patent [Sang2019]_ and at patent itself: [6502adder]_.

The subtraction operation is possible due to specific property of binary system:
the subtraction of two arguments: ``arg1`` - ``arg2`` may be replaced by addition 
of ``arg1`` and `two's complement`_ of ``arg2``.

Procedure of calculation two's complement is simple: we need to flip (invert) all
bits in argument and then **add one to that argument**, ignoring any overflow, so
operation like ``09 - 02`` we can implement in following way::

  arg1 (09)      : 1001   <= our first argument
  arg2 (02)      : 0010
  arg2 xor F     : 1101
  arg2 xor F + 1 : 1110   <= our second argument

Math::

     1001  (09)
  +  1110  (two's complement of 2)   
    -----
     0111  (07)

In that way CPU is able to handle both subtraction and addition with single set
of logic gates: although I implemented two, separate - but similar - routines.
It was intentional - there is a possibility to create single one, universal
procedure, but I wanted to simplify things to bare minimum to give a simple way
to understanding whole process - and more universal code, created with DRY 
principle, would require extra booleans and conditions that would have negative
impact on clarity.

Following routines passes all available tests ([SSTest]_, [6502func-ca65]_) for
65C02 and 65C816 in native and emulation mode. They were not tested on MOS6502
behaviour, although there is a possibility to improve that situation in future.

Just for convenience we use a 32-bit variables for 16-bit (65c816) operations,
because it is easy to test overflow (carry) by testing bit 9 or 17 (for 16bit), 
thus we need vars of size larger that size of arguments.

Variables
-------------------------------------------------------------------------------
b0-b3
  A sum of 4-bit binary addition (subtraction)

d0-d3
  Result of decimal correction (if required) or simply copy of ``b0-b3``
  result, it represents a block diagram of adder: adder -> correction -> A

bc0-bc3
  Binary Carry status

dc0-dc3
  Decimal Carry status: it has effect only in two cases: 

  a) decimal add
  
  b) additional decimal carry in subtract on physical 65C02 (but not on
     emulated one!)

real6502
  Emulator-specific variable that denotes "real" 65C02 not emulated-one,
  is has meaning for digital carry application, specific for that one model

f.D, f.C, f.N, f.Z
  CPU status flags

r.A
  A register (accumulator)

Coding convention
-------------------------------------------------------------------------------
Following code is written in `Odin`_ - but code itself is so simple that can 
be translated in 1:1 to almost any language and reader may treat it as kind of 
pseudocode.

The routines uses a simple coding convention, when syntax like ``a += 1`` 
means ``a = a + 1`` and operators like ``&``, ``|``, ``~`` correspond to
bitwise ``and``, ``or`` and ``xor``.

There are number of operations like ``b0 &= 0x000f`` when we are clearing
unused bits that have no equivalent in CPU but are necessary in general
programming language with variables larger than 4-bits.

The code itself is a more redundant that is may be, but I wanted to show
clear and very simple path of doing things.

A single conditional in form ``val1  if   condition  else val2`` should be
read as: `if condition is true use val1 - else use val2`. In some cases
code like ``b0 += 0x0006 if something else 0`` may be replaced by more
familiar ``if something { b0 += 0x0006 }`` but former construct provides
more - in my opinion - pleasant notation: more regular, more like a set 
of assembly instructions.  It is only a matter of aesthetics, though.

ADC
-------------------------------------------------------------------------------

SBC
-------------------------------------------------------------------------------

 ::

    ar1      := [8 bit value]
    ar2      := [8 bit value]

    // first 4 bits -----------------------------------------------------------
    // step 1b: prepare arguments
    b0        = ar1 & 0x000f
    tmp      := ar2 & 0x000f
    tmp      ~=       0x000f

    // step 2 : add values and carry
    b0       += tmp
    b0       +=       0x0001 if  f.C                   else 0

    // step 4b: check carry
    bc0       = b0 >  0x000f
    f.C       = bc0

    // step 5b: digital correction and digital carry
    d0        = b0  & 0x000f
    d0       -=       0x0006 if !f.C & f.D             else 0
    
    dc0       = d0  > 0x000F
    d0       &=       0x000f

    // second 4 bits -----------------------------------------------------------
    b1        = ar1 & 0x00f0
    tmp       = ar2 & 0x00f0
    tmp      ~=       0x00f0

    b1       += tmp
    b1       +=       0x0010 if  f.C                   else 0
    bc1       = b1 >  0x00f0
    f.C       = bc1

    d1        = b1  & 0x00f0
    d1       -=       0x0060 if !f.C & f.D             else 0
    d1       -=       0x0010 if  dc0 & f.D & real65c02 else 0
    dc1       = d1  > 0x00F0
    d1       &=       0x00f0

    // ------------------------------------------------------------------------
    a.val     = u16(d1 | d0)
    f.V       = test_v(a.size, ar1, ~ar2, b1)
    f.N       = test_n( a )
    f.Z       = test_z( a )




More accurate emulation of process
-------------------------------------------------------------------------------


Bibliography
-------------------------------------------------------------------------------

.. [Clar2016] Bruce Clark (2016) 

   "Decimal Mode"

   http://www.6502.org/tutorials/decimal_mode.html


.. [Sang2019] Kevin Sangeelee (2019)          

   "The MOS 6502’s Parallel Binary/BCD Adder patent"

   https://www.susa.net/wordpress/2019/05/the-mos-6502s-parallel-binary-bcd-adder-patent/


.. [Clark2004] Bruce Clark (2004)

   "The Overflow (V) Flag Explained"

   http://www.6502.org/tutorials/vflag.html


.. [Shir2012] Ken Shirriff (2012)

   "The 6502 overflow flag explained mathematically"

   http://www.righto.com/2012/12/the-6502-overflow-flag-explained.html


.. [Muel2006] Dieter Mueller (2006)

   "BCD / A simple implementation"

   http://6502.org/users/dieter/bcd/bcd_2.htm


.. [SSTest] Tom Harte (2024)

   "SingleStepTests / ProcessorTests"

   https://github.com/SingleStepTests


.. [6502func] Bruce Clark, Klaus Dorman and others

   "6502_65C02_functional_tests"

   https://github.com/Klaus2m5/6502_65C02_functional_tests


.. [6502func-ca65] Bruce Clark, Kalus Dorman and uknown

   "6502_65C02_functional_tests for CA65"
   
   https://github.com/Kowloon-walled-City/6502_65C02_functional_tests


.. [6502adder] Jed Margolin (2001)

   "A Word (or more) about the 6502"

   http://www.jmargolin.com/patents/6502.htm

   patent itself: http://www.jmargolin.com/patents/3991307.pdf

.. _`two's complement`: https://en.wikipedia.org/wiki/Two%27s_complement
.. _`Odin`:             https://odin-lang.org/
