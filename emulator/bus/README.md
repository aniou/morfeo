
# BUS implementation

Bus provides an layer for routing memory read/writes to appropriate
devices (RAM, GPU etc.). There are different implementations for
different platforms.

Current implementation, build around set of case statements is the
simplest possible.

Performance: O(n) where n = number of memory segments but maybe there 
is a room for compiler optimizations?



## Alternative implementations

### array of pointers and vtables

That one was used in Go-based emulator: whole memory was divided to
16-byte regions (arbitrary) and resulting table contains pointers to
particular devices (RAM, GPU). In Odin case there are two possibilities
to achive that:

1. Use function overloading like `read8`:

```odin
read8 :: proc {
  gpu.read8,
  cpu.read8,
}

// init
lookup_table[address >> 4] = gpu_pointer  

// call
read8(lookup_table[addres >> 4], addr)
```


- thus, there is a quirk: `gpu.read8` is already overloaded and it was
not tested.

2. Use vtables and call 

Example taken from Odin's discord

```odin
package foo

import "core:fmt"

Foo :: struct {
    print: proc(foo: ^Foo),
    bar: int,
}

make_foo :: proc(bar: int) -> (res: ^Foo) {
    res = new_clone(Foo{
        print = print_foo,
        bar   = bar,
    })
    return
}

print_foo :: proc(foo: ^Foo) {
    fmt.printf("%#v\n", foo)
}

main :: proc() {
    f := make_foo(42)
    f->print()
}
```

and use it in following way:

```
// init
lookup_table[address >> 4] = gpu_pointer  

// call
lookup_table[addres >> 4]->read8(addr)
```

3. Separated functions for particular areas

Something like that (not tested):

```
// init
read8_lookup_table[0x0000] = ram.read8(ram_pointer: ^RAM, addr u32) -> u8

// call
result = lookup_table[addres >> 4](ram_pointer, addr)
```

Performance: O(1)

### use two arrays for denote range

Like `[dynamic]start_mem`, `[dynamic]end_mem` and `[dynamic]read8_lookup`:

```
start      end
0000       E000
F000       FFFF

```

```
for index len(end_mem) {
  if addr < end_mem[index] {
    if addr < start_mem[index] {
        // error - no region defined
        // in example above there is a hole between E000-EFFF
        // and addr = EF00 will match here
    } else {
        // make the call to read8_lookup[index]
    }

  }
```

Performance: O(n*2), where n=memory_segments
             O(n) if all segments (also unused) will be defined.

### use case to get pointer and return them to read8/write8

In this case there will be a less typing due to avoiding separate
cases for read8/write8/whatever() but it is probably worth nothing.



