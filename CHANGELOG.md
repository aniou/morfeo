# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2025-08-05
- a brand new ps/2 model - with proper support for modes
  1, 2 and 3 and keycodes queue. FUZIX now works with VT

## 2025-08-01
- writing support for PATA added. Beware: don't trust it
  too much, always backup your data!

## 2025-07-30
- large upgrade of PATA emulation code, now it is able to 
  handle disk operation from FUZIX too

## 2025-07-25
- a2560x: add kind of pseudo-tty, that works only on Linux.
  During a start driver allocates pts and prints it on screen,
  for example `/dev/pts/7`. After that we can assign to that
  pts by command `screen /dev/pts/7` and see characters sent
  to COM2 (0xFE_C0_22F8). It should make porting comples OS-es
  easier due to availability of early-kernel-console-output.

## 2025-07-23
- finished RTC implementation of bq4802 RTC timer, only one
  things missed are Daylight Saving Time function and Watchdog,
  see comments in code for explanation.

  If someone wants FUZIX on a2560x there is the Time.

## 2025-07-20
- a2560x, c256: handling ps2 keycodes when CPU/IRQ is too slow.

  In that case codes are enqueued in GUI and passed again as soon
  as it is possible. Additional IRQ is triggered on every try.

  It doesn't look nice, but missing keys during typing in c256
  is far worse.

- 65xxxx emulation: pity mistake, that causes weird jumps after
  interrupt call - internal 'index' register of virtual address
  bus was not cleared...

## 2025-07-12
- a2560x: model/submodel/version support 
- general: CHANGELOG introduced

